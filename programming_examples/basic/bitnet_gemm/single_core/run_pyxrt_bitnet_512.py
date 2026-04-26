#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
# Copyright (C) 2026, halo-ai-core / bong-water-water-bong.
#
# Phase-2 host runner — BitNet 1.58 ternary GEMM at M=K=N=512 on AIE2P.
#
# This runner does the work the kernel used to do at runtime:
#   (1) Pack ternary weights with HALO_V2 (16 codes per uint32),
#   (2) PRE-TILE the packed weights into the inner-kernel microtile order
#       (s*t = 8*8 = 64 codes per microtile, packed as 4 uint32 in lane
#       order),
#   (3) Concatenate microtile-blocks in (n_blk, k_blk) traversal order
#       (matches IRON tap with tile_group_col_major=True), so the kernel
#       can stream pW directly with no on-tile re-tile pass.
#
# Pass criterion same as Phase-1: rel-err < 5e-3 AND max-abs < 4 bf16-ULPs.
#
# Usage:
#   source /home/bcloud/.venvs/ironenv/bin/activate
#   source /home/bcloud/repos/mlir-aie/utils/env_setup.sh /home/bcloud/repos/mlir-aie/install
#   make -f Makefile.512
#   python run_pyxrt_bitnet_512.py

import os
import sys
import numpy as np
import pyxrt

M, K, N = 512, 512, 512
m, k, n = 64, 64, 64

# Mmul micro-tile (matches kernel's R, S, T constants).
R, S, T = 4, 8, 8

assert M % m == 0 and K % k == 0 and N % n == 0
assert m % R == 0 and k % S == 0 and n % T == 0

M_div_m = M // m
K_div_k = K // k
N_div_n = N // n

BUILD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build")
SUFFIX = f"512_{M}x{K}x{N}_{m}x{k}x{n}"
XCLBIN = os.path.join(BUILD, f"final_{SUFFIX}.xclbin")
INSTS  = os.path.join(BUILD, f"insts_{SUFFIX}.txt")


# ---------------------------------------------------------------------------
# bf16 <-> fp32 helpers (numpy has no native bf16; we transport as uint16).
# ---------------------------------------------------------------------------
def fp32_to_bf16_u16(x: np.ndarray) -> np.ndarray:
    x = np.ascontiguousarray(x, dtype=np.float32)
    u32 = x.view(np.uint32).copy()
    rounding_bias = 0x7FFF + ((u32 >> 16) & 1)
    u32 = u32 + rounding_bias
    return (u32 >> 16).astype(np.uint16)


def bf16_u16_to_fp32(u: np.ndarray) -> np.ndarray:
    u32 = (u.astype(np.uint32) << 16)
    return u32.view(np.float32)


# ---------------------------------------------------------------------------
# HALO_V2 packing & tiling.
#
# pretile_weights_for_kernel:
#   Input:  W_ternary : int8 [K, N] in {-1, 0, +1}, dense row-major.
#   Output: W_packed  : uint32 [M_div_m * K_div_k * N_div_n * (k*n/16)],
#                       laid out for the IRON DSL tap.
#
# Kernel inner-call expects, for one (m_blk, n_blk, k_blk) inner tile, a
# contiguous (k/s * n/t * 4) uint32 chunk where each 4-uint32 microtile
# decodes to an aie::vector<bf16, 64> matching aie::mmul<R,S,T>::B layout
# (s rows by t cols, row-major). The IRON tap streams these chunks in
# (m_blk, n_blk, k_blk) outer-to-inner order — m_blk repeats outermost,
# tile_group_col_major=True means (k_blk fastest, n_blk slower) within
# each m-row pass.
# ---------------------------------------------------------------------------
HALO_CODES = {0: 0b00, 1: 0b01, -1: 0b10}


def _pack_microtile_codes_to_4_u32(microtile_codes: np.ndarray) -> np.ndarray:
    """microtile_codes : uint8 shape (S, T)  -- row-major (S rows by T cols)
    Returns 4 uint32 words such that decoding word[w] in lane order
    (lane_i = bits[2i:2i+1]) yields bf16 lanes [w*16 .. w*16+15], with
    lane-to-(s,t) mapping (s = lane // T, t = lane % T)."""
    assert microtile_codes.shape == (S, T)
    flat = microtile_codes.reshape(-1).astype(np.uint32)  # (S*T,) = 64 codes
    assert flat.size == 64 and S * T == 64
    out = np.zeros(4, dtype=np.uint32)
    # Lanes 0..15 -> word[0], 16..31 -> word[1], etc. Within each word, lane
    # i contributes bits at position (2*i, 2*i+1).
    for w in range(4):
        chunk = flat[w * 16:(w + 1) * 16]  # 16 codes, lane order within word
        word = np.uint32(0)
        for i in range(16):
            word |= (chunk[i] & 0x3) << (2 * i)
        out[w] = word
    return out


def _ternary_to_codes(W_ternary: np.ndarray) -> np.ndarray:
    """int8 {-1, 0, +1} -> uint8 {0b00, 0b01, 0b10}."""
    codes = np.zeros_like(W_ternary, dtype=np.uint8)
    codes[W_ternary ==  0] = 0b00
    codes[W_ternary ==  1] = 0b01
    codes[W_ternary == -1] = 0b10
    assert ((W_ternary == 0) | (W_ternary == 1) | (W_ternary == -1)).all(), \
        "ternary values only"
    return codes


def pretile_weights_for_kernel(W_ternary: np.ndarray) -> np.ndarray:
    """Pre-tile and pack ternary W [K,N] into the IRON-tap stream order.

    Returns flat uint32 array of length K*N/16 -- 64 KiB for 512x512.
    Note: the IRON design re-streams this buffer M_div_m times via its
    tap structure; we ship just the K*N/16 base buffer to host BO.
    Wait: see runtime tap section below; we actually need to ship a buffer
    that matches the tap walk dimensions.
    """
    assert W_ternary.shape == (K, N)
    codes = _ternary_to_codes(W_ternary)  # (K, N) uint8 in {0,1,2}

    # Build flat output sized for the kernel's view: per inner call,
    # (k/s) * (n/t) * 4 uint32 microtiles, in (i_blk, j_blk) row-major
    # order matching the kernel's pW indexing (pW[i*colB*4 + j*4 + w]).
    #
    # Per (n_blk, k_blk) inner-call:
    #   for i_blk in 0..(k/s):
    #     for j_blk in 0..(n/t):
    #       emit 4 u32 from codes[k_blk*k + i_blk*S : k_blk*k + (i_blk+1)*S,
    #                              n_blk*n + j_blk*T : n_blk*n + (j_blk+1)*T]
    #
    # Total K*N/16 u32 == 16384 u32 == 64 KiB.
    nwords_per_inner = (k * n) // 16  # 256
    total_inner_calls_in_one_pass = K_div_k * N_div_n  # 64
    out = np.zeros(total_inner_calls_in_one_pass * nwords_per_inner,
                   dtype=np.uint32)

    # Stream order matches the IRON tap with tile_group_col_major=True:
    # outer = n_blk, inner = k_blk (k_blk fastest within an n_blk group).
    write_idx = 0
    for n_blk in range(N_div_n):
        for k_blk in range(K_div_k):
            # Slice this inner-call's (k, n) source block.
            blk = codes[k_blk * k : (k_blk + 1) * k,
                        n_blk * n : (n_blk + 1) * n]   # (k, n) uint8
            for i_blk in range(k // S):
                for j_blk in range(n // T):
                    micro = blk[i_blk * S : (i_blk + 1) * S,
                                j_blk * T : (j_blk + 1) * T]   # (S, T)
                    out[write_idx:write_idx + 4] = (
                        _pack_microtile_codes_to_4_u32(micro)
                    )
                    write_idx += 4
    assert write_idx == out.size
    return out


# ---------------------------------------------------------------------------
# CPU reference (bf16 acts, ternary weights, fp32 acc, bf16 store).
# Per-row scale already baked into A on host -- same contract as Phase-1.
# ---------------------------------------------------------------------------
def cpu_reference(A_baked_bf16: np.ndarray, W_ternary: np.ndarray) -> np.ndarray:
    A_fp32 = bf16_u16_to_fp32(A_baked_bf16).astype(np.float32)
    W_fp32 = W_ternary.astype(np.float32)
    C = A_fp32 @ W_fp32
    return fp32_to_bf16_u16(C)


def main():
    if not os.path.exists(XCLBIN):
        sys.exit(f"missing {XCLBIN} -- run `make -f Makefile.512` first")
    if not os.path.exists(INSTS):
        sys.exit(f"missing {INSTS}")

    rng = np.random.default_rng(20260426)

    # Random fp32 acts in a small dynamic range -- bf16 round-off stays
    # benign. Per-row scale folded into A host-side.
    A_fp32 = rng.uniform(-1.0, 1.0, size=(M, K)).astype(np.float32)
    Sscale = rng.uniform(0.5, 2.0, size=(M,)).astype(np.float32)
    A_baked_fp32 = (A_fp32 * Sscale[:, None]).astype(np.float32)
    A_baked_bf16 = fp32_to_bf16_u16(A_baked_fp32)

    # Random ternary weights ~50% sparsity.
    W_choice = rng.integers(0, 3, size=(K, N))     # 0,1,2 -> 0,+1,-1
    W_ternary = np.zeros((K, N), dtype=np.int8)
    W_ternary[W_choice == 1] =  1
    W_ternary[W_choice == 2] = -1

    # Pre-tile + pack -- this is the work the on-tile re-tile pass used to do.
    W_packed_u32 = pretile_weights_for_kernel(W_ternary)
    W_packed = W_packed_u32.view(np.int32)

    # C is fp32 from the kernel (precision across 8 K-blocks); we cast to
    # bf16 host-side after drain.
    C_bytes_fp32 = M * N * 4
    print(f"A bytes        : {A_baked_bf16.nbytes}")
    print(f"W bytes        : {W_packed.nbytes}  (packed+pretiled)")
    print(f"C bytes        : {C_bytes_fp32}  (fp32 from kernel)")
    print(f"per-tile u32   : {(k * n) // 16}")

    C_ref_bf16 = cpu_reference(A_baked_bf16, W_ternary)

    # ---- XRT dispatch ----
    insts = np.frombuffer(open(INSTS, "rb").read(), dtype=np.uint32)
    print(f"insts          : {insts.shape[0]} u32s, {insts.nbytes} bytes")

    dev = pyxrt.device(0)
    xclbin = pyxrt.xclbin(XCLBIN)
    dev.register_xclbin(xclbin)
    ctx = pyxrt.hw_context(dev, xclbin.get_uuid())

    kernels = xclbin.get_kernels()
    if not kernels:
        sys.exit("no kernels in xclbin")
    kname = kernels[0].get_name()
    print(f"kernel         : {kname}")
    kern = pyxrt.kernel(ctx, kname)

    A_bytes = A_baked_bf16.nbytes
    W_bytes = W_packed.nbytes
    C_bytes = C_bytes_fp32

    bo_i = pyxrt.bo(dev, insts.nbytes, pyxrt.bo.flags.cacheable, kern.group_id(1))
    bo_a = pyxrt.bo(dev, A_bytes,      pyxrt.bo.flags.host_only, kern.group_id(3))
    bo_w = pyxrt.bo(dev, W_bytes,      pyxrt.bo.flags.host_only, kern.group_id(4))
    bo_c = pyxrt.bo(dev, C_bytes,      pyxrt.bo.flags.host_only, kern.group_id(5))

    bo_i.write(insts.tobytes(),         0)
    bo_a.write(A_baked_bf16.tobytes(),  0)
    bo_w.write(W_packed.tobytes(),      0)
    for bo in (bo_i, bo_a, bo_w):
        bo.sync(pyxrt.xclBOSyncDirection.XCL_BO_SYNC_BO_TO_DEVICE)

    run = kern(3, bo_i, insts.shape[0], bo_a, bo_w, bo_c)
    state = run.wait()
    # Issue #103: ERT_CMD_STATE_ERROR sometimes appears post-completion --
    # still report the value but don't mask other failures.
    print(f"run state      : {state}")
    ert_state_error = "ERROR" in str(state)

    bo_c.sync(pyxrt.xclBOSyncDirection.XCL_BO_SYNC_BO_FROM_DEVICE)
    # NPU emits fp32 C; we round to bf16 host-side to match the Phase-1
    # contract for downstream consumers.
    C_npu_fp32_raw = np.frombuffer(bo_c.read(C_bytes, 0),
                                   dtype=np.float32).reshape(M, N)
    C_npu_bf16 = fp32_to_bf16_u16(C_npu_fp32_raw)

    C_ref_fp32 = bf16_u16_to_fp32(C_ref_bf16).reshape(M, N).astype(np.float32)
    C_npu_fp32 = bf16_u16_to_fp32(C_npu_bf16).astype(np.float32)

    diff = C_npu_fp32 - C_ref_fp32
    abs_norm = float(np.linalg.norm(diff))
    ref_norm = float(np.linalg.norm(C_ref_fp32) + 1e-12)
    rel_err  = abs_norm / ref_norm
    max_abs  = float(np.max(np.abs(diff)))

    ref_max = float(np.max(np.abs(C_ref_fp32)) + 1e-12)
    ulp_at_ref_max = ref_max * 2 ** -7
    max_abs_ulps = max_abs / ulp_at_ref_max if ulp_at_ref_max > 0 else float("inf")

    print(f"||npu - cpu||  : {abs_norm:.6f}")
    print(f"||cpu||        : {ref_norm:.6f}")
    print(f"rel error      : {rel_err:.3e}")
    print(f"max abs        : {max_abs:.6f}  ({max_abs_ulps:.2f} bf16 ULPs at ref-max)")
    print(f"ERT_CMD_STATE_ERROR observed : {ert_state_error}")

    # K=512 has 8x more accumulation than K=64, so per-element drift grows
    # ~sqrt(8) ~ 2.8x. Threshold: rel-err < 5e-3 AND max-abs < 4 ULPs at
    # the reference magnitude (same as Phase-1).
    ok = (rel_err < 5e-3) and (max_abs_ulps < 4.0)
    print("PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
