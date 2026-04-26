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
    aie.objectfifo @memC(%tile_0_2, {%mem_tile_0_1}, 2 : i32) : !aie.objectfifo<memref<64x64xf32>> 
    aie.objectfifo @outC(%mem_tile_0_1 dimensionsToStream [<size = 16, stride = 256>, <size = 4, stride = 8>, <size = 8, stride = 32>, <size = 8, stride = 1>], {%shim_noc_tile_0_0}, 2 : i32) : !aie.objectfifo<memref<64x64xf32>> 
    aie.objectfifo.link [@memC] -> [@outC]([] [0])
    func.func private @zero_bitnet_f32_512(memref<64x64xf32>) attributes {link_with = "bitnet_gemm_512_64x64x64.o"}
    func.func private @bitnet_gemm_bf16_512(memref<64x64xbf16>, memref<256xi32>, memref<64x64xf32>) attributes {link_with = "bitnet_gemm_512_64x64x64.o"}
    %core_0_2 = aie.core(%tile_0_2) {
      %c0 = arith.constant 0 : index
      %c9223372036854775807 = arith.constant 9223372036854775807 : index
      %c1 = arith.constant 1 : index
      scf.for %arg0 = %c0 to %c9223372036854775807 step %c1 {
        %c0_0 = arith.constant 0 : index
        %c64 = arith.constant 64 : index
        %c1_1 = arith.constant 1 : index
        scf.for %arg1 = %c0_0 to %c64 step %c1_1 {
          %0 = aie.objectfifo.acquire @memC(Produce, 1) : !aie.objectfifosubview<memref<64x64xf32>>
          %1 = aie.objectfifo.subview.access %0[0] : !aie.objectfifosubview<memref<64x64xf32>> -> memref<64x64xf32>
          func.call @zero_bitnet_f32_512(%1) : (memref<64x64xf32>) -> ()
          %c0_2 = arith.constant 0 : index
          %c8 = arith.constant 8 : index
          %c1_3 = arith.constant 1 : index
          scf.for %arg2 = %c0_2 to %c8 step %c1_3 {
            %2 = aie.objectfifo.acquire @memA(Consume, 1) : !aie.objectfifosubview<memref<64x64xbf16>>
            %3 = aie.objectfifo.subview.access %2[0] : !aie.objectfifosubview<memref<64x64xbf16>> -> memref<64x64xbf16>
            %4 = aie.objectfifo.acquire @memW(Consume, 1) : !aie.objectfifosubview<memref<256xi32>>
            %5 = aie.objectfifo.subview.access %4[0] : !aie.objectfifosubview<memref<256xi32>> -> memref<256xi32>
            func.call @bitnet_gemm_bf16_512(%3, %5, %1) : (memref<64x64xbf16>, memref<256xi32>, memref<64x64xf32>) -> ()
            aie.objectfifo.release @memA(Consume, 1)
            aie.objectfifo.release @memW(Consume, 1)
          }
          aie.objectfifo.release @memC(Produce, 1)
        }
      }
      aie.end
    } {stack_size = 3328 : i32}
    aie.runtime_sequence(%arg0: memref<262144xbf16>, %arg1: memref<16384xi32>, %arg2: memref<262144xf32>) {
      %0 = aiex.dma_configure_task_for @inA {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 0, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%0)
      %1 = aiex.dma_configure_task_for @inW {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%1)
      %2 = aiex.dma_configure_task_for @inA {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 32768, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%2)
      %3 = aiex.dma_configure_task_for @inW {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%3)
      %4 = aiex.dma_configure_task_for @outC {
        aie.dma_bd(%arg2 : memref<262144xf32>, 0, 32768, [<size = 2, stride = 32768>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {issue_token = true, repeat_count = 1 : i32}
      aiex.dma_start_task(%4)
      %5 = aiex.dma_configure_task_for @inA {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 65536, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%5)
      %6 = aiex.dma_configure_task_for @inW {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%6)
      %7 = aiex.dma_configure_task_for @inA {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 98304, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%7)
      %8 = aiex.dma_configure_task_for @inW {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%8)
      %9 = aiex.dma_configure_task_for @outC {
        aie.dma_bd(%arg2 : memref<262144xf32>, 65536, 32768, [<size = 2, stride = 32768>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {issue_token = true, repeat_count = 1 : i32}
      aiex.dma_start_task(%9)
      aiex.dma_await_task(%4)
      aiex.dma_free_task(%0)
      aiex.dma_free_task(%1)
      aiex.dma_free_task(%2)
      aiex.dma_free_task(%3)
      %10 = aiex.dma_configure_task_for @inA {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 131072, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%10)
      %11 = aiex.dma_configure_task_for @inW {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%11)
      %12 = aiex.dma_configure_task_for @inA {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 163840, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%12)
      %13 = aiex.dma_configure_task_for @inW {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%13)
      %14 = aiex.dma_configure_task_for @outC {
        aie.dma_bd(%arg2 : memref<262144xf32>, 131072, 32768, [<size = 2, stride = 32768>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {issue_token = true, repeat_count = 1 : i32}
      aiex.dma_start_task(%14)
      aiex.dma_await_task(%9)
      aiex.dma_free_task(%5)
      aiex.dma_free_task(%6)
      aiex.dma_free_task(%7)
      aiex.dma_free_task(%8)
      %15 = aiex.dma_configure_task_for @inA {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 196608, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%15)
      %16 = aiex.dma_configure_task_for @inW {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%16)
      %17 = aiex.dma_configure_task_for @inA {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 229376, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%17)
      %18 = aiex.dma_configure_task_for @inW {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%18)
      %19 = aiex.dma_configure_task_for @outC {
        aie.dma_bd(%arg2 : memref<262144xf32>, 196608, 32768, [<size = 2, stride = 32768>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {issue_token = true, repeat_count = 1 : i32}
      aiex.dma_start_task(%19)
      aiex.dma_await_task(%14)
      aiex.dma_free_task(%10)
      aiex.dma_free_task(%11)
      aiex.dma_free_task(%12)
      aiex.dma_free_task(%13)
      aiex.dma_await_task(%19)
      aiex.dma_free_task(%15)
      aiex.dma_free_task(%16)
      aiex.dma_free_task(%17)
      aiex.dma_free_task(%18)
    }
  }
}

