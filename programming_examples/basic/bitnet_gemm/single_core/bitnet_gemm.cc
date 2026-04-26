//===- bitnet_gemm.cc -------------------------------------*- C++ -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
// Copyright (C) 2026, halo-ai-core / bong-water-water-bong.
//
// BitNet 1.58 ternary GEMM microkernel for AIE2P (Strix Halo NPU2 / XDNA2).
//
// Contract (mirrors HIP rcpp_ternary_gemv_halo_f16_devscale at the host
// boundary, but the AIE tile speaks bf16 internally — bf16 represents
// {-1,0,+1} exactly, so no precision is lost vs. fp16):
//
//   Inputs (per-tile, m=k=n=64):
//     A : bfloat16 [m, k]   — row-major activation tile WITH the per-row
//                              dequant scale ALREADY FOLDED IN at the host
//                              (A_baked[i,k] = scale[i] * A[i,k]).
//                              The scale fold happens host-side because each
//                              AIE2P compute tile has only 2 input DMA
//                              channels — taking acts + weights uses both.
//     W : uint32   [k*n/16] — HALO_V2 packed ternary weights, ROW-MAJOR (k by n)
//                              stored as 16 codes per uint32 (32 bits / 2 bits).
//   Output:
//     C : bfloat16 [m, n]   — C[i,j] = sum_k(A_baked[i,k] * W_dense[k,j]).
//
// HALO_V2 packing scheme  (per-weight 2-bit code, 16 codes per uint32 word):
//
//   uint32 word layout (LSB first):
//     bits[ 1: 0] = code for weight 0
//     bits[ 3: 2] = code for weight 1
//     ...
//     bits[31:30] = code for weight 15
//
//   2-bit code → int8 ternary value:
//     0b00 → 0
//     0b01 → +1
//     0b10 → -1
//     0b11 → 0   (reserved; treated as 0 so encoder bugs degrade gracefully)
//
//   Lookup table: code_to_i8[4] = { 0, +1, -1, 0 }.
//   Equivalent branch-free decode for one code c (uint8 in {0..3}):
//       int8 v = ((c & 1u) ? 1 : 0) - ((c >> 1) & 1u ? 1 : 0);
//                                  ^ -1 if bit1 set, else 0
//
// We unpack into a dense bf16 staging buffer once per K-block, then issue
// a stock aie::mmul<r,s,t,bf16,bf16,accauto> over it. This trades a small
// LDS-equivalent staging cost (k*n*sizeof(bf16) = 8 KiB for 64x64) for
// reuse of the proven AIE2P bf16 mmul path — minimal-viable correctness
// before we fuse the unpack into the inner loop.

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

// AIE2P bf16 mmul shape (matches mm.cc i8/bf16 layout).
static constexpr unsigned R = 4;
static constexpr unsigned S = 8;
static constexpr unsigned T = 8;

static_assert(DIM_M % (2 * R) == 0, "DIM_M must be divisible by 2*r=8");
static_assert(DIM_K %      S  == 0, "DIM_K must be divisible by s=8");
static_assert(DIM_N % (2 * T) == 0, "DIM_N must be divisible by 2*t=16");

// ---------------------------------------------------------------------------
// Unpack HALO_V2 packed weights into a row-major bf16 dense tile.
//
// Input  W:   uint32[k*n/16] in row-major layout — i.e., for row i and
//             col j, the code lives in word W[(i*n + j) / 16] at bit-pos
//             ((i*n + j) % 16) * 2.
// Output Wbf: bfloat16[k*n] dense, row-major.
//
// We iterate one uint32 at a time and unpack 16 codes into 16 bf16s.
// On AIE2P, bf16 is 16 bits, so we can stamp the 16 codes through a
// scalar loop or a small SIMD store. For correctness-first we use the
// scalar form — vectorization is a Phase-2 task once the test passes.
// ---------------------------------------------------------------------------
static inline void unpack_halo_v2_to_bf16(const uint32_t *__restrict W,
                                          bfloat16 *__restrict Wbf,
                                          unsigned k, unsigned n) {
  event0();
  const unsigned total = k * n;
  // 16 codes per uint32, so total/16 words.
  const unsigned nwords = total >> 4;
  for (unsigned w = 0; w < nwords; ++w) {
    uint32_t word = W[w];
    bfloat16 *out = Wbf + (w << 4);
    // Branch-free unpack: for each 2-bit code c, value = (c & 1) - ((c>>1) & 1).
    // Unrolled by 16. Compiler will fold the constants.
#pragma clang loop unroll(full)
    for (unsigned i = 0; i < 16; ++i) {
      uint32_t c   = (word >> (i * 2)) & 0x3u;
      int32_t  bit0 = (int32_t)( c        & 1u);
      int32_t  bit1 = (int32_t)((c >> 1)  & 1u);
      int32_t  v    = bit0 - bit1;       // {0,+1,-1,0} for codes {00,01,10,11}
      // bf16 represents -1, 0, +1 exactly.
      out[i] = (bfloat16)(float)v;
    }
  }
  event1();
}

// ---------------------------------------------------------------------------
// Reuse the same 2x2 mmul expansion idiom as aie_kernels/aie2p/mm.cc, but
// inlined here so this kernel is self-contained and the existing mm.cc is
// untouched (per architect constraint).
// ---------------------------------------------------------------------------
template <typename T_in, typename T_out, unsigned rowA, unsigned colA,
          unsigned colB, unsigned r, unsigned s, unsigned t>
static inline void bitnet_matmul_2x2_bf16(const T_in *__restrict pA,
                                          const T_in *__restrict pB,
                                          T_out *__restrict pC) {
  using MMUL = aie::mmul<r, s, t, T_in, T_in, accauto>;

  for (unsigned z = 0; z < rowA; z += 2)
    chess_prepare_for_pipelining chess_loop_range(4, ) {
      T_out *__restrict pC1 = pC + (z * colB) * MMUL::size_C;
      T_out *__restrict pC2 = pC + ((z + 1) * colB) * MMUL::size_C;

      for (unsigned j = 0; j < colB; j += 2) {
        const T_in *__restrict pA1 = pA + (z * colA) * MMUL::size_A;
        const T_in *__restrict pA2 = pA + ((z + 1) * colA) * MMUL::size_A;
        const T_in *__restrict pB1 = pB + (j) * MMUL::size_B;
        const T_in *__restrict pB2 = pB + (j + 1) * MMUL::size_B;

        aie::vector<T_in, MMUL::size_A> A0, A1;
        aie::vector<T_in, MMUL::size_B> B0, B1;

        // C is fresh-zeroed by zero_bf16 each tile, so initialise from load.
        aie::vector<T_out, MMUL::size_C> acc_C00 = aie::load_v<MMUL::size_C>(pC1);
        aie::vector<T_out, MMUL::size_C> acc_C01 = aie::load_v<MMUL::size_C>(pC1 + MMUL::size_C);
        aie::vector<T_out, MMUL::size_C> acc_C10 = aie::load_v<MMUL::size_C>(pC2);
        aie::vector<T_out, MMUL::size_C> acc_C11 = aie::load_v<MMUL::size_C>(pC2 + MMUL::size_C);

        MMUL C00(acc_C00), C01(acc_C01), C10(acc_C10), C11(acc_C11);

        for (unsigned i = 0; i < colA; ++i) {
          A0 = aie::load_v<MMUL::size_A>(pA1); pA1 += MMUL::size_A;
          A1 = aie::load_v<MMUL::size_A>(pA2); pA2 += MMUL::size_A;
          B0 = aie::load_v<MMUL::size_B>(pB1); pB1 += MMUL::size_B * colB;
          B1 = aie::load_v<MMUL::size_B>(pB2); pB2 += MMUL::size_B * colB;

          C00.mac(A0, B0);
          C01.mac(A0, B1);
          C10.mac(A1, B0);
          C11.mac(A1, B1);
        }

        aie::store_v(pC1, C00.template to_vector<T_out>()); pC1 += MMUL::size_C;
        aie::store_v(pC1, C01.template to_vector<T_out>()); pC1 += MMUL::size_C;
        aie::store_v(pC2, C10.template to_vector<T_out>()); pC2 += MMUL::size_C;
        aie::store_v(pC2, C11.template to_vector<T_out>()); pC2 += MMUL::size_C;
      }
    }
}

// ---------------------------------------------------------------------------
// Per-tile staging for the unpacked bf16 weight matrix. Sized for the
// largest tile we ship: 64*64*sizeof(bf16) = 8 KiB — fits in the AIE
// tile's local memory comfortably (each AIE2P tile has 64 KiB).
// ---------------------------------------------------------------------------
alignas(32) static bfloat16 g_w_bf16_stage[DIM_K * DIM_N];

extern "C" {

// Zero the C tile (reuse template from zero.cc).
void zero_bitnet_bf16(bfloat16 *c_out) {
  zero_vectorized<bfloat16, DIM_M, DIM_N>(c_out);
}

// Main BitNet ternary GEMM entry point.
//
// A:  bf16  [DIM_M * DIM_K]      row-major, scale-baked (A_baked = S * A_raw).
// W:  int32 [DIM_K * DIM_N / 16] HALO_V2 packed (bit-pattern uint32),
//                                 row-major. IRON DSL has no uint32 dtype
//                                 so we transport as int32 and reinterpret.
// C:  bf16  [DIM_M * DIM_N]      pre-zeroed by zero_bitnet_bf16
void bitnet_gemm_bf16(bfloat16 *a_in, int32_t *w_in, bfloat16 *c_out) {
  event0();

  // Reinterpret the int32 transport buffer as the uint32 bit-pattern stream.
  const uint32_t *w_u32 = reinterpret_cast<const uint32_t *>(w_in);

  // Step 1: unpack ternary weights into local bf16 staging.
  unpack_halo_v2_to_bf16(w_u32, g_w_bf16_stage, DIM_K, DIM_N);

  // Step 2: bf16 GEMM with the 2x2 mmul expansion.
  // Layout matches the matmul example: A is pre-tiled into rxs blocks,
  // B is pre-tiled into sxt blocks. Since we built the bf16 stage in
  // simple row-major above (no pre-tiling), we rely on the IRON DSL
  // dimension specs (a_dims, b_dims) on the *activation* fifo to land
  // it in r-tiled order. The weight tile, post-unpack, is plain
  // row-major — to keep the example self-contained we re-tile here.
  //
  // For the *correctness-first* M=K=N=64 path we accept that layout
  // and let the DSL stream A in the r-tiled form. The unpacked weight
  // stage we re-tile to s-tiled form with one pass:
  alignas(32) static bfloat16 g_w_bf16_tiled[DIM_K * DIM_N];
  for (unsigned ks = 0; ks < DIM_K; ks += S)
    for (unsigned nt = 0; nt < DIM_N; nt += T)
      for (unsigned ii = 0; ii < S; ++ii)
        for (unsigned jj = 0; jj < T; ++jj) {
          unsigned src = (ks + ii) * DIM_N + (nt + jj);
          unsigned dst = (ks / S) * (DIM_N / T) * (S * T)
                       + (nt / T) * (S * T) + ii * T + jj;
          g_w_bf16_tiled[dst] = g_w_bf16_stage[src];
        }

  bitnet_matmul_2x2_bf16<bfloat16, bfloat16,
                         (DIM_M / R), (DIM_K / S), (DIM_N / T),
                         R, S, T>(a_in, g_w_bf16_tiled, c_out);

  // Per-row scale was baked into A on the host, so the mmul output is the
  // final result. No post-scale step on this tile.

  event1();
}

} // extern "C"
