/// v0.5.2: 공통 리뷰 수정 launcher
///
/// 모든 진입점(박물관별 리뷰, 내 리뷰, 리뷰 상세)에서 동일한 수정 흐름을 사용합니다.
///
/// 저장 순서:
///   1. reviewId로 기존 사진 상태 확보 (ReviewFormSheet 내부에서 _loadExistingImages)
///   2. 리뷰 텍스트·별점 UPDATE
///   3. 삭제 예약된 review_images soft delete (applyPendingDeletes)
///   4. 삭제 DB 성공 후 Storage 삭제
///   5. 신규 pending 이미지 Storage 업로드 + review_images INSERT (uploadPendingImages)
///   6. 남은 published 사진 display_order 재정렬
///   7. provider invalidate
///   8. 화면 닫기 + Snackbar
library;

import 'package:flutter/foundation.dart';
import '../../../data/repositories/review_image_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/review.dart';
import '../../../presentation/providers/review_provider.dart';
import 'review_screen.dart' show ReviewFormSheet, ReviewFormSheetState;

/// 공통 리뷰 수정 BottomSheet를 표시합니다.
///
/// [review] 수정할 리뷰 (id, museumId, visitId, rating, content, visitedOn 필요)
/// [museumName] 박물관 이름 (수정 시트 타이틀용, 선택)
Future<void> showReviewEditSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Review review,
  String? museumName,
}) async {
  if (!review.isEditable) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('작성 후 7일이 지나 수정할 수 없습니다.')),
    );
    return;
  }

  if (kDebugMode) {
    final maskedId = review.id.length > 8 ? '${review.id.substring(0, 8)}...' : review.id;
    debugPrint('REVIEW_EDIT: open reviewId=$maskedId');
  }

  // GlobalKey는 반드시 builder 밖에서 생성 (키보드 포커스 유지)
  final sheetKey = GlobalKey<ReviewFormSheetState>();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReviewFormSheet(
      key: sheetKey,
      museumId: review.museumId,
      visitId: review.visitId,
      reviewId: review.id, // 기존 사진 로드 필수
      isEdit: true,
      initialRating: review.rating,
      initialContent: review.content,
      visitedAt: review.visitedOn ?? review.createdAt,
      onSubmit: (rating, content, visitedOn) async {
        try {
          if (kDebugMode) debugPrint('REVIEW_EDIT: text update start');

          // 2. 리뷰 텍스트·별점 UPDATE
          final updated = await ref
              .read(myReviewsProvider.notifier)
              .updateReview(
                reviewId: review.id,
                rating: rating,
                content: content,
                visitedOn: visitedOn,
              );

          if (kDebugMode) debugPrint('REVIEW_EDIT: text update success');

          // 3~6. 삭제 예약 처리 + 신규 사진 업로드
          final deleteResult = await sheetKey.currentState?.applyPendingDeletes();
          final failedCount =
              await sheetKey.currentState?.uploadPendingImages(review.id) ?? 0;

          if (kDebugMode) {
            debugPrint('REVIEW_EDIT: completed failedUploads=$failedCount');
          }

          // 7. provider 재조회 (invalidate + 즉시 refresh)
          // invalidate만으로는 watch 구독자가 rebuild될 때까지 지연될 수 있어
          // ref.refresh로 즉시 재조회 트리거
          Future.microtask(() {
            // ignore: unused_result
            ref.refresh(reviewImagesProvider(review.id));
            ref.invalidate(communityReviewsProvider);
            ref.invalidate(museumReviewsProvider(review.museumId));
            ref.invalidate(myReviewsForMuseumProvider(review.museumId));
            ref.invalidate(myReviewForVisitProvider(updated.visitId));
            ref.invalidate(myReviewsProvider);
          });

          // 8. 화면 닫기 + Snackbar
          if (context.mounted) {
            Navigator.pop(context);
            // Storage 삭제 실패 건수 집계
            final storageFailedCount = deleteResult?.failed ?? 0;
            if (failedCount > 0) {
              // 신규 사진 업로드 실패
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('수정됐지만 $failedCount장의 사진을 올리지 못했습니다.'),
                  duration: const Duration(seconds: 4),
                ),
              );
            } else if (storageFailedCount > 0) {
              // Storage 삭제 실패 (orphan)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('리뷰는 수정됐지만 $storageFailedCount장의 사진 파일 정리에 실패했습니다.'),
                  duration: const Duration(seconds: 4),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    updated.status.toString().contains('pending')
                        ? '수정 완료 — 검토 후 게시됩니다.'
                        : '리뷰가 수정되었습니다.',
                  ),
                ),
              );
            }
          }
        } on PostgrestException catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('서버 오류: ${e.message}'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('수정 중 오류가 발생했습니다: $e'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      },
    ),
  );
}
