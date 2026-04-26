; ModuleID = 'aie_512_512x512x512_64x64x64.mlir.prj/main_core_0_2.peanohack.ll'
source_filename = "LLVMDialectModule"
target datalayout = "e-m:e-p:20:32-i1:8:32-i8:8:32-i16:16:32-i32:32:32-f32:32:32-i64:32-f64:32-a:0:32-n32"
target triple = "aie2p"

@memA_cons_buff_1 = external global [64 x [64 x bfloat]]
@memA_cons_buff_0 = external global [64 x [64 x bfloat]]
@memW_cons_buff_1 = external global [256 x i32]
@memW_cons_buff_0 = external global [256 x i32]
@memC_buff_1 = external global [64 x [64 x float]]
@memC_buff_0 = external global [64 x [64 x float]]

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn
declare void @llvm.aie2p.acquire(i32, i32) #0

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn
declare void @llvm.aie2p.release(i32, i32) #0

declare void @zero_bitnet_f32_512(ptr) local_unnamed_addr

declare void @bitnet_gemm_bf16_512(ptr, ptr, ptr) local_unnamed_addr

define void @core_0_2() local_unnamed_addr {
  br label %.preheader

.preheader:                                       ; preds = %0, %6
  %1 = phi i64 [ 0, %0 ], [ %7, %6 ]
  br label %2

2:                                                ; preds = %.preheader, %2
  %3 = phi i64 [ 0, %.preheader ], [ %4, %2 ]
  tail call void @llvm.aie2p.acquire(i32 52, i32 -1)
  tail call void @zero_bitnet_f32_512(ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_0, ptr nonnull @memW_cons_buff_0, ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_1, ptr nonnull @memW_cons_buff_1, ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_0, ptr nonnull @memW_cons_buff_0, ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_1, ptr nonnull @memW_cons_buff_1, ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_0, ptr nonnull @memW_cons_buff_0, ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_1, ptr nonnull @memW_cons_buff_1, ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_0, ptr nonnull @memW_cons_buff_0, ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_1, ptr nonnull @memW_cons_buff_1, ptr nonnull @memC_buff_0)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.release(i32 53, i32 1)
  tail call void @llvm.aie2p.acquire(i32 52, i32 -1)
  tail call void @zero_bitnet_f32_512(ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_0, ptr nonnull @memW_cons_buff_0, ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_1, ptr nonnull @memW_cons_buff_1, ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_0, ptr nonnull @memW_cons_buff_0, ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_1, ptr nonnull @memW_cons_buff_1, ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_0, ptr nonnull @memW_cons_buff_0, ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_1, ptr nonnull @memW_cons_buff_1, ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_0, ptr nonnull @memW_cons_buff_0, ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.acquire(i32 49, i32 -1)
  tail call void @llvm.aie2p.acquire(i32 51, i32 -1)
  tail call void @bitnet_gemm_bf16_512(ptr nonnull @memA_cons_buff_1, ptr nonnull @memW_cons_buff_1, ptr nonnull @memC_buff_1)
  tail call void @llvm.aie2p.release(i32 48, i32 1)
  tail call void @llvm.aie2p.release(i32 50, i32 1)
  tail call void @llvm.aie2p.release(i32 53, i32 1)
  %4 = add nuw nsw i64 %3, 2
  %5 = icmp samesign ult i64 %3, 62
  br i1 %5, label %2, label %6

6:                                                ; preds = %2
  %7 = add nuw nsw i64 %1, 1
  %.not = icmp eq i64 %7, 9223372036854775807
  br i1 %.not, label %8, label %.preheader

8:                                                ; preds = %6
  ret void
}

attributes #0 = { mustprogress nocallback nofree nosync nounwind willreturn }

!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
