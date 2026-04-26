; ModuleID = 'LLVMDialectModule'
source_filename = "LLVMDialectModule"
target triple = "aie2p"

@inA_cons_buff_1 = external global [64 x [64 x bfloat]]
@inA_cons_buff_0 = external global [64 x [64 x bfloat]]
@memA_cons_buff_1 = external global [64 x [64 x bfloat]]
@memA_cons_buff_0 = external global [64 x [64 x bfloat]]
@inW_cons_buff_1 = external global [256 x i32]
@inW_cons_buff_0 = external global [256 x i32]
@memW_cons_buff_1 = external global [256 x i32]
@memW_cons_buff_0 = external global [256 x i32]
@memC_buff_1 = external global [64 x [64 x bfloat]]
@memC_buff_0 = external global [64 x [64 x bfloat]]
@memC_cons_buff_1 = external global [64 x [64 x bfloat]]
@memC_cons_buff_0 = external global [64 x [64 x bfloat]]

declare void @debug_i32(i32)

; Unknown intrinsic
declare void @llvm.aie2p.event(i32)

; Unknown intrinsic
declare void @llvm.aie2p.put.ms(i32, i32)

; Unknown intrinsic
declare { i32, i32 } @llvm.aie2p.get.ss()

; Unknown intrinsic
declare void @llvm.aie2p.mcd.write.vec(<16 x i32>, i32)

; Unknown intrinsic
declare <16 x i32> @llvm.aie2p.scd.read.vec(i32)

; Unknown intrinsic
declare void @llvm.aie2p.acquire(i32, i32)

; Unknown intrinsic
declare void @llvm.aie2p.release(i32, i32)

; Unknown intrinsic
declare void @llvm.aie2p.set.ctrl.reg(i32, i32)

declare void @zero_bitnet_bf16(ptr)

declare void @bitnet_gemm_bf16(ptr, ptr, ptr)

define void @core_0_2() {
  br label %1

1:                                                ; preds = %4, %0
  %2 = phi i64 [ %5, %4 ], [ 0, %0 ]
  %3 = icmp slt i64 %2, 9223372036854775806
  br i1 %3, label %4, label %6

4:                                                ; preds = %1
  call void @llvm.aie2p.acquire(i32 52, i32 -1)
  call void @zero_bitnet_bf16(ptr @memC_buff_0)
  call void @llvm.aie2p.acquire(i32 49, i32 -1)
  call void @llvm.aie2p.acquire(i32 51, i32 -1)
  call void @bitnet_gemm_bf16(ptr @memA_cons_buff_0, ptr @memW_cons_buff_0, ptr @memC_buff_0)
  call void @llvm.aie2p.release(i32 48, i32 1)
  call void @llvm.aie2p.release(i32 50, i32 1)
  call void @llvm.aie2p.release(i32 53, i32 1)
  call void @llvm.aie2p.acquire(i32 52, i32 -1)
  call void @zero_bitnet_bf16(ptr @memC_buff_1)
  call void @llvm.aie2p.acquire(i32 49, i32 -1)
  call void @llvm.aie2p.acquire(i32 51, i32 -1)
  call void @bitnet_gemm_bf16(ptr @memA_cons_buff_1, ptr @memW_cons_buff_1, ptr @memC_buff_1)
  call void @llvm.aie2p.release(i32 48, i32 1)
  call void @llvm.aie2p.release(i32 50, i32 1)
  call void @llvm.aie2p.release(i32 53, i32 1)
  %5 = add i64 %2, 2
  br label %1

6:                                                ; preds = %1
  call void @llvm.aie2p.acquire(i32 52, i32 -1)
  call void @zero_bitnet_bf16(ptr @memC_buff_0)
  call void @llvm.aie2p.acquire(i32 49, i32 -1)
  call void @llvm.aie2p.acquire(i32 51, i32 -1)
  call void @bitnet_gemm_bf16(ptr @memA_cons_buff_0, ptr @memW_cons_buff_0, ptr @memC_buff_0)
  call void @llvm.aie2p.release(i32 48, i32 1)
  call void @llvm.aie2p.release(i32 50, i32 1)
  call void @llvm.aie2p.release(i32 53, i32 1)
  ret void
}

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
