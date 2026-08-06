import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/router.dart';
import '../../../core/utils/nickname_utils.dart'; // §8-1
import '../../../core/errors/auth_required_exception.dart';
import '../../../core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../domain/models/review.dart';
import '../../../domain/models/visit.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/comment_provider.dart';
import '../../../presentation/providers/review_provider.dart';
import '../../../presentation/providers/visit_provider.dart';
import '../../widgets/common/user_avatar.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../data/repositories/review_image_repository.dart';
import '../../../features/review/services/review_image_upload_service.dart';

/// 박물관 리뷰 화면.
/// museum_detail_screen.dart에서 Navigator.push로 열리거나
/// GoRouter '/museum/:id/reviews' 경로로 직접 접근 가능.
///
/// v1.6 변경: 리뷰 작성 시 방문 기록 선택 단계 추가 (1방문 1리뷰 정책)
class ReviewScreen extends ConsumerWidget {
  final String museumId;
  final String museumName;

  const ReviewScreen({
    super.key,
    required this.museumId,
    required this.museumName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(museumReviewsProvider(museumId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('$museumName 리뷰'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '리뷰 작성',
            onPressed: currentUser != null
                ? () => _showVisitSelectSheet(context, ref)
                : () => _showLoginRequired(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(museumReviewsProvider(museumId));
          ref.invalidate(myReviewsForMuseumProvider(museumId));
        },
        child: reviewsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(onRetry: () {
            ref.invalidate(museumReviewsProvider(museumId));
          }),
          data: (reviews) {
            if (reviews.isEmpty) {
              return _EmptyState(
                onWrite: currentUser != null
                    ? () => _showVisitSelectSheet(context, ref)
                    : () => _showLoginRequired(context),
              );
            }
            // R22: 댓글 수 일괄 조회 (R18과 동일한 join key 방식)
            final reviewIdsKey = reviews.map((r) => r.id).join(',');
            final countsAsync = ref.watch(commentCountsProvider(reviewIdsKey));
            final counts = countsAsync.valueOrNull ?? {};

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final review = reviews[index];
                final isMyReview = review.userId == currentUser?.id;
                return _ReviewCard(
                  review: review,
                  isMyReview: isMyReview,
                  commentCount: counts[review.id],
                  onTap: () => context.push(
                    AppRoutes.reviewDetail.replaceFirst(':reviewId', review.id),
                  ),
                  onEdit: isMyReview
                      ? () => _showEditBottomSheet(context, ref, review)
                      : null,
                  onDelete: isMyReview
                      ? () => _showDeleteDialog(context, ref, review)
                      : null,
                  onReport: !isMyReview && currentUser != null
                      ? () => _showReportDialog(context, ref, review.id)
                      : null,
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ── v1.6: 방문 기록 선택 BottomSheet ────────────────────────────────────

  /// 방문 기록 선택 단계 (1방문 1리뷰 정책 진입점)
  void _showVisitSelectSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _VisitSelectSheet(
          museumId: museumId,
          museumName: museumName,
          onVisitSelected: (visit) {
            Navigator.pop(sheetContext);
            _showWriteBottomSheet(context, ref, visit: visit);
          },
        ),
      ),
    );
  }

  // ── 리뷰 작성 BottomSheet ────────────────────────────────────────────────

  /// 방문 기록 선택 후 리뷰 작성 폼 표시 (v1.6: visit 필수)
  void _showWriteBottomSheet(BuildContext context, WidgetRef ref,
      {required Visit visit}) {
    // A: GlobalKey를 builder 밖에서 한 번만 생성 — builder 재실행 시 State 교체 방지
    final sheetKey = GlobalKey<_ReviewFormSheetState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return ReviewFormSheet(
          key: sheetKey,
          museumId: museumId,
          visitId: visit.id,
          visitedAt: visit.visitedAt,
          onSubmit: (rating, content, visitedOn) async { // R27
            try {
              final newReview = await ref
                  .read(myReviewsProvider.notifier)
                  .createReview(
                    museumId: museumId,
                    visitId: visit.id,
                    rating: rating,
                    content: content,
                    visitedOn: visitedOn,
                  );
              // v0.5.1: 리뷰 저장 후 사진 업로드
              final failedCount = await sheetKey.currentState
                  ?.uploadPendingImages(newReview.id) ?? 0;
              if (context.mounted) {
                Navigator.pop(context);
                if (failedCount > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '리뷰는 등록됐지만 $failedCount장의 사진을 올리지 못했습니다.',
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else {
                  _showStatusSnackBar(context, newReview.status);
                }
              }
              // v1.10: microtask로 invalidate (build 중 setState 방지)
              Future.microtask(() {
                ref
                    .read(museumReviewsProvider(museumId).notifier)
                    .addReview(newReview);
                ref.invalidate(myReviewsForMuseumProvider(museumId));
                ref.invalidate(myReviewForVisitProvider(visit.id));
                // v0.5.1: 사진 provider 무효화
                ref.invalidate(reviewImagesProvider(newReview.id));
                ref.invalidate(communityReviewsProvider);
              });
            } on AuthRequiredException {
              if (context.mounted) _showLoginRequired(context);
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
                    content: Text('오류가 발생했습니다: $e'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
            }
          }
        },
        );
      },
    );
  }

  // ── 리뷰 수정 BottomSheet ────────────────────────────────────────────────

  void _showEditBottomSheet(
      BuildContext context, WidgetRef ref, Review review) {
    if (!review.isEditable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작성 후 7일이 지나 수정할 수 없습니다.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewFormSheet(
        museumId: museumId,
        visitId: review.visitId,
        isEdit: true,
        initialRating: review.rating,
        initialContent: review.content,
        onSubmit: (rating, content, visitedOn) async { // R27
          try {
            final updated = await ref
                .read(myReviewsProvider.notifier)
                .updateReview(
                  reviewId: review.id,
                  rating: rating,
                  content: content,
                  visitedOn: visitedOn,
                );
            if (context.mounted) {
              Navigator.pop(context);
              _showStatusSnackBar(context, updated.status);
            }
            // v1.10: microtask로 invalidate (build 중 setState 방지)
            Future.microtask(() {
              ref
                  .read(museumReviewsProvider(museumId).notifier)
                  .updateReview(updated);
              ref.invalidate(myReviewsForMuseumProvider(museumId));
              ref.invalidate(myReviewForVisitProvider(updated.visitId));
            });
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

  // ── 삭제 확인 다이얼로그 ─────────────────────────────────────────────────

  // v1.9 이슈 5: Review 객체를 받아 visitId로 myReviewForVisitProvider도 invalidate
  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, Review review) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('리뷰 삭제'),
        content: const Text('이 리뷰를 삭제하시겠습니까?\n삭제된 리뷰는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                // v0.5.1: 원자성 보완 — Storage path 먼저 확보 후 리뷰 삭제
                final imgRepo = ref.read(reviewImageRepositoryProvider);
                final storagePaths = await imgRepo.loadStoragePaths(review.id);
                // 리뷰 DB 삭제 (CASCADE로 review_images 행도 삭제됨)
                await ref
                    .read(myReviewsProvider.notifier)
                    .deleteReview(review.id);
                // 리뷰 삭제 성공 후 Storage 후처리 (실패 허용 — orphan)
                await imgRepo.deleteStorageFilesByPaths(storagePaths);
                ref
                    .read(museumReviewsProvider(museumId).notifier)
                    .removeReview(review.id);
                ref.invalidate(myReviewsForMuseumProvider(museumId));
                // v1.9 이슈 5: 삭제 후 해당 방문 리뷰 캐시도 무효화
                ref.invalidate(myReviewForVisitProvider(review.visitId));
                // v0.5.1: 사진 provider 무효화
                ref.invalidate(communityReviewsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('리뷰가 삭제되었습니다.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('삭제 중 오류가 발생했습니다: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.errorColor),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // ── 신고 다이얼로그 ──────────────────────────────────────────────────────

  void _showReportDialog(
      BuildContext context, WidgetRef ref, String reviewId) {
    String selectedReason = 'spam';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('리뷰 신고'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('신고 사유를 선택해 주세요.'),
              const SizedBox(height: 12),
              ...[
                ('spam', '스팸 / 광고'),
                ('inappropriate', '부적절한 내용'),
                ('fake', '허위 정보'),
                ('other', '기타'),
              ].map(
                (e) => RadioListTile<String>(
                  title: Text(e.$2),
                  value: e.$1,
                  groupValue: selectedReason,
                  onChanged: (v) =>
                      setDialogState(() => selectedReason = v!),
                  dense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref
                      .read(reviewRepositoryProvider)
                      .reportReview(
                        reviewId: reviewId,
                        reason: selectedReason,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('신고가 접수되었습니다. 검토 후 조치하겠습니다.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('신고 중 오류가 발생했습니다: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
              child: const Text('신고'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 헬퍼 ────────────────────────────────────────────────────────────────

  void _showLoginRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인 후 이용할 수 있습니다.')),
    );
  }

  void _showStatusSnackBar(BuildContext context, ReviewStatus status) {
    final message = status == ReviewStatus.pendingReview
        ? '리뷰가 등록되었습니다. 운영자 확인 후 공개됩니다.'
        : '리뷰가 등록되었습니다.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ─── v1.6: 방문 기록 선택 BottomSheet ──────────────────────────────────────

/// 리뷰 작성 전 방문 기록 선택 단계.
/// - 방문 기록 없음: "방문 기록을 먼저 남겨주세요" 안내 + "다녀왔어요" 버튼
/// - 방문 기록 있음: 방문별 리뷰 작성 가능 여부 표시
///   - 이미 리뷰 있는 방문: "리뷰 완료" 표시 (탭 비활성)
///   - 리뷰 없는 방문: "리뷰 쓰기" 버튼 (탭 활성)
class _VisitSelectSheet extends ConsumerWidget {
  final String museumId;
  final String museumName;
  final void Function(Visit visit) onVisitSelected;

  const _VisitSelectSheet({
    required this.museumId,
    required this.museumName,
    required this.onVisitSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitsForMuseumProvider(museumId));
    final myReviewsAsync = ref.watch(myReviewsForMuseumProvider(museumId));

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '어느 방문에 대한 리뷰인가요?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '방문 기록을 선택하면 해당 방문에 대한 리뷰를 작성할 수 있어요.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 16),
          visitsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '방문 기록을 불러오지 못했어요.',
                  style: TextStyle(color: AppTheme.textSecondaryColor),
                ),
              ),
            ),
            data: (visits) {
              if (visits.isEmpty) {
                return _NoVisitState(museumName: museumName);
              }
              final myReviews = myReviewsAsync.valueOrNull ?? [];
              final reviewedVisitIds =
                  myReviews.map((r) => r.visitId).toSet();

              return Column(
                children: visits.map((visit) {
                  final hasReview = reviewedVisitIds.contains(visit.id);
                  return _VisitSelectTile(
                    visit: visit,
                    hasReview: hasReview,
                    onTap: hasReview ? null : () => onVisitSelected(visit),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 방문 기록 없는 경우 안내 위젯
class _NoVisitState extends StatelessWidget {
  final String museumName;

  const _NoVisitState({required this.museumName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const Icon(
            Icons.place_outlined,
            size: 48,
            color: AppTheme.dividerColor,
          ),
          const SizedBox(height: 12),
          const Text(
            '리뷰를 쓰려면 먼저 방문 기록을 남겨주세요.',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '$museumName을(를) 다녀오셨나요?',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '박물관 상세 화면에서 "다녀왔어요"를 눌러 방문 기록을 추가해 주세요.'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('다녀왔어요'),
          ),
        ],
      ),
    );
  }
}

/// 방문 기록 선택 타일
class _VisitSelectTile extends StatelessWidget {
  final Visit visit;
  final bool hasReview;
  final VoidCallback? onTap;

  const _VisitSelectTile({
    required this.visit,
    required this.hasReview,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${visit.visitedAt.year}.${visit.visitedAt.month.toString().padLeft(2, '0')}.${visit.visitedAt.day.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: hasReview ? AppTheme.backgroundColor : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasReview
              ? AppTheme.dividerColor
              : AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // 날짜 배지
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: hasReview
                      ? AppTheme.dividerColor
                      : AppTheme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      visit.visitedAt.day.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: hasReview
                            ? AppTheme.textSecondaryColor
                            : AppTheme.accentColor,
                      ),
                    ),
                    Text(
                      '${visit.visitedAt.month}월',
                      style: TextStyle(
                        fontSize: 10,
                        color: hasReview
                            ? AppTheme.textSecondaryColor
                            : AppTheme.accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 날짜 + 메모
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasReview
                            ? AppTheme.textSecondaryColor
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    if (visit.privateNote != null &&
                        visit.privateNote!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        visit.privateNote!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // 리뷰 상태 표시
              if (hasReview)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    '리뷰 완료',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '리뷰 쓰기',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 리뷰 카드 ─────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Review review;
  final bool isMyReview;
  final int? commentCount; // R22: 댓글 수 맱지
  final VoidCallback? onTap; // R22: 단일 리뷰 화면으로 이동
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  const _ReviewCard({
    required this.review,
    required this.isMyReview,
    this.commentCount,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias, // R22: InkWell 리플 클립
      child: InkWell(
        onTap: onTap, // R22: 리뷰 상세 화면으로 이동
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    avatarStoragePath: review.authorAvatarStoragePath,
                    avatarUrl: review.authorAvatarUrl,
                    displayName: review.authorNickname ?? '익명',
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          maskNickname(review.authorNickname), // §8-1
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _StarRow(rating: review.rating),
                      ],
                    ),
                  ),
                  if (review.status == ReviewStatus.pendingReview)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '검토 중',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isMyReview)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          enabled: review.isEditable,
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: review.isEditable
                                    ? null
                                    : AppTheme.textSecondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                review.isEditable
                                    ? '수정 (${review.editableDaysLeft}일 남음)'
                                    : '수정 불가 (7일 경과)',
                                style: TextStyle(
                                  color: review.isEditable
                                      ? null
                                      : AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 16, color: AppTheme.errorColor),
                              SizedBox(width: 8),
                              Text('삭제',
                                  style: TextStyle(
                                      color: AppTheme.errorColor)),
                            ],
                          ),
                        ),
                      ],
                    )
                  else if (onReport != null)
                    IconButton(
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      tooltip: '신고',
                      color: AppTheme.textSecondaryColor,
                      onPressed: onReport,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                review.content,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              // R22: 날짜 + 댓글 수 뱃지 Row / R27: 방문일 추가
              Row(
                children: [
                  Text(
                    _formatDate(review.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  if (review.visitedOn != null) ...[  // R27
                    const SizedBox(width: 8),
                    Text(
                      '방문일 ${review.visitedOn!.month}월 ${review.visitedOn!.day}일',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if ((commentCount ?? 0) > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '💬$commentCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

// _Avatar 제거됨 — UserAvatar 공통 위젯으로 교체 (v0.5.0)
// ─── 별점 표시 ──────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  final double rating;

  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ...List.generate(5, (i) {
          final filled = i < rating.floor();
          final half = !filled && (i < rating);
          return Icon(
            half ? Icons.star_half : (filled ? Icons.star : Icons.star_border),
            size: 14,
            color: AppTheme.accentColor,
          );
        }),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}

// ─── 리뷰 작성/수정 폼 BottomSheet ─────────────────────────────────────────

class ReviewFormSheet extends StatefulWidget {
  final String museumId;
  final String visitId;
  final DateTime? visitedAt;
  final double? initialRating;
  final String? initialContent;
  final bool isEdit;
  final Future<void> Function(double rating, String content, DateTime? visitedOn) onSubmit; // R27

  const ReviewFormSheet({
    super.key,
    required this.museumId,
    required this.visitId,
    this.visitedAt,
    this.initialRating,
    this.initialContent,
    this.isEdit = false,
    required this.onSubmit,
  });

  @override
  State<ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<ReviewFormSheet> {
  late double _rating;
  late TextEditingController _contentController;
  bool _isSubmitting = false;
  String? _filterError;
  DateTime? _visitedOn; // R27: 방문일 (기본값 = visitedAt 또는 오늘)
  static const int _minLength = 10;  // DB reviews_content_check 제약과 일치
  static const int _maxLength = 500; // DB reviews_content_check 제약과 일치

  // v0.5.1: 사진 첨부
  final List<File> _pendingImages = []; // 선택된 임시 파일 목록
  bool _imageUploading = false;
  late ReviewImageUploadService _imageService;
  // A: 명시적 FocusNode — builder 재실행 시 포커스 유지
  late final FocusNode _contentFocusNode;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating ?? 3.0;
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
    // R27: 방문일 기본값 = 방문 기록의 visitedAt, 없으면 오늘
    _visitedOn = widget.visitedAt ?? DateTime.now();
    // v0.5.1: 사진 서비스 초기화
    final client = Supabase.instance.client;
    final repo = ReviewImageRepository(client);
    _imageService = ReviewImageUploadService(client, repo);
    // A: FocusNode 초기화
    _contentFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _contentFocusNode.dispose();
    _contentController.dispose();
    // 임시 파일 정리
    for (final f in _pendingImages) {
      try { f.deleteSync(); } catch (_) {}
    }
    super.dispose();
  }

  void _onContentChanged(String text) {
    final error = KoreanContentFilter.check(text);
    setState(() => _filterError = error);
  }

  Future<void> _submit() async {
  final content = _contentController.text.trim();
  if (content.isEmpty) {
    setState(() => _filterError = '리뷰 내용을 입력해 주세요.');
    return;
  }
  if (content.length < _minLength) {
    setState(() => _filterError = '리뷰는 $_minLength자 이상 작성해 주세요. (현재 ${content.length}자)');
    return;
  }
  if (content.length > _maxLength) {
    setState(() => _filterError = '리뷰는 $_maxLength자 이내로 작성해 주세요.');
    return;
  }
  setState(() {
    _isSubmitting = true;
    _filterError = null;
  });
  try {
    await widget.onSubmit(_rating, content, _visitedOn); // R27
    // v0.5.1: 사진 업로드는 onSubmit에서 reviewId를 받아야 하므로
    // onSubmit이 완료된 후 별도로 처리됨 (ReviewFormSheet는 reviewId를 모름)
    // → onSubmitWithImages 콜백으로 처리 (아래 참조)
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}

  /// v0.5.1: 사진 선택 (갤러리)
  Future<void> _pickImage() async {
    if (_imageService.isMaxReached(_pendingImages.length)) return;
    setState(() => _imageUploading = true);
    try {
      final file = await _imageService.pickAndCompress();
      if (file != null && mounted) {
        setState(() => _pendingImages.add(file));
      }
    } on ReviewImageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 선택 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _imageUploading = false);
    }
  }

  /// v0.5.1: 선택된 사진 제거
  void _removeImage(int index) {
    setState(() {
      try { _pendingImages[index].deleteSync(); } catch (_) {}
      _pendingImages.removeAt(index);
    });
  }

  /// v0.5.1: 리뷰 저장 후 사진 업로드 (review_id 획득 후 호출)
  /// v0.5.1: 사진 업로드 — 실패 건수 반환 (0 = 전체 성공)
  Future<int> uploadPendingImages(String reviewId) async {
    if (_pendingImages.isEmpty) return 0;
    int failedCount = 0;
    for (int i = 0; i < _pendingImages.length; i++) {
      try {
        await _imageService.uploadAndInsert(
          reviewId: reviewId,
          file: _pendingImages[i],
          displayOrder: i,
          isJpeg: _pendingImages[i].path.endsWith('.jpg'),
        );
      } catch (e) {
        if (kDebugMode) print('REVIEW: image upload failed index=$i: $e');
        failedCount++;
      }
    }
    return failedCount;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _maxLength - _contentController.text.length;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          // 키보드가 올라와도 스크롤 가능하도록 감쌈
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 제목 + 방문 날짜 배지
              Row(
                children: [
                  Text(
                    widget.isEdit ? '리뷰 수정' : '리뷰 작성',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // R27: 방문일 선택 (date picker)
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _visitedOn ?? now,
                    firstDate: DateTime(2000),
                    lastDate: now, // 미래 날짜 금지
                    helpText: '방문일 선택',
                    cancelText: '취소',
                    confirmText: '확인',
                  );
                  if (picked != null) setState(() => _visitedOn = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16,
                          color: AppTheme.textSecondaryColor),
                      const SizedBox(width: 8),
                      Text(
                        _visitedOn != null
                            ? '방문일: ${_visitedOn!.month}월 ${_visitedOn!.day}일'
                            : '방문일 선택 (선택사항)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, size: 16,
                          color: AppTheme.textSecondaryColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 별점 선택
              const Text(
                '별점',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              _RatingSelector(
                rating: _rating,
                onChanged: (r) => setState(() => _rating = r),
              ),
              const SizedBox(height: 16),
              // 내용 입력
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '리뷰 내용',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor),
                  ),
                  Text(
                    '$remaining자 남음',
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining < 50
                          ? AppTheme.errorColor
                          : AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                focusNode: _contentFocusNode,
                controller: _contentController,
                maxLines: 5,
                maxLength: _maxLength,
                onChanged: _onContentChanged,
                decoration: InputDecoration(
                  hintText: '방문 경험을 솔직하게 작성해 주세요. ($_minLength~$_maxLength자)',
                  counterText: '',
                  errorText: _filterError,
                ),
              ),
              const SizedBox(height: 16),
              // v0.5.1: 사진 첨부 섹션
              if (!widget.isEdit) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '사진 첨부',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      '${_pendingImages.length}/${_imageService.maxImages}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_pendingImages.isNotEmpty)
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingImages.length +
                          (_imageService.isMaxReached(_pendingImages.length) ? 0 : 1),
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == _pendingImages.length) {
                          return _AddPhotoButton(
                            onTap: _imageUploading ? null : _pickImage,
                            isLoading: _imageUploading,
                          );
                        }
                        return _PendingImageTile(
                          file: _pendingImages[index],
                          onRemove: () => _removeImage(index),
                        );
                      },
                    ),
                  )
                else
                  _AddPhotoButton(
                    onTap: _imageUploading ? null : _pickImage,
                    isLoading: _imageUploading,
                  ),
                const SizedBox(height: 16),
              ],
              // 제출 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || _filterError != null)
                      ? null
                      : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(widget.isEdit ? '수정 완료' : '등록'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 별점 선택 위젯 ─────────────────────────────────────────────────────────

class _RatingSelector extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onChanged;

  const _RatingSelector({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 별 5개를 하나의 GestureDetector로 감싸기
        Builder(
          builder: (ctx) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final box = ctx.findRenderObject() as RenderBox?;
              if (box == null) return;
              final totalWidth = box.size.width;
              final starWidth = totalWidth / 5;
              final tapX = details.localPosition.dx.clamp(0.0, totalWidth);
              final starIndex = (tapX / starWidth).floor().clamp(0, 4);
              final withinStar = tapX - (starIndex * starWidth);
              final isLeftHalf = withinStar < starWidth * 0.5;
              final newRating = isLeftHalf
                  ? (starIndex + 0.5)
                  : (starIndex + 1.0);
              onChanged(newRating.clamp(0.5, 5.0));
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Icon(
                    i < rating.floor()
                        ? Icons.star
                        : (i < rating ? Icons.star_half : Icons.star_border),
                    size: 36,
                    color: AppTheme.accentColor,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${rating.toStringAsFixed(1)}점',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }
}
// ─── 빈 상태 ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onWrite;

  const _EmptyState({required this.onWrite});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.rate_review_outlined,
              size: 64, color: AppTheme.dividerColor),
          const SizedBox(height: 16),
          const Text(
            '아직 리뷰가 없습니다.',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 8),
          const Text(
            '첫 번째 리뷰를 작성해 보세요!',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onWrite,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('리뷰 작성'),
          ),
        ],
      ),
    );
  }
}

// ─── 오류 상태 ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          const Text('리뷰를 불러오지 못했습니다.'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

// ─── v0.5.1: 사진 첨부 위젯 ─────────────────────────────────────────────────

/// 사진 추가 버튼
class _AddPhotoButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  const _AddPhotoButton({this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.dividerColor),
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.backgroundColor,
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppTheme.textSecondaryColor,
                size: 28,
              ),
      ),
    );
  }
}

/// 선택된 임시 사진 썸네일 (삭제 버튼 포함)
class _PendingImageTile extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _PendingImageTile({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
