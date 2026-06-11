import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/review.dart';
import '../../providers/review_provider.dart';

/// 단일 리뷰 상세 화면 (R5: 알림 딥링크 /reviews/:reviewId)
///
/// 알림 탭에서 "새 댓글이 달렸어요" 탭 시 해당 리뷰로 바로 이동.
class ReviewDetailScreen extends ConsumerWidget {
  final String reviewId;

  const ReviewDetailScreen({super.key, required this.reviewId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(_reviewByIdProvider(reviewId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('리뷰'),
      ),
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                '리뷰를 불러오지 못했어요.',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(_reviewByIdProvider(reviewId)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (review) {
          if (review == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    '리뷰를 찾을 수 없어요.',
                    style: TextStyle(color: AppTheme.textSecondaryColor),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('돌아가기'),
                  ),
                ],
              ),
            );
          }
          return _ReviewDetailBody(review: review);
        },
      ),
    );
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final _reviewByIdProvider =
    FutureProvider.autoDispose.family<Review?, String>((ref, reviewId) async {
  final repo = ref.read(reviewRepositoryProvider);
  return repo.fetchReviewById(reviewId);
});

// ── Body ──────────────────────────────────────────────────────────────────────

class _ReviewDetailBody extends StatelessWidget {
  final Review review;
  const _ReviewDetailBody({required this.review});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 + 별점
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.dividerColor,
                backgroundImage: review.authorAvatarUrl != null
                    ? NetworkImage(review.authorAvatarUrl!)
                    : null,
                child: review.authorAvatarUrl == null
                    ? Icon(Icons.person, size: 20, color: Colors.grey[400])
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorNickname ?? '익명',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              _StarRow(rating: review.rating),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppTheme.dividerColor),
          const SizedBox(height: 16),
          // 리뷰 내용
          Text(
            review.content,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 24),
          // 박물관 이동 버튼 (museum 조인 없으면 museumId로 이동)
          OutlinedButton.icon(
            onPressed: () =>
                context.push('/museum/${review.museumId}'),
            icon: const Icon(Icons.museum_outlined, size: 18),
            label: Text(
              review.museum?.name ?? '박물관 보기',
              style: const TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.dividerColor),
              foregroundColor: AppTheme.textPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

class _StarRow extends StatelessWidget {
  final double rating;
  const _StarRow({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && (i < rating);
        return Icon(
          half ? Icons.star_half : (filled ? Icons.star : Icons.star_border),
          size: 16,
          color: const Color(0xFFF5A623),
        );
      }),
    );
  }
}
