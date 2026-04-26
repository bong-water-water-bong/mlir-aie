module {
  aie.device(npu2) {
    %tile_0_2 = aie.tile(0, 2)
    %shim_noc_tile_0_0 = aie.tile(0, 0)
    %mem_tile_0_1 = aie.tile(0, 1)
    aie.objectfifo @inA(%shim_noc_tile_0_0, {%mem_tile_0_1}, 2 : i32) : !aie.objectfifo<memref<64x64xbf16>> 
    aie.objectfifo @memA(%mem_tile_0_1 dimensionsToStream [<size = 16, stride = 256>, <size = 8, stride = 8>, <size = 4, stride = 64>, <size = 8, stride = 1>], {%tile_0_2}, 2 : i32) : !aie.objectfifo<memref<64x64xbf16>> 
    aie.objectfifo.link [@inA] -> [@memA]([] [0])
    aie.objectfifo @inW(%shim_noc_tile_0_0, {%mem_tile_0_1}, 2 : i32) : !aie.objectfifo<memref<256xi32>> 
    aie.objectfifo @memW(%mem_tile_0_1, {%tile_0_2}, 2 : i32) : !aie.objectfifo<memref<256xi32>> 
    aie.objectfifo.link [@inW] -> [@memW]([] [0])
    aie.objectfifo @memC(%tile_0_2, {%mem_tile_0_1}, 2 : i32) : !aie.objectfifo<memref<64x64xbf16>> 
    aie.objectfifo @outC(%mem_tile_0_1 dimensionsToStream [<size = 16, stride = 256>, <size = 4, stride = 8>, <size = 8, stride = 32>, <size = 8, stride = 1>], {%shim_noc_tile_0_0}, 2 : i32) : !aie.objectfifo<memref<64x64xbf16>> 
    aie.objectfifo.link [@memC] -> [@outC]([] [0])
    func.func private @zero_bitnet_bf16(memref<64x64xbf16>) attributes {link_with = "bitnet_gemm_64x64x64.o"}
    func.func private @bitnet_gemm_bf16(memref<64x64xbf16>, memref<256xi32>, memref<64x64xbf16>) attributes {link_with = "bitnet_gemm_64x64x64.o"}
    %core_0_2 = aie.core(%tile_0_2) {
      %c0 = arith.constant 0 : index
      %c9223372036854775807 = arith.constant 9223372036854775807 : index
      %c1 = arith.constant 1 : index
      scf.for %arg0 = %c0 to %c9223372036854775807 step %c1 {
        %0 = aie.objectfifo.acquire @memC(Produce, 1) : !aie.objectfifosubview<memref<64x64xbf16>>
        %1 = aie.objectfifo.subview.access %0[0] : !aie.objectfifosubview<memref<64x64xbf16>> -> memref<64x64xbf16>
        func.call @zero_bitnet_bf16(%1) : (memref<64x64xbf16>) -> ()
        %2 = aie.objectfifo.acquire @memA(Consume, 1) : !aie.objectfifosubview<memref<64x64xbf16>>
        %3 = aie.objectfifo.subview.access %2[0] : !aie.objectfifosubview<memref<64x64xbf16>> -> memref<64x64xbf16>
        %4 = aie.objectfifo.acquire @memW(Consume, 1) : !aie.objectfifosubview<memref<256xi32>>
        %5 = aie.objectfifo.subview.access %4[0] : !aie.objectfifosubview<memref<256xi32>> -> memref<256xi32>
        func.call @bitnet_gemm_bf16(%3, %5, %1) : (memref<64x64xbf16>, memref<256xi32>, memref<64x64xbf16>) -> ()
        aie.objectfifo.release @memA(Consume, 1)
        aie.objectfifo.release @memW(Consume, 1)
        aie.objectfifo.release @memC(Produce, 1)
      }
      aie.end
    } {stack_size = 3328 : i32}
    aie.runtime_sequence(%arg0: memref<4096xbf16>, %arg1: memref<256xi32>, %arg2: memref<4096xbf16>) {
      %0 = aiex.dma_configure_task_for @inA {
        aie.dma_bd(%arg0 : memref<4096xbf16>, 0, 4096, [<size = 1, stride = 0>, <size = 1, stride = 0>, <size = 1, stride = 0>, <size = 4096, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%0)
      %1 = aiex.dma_configure_task_for @inW {
        aie.dma_bd(%arg1 : memref<256xi32>, 0, 256, [<size = 1, stride = 0>, <size = 1, stride = 0>, <size = 1, stride = 0>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%1)
      %2 = aiex.dma_configure_task_for @outC {
        aie.dma_bd(%arg2 : memref<4096xbf16>, 0, 4096, [<size = 1, stride = 0>, <size = 1, stride = 0>, <size = 1, stride = 0>, <size = 4096, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {issue_token = true}
      aiex.dma_start_task(%2)
      aiex.dma_await_task(%2)
      aiex.dma_free_task(%0)
      aiex.dma_free_task(%1)
    }
  }
}

