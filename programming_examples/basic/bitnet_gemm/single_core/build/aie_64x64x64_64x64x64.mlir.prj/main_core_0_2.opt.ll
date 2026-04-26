; ModuleID = 'aie_64x64x64_64x64x64.mlir.prj/main_core_0_2.peanohack.ll'
source_filename = "LLVMDialectModule"
target datalayout = "e-m:e-p:20:32-i1:8:32-i8:8:32-i16:16:32-i32:32:32-f32:32:32-i64:32-f64:32-a:0:32-n32"
target triple = "aie2p"

@memA_cons_buff_1 = external global [64 x [64 x bfloat]]
@memA_cons_buff_0 = external global [64 x [64 x bfloat]]
@memW_cons_buff_1 = external global [256 x i32]
@memW_cons_buff_0 = external global [256 x i32]
@memC_buff_1 = external global [64 x [64 x bfloat]]
@memC_buff_0 = external global [64 x [64 x bfloat]]

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn
declare void @llvm.aie2p.acquire(i32, i32) #0

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn
declare void @llvm.aie2p.release(i32, i32) #0

declare void @zero_bitnet_bf16(ptr) local_unnamed_addr

declare void @bitnet_gemm_bf16(ptr, ptr, ptr) local_unnamed_addr

define void @core_0_2() local_unnamed_addr {
  br label %1

1:                                                ; preds = %0, %1
  %2 = phi i64 [ 0, %0 ], [ %3, %1 ]
  tail call void @llvm.aie2p.acquire(i32 52, i32 -1)
  tail call void @zero_bitnet_bf16(ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16(ptr nonnull @memA_cons_buff_0, ptr nonnull @memW_cons_buff_0, ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.release(i32 53, i32 1)
  tail call void @llvm.aie2p.acquire(i32 52, i32 -1)
  tail call void @zero_bitnet_bf16(ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16(ptr nonnull @memA_cons_buff_1, ptr nonnull @memW_cons_buff_1, ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.release(i32 53, i32 1)
  %3 = add nuw nsw i64 %2, 2
  %.not = icmp eq i64 %3, 9223372036854775806
  br i1 %.not, label %4, label %1

4:                                                ; preds = %1
  tail call void @llvm.aie2p.acquire(i32 52, i32 -1)
  tail call void @zero_bitnet_bf16(ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16(ptr nonnull @memA_cons_buff_0, ptr nonnull @memW_cons_buff_0, ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.release(i32 53, i32 1)
  ret void
}

attributes #0 = { mustprogress nocallback nofree nosync nounwind willreturn }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
