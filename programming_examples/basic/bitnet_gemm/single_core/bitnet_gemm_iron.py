#
# This file is licensed under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# (c) Copyright 2026 halo-ai-core / bong-water-water-bong
#
# IRON DSL design for the BitNet 1.58 ternary GEMM single-core example.
#
# Pipeline (per tile, m=k=n=64):
#   inA   : bf16   [m * k]                  -- activation tile, scale BAKED IN
#                                              host-side (A_baked = S * A_raw)
#   inW   : int32  [k * n / 16]             -- HALO_V2 packed ternary weights
#                                              (transported as int32; kernel
#                                              reinterprets to uint32).
#   outC  : bf16   [m * n]                  -- output row sums
#
# Why no inS fifo: AIE2P compute tiles have only 2 input DMA channels;
# acts + weights uses both. Per-row scale folds into A on the host (cheap:
# M floats per tile). Once we move to multi-tile/multi-core we revisit.
#
# Single AIE2P core; for v1 we run a single tile (M=K=N=m=k=n) so there is
# no outer K-reduction loop. Once correctness lands we grow M=K=N=512.

import argparse
import numpy as np

from aie.iron import Kernel, ObjectFifo, Program, Runtime, Worker
from aie.iron.device import NPU2
from aie.iron.controlflow import range_
from aie.iron.placers import SequentialPlacer


def main():
    p = argparse.ArgumentParser(
        prog="BitNet 1.58 ternary GEMM (single core, AIE2P)",
        description="Emits MLIR for a ternary GEMM design.",
    )
    p.add_argument("-M", type=int, default=64)
    p.add_argument("-K", type=int, default=64)
    p.add_argument("-N", type=int, default=64)
    p.add_argument("-m", type=int, default=64)
    p.add_argument("-k", type=int, default=64)
    p.add_argument("-n", type=int, default=64)
    p.add_argument("--trace_size", type=int, default=0)
    args = p.parse_args()
    print(my_bitnet(args.M, args.K, args.N, args.m, args.k, args.n,
                    args.trace_size))


def my_bitnet(M, K, N, m, k, n, trace_size):
    assert M % m == 0 and K % k == 0 and N % n == 0
    M_div_m = M // m
    K_div_k = K // k
    N_div_n = N // n
    tiles = M_div_m * N_div_n
    assert K_div_k == 1, "v1: single K-block (M=K=N=m=k=n=64). Outer K-reduction is Phase 2."

    # Tensor types ---------------------------------------------------------
    A_ty   = np.ndarray[(M * K,),       np.dtype[np.dtype("bfloat16") if False else np.float32]]
    # numpy has no bfloat16; use uint16 for opaque transport at runtime
    # boundary, but the IRON DSL takes a dtype. The aie type is bfloat16
    # via the Kernel signature on the C side; the DSL records it as bf16.
    from aie.iron import str_to_dtype
    bf16  = str_to_dtype("bf16")
    f32   = str_to_dtype("f32")
    # IRON dtype map has no uint32; transport packed weights as i32 (same
    # 32-bit width). The kernel reinterprets via a uint32_t pointer cast.
    i32   = str_to_dtype("i32")

    A_ty  = np.ndarray[(M * K,),       np.dtype[bf16]]
    W_ty  = np.ndarray[(K * N // 16,), np.dtype[i32]]   # 16 codes per i32 word
    C_ty  = np.ndarray[(M * N,),       np.dtype[bf16]]

    a_ty  = np.ndarray[(m, k),          np.dtype[bf16]]
    w_ty  = np.ndarray[(k * n // 16,),  np.dtype[i32]]
    c_ty  = np.ndarray[(m, n),          np.dtype[bf16]]

    # External kernels (compiled from bitnet_gemm.cc -> bitnet_gemm.o) -----
    obj = f"bitnet_gemm_{m}x{k}x{n}.o"
    zero_k   = Kernel("zero_bitnet_bf16",  obj, [c_ty])
    bitnet_k = Kernel("bitnet_gemm_bf16",  obj, [a_ty, w_ty, c_ty])

    # Object fifos ---------------------------------------------------------
    inA = ObjectFifo(a_ty, name="inA")
    # Pre-tile A on the way in: split into r=4 micro-rows, s=8-wide micro-cols.
    r, s, t = 4, 8, 8
    a_dims  = [(m // r, r * k), (k // s, s), (r, k), (s, 1)]
    memA    = inA.cons().forward(name="memA", dims_to_stream=a_dims)

    # Weights stream as flat int32 (uint32 bit pattern); kernel re-tiles.
    inW  = ObjectFifo(w_ty, name="inW")
    memW = inW.cons().forward(name="memW")

    # Output: same dim layout as matmul example (r-tiled rows).
    memC = ObjectFifo(c_ty, name="memC")
    c_dims = [(m // r, r * n), (r, t), (n // t, r * t), (t, 1)]
    outC = memC.cons().forward(name="outC", dims_to_stream=c_dims)

    # Core task ------------------------------------------------------------
    def core_fn(of_a, of_w, of_c, zero, bitnet):
        for _ in range_(tiles) if tiles > 1 else range(1):
            elem_c = of_c.acquire(1)
            zero(elem_c)
            elem_a = of_a.acquire(1)
            elem_w = of_w.acquire(1)
            bitnet(elem_a, elem_w, elem_c)
            of_a.release(1)
            of_w.release(1)
            of_c.release(1)

    worker = Worker(
        core_fn,
        [memA.cons(), memW.cons(), memC.prod(), zero_k, bitnet_k],
        stack_size=0xD00,
    )

    # Runtime: one shot; for v1 tiles==1, so no fancy double-buffering.
    rt = Runtime()
    with rt.sequence(A_ty, W_ty, C_ty) as (A, W, C):
        rt.enable_trace(trace_size, workers=[worker])
        rt.start(worker)
        rt.fill(inA.prod(), A)
        rt.fill(inW.prod(), W)
        rt.drain(outC.cons(), C, wait=True)

    prog = Program(NPU2(), rt)
    return prog.resolve_program(placer=SequentialPlacer())


if __name__ == "__main__":
    main()
