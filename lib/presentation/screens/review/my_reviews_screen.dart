import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/review.dart';
import '../../../presentation/providers/review_provider.dart';
import 'review_edit_launcher.dart'; // v0.5.2: 공통 수정 launcher
import '../../../config/router.dart';
import '../../../domain/models/review_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/media/image_url_resolver.dart';

/// 내 리뷰 목록 화면 (마이페이지 → 내 활동 → 리뷰).
/// published + pending_review 상태 리뷰만 표시.
///
/// M7-G-6: '수정 N일 남음' 버튼 탭 → _ReviewFormSheet 즉석 오픈
///   - review_screen.dart의 수정 플로우 그대로 재사용 (새 시트 없음)
///   - 수정 완료 시 myReviewsProvider 로컬 갱신 + 관련 provider invalidate
///   - 삭제: 기존 삭제 버튼 유지 + ⋮ 팝업 메뉴로 수정/삭제 통합
///   - 카드 본문(시설명) 탭 → 박물관 페이지 이동 (동선 분리 유지)
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(myReviewsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: const Text('내 리뷰')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myReviewsProvider.notifier).refresh(),
        child: reviewsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppTheme.errorColor),
                const SizedBox(height: 12),
                const Text('리뷰를 불러오지 못했습니다.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(myReviewsProvider.notifier).refresh(),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rate_review_outlined,
                        size: 64, color: AppTheme.dividerColor),
                    SizedBox(height: 16),
                    Text(
                      '작성한 리뷰가 없습니다.',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondaryColor),
                    ),
                  ],
                ),
              );
            }
            // v0.5.2: 대표사진 일괄 조회
            final reviewIdsKey = reviews.map((r) => r.id).join(',');
            final thumbnailsAsync = ref.watch(reviewThumbnailsProvider(reviewIdsKey));
            final thumbnails = thumbnailsAsync.valueOrNull ?? {};
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final review = reviews[index];
                return _MyReviewCard(
                  review: review,
                  thumbnail: thumbnails[review.id],
                  onTap: () => context.push(
                    AppRoutes.reviewDetail.replaceFirst(':reviewId', review.id),
                  ),
                  onTapMuseum: () =>
                      context.push('/museum/${review.museumId}'),
                  onEdit: review.isEditable
                      ? () => showReviewEditSheet(
                            context: context,
                            ref: ref,
                            review: review,
                          )
                      : null,
                  onDelete: () =>
                      _showDeleteDialog(context, ref, review),
                );
              },
            );
          },
        ),
      ),
    );
  }


  // ── 삭제 확인 다이얼로그 ──────────────────────────────────────────────────
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
                await ref
                    .read(myReviewsProvider.notifier)
                    .deleteReview(review.id);
                // M7-G-6: 삭제 후 관련 provider invalidate
                Future.microtask(() {
                  ref.invalidate(myReviewsForMuseumProvider(review.museumId));
                  ref.invalidate(myReviewForVisitProvider(review.visitId));
                  ref.invalidate(museumReviewsProvider(review.museumId));
                });
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
}

class _MyReviewCard extends StatelessWidget {
  final Review review;
  final ReviewImage? thumbnail; // v0.5.2: 대표사진
  final VoidCallback? onTap; // v0.5.2: 리뷰 상세 이동
  final VoidCallback onTapMuseum;
  final VoidCallback? onEdit; // M7-G-6: nullable (수정 기한 만료 시 null)
  final VoidCallback onDelete;

  const _MyReviewCard({
    required this.review,
    this.thumbnail,
    this.onTap,
    required this.onTapMuseum,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // v0.5.2: 박물관 헤더 탭 → 박물관 상세
          InkWell(
            onTap: onTapMuseum,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 박물관 이름 + 상태 배지
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.museum?.name ?? '박물관',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
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
                    ],
                  ),

                ],
              ),
            ),
          ),
          // v0.5.2: 리뷰 본문 탭 → 리뷰 상세
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 별점
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final filled = i < review.rating.floor();
                        final half = !filled && (i < review.rating);
                        return Icon(
                          half
                              ? Icons.star_half
                              : (filled ? Icons.star : Icons.star_border),
                          size: 14,
                          color: AppTheme.accentColor,
                        );
                      }),
                      const SizedBox(width: 4),
                      Text(
                        review.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 리뷰 내용 (최대 3줄)
                  Text(
                    review.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  // v0.5.2: 대표사진 (16:9)
                  if (thumbnail != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: resolveImageUrl(thumbnail!.storagePath),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: const Color(0xFFEEEEEE)),
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFFEEEEEE),
                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // 날짜 + 방문일
                  Row(
                    children: [
                      Text(
                        _formatDate(review.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      if (review.visitedOn != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '방문일 ${review.visitedOn!.month}월 ${review.visitedOn!.day}일',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.accentColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

              ),
            ),
          ),
          // M7-G-6: 하단 액션 바 (수정 버튼 + ⋮ 메뉴)
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // 수정 버튼: 기한 내 → 탭 시 즉석 수정 시트 오픈
                //           기한 만료 → 비활성 '수정 기간 만료' 라벨
                if (review.isEditable) ...[
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text('수정 ${review.editableDaysLeft}일 남음'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: const Size(0, 28),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '수정 기간 만료',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // ⋮ 팝업 메뉴: 수정 + 삭제 통합
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18,
                      color: AppTheme.textSecondaryColor),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete();
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
                              style:
                                  TextStyle(color: AppTheme.errorColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}
