##===- Makefile -----------------------------------------------------------===##
#
# This file licensed under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# Copyright (C) 2026, halo-ai-core / bong-water-water-bong.
#
##===----------------------------------------------------------------------===##

srcdir := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# Final GEMM dims (v1: M=K=N=64 = single tile).
M ?= 64
K ?= 64
N ?= 64

# Single AIE core tile dims.
m ?= 64
k ?= 64
n ?= 64

devicename ?= npu2
target_suffix ?= ${M}x${K}x${N}_${m}x${k}x${n}

mlir_target  ?= build/aie_${target_suffix}.mlir
xclbin_target ?= build/final_${target_suffix}.xclbin
insts_target  ?= build/insts_${target_suffix}.txt

# Locate Peano (toolchain root).
ifndef PEANO_INSTALL_DIR
$(error PEANO_INSTALL_DIR not set — `source utils/env_setup.sh <install>` first.)
endif

# Pull in PEANOWRAP2P_FLAGS / WARNING_FLAGS / MLIR_AIE_DIR.
include $(srcdir)/../../../makefile-common

# AIE2P kernel compilation (peano / clang++).
KERNEL_CC = ${PEANO_INSTALL_DIR}/bin/clang++
KERNEL_CFLAGS = ${PEANOWRAP2P_FLAGS}
KERNEL_DEFINES = -DDIM_M=${m} -DDIM_K=${k} -DDIM_N=${n}

# kernels_dir hosts the shared zero.cc include.
kernels_dir := $(srcdir)/../../../../aie_kernels/aie2p

aieargs = -M $M -K $K -N $N -m $m -k $k -n $n
runargs = -v 2 --warmup 1 --iters 1
buffer_aloc_flag = basic-sequential
trace_size ?= 0

aiecc_peano_flags = --no-xchesscc --no-xbridge --peano ${PEANO_INSTALL_DIR}

.PHONY: all clean

all: ${xclbin_target}

# Build the kernel object. We compile bitnet_gemm.cc with -I to the shared
# aie2p kernel dir so the `#include "zero.cc"` resolves.
build/bitnet_gemm_${m}x${k}x${n}.o: ${srcdir}/bitnet_gemm.cc
	mkdir -p ${@D}
	cd ${@D} && ${KERNEL_CC} ${KERNEL_CFLAGS} ${KERNEL_DEFINES} \
	    -I${kernels_dir} \
	    -c $< -o ${@F}

${mlir_target}: ${srcdir}/bitnet_gemm_iron.py
	mkdir -p ${@D}
	python3 $< ${aieargs} --trace_size 0 > $@

${xclbin_target}: ${mlir_target} build/bitnet_gemm_${m}x${k}x${n}.o
	mkdir -p ${@D}
	cd ${@D} && aiecc \
	    --alloc-scheme=${buffer_aloc_flag} \
	    --aie-generate-xclbin \
	    --no-compile-host \
	    --xclbin-name=${@F} \
	    ${aiecc_peano_flags} \
	    --aie-generate-npu-insts \
	    --npu-insts-name=${insts_target:build/%=%} \
	    $(<:%=../%)

clean:
	rm -rf build _build
