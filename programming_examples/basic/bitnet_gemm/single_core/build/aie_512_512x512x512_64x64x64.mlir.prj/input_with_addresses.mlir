module {
  aie.device(npu2) {
    %tile_0_2 = aie.tile(0, 2) {controller_id = #aie.packet_info<pkt_type = 0, pkt_id = 27>}
    %shim_noc_tile_0_0 = aie.tile(0, 0) {controller_id = #aie.packet_info<pkt_type = 0, pkt_id = 15>}
    %mem_tile_0_1 = aie.tile(0, 1) {controller_id = #aie.packet_info<pkt_type = 0, pkt_id = 26>}
    %outC_cons_prod_lock_0 = aie.lock(%shim_noc_tile_0_0, 4) {init = 0 : i32, sym_name = "outC_cons_prod_lock_0"}
    %outC_cons_cons_lock_0 = aie.lock(%shim_noc_tile_0_0, 5) {init = 0 : i32, sym_name = "outC_cons_cons_lock_0"}
    %memC_cons_buff_0 = aie.buffer(%mem_tile_0_1) {address = 0 : i32, sym_name = "memC_cons_buff_0"} : memref<64x64xf32> 
    %memC_cons_buff_1 = aie.buffer(%mem_tile_0_1) {address = 16384 : i32, sym_name = "memC_cons_buff_1"} : memref<64x64xf32> 
    %memC_cons_prod_lock_0 = aie.lock(%mem_tile_0_1, 4) {init = 2 : i32, sym_name = "memC_cons_prod_lock_0"}
    %memC_cons_cons_lock_0 = aie.lock(%mem_tile_0_1, 5) {init = 0 : i32, sym_name = "memC_cons_cons_lock_0"}
    %memC_buff_0 = aie.buffer(%tile_0_2) {address = 3328 : i32, sym_name = "memC_buff_0"} : memref<64x64xf32> 
    %memC_buff_1 = aie.buffer(%tile_0_2) {address = 19712 : i32, sym_name = "memC_buff_1"} : memref<64x64xf32> 
    %memC_prod_lock_0 = aie.lock(%tile_0_2, 4) {init = 2 : i32, sym_name = "memC_prod_lock_0"}
    %memC_cons_lock_0 = aie.lock(%tile_0_2, 5) {init = 0 : i32, sym_name = "memC_cons_lock_0"}
    %memW_cons_buff_0 = aie.buffer(%tile_0_2) {address = 52480 : i32, sym_name = "memW_cons_buff_0"} : memref<256xi32> 
    %memW_cons_buff_1 = aie.buffer(%tile_0_2) {address = 53504 : i32, sym_name = "memW_cons_buff_1"} : memref<256xi32> 
    %memW_cons_prod_lock_0 = aie.lock(%tile_0_2, 2) {init = 2 : i32, sym_name = "memW_cons_prod_lock_0"}
    %memW_cons_cons_lock_0 = aie.lock(%tile_0_2, 3) {init = 0 : i32, sym_name = "memW_cons_cons_lock_0"}
    %inW_cons_buff_0 = aie.buffer(%mem_tile_0_1) {address = 49152 : i32, sym_name = "inW_cons_buff_0"} : memref<256xi32> 
    %inW_cons_buff_1 = aie.buffer(%mem_tile_0_1) {address = 50176 : i32, sym_name = "inW_cons_buff_1"} : memref<256xi32> 
    %inW_cons_prod_lock_0 = aie.lock(%mem_tile_0_1, 2) {init = 2 : i32, sym_name = "inW_cons_prod_lock_0"}
    %inW_cons_cons_lock_0 = aie.lock(%mem_tile_0_1, 3) {init = 0 : i32, sym_name = "inW_cons_cons_lock_0"}
    %inW_prod_lock_0 = aie.lock(%shim_noc_tile_0_0, 2) {init = 0 : i32, sym_name = "inW_prod_lock_0"}
    %inW_cons_lock_0 = aie.lock(%shim_noc_tile_0_0, 3) {init = 0 : i32, sym_name = "inW_cons_lock_0"}
    %memA_cons_buff_0 = aie.buffer(%tile_0_2) {address = 36096 : i32, sym_name = "memA_cons_buff_0"} : memref<64x64xbf16> 
    %memA_cons_buff_1 = aie.buffer(%tile_0_2) {address = 44288 : i32, sym_name = "memA_cons_buff_1"} : memref<64x64xbf16> 
    %memA_cons_prod_lock_0 = aie.lock(%tile_0_2, 0) {init = 2 : i32, sym_name = "memA_cons_prod_lock_0"}
    %memA_cons_cons_lock_0 = aie.lock(%tile_0_2, 1) {init = 0 : i32, sym_name = "memA_cons_cons_lock_0"}
    %inA_cons_buff_0 = aie.buffer(%mem_tile_0_1) {address = 32768 : i32, sym_name = "inA_cons_buff_0"} : memref<64x64xbf16> 
    %inA_cons_buff_1 = aie.buffer(%mem_tile_0_1) {address = 40960 : i32, sym_name = "inA_cons_buff_1"} : memref<64x64xbf16> 
    %inA_cons_prod_lock_0 = aie.lock(%mem_tile_0_1, 0) {init = 2 : i32, sym_name = "inA_cons_prod_lock_0"}
    %inA_cons_cons_lock_0 = aie.lock(%mem_tile_0_1, 1) {init = 0 : i32, sym_name = "inA_cons_cons_lock_0"}
    %inA_prod_lock_0 = aie.lock(%shim_noc_tile_0_0, 0) {init = 0 : i32, sym_name = "inA_prod_lock_0"}
    %inA_cons_lock_0 = aie.lock(%shim_noc_tile_0_0, 1) {init = 0 : i32, sym_name = "inA_cons_lock_0"}
    aie.flow(%shim_noc_tile_0_0, DMA : 0, %mem_tile_0_1, DMA : 0)
    aie.flow(%mem_tile_0_1, DMA : 0, %tile_0_2, DMA : 0)
    aie.flow(%shim_noc_tile_0_0, DMA : 1, %mem_tile_0_1, DMA : 1)
    aie.flow(%mem_tile_0_1, DMA : 1, %tile_0_2, DMA : 1)
    aie.flow(%tile_0_2, DMA : 0, %mem_tile_0_1, DMA : 2)
    aie.flow(%mem_tile_0_1, DMA : 2, %shim_noc_tile_0_0, DMA : 0)
    func.func private @zero_bitnet_f32_512(memref<64x64xf32>) attributes {link_with = "bitnet_gemm_512_64x64x64.o"}
    func.func private @bitnet_gemm_bf16_512(memref<64x64xbf16>, memref<256xi32>, memref<64x64xf32>) attributes {link_with = "bitnet_gemm_512_64x64x64.o"}
    %core_0_2 = aie.core(%tile_0_2) {
      %c2 = arith.constant 2 : index
      %c8 = arith.constant 8 : index
      %c64 = arith.constant 64 : index
      %c0 = arith.constant 0 : index
      %c9223372036854775807 = arith.constant 9223372036854775807 : index
      %c1 = arith.constant 1 : index
      cf.br ^bb1(%c0 : index)
    ^bb1(%0: index):  // 2 preds: ^bb0, ^bb11
      %1 = arith.cmpi slt, %0, %c9223372036854775807 : index
      cf.cond_br %1, ^bb2, ^bb12
    ^bb2:  // pred: ^bb1
      cf.br ^bb3(%c0 : index)
    ^bb3(%2: index):  // 2 preds: ^bb2, ^bb10
      %3 = arith.cmpi slt, %2, %c64 : index
      cf.cond_br %3, ^bb4, ^bb11
    ^bb4:  // pred: ^bb3
      aie.use_lock(%memC_prod_lock_0, AcquireGreaterEqual, 1)
      func.call @zero_bitnet_f32_512(%memC_buff_0) : (memref<64x64xf32>) -> ()
      cf.br ^bb5(%c0 : index)
    ^bb5(%4: index):  // 2 preds: ^bb4, ^bb6
      %5 = arith.cmpi slt, %4, %c8 : index
      cf.cond_br %5, ^bb6, ^bb7
    ^bb6:  // pred: ^bb5
      aie.use_lock(%memA_cons_cons_lock_0, AcquireGreaterEqual, 1)
      aie.use_lock(%memW_cons_cons_lock_0, AcquireGreaterEqual, 1)
      func.call @bitnet_gemm_bf16_512(%memA_cons_buff_0, %memW_cons_buff_0, %memC_buff_0) : (memref<64x64xbf16>, memref<256xi32>, memref<64x64xf32>) -> ()
      aie.use_lock(%memA_cons_prod_lock_0, Release, 1)
      aie.use_lock(%memW_cons_prod_lock_0, Release, 1)
      aie.use_lock(%memA_cons_cons_lock_0, AcquireGreaterEqual, 1)
      aie.use_lock(%memW_cons_cons_lock_0, AcquireGreaterEqual, 1)
      func.call @bitnet_gemm_bf16_512(%memA_cons_buff_1, %memW_cons_buff_1, %memC_buff_0) : (memref<64x64xbf16>, memref<256xi32>, memref<64x64xf32>) -> ()
      aie.use_lock(%memA_cons_prod_lock_0, Release, 1)
      aie.use_lock(%memW_cons_prod_lock_0, Release, 1)
      %6 = arith.addi %4, %c2 : index
      cf.br ^bb5(%6 : index)
    ^bb7:  // pred: ^bb5
      aie.use_lock(%memC_cons_lock_0, Release, 1)
      aie.use_lock(%memC_prod_lock_0, AcquireGreaterEqual, 1)
      func.call @zero_bitnet_f32_512(%memC_buff_1) : (memref<64x64xf32>) -> ()
      cf.br ^bb8(%c0 : index)
    ^bb8(%7: index):  // 2 preds: ^bb7, ^bb9
      %8 = arith.cmpi slt, %7, %c8 : index
      cf.cond_br %8, ^bb9, ^bb10
    ^bb9:  // pred: ^bb8
      aie.use_lock(%memA_cons_cons_lock_0, AcquireGreaterEqual, 1)
      aie.use_lock(%memW_cons_cons_lock_0, AcquireGreaterEqual, 1)
      func.call @bitnet_gemm_bf16_512(%memA_cons_buff_0, %memW_cons_buff_0, %memC_buff_1) : (memref<64x64xbf16>, memref<256xi32>, memref<64x64xf32>) -> ()
      aie.use_lock(%memA_cons_prod_lock_0, Release, 1)
      aie.use_lock(%memW_cons_prod_lock_0, Release, 1)
      aie.use_lock(%memA_cons_cons_lock_0, AcquireGreaterEqual, 1)
      aie.use_lock(%memW_cons_cons_lock_0, AcquireGreaterEqual, 1)
      func.call @bitnet_gemm_bf16_512(%memA_cons_buff_1, %memW_cons_buff_1, %memC_buff_1) : (memref<64x64xbf16>, memref<256xi32>, memref<64x64xf32>) -> ()
      aie.use_lock(%memA_cons_prod_lock_0, Release, 1)
      aie.use_lock(%memW_cons_prod_lock_0, Release, 1)
      %9 = arith.addi %7, %c2 : index
      cf.br ^bb8(%9 : index)
    ^bb10:  // pred: ^bb8
      aie.use_lock(%memC_cons_lock_0, Release, 1)
      %10 = arith.addi %2, %c2 : index
      cf.br ^bb3(%10 : index)
    ^bb11:  // pred: ^bb3
      %11 = arith.addi %0, %c1 : index
      cf.br ^bb1(%11 : index)
    ^bb12:  // pred: ^bb1
      aie.end
    } {link_files = ["bitnet_gemm_512_64x64x64.o"], stack_size = 3328 : i32}
    aie.runtime_sequence(%arg0: memref<262144xbf16>, %arg1: memref<16384xi32>, %arg2: memref<262144xf32>) {
      %0 = aiex.dma_configure_task_for @inA_shim_alloc {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 0, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%0)
      %1 = aiex.dma_configure_task_for @inW_shim_alloc {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%1)
      %2 = aiex.dma_configure_task_for @inA_shim_alloc {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 32768, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%2)
      %3 = aiex.dma_configure_task_for @inW_shim_alloc {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%3)
      %4 = aiex.dma_configure_task_for @outC_shim_alloc {
        aie.dma_bd(%arg2 : memref<262144xf32>, 0, 32768, [<size = 2, stride = 32768>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {issue_token = true, repeat_count = 1 : i32}
      aiex.dma_start_task(%4)
      %5 = aiex.dma_configure_task_for @inA_shim_alloc {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 65536, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%5)
      %6 = aiex.dma_configure_task_for @inW_shim_alloc {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%6)
      %7 = aiex.dma_configure_task_for @inA_shim_alloc {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 98304, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%7)
      %8 = aiex.dma_configure_task_for @inW_shim_alloc {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%8)
      %9 = aiex.dma_configure_task_for @outC_shim_alloc {
        aie.dma_bd(%arg2 : memref<262144xf32>, 65536, 32768, [<size = 2, stride = 32768>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {issue_token = true, repeat_count = 1 : i32}
      aiex.dma_start_task(%9)
      aiex.dma_await_task(%4)
      aiex.dma_free_task(%0)
      aiex.dma_free_task(%1)
      aiex.dma_free_task(%2)
      aiex.dma_free_task(%3)
      %10 = aiex.dma_configure_task_for @inA_shim_alloc {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 131072, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%10)
      %11 = aiex.dma_configure_task_for @inW_shim_alloc {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%11)
      %12 = aiex.dma_configure_task_for @inA_shim_alloc {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 163840, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%12)
      %13 = aiex.dma_configure_task_for @inW_shim_alloc {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%13)
      %14 = aiex.dma_configure_task_for @outC_shim_alloc {
        aie.dma_bd(%arg2 : memref<262144xf32>, 131072, 32768, [<size = 2, stride = 32768>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {issue_token = true, repeat_count = 1 : i32}
      aiex.dma_start_task(%14)
      aiex.dma_await_task(%9)
      aiex.dma_free_task(%5)
      aiex.dma_free_task(%6)
      aiex.dma_free_task(%7)
      aiex.dma_free_task(%8)
      %15 = aiex.dma_configure_task_for @inA_shim_alloc {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 196608, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%15)
      %16 = aiex.dma_configure_task_for @inW_shim_alloc {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%16)
      %17 = aiex.dma_configure_task_for @inA_shim_alloc {
        aie.dma_bd(%arg0 : memref<262144xbf16>, 229376, 32768, [<size = 8, stride = 0>, <size = 8, stride = 64>, <size = 64, stride = 512>, <size = 64, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      } {repeat_count = 7 : i32}
      aiex.dma_start_task(%17)
      %18 = aiex.dma_configure_task_for @inW_shim_alloc {
        aie.dma_bd(%arg1 : memref<16384xi32>, 0, 16384, [<size = 1, stride = 0>, <size = 64, stride = 256>, <size = 1, stride = 256>, <size = 256, stride = 1>]) {burst_length = 0 : i32}
        aie.end
      }
      aiex.dma_start_task(%18)
      %19 = aiex.dma_configure_task_for @outC_shim_alloc {
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
    aie.shim_dma_allocation @inA_shim_alloc(%shim_noc_tile_0_0, MM2S, 0)
    %memtile_dma_0_1 = aie.memtile_dma(%mem_tile_0_1) {
      %0 = aie.dma_start(S2MM, 0, ^bb1, ^bb3)
    ^bb1:  // 2 preds: ^bb0, ^bb2
      aie.use_lock(%inA_cons_prod_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%inA_cons_buff_0 : memref<64x64xbf16>, 0, 4096) {bd_id = 0 : i32, next_bd_id = 1 : i32}
      aie.use_lock(%inA_cons_cons_lock_0, Release, 1)
      aie.next_bd ^bb2
    ^bb2:  // pred: ^bb1
      aie.use_lock(%inA_cons_prod_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%inA_cons_buff_1 : memref<64x64xbf16>, 0, 4096) {bd_id = 1 : i32, next_bd_id = 0 : i32}
      aie.use_lock(%inA_cons_cons_lock_0, Release, 1)
      aie.next_bd ^bb1
    ^bb3:  // pred: ^bb0
      %1 = aie.dma_start(MM2S, 0, ^bb4, ^bb6)
    ^bb4:  // 2 preds: ^bb3, ^bb5
      aie.use_lock(%inA_cons_cons_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%inA_cons_buff_0 : memref<64x64xbf16>, 0, 4096, [<size = 16, stride = 256>, <size = 8, stride = 8>, <size = 4, stride = 64>, <size = 8, stride = 1>]) {bd_id = 2 : i32, next_bd_id = 3 : i32}
      aie.use_lock(%inA_cons_prod_lock_0, Release, 1)
      aie.next_bd ^bb5
    ^bb5:  // pred: ^bb4
      aie.use_lock(%inA_cons_cons_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%inA_cons_buff_1 : memref<64x64xbf16>, 0, 4096, [<size = 16, stride = 256>, <size = 8, stride = 8>, <size = 4, stride = 64>, <size = 8, stride = 1>]) {bd_id = 3 : i32, next_bd_id = 2 : i32}
      aie.use_lock(%inA_cons_prod_lock_0, Release, 1)
      aie.next_bd ^bb4
    ^bb6:  // pred: ^bb3
      %2 = aie.dma_start(S2MM, 1, ^bb7, ^bb9)
    ^bb7:  // 2 preds: ^bb6, ^bb8
      aie.use_lock(%inW_cons_prod_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%inW_cons_buff_0 : memref<256xi32>, 0, 256) {bd_id = 24 : i32, next_bd_id = 25 : i32}
      aie.use_lock(%inW_cons_cons_lock_0, Release, 1)
      aie.next_bd ^bb8
    ^bb8:  // pred: ^bb7
      aie.use_lock(%inW_cons_prod_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%inW_cons_buff_1 : memref<256xi32>, 0, 256) {bd_id = 25 : i32, next_bd_id = 24 : i32}
      aie.use_lock(%inW_cons_cons_lock_0, Release, 1)
      aie.next_bd ^bb7
    ^bb9:  // pred: ^bb6
      %3 = aie.dma_start(MM2S, 1, ^bb10, ^bb12)
    ^bb10:  // 2 preds: ^bb9, ^bb11
      aie.use_lock(%inW_cons_cons_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%inW_cons_buff_0 : memref<256xi32>, 0, 256) {bd_id = 26 : i32, next_bd_id = 27 : i32}
      aie.use_lock(%inW_cons_prod_lock_0, Release, 1)
      aie.next_bd ^bb11
    ^bb11:  // pred: ^bb10
      aie.use_lock(%inW_cons_cons_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%inW_cons_buff_1 : memref<256xi32>, 0, 256) {bd_id = 27 : i32, next_bd_id = 26 : i32}
      aie.use_lock(%inW_cons_prod_lock_0, Release, 1)
      aie.next_bd ^bb10
    ^bb12:  // pred: ^bb9
      %4 = aie.dma_start(S2MM, 2, ^bb13, ^bb15)
    ^bb13:  // 2 preds: ^bb12, ^bb14
      aie.use_lock(%memC_cons_prod_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%memC_cons_buff_0 : memref<64x64xf32>, 0, 4096) {bd_id = 4 : i32, next_bd_id = 5 : i32}
      aie.use_lock(%memC_cons_cons_lock_0, Release, 1)
      aie.next_bd ^bb14
    ^bb14:  // pred: ^bb13
      aie.use_lock(%memC_cons_prod_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%memC_cons_buff_1 : memref<64x64xf32>, 0, 4096) {bd_id = 5 : i32, next_bd_id = 4 : i32}
      aie.use_lock(%memC_cons_cons_lock_0, Release, 1)
      aie.next_bd ^bb13
    ^bb15:  // pred: ^bb12
      %5 = aie.dma_start(MM2S, 2, ^bb16, ^bb18)
    ^bb16:  // 2 preds: ^bb15, ^bb17
      aie.use_lock(%memC_cons_cons_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%memC_cons_buff_0 : memref<64x64xf32>, 0, 4096, [<size = 16, stride = 256>, <size = 4, stride = 8>, <size = 8, stride = 32>, <size = 8, stride = 1>]) {bd_id = 6 : i32, next_bd_id = 7 : i32}
      aie.use_lock(%memC_cons_prod_lock_0, Release, 1)
      aie.next_bd ^bb17
    ^bb17:  // pred: ^bb16
      aie.use_lock(%memC_cons_cons_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%memC_cons_buff_1 : memref<64x64xf32>, 0, 4096, [<size = 16, stride = 256>, <size = 4, stride = 8>, <size = 8, stride = 32>, <size = 8, stride = 1>]) {bd_id = 7 : i32, next_bd_id = 6 : i32}
      aie.use_lock(%memC_cons_prod_lock_0, Release, 1)
      aie.next_bd ^bb16
    ^bb18:  // pred: ^bb15
      aie.end
    }
    %mem_0_2 = aie.mem(%tile_0_2) {
      %0 = aie.dma_start(S2MM, 0, ^bb1, ^bb3)
    ^bb1:  // 2 preds: ^bb0, ^bb2
      aie.use_lock(%memA_cons_prod_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%memA_cons_buff_0 : memref<64x64xbf16>, 0, 4096) {bd_id = 0 : i32, next_bd_id = 1 : i32}
      aie.use_lock(%memA_cons_cons_lock_0, Release, 1)
      aie.next_bd ^bb2
    ^bb2:  // pred: ^bb1
      aie.use_lock(%memA_cons_prod_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%memA_cons_buff_1 : memref<64x64xbf16>, 0, 4096) {bd_id = 1 : i32, next_bd_id = 0 : i32}
      aie.use_lock(%memA_cons_cons_lock_0, Release, 1)
      aie.next_bd ^bb1
    ^bb3:  // pred: ^bb0
      %1 = aie.dma_start(S2MM, 1, ^bb4, ^bb6)
    ^bb4:  // 2 preds: ^bb3, ^bb5
      aie.use_lock(%memW_cons_prod_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%memW_cons_buff_0 : memref<256xi32>, 0, 256) {bd_id = 2 : i32, next_bd_id = 3 : i32}
      aie.use_lock(%memW_cons_cons_lock_0, Release, 1)
      aie.next_bd ^bb5
    ^bb5:  // pred: ^bb4
      aie.use_lock(%memW_cons_prod_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%memW_cons_buff_1 : memref<256xi32>, 0, 256) {bd_id = 3 : i32, next_bd_id = 2 : i32}
      aie.use_lock(%memW_cons_cons_lock_0, Release, 1)
      aie.next_bd ^bb4
    ^bb6:  // pred: ^bb3
      %2 = aie.dma_start(MM2S, 0, ^bb7, ^bb9)
    ^bb7:  // 2 preds: ^bb6, ^bb8
      aie.use_lock(%memC_cons_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%memC_buff_0 : memref<64x64xf32>, 0, 4096) {bd_id = 4 : i32, next_bd_id = 5 : i32}
      aie.use_lock(%memC_prod_lock_0, Release, 1)
      aie.next_bd ^bb8
    ^bb8:  // pred: ^bb7
      aie.use_lock(%memC_cons_lock_0, AcquireGreaterEqual, 1)
      aie.dma_bd(%memC_buff_1 : memref<64x64xf32>, 0, 4096) {bd_id = 5 : i32, next_bd_id = 4 : i32}
      aie.use_lock(%memC_prod_lock_0, Release, 1)
      aie.next_bd ^bb7
    ^bb9:  // pred: ^bb6
      aie.end
    }
    aie.shim_dma_allocation @inW_shim_alloc(%shim_noc_tile_0_0, MM2S, 1)
    aie.shim_dma_allocation @outC_shim_alloc(%shim_noc_tile_0_0, S2MM, 0)
    aie.packet_flow(15) {
      aie.packet_source<%shim_noc_tile_0_0, TileControl : 0>
      aie.packet_dest<%shim_noc_tile_0_0, South : 0>
    } {keep_pkt_header = true, priority_route = true}
  }
}
