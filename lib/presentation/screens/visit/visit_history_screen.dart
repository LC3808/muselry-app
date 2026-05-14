import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/models/review.dart';
import '../../../domain/models/visit.dart';
import '../../providers/review_provider.dart';
import '../../providers/visit_provider.dart';

class VisitHistoryScreen extends ConsumerStatefulWidget {
  const VisitHistoryScreen({super.key});
  @override
  ConsumerState<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends ConsumerState<VisitHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 강제 새로고침 (리뷰 상태 최신화)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(myVisitsProvider);
      final visits = ref.read(myVisitsProvider).valueOrNull ?? [];
      for (final visit in visits) {
        ref.invalidate(myReviewForVisitProvider(visit.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(myVisitsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          '방문 기록',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // v1.9 이슈 11: 리프레시 시 방문 기록 + 리뷰 캐시 전체 무효화
          ref.invalidate(myVisitsProvider);
          ref.invalidate(myReviewsProvider);
          await ref.read(myVisitsProvider.future).catchError((_) => <Visit>[]);
        },
        child: visitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              _ErrorView(
                error: e.toString(),
                onRetry: () => ref.invalidate(myVisitsProvider),
              ),
            ],
          ),
          data: (visits) {
            if (visits.isEmpty) {
              return ListView(
                children: const [_EmptyView()],
              );
            }
            return _VisitList(visits: visits);
          },
        ),
      ),
    );
  }
}

// ─── 방문 목록 ─────────────────────────────────────────────────────────────────
class _VisitList extends ConsumerWidget {
  final List<Visit> visits;
  const _VisitList({required this.visits});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 날짜별 그룹핑
    final grouped = <String, List<Visit>>{};
    for (final v in visits) {
      final key =
          '${v.visitedAt.year}년 ${v.visitedAt.month}월';
      grouped.putIfAbsent(key, () => []).add(v);
    }

    final keys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final monthKey = keys[i];
        final monthVisits = grouped[monthKey]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                monthKey,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C3E50),
                    ),
              ),
            ),
            ...monthVisits.map((v) => _VisitCard(visit: v)),
          ],
        );
      },
    );
  }
}

// ─── 방문 카드 (v1.6: 리뷰 상태 표시 추가) ────────────────────────────────────
class _VisitCard extends ConsumerWidget {
  final Visit visit;
  const _VisitCard({required this.visit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final museum = visit.museum;
    final name = museum?.name ?? '(박물관 정보 없음)';
    final type = museum?.type ?? '';
    final region = museum != null ? '${museum.region1} ${museum.region2}' : '';

    // v1.6: 해당 방문에 대한 리뷰 조회 (v1.10: ReviewStatus별 배지 UI)
    final reviewAsync = ref.watch(myReviewForVisitProvider(visit.id));
    final isReviewLoading = reviewAsync.isLoading;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => context.push('/museum/${visit.museumId}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 배지
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8A87C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      visit.visitedAt.day.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE8A87C),
                      ),
                    ),
                    Text(
                      '${visit.visitedAt.month}월',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE8A87C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C3E50),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (type.isNotEmpty) ...[
                          _Badge(label: type, color: const Color(0xFFE8A87C)),
                          const SizedBox(width: 6),
                        ],
                        if (region.trim().isNotEmpty)
                          _Badge(
                              label: region.trim(),
                              color: Colors.blueGrey),
                      ],
                    ),
                    // v1.10: 별점은 review에만 표시 (visit.rating 제거)
                    if (visit.privateNote != null &&
                        visit.privateNote!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        visit.privateNote!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // 삭제 버튼
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.grey),
                onPressed: () => _confirmDelete(context, ref),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
              // v1.6: 리뷰 상태 행
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 8),
              _ReviewStatusRow(
                visitId: visit.id,
                museumId: visit.museumId,
                museumName: name,
                review: reviewAsync.valueOrNull,
                isLoading: isReviewLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    // v1.7: 리뷰 존재 여부 확인 후 경고 문구 분기 (CASCADE DELETE 정책)
    final reviewAsync = ref.read(myReviewForVisitProvider(visit.id));
    final review = reviewAsync.valueOrNull;
    final hasReview = review != null && review.status != ReviewStatus.removed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('방문 기록 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이 방문 기록을 삭제하시겠습니까?'),
            if (hasReview) ...
              [
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '이 방문에 작성된 리뷰도 함께 삭제됩니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(myVisitsProvider.notifier).deleteVisit(visit.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('방문 기록이 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }
}

// ─── v1.6: 리뷰 상태 행 ────────────────────────────────────────────────────────

/// 방문 카드 하단에 표시되는 리뷰 상태 행.
/// - 리뷰 있음: 초록색 "리뷰 작성 완료" 배지 + "수정하기" 텍스트 버튼
/// - 리뷰 없음: 회색 "리뷰 미작성" 배지 + "리뷰 쓰기" 버튼
class _ReviewStatusRow extends StatelessWidget {
  final String visitId;
  final String museumId;
  final String museumName;
  final Review? review;
  final bool isLoading;

  const _ReviewStatusRow({
    required this.visitId,
    required this.museumId,
    required this.museumName,
    required this.review,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 24,
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              '리뷰 확인 중...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // v1.10 보완: ReviewStatus별 뱃지 UI 분기
    final status = review?.status;
    final hasActiveReview = review != null &&
        status != ReviewStatus.removed &&
        status != ReviewStatus.unknown;

    Widget badge;
    if (status == null ||
        status == ReviewStatus.removed ||
        status == ReviewStatus.unknown) {
      badge = _ReviewBadge(
        label: '리뷰 미작성',
        icon: Icons.rate_review_outlined,
        color: Colors.grey.shade500,
        backgroundColor: Colors.grey.shade100,
      );
    } else if (status == ReviewStatus.published) {
      badge = _ReviewBadge(
        label: '리뷰 작성 완료',
        icon: Icons.check_circle_outline,
        color: Colors.green.shade600,
        backgroundColor: Colors.green.shade50,
      );
    } else if (status == ReviewStatus.pendingReview) {
      badge = _ReviewBadge(
        label: '검토 중',
        icon: Icons.hourglass_top_outlined,
        color: Colors.orange.shade600,
        backgroundColor: Colors.orange.shade50,
      );
    } else if (status == ReviewStatus.hidden) {
      badge = _ReviewBadge(
        label: '비공개 처리됨',
        icon: Icons.visibility_off_outlined,
        color: Colors.grey.shade600,
        backgroundColor: Colors.grey.shade100,
      );
    } else {
      badge = _ReviewBadge(
        label: '리뷰 미작성',
        icon: Icons.rate_review_outlined,
        color: Colors.grey.shade500,
        backgroundColor: Colors.grey.shade100,
      );
    }

    return Row(
      children: [
        badge,
        const Spacer(),
        if (hasActiveReview)
          TextButton.icon(
            onPressed: () => context.push(
              '/museum/$museumId/reviews',
              extra: {'museumName': museumName},
            ),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('수정하기'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: () => context.push(
              '/museum/$museumId/reviews',
              extra: {'museumName': museumName},
            ),
            icon: const Icon(Icons.rate_review_outlined, size: 14),
            label: const Text('리뷰 쓰기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8A87C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              elevation: 0,
            ),
          ),
      ],
    );
  }
}

/// 리뷰 상태 배지
class _ReviewBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _ReviewBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 배지 ──────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── 빈 상태 ───────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '아직 방문 기록이 없어요',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '박물관 상세 화면에서\n다녀왔어요 버튼을 눌러 기록해보세요',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[400],
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── 에러 상태 ─────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              '방문 기록을 불러올 수 없습니다.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
