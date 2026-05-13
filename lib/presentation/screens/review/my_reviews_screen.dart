import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/review.dart';
import '../../../presentation/providers/review_provider.dart';

/// 내 리뷰 목록 화면 (마이페이지 → 내 활동 → 리뷰).
/// published + pending_review 상태 리뷰만 표시.
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
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final review = reviews[index];
                return _MyReviewCard(
                  review: review,
                  onTapMuseum: () =>
                      context.push('/museum/${review.museumId}'),
                  onDelete: () =>
                      _showDeleteDialog(context, ref, review.id),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, String reviewId) {
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
                    .deleteReview(reviewId);
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
  final VoidCallback onTapMuseum;
  final VoidCallback onDelete;

  const _MyReviewCard({
    required this.review,
    required this.onTapMuseum,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTapMuseum,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 6),
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
              const SizedBox(height: 8),
              // 날짜 + 수정 가능 여부 + 삭제 버튼
              Row(
                children: [
                  Text(
                    _formatDate(review.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  if (review.isEditable) ...[
                    const SizedBox(width: 8),
                    Text(
                      '수정 ${review.editableDaysLeft}일 남음',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                  const Spacer(),
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 28),
                    ),
                    child: const Text('삭제', style: TextStyle(fontSize: 13)),
                  ),
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
