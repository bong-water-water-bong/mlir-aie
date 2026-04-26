//===- bitnet_gemm_512.cc ---------------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Copyright (C) 2026, halo-ai-core / bong-water-water-bong.
//
// BitNet 1.58 ternary GEMM microkernel for AIE2P, Phase-2 (M=K=N=512 grid,
// per-call inner tile m=k=n=64). Differences vs. Phase-1 (bitnet_gemm.cc):
//
//   1. **Fused unpack inside the inner mmul K-loop.** The Phase-1 kernel
//      materialised g_w_bf16_stage[k*n] (8 KiB) and g_w_bf16_tiled[k*n]
//      (8 KiB) — total 16 KiB of LDS-equivalent staging that has now been
//      eliminated. Unpack happens just-in-time, into an aie::vector<bf16>
//      register that lives only for the lifetime of one mac() call.
//
//   2. **Pre-tiled packed-weight layout.** The host pre-tiles the packed
//      weight stream so that within one (m=k=n=64) tile call, the i32
//      buffer is laid out as [k/s tiles][n/t tiles][s*t/16 = 4 i32 words]
//      — i.e., 4 i32 per (s*t) = (8*8) = 64-weight micro-tile, in
//      tile-row-major order. The Phase-1 on-tile re-tile pass (the
//      g_w_bf16_tiled triple loop) is gone.
//
//   3. **In-place accumulation.** The IRON design issues one zero_ then
//      K_div_k = 8 calls to bitnet_gemm_bf16 against the same C tile.
//      The kernel reads C, accumulates partial mmul results into the
//      MMUL accumulators, stores back. Same protocol as the stock
//      mm.cc 2x2 mmul kernel.
//
// Contract per kernel call (one inner tile, m = k = n = 64):
//
//   A : bfloat16 [m * k]                        — pre-tiled (m/r, k/s, r, s)
//                                                 by the IRON DSL a_dims.
//                                                 Per-row scale baked in
//                                                 host-side (A_baked = S*A).
//   W : int32    [k * n / 16]                   — HALO_V2 packed ternary,
//                                                 pre-tiled host-side into
//                                                 (k/s, n/t, s*t/16) =
//                                                 (8, 8, 4) i32 micro-tiles.
//                                                 IRON has no uint32; we
//                                                 transport as i32 and
//                                                 reinterpret_cast inside.
//   C : float    [m * n]                        — fp32 accumulator, pre-tiled
//                                                 (m/r, n/t, r, t) by the
//                                                 IRON c_dims. Pre-zeroed
//                                                 by zero_bitnet_f32_512
//                                                 once per outer (m,n)
//                                                 tile (NOT per K-block).
//                                                 Host casts to bf16 after
//                                                 drain. Why fp32 (not bf16)
//                                                 across K-blocks: K=512 =
//                                                 8 round-trips through the
//                                                 C tile via bf16 store/load
//                                                 cost ~3 ULP/elem of
//                                                 quantization noise
//                                                 (validated empirically
//                                                 with the bf16 variant —
//                                                 rel_err 1.5e-2 vs the
//                                                 5e-3 envelope). Keeping
//                                                 the partial sum in fp32
//                                                 holds rel_err ~ Phase-1
//                                                 levels.
//
// HALO_V2 packing scheme — unchanged from Phase-1:
//   2-bit code per weight, 16 codes per uint32 (LSB first).
//     0b00 -> 0
//     0b01 -> +1
//     0b10 -> -1
//     0b11 -> 0   (reserved; encoder must not emit; we treat as 0)
//
// AIE2P bf16 mmul tile shape r=4, s=8, t=8 (matches stock mm.cc bf16->bf16).

#define NOCPP

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <aie_api/aie.hpp>

#include "zero.cc"

#ifndef DIM_M
#define DIM_M 64
#endif
#ifndef DIM_K
#define DIM_K 64
#endif
#ifndef DIM_N
#define DIM_N 64
#endif

// AIE2P bf16 mmul shape (matches mm.cc bf16/bf16 layout, no bfp16 emul).
static constexpr unsigned R = 4;
static constexpr unsigned S = 8;
static constexpr unsigned T = 8;

static_assert(DIM_M % (2 * R) == 0, "DIM_M must be divisible by 2*r=8");
static_assert(DIM_K %      S  == 0, "DIM_K must be divisible by s=8");
static_assert(DIM_N % (2 * T) == 0, "DIM_N must be divisible by 2*t=16");

// Per (s*t) = 64-weight micro-tile, packed into 64*2/32 = 4 uint32 words.
static constexpr unsigned ST           = S * T;            // 64
static constexpr unsigned WORDS_PER_ST = (S * T) / 16;     // 4

// ---------------------------------------------------------------------------
// Decode 16 ternary codes from one uint32 word into one aie::vector<bf16, 16>.
//
// Branch-free per-code: v = (c & 1) - ((c >> 1) & 1).
//   00 -> 0,  01 -> +1,  10 -> -1,  11 -> 0
//
// We build a stack-resident bf16[16] and load it into a vector. The compiler
// is free to fold the constants and emit a constant-table load; we keep the
// per-call cost in registers, never spilling to LDS. (Phase-2 ambition for
// later: emit a true SIMD decode using shifted bit-tests + aie::select; for
// correctness-first we let the C++ frontend lower this loop.)
// ---------------------------------------------------------------------------
static inline aie::vector<bfloat16, 16>
decode_word_to_v16_bf16(uint32_t word) {
  alignas(32) bfloat16 lane[16];
#pragma clang loop unroll(full)
  for (unsigned i = 0; i < 16; ++i) {
    uint32_t c    = (word >> (i * 2)) & 0x3u;
    int32_t  bit0 = (int32_t)( c       & 1u);
    int32_t  bit1 = (int32_t)((c >> 1) & 1u);
    int32_t  v    = bit0 - bit1;
    lane[i] = (bfloat16)(float)v;
  }
  return aie::load_v<16>(lane);
}

// ---------------------------------------------------------------------------
// Decode one (s*t)=64-weight micro-tile (4 consecutive uint32 words) into
// an aie::vector<bf16, 64>. The four 16-lane vectors are concatenated.
//
// Layout of the 4 words inside one (s*t) micro-tile, host-pre-tiled:
//   word[0] = codes for weights (0..15)   = bf16 lanes (0..15)
//   word[1] = codes for weights (16..31)  = bf16 lanes (16..31)
//   word[2] = codes for weights (32..47)  = bf16 lanes (32..47)
//   word[3] = codes for weights (48..63)  = bf16 lanes (48..63)
//
// The (s,t) micro-tile is row-major (s fastest-changing within a tile) so
// that aie::mmul<r,s,t,bf16,bf16> consumes it directly as B operand —
// matching the stock mm.cc 2x2 mmul B layout.
// ---------------------------------------------------------------------------
static inline aie::vector<bfloat16, ST>
decode_microtile_to_vST_bf16(const uint32_t *__restrict pW4) {
  aie::vector<bfloat16, 16> v0 = decode_word_to_v16_bf16(pW4[0]);
  aie::vector<bfloat16, 16> v1 = decode_word_to_v16_bf16(pW4[1]);
  aie::vector<bfloat16, 16> v2 = decode_word_to_v16_bf16(pW4[2]);
  aie::vector<bfloat16, 16> v3 = decode_word_to_v16_bf16(pW4[3]);
  return aie::concat(v0, v1, v2, v3);
}

// ---------------------------------------------------------------------------
// Fused 2x2 mmul with on-the-fly weight unpack.
//
// rowA = m/r, colA = k/s, colB = n/t.
//
// One (s*t) micro-tile of B is 4 uint32. The B stream is stored in
// [colA][colB] tile order (k-tile-row major, n-tile within a row), so:
//
//   pBword(i, j) = pW + (i * colB + j) * WORDS_PER_ST
//
// Same access pattern as pB in mm.cc, just shifted by the
// 16-codes-per-uint32 ratio.
// ---------------------------------------------------------------------------
static inline void
bitnet_matmul_2x2_fused(const bfloat16 *__restrict pA,
                        const uint32_t *__restrict pW,
                        float          *__restrict pC,
                        unsigned rowA, unsigned colA, unsigned colB) {
  using MMUL = aie::mmul<R, S, T, bfloat16, bfloat16, accauto>;

  for (unsigned z = 0; z < rowA; z += 2)
    chess_prepare_for_pipelining chess_loop_range(4, ) {
      float *__restrict pC1 = pC + (z * colB)       * MMUL::size_C;
      float *__restrict pC2 = pC + ((z + 1) * colB) * MMUL::size_C;

      for (unsigned j = 0; j < colB; j += 2) {
        const bfloat16 *__restrict pA1 = pA + (z * colA)       * MMUL::size_A;
        const bfloat16 *__restrict pA2 = pA + ((z + 1) * colA) * MMUL::size_A;
        const uint32_t *__restrict pW1 = pW + (j)     * WORDS_PER_ST;
        const uint32_t *__restrict pW2 = pW + (j + 1) * WORDS_PER_ST;

        // Initialise C accumulators from existing C contents — Phase-2 IRON
        // calls the kernel K_div_k times against the same C tile, so reads
        // pick up partial sums from prior K-block calls. zero_bitnet_f32_512
        // is invoked once per outer (m,n) tile, before the K-loop. C is fp32
        // here so the running sum survives the K-block round-trips with no
        // bf16 quantization drift.
        aie::vector<float, MMUL::size_C> acc_C00 =
            aie::load_v<MMUL::size_C>(pC1);
        aie::vector<float, MMUL::size_C> acc_C01 =
            aie::load_v<MMUL::size_C>(pC1 + MMUL::size_C);
        aie::vector<float, MMUL::size_C> acc_C10 =
            aie::load_v<MMUL::size_C>(pC2);
        aie::vector<float, MMUL::size_C> acc_C11 =
            aie::load_v<MMUL::size_C>(pC2 + MMUL::size_C);

        MMUL C00(acc_C00), C01(acc_C01), C10(acc_C10), C11(acc_C11);

        for (unsigned i = 0; i < colA; ++i) {
          aie::vector<bfloat16, MMUL::size_A> A0 =
              aie::load_v<MMUL::size_A>(pA1);
          pA1 += MMUL::size_A;
          aie::vector<bfloat16, MMUL::size_A> A1 =
              aie::load_v<MMUL::size_A>(pA2);
          pA2 += MMUL::size_A;

          // Fused unpack: decode 4 i32 -> 64 bf16 in registers, no spill.
          aie::vector<bfloat16, MMUL::size_B> B0 =
              decode_microtile_to_vST_bf16(pW1);
          pW1 += WORDS_PER_ST * colB;     // step one s-row in the B grid
          aie::vector<bfloat16, MMUL::size_B> B1 =
              decode_microtile_to_vST_bf16(pW2);
          pW2 += WORDS_PER_ST * colB;

          C00.mac(A0, B0);
          C01.mac(A0, B1);
          C10.mac(A1, B0);
          C11.mac(A1, B1);
        }

        aie::store_v(pC1, C00.template to_vector<float>());
        pC1 += MMUL::size_C;
        aie::store_v(pC1, C01.template to_vector<float>());
        pC1 += MMUL::size_C;
        aie::store_v(pC2, C10.template to_vector<float>());
        pC2 += MMUL::size_C;
        aie::store_v(pC2, C11.template to_vector<float>());
        pC2 += MMUL::size_C;
      }
    }
}

extern "C" {

// Zero the C tile. Called once per (m,n) outer tile, BEFORE the K-loop.
// fp32 accumulator (see contract above for why we don't use bf16 here).
void zero_bitnet_f32_512(float *c_out) {
  zero_vectorized<float, DIM_M, DIM_N>(c_out);
}

// Phase-2 BitNet ternary GEMM entry point — one (m=k=n) inner tile.
//
// A : bf16  [DIM_M * DIM_K]      A pre-tiled (m/r, k/s, r, s) by IRON DSL.
// W : int32 [DIM_K * DIM_N / 16] W pre-tiled host-side as
//                                 (k/s, n/t, WORDS_PER_ST=4) i32 microtiles
//                                 in s-row-major / t-block-major order.
//                                 Reinterpreted to uint32 inside.
// C : f32   [DIM_M * DIM_N]      C accumulator. Caller (IRON) zero-inits
//                                 once per (m,n) outer tile then calls this
//                                 K_div_k times to accumulate partial sums.
//                                 Host casts to bf16 after drain (cheap;
//                                 4 bytes -> 2 bytes per element). Kept fp32
//                                 inside the AIE tile to preserve precision
//                                 across K-block round-trips.
void bitnet_gemm_bf16_512(bfloat16 *a_in, int32_t *w_in, float *c_out) {
  event0();

  const uint32_t *w_u32 = reinterpret_cast<const uint32_t *>(w_in);

  bitnet_matmul_2x2_fused(a_in, w_u32, c_out,
                          /*rowA=*/(DIM_M / R),
                          /*colA=*/(DIM_K / S),
                          /*colB=*/(DIM_N / T));

  event1();
}

} // extern "C"
