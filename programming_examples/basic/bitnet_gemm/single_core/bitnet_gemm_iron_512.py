#
# This file is licensed under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# (c) Copyright 2026 halo-ai-core / bong-water-water-bong
#
# IRON DSL design — BitNet 1.58 ternary GEMM, Phase-2 (M=K=N=512, single
# AIE2P core, inner tile m=k=n=64).
#
# Key differences vs. Phase-1 (bitnet_gemm_iron.py):
#   - K-reduction loop: outer (M_div_m * N_div_n) tiles, inner K_div_k = 8.
#     C is zeroed once per outer tile, then accumulated across K-blocks
#     in-place (mirrors matmul/single_core/single_core_iron.py).
#   - Weights stream as host-pre-tiled int32 chunks of size (k*n/16) per
#     inner kernel call — host-side pre-tiling deletes the on-tile re-tile
#     pass (the g_w_bf16_tiled triple loop) that Phase-1 paid for.
#   - C tile DMA uses the matmul example's (m/r, r, n/t, t) c_dims layout.
#     A tile DMA uses (m/r, r, k/s, s) a_dims.
#   - Pingpong row-block scheduler (rows_per_block = 4) with task groups,
#     same as matmul/single_core/single_core_iron.py — overlaps DMA with
#     compute on the same core.
#
# Pipeline (per inner kernel call, m = k = n = 64):
#   inA  : bf16   [m * k]              -- activation tile, scale BAKED IN host
#   inW  : int32  [k * n / 16]         -- HALO_V2 packed ternary, host-pretiled
#                                         into (k/s, n/t, 4) i32 microtiles.
#   outC : bf16   [m * n]              -- accumulator (read+write each call)

import argparse
import numpy as np

from aie.iron import Kernel, ObjectFifo, Program, Runtime, Worker
from aie.iron import str_to_dtype
from aie.iron.device import NPU2
from aie.iron.controlflow import range_
from aie.iron.placers import SequentialPlacer
from aie.helpers.taplib import TensorTiler2D


def ceildiv(a, b):
    return (a + b - 1) // b


def main():
    p = argparse.ArgumentParser(
        prog="BitNet 1.58 ternary GEMM Phase-2 (single core, AIE2P, M=K=N=512)",
        description="Emits MLIR for the K-reduction ternary GEMM design.",
    )
    p.add_argument("-M", type=int, default=512)
    p.add_argument("-K", type=int, default=512)
    p.add_argument("-N", type=int, default=512)
    p.add_argument("-m", type=int, default=64)
    p.add_argument("-k", type=int, default=64)
    p.add_argument("-n", type=int, default=64)
    p.add_argument("--trace_size", type=int, default=0)
    args = p.parse_args()
    print(my_bitnet_512(args.M, args.K, args.N, args.m, args.k, args.n,
                        args.trace_size))


def my_bitnet_512(M, K, N, m, k, n, trace_size):
    assert M % m == 0 and K % k == 0 and N % n == 0
    M_div_m = M // m
    K_div_k = K // k
    N_div_n = N // n
    tiles = M_div_m * N_div_n

    # AIE-API mmul shape (bf16, no bfp16 emulation).
    r, s, t = 4, 8, 8
    assert m % r == 0 and k % s == 0 and n % t == 0

    bf16 = str_to_dtype("bf16")
    f32  = str_to_dtype("f32")
    # IRON has no uint32; transport packed weights as i32 (same 32-bit width).
    i32  = str_to_dtype("i32")

    # Tensor types --------------------------------------------------------
    A_ty = np.ndarray[(M * K,),       np.dtype[bf16]]
    W_ty = np.ndarray[(K * N // 16,), np.dtype[i32]]   # 16 codes/i32
    # Output is fp32 inside the AIE tile so the K-reduction running sum
    # holds full precision; host casts to bf16 after drain (see contract
    # in bitnet_gemm_512.cc).
    C_ty = np.ndarray[(M * N,),       np.dtype[f32]]

    a_ty = np.ndarray[(m, k),         np.dtype[bf16]]
    w_ty = np.ndarray[(k * n // 16,), np.dtype[i32]]
    c_ty = np.ndarray[(m, n),         np.dtype[f32]]

    # External kernels ----------------------------------------------------
    obj = f"bitnet_gemm_512_{m}x{k}x{n}.o"
    zero_k   = Kernel("zero_bitnet_f32_512",  obj, [c_ty])
    bitnet_k = Kernel("bitnet_gemm_bf16_512", obj, [a_ty, w_ty, c_ty])

    # Object fifos --------------------------------------------------------
    # A: same r-tiled streaming as the stock matmul example.
    inA = ObjectFifo(a_ty, name="inA")
    a_dims = [(m // r, r * k), (k // s, s), (r, k), (s, 1)]
    memA = inA.cons().forward(name="memA", dims_to_stream=a_dims)

    # W: flat int32 stream — host has already pre-tiled the packed weights
    # into the kernel's expected microtile order, so no on-tile re-tile.
    inW = ObjectFifo(w_ty, name="inW")
    memW = inW.cons().forward(name="memW")

    # C: same r-tiled / t-tiled output layout as matmul.
    memC = ObjectFifo(c_ty, name="memC")
    c_dims = [(m // r, r * n), (r, t), (n // t, r * t), (t, 1)]
    outC = memC.cons().forward(name="outC", dims_to_stream=c_dims)

    # Core task -----------------------------------------------------------
    def core_fn(of_a, of_w, of_c, zero, bitnet):
        for _ in range_(tiles) if tiles > 1 else range(1):
            elem_c = of_c.acquire(1)
            zero(elem_c)
            for _ in range_(K_div_k) if K_div_k > 1 else range(1):
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

    # Pingpong scheduler — same shape as matmul single_core_iron.py.
    rows_per_block = 4

    # A access pattern: for each (m_row), repeat the K-row of m-tiles
    # N_div_n times, mirroring matmul's group_tiler call.
    A_tiles = TensorTiler2D.group_tiler(
        (M, K), (m, k), (1, K_div_k), pattern_repeat=N_div_n,
        prune_step=False,
    )

    # W access pattern: host has laid the packed weight buffer out as a
    # flat i32 array of length (K*N/16) = 16384 i32 = 64 KiB, organised
    # as (K_div_k * N_div_n) microtile-blocks of size (k*n/16) = 256 i32
    # each, in (n_blk-outer, k_blk-inner) order — matching the inner
    # consumption order of the kernel.
    #
    # We declare the W tensor as 2D shape (K_div_k * N_div_n, k*n/16) so
    # one tap = (1, total) walk = 64 chunks * 256 i32 = whole buffer,
    # strides stay sane. The fill is invoked once per m-row pass, so the
    # 64 KiB buffer re-streams M_div_m = 8 times (same idiom as matmul's
    # b_tap re-stream-per-m-row).
    #
    # See pretile_weights_for_kernel() in run_pyxrt_bitnet_512.py for the
    # host pre-tile that lands this layout.
    rows_W = K_div_k * N_div_n
    cols_W = k * n // 16
    W_tiles = TensorTiler2D.group_tiler(
        (rows_W, cols_W),
        (1, cols_W),
        (rows_W, 1),
        prune_step=False,
    )

    C_tiles = TensorTiler2D.group_tiler(
        (M, N), (m, n), (rows_per_block // 2, N_div_n),
        prune_step=False,
    )
    c_index = 0

    rt = Runtime()
    with rt.sequence(A_ty, W_ty, C_ty) as (A, W, C):
        rt.enable_trace(trace_size, workers=[worker])
        rt.start(worker)

        tgs = []
        for tile_row_block in range(ceildiv(M_div_m, rows_per_block)):
            for pingpong in [0, 1]:
                row_base = (
                    tile_row_block * rows_per_block
                    + pingpong * rows_per_block // 2
                )
                num_tile_rows = min(
                    [rows_per_block // 2, M_div_m - row_base]
                )
                if num_tile_rows <= 0:
                    break
                tgs.append(rt.task_group())
                for tile_row in range(num_tile_rows):
                    a_tap_idx = (row_base + tile_row) % len(A_tiles)
                    rt.fill(inA.prod(), A,
                            tap=A_tiles[a_tap_idx], task_group=tgs[-1])
                    # One W tap covers K_div_k * N_div_n inner-tile fills,
                    # i.e., the entire row-of-(n,k)-blocks for this m-row.
                    w_tap_idx = (row_base + tile_row) % len(W_tiles)
                    rt.fill(inW.prod(), W,
                            tap=W_tiles[w_tap_idx], task_group=tgs[-1])

                rt.drain(outC.cons(), C,
                         tap=C_tiles[c_index], task_group=tgs[-1], wait=True)
                c_index += 1

                if tile_row_block > 0 or (
                    tile_row_block == 0 and pingpong > 0
                ):
                    rt.finish_task_group(tgs[-2])
                    del tgs[-2]

        rt.finish_task_group(tgs[-1])
        del tgs[-1]

    prog = Program(NPU2(), rt)
    return prog.resolve_program(placer=SequentialPlacer())


if __name__ == "__main__":
    main()
