import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/models/museum.dart';
import '../../providers/museum_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/visit_provider.dart';
import '../../providers/review_provider.dart';
import '../../../core/errors/auth_required_exception.dart';
import '../../../core/errors/duplicate_visit_exception.dart';
import '../museum/visit_add_dialog.dart';
import '../../widgets/museum/museum_image.dart';

class MuseumDetailScreen extends ConsumerWidget {
  final String museumId;

  const MuseumDetailScreen({super.key, required this.museumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final museumAsync = ref.watch(museumDetailProvider(museumId));

    return Scaffold(
      body: museumAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(error: e.toString()),
        data: (museum) {
          if (museum == null) return const _NotFoundView();
          return _DetailBody(museum: museum);
        },
      ),
    );
  }
}

// ─── 본문 ─────────────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final Museum museum;
  const _DetailBody({required this.museum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBookmarked = ref.watch(isBookmarkedProvider(museum.id));

    return CustomScrollView(
      slivers: [
        // ── SliverAppBar (이미지 헤더) ──────────────────────────────────────
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          backgroundColor: const Color(0xFF2C3E50),
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: FlexibleSpaceBar(
            // M2: MuseumImage 공용 위젯 사용 (dedicated 우선 fallback)
            background: MuseumImage(
              imageUrl: museum.imageUrl,
              type: museum.type,
              kidsCategory: museum.kidsCategory,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 240,
            ),
          ),
          actions: [
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  key: ValueKey(isBookmarked),
                  color: Colors.white,
                  size: 26,
                ),
              ),
              onPressed: () async {
                try {
                  await ref
                      .read(bookmarksProvider.notifier)
                      .toggleBookmark(museum.id);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('북마크 오류: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),

        // ── 본문 콘텐츠 ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BadgeRow(museum: museum),
                const SizedBox(height: 10),
                Text(
                  museum.name,
                  style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2C3E50),
                            height: 1.3,
                          ),
                ),
                const SizedBox(height: 20),

                // 기본 정보 카드
                _SectionCard(
                  children: [
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: '주소',
                      value: (museum.roadAddress != null &&
                              museum.roadAddress!.trim().isNotEmpty)
                          ? museum.roadAddress!
                          : Museum.orEmpty(museum.address),
                    ),
                    if (museum.phone != null &&
                        museum.phone!.trim().isNotEmpty) ...[
                      const _RowDivider(),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: '전화',
                        value: museum.phone!,
                      ),
                    ],
                    if (museum.openingHours != null &&
                        museum.openingHours!.trim().isNotEmpty) ...[
                      const _RowDivider(),
                      _InfoRow(
                        icon: Icons.access_time_outlined,
                        label: '운영시간',
                        value: museum.openingHours!,
                      ),
                    ],
                    if (museum.closedDays != null &&
                        museum.closedDays!.trim().isNotEmpty) ...[
                      const _RowDivider(),
                      _InfoRow(
                        icon: Icons.event_busy_outlined,
                        label: '휴관일',
                        value: museum.closedDays!,
                      ),
                    ],
                    const _RowDivider(),
                    _InfoRow(
                      icon: museum.isFree
                          ? Icons.money_off_outlined
                          : Icons.attach_money_outlined,
                      label: '관람료',
                      value: museum.admissionFeeDisplay,
                      valueColor: museum.isFree ? Colors.green[700] : null,
                      valueBold: museum.isFree,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 설명 섹션 (null이면 숨김)
                if (museum.description != null &&
                    museum.description!.trim().isNotEmpty) ...[
                  const _SectionTitle(title: '소개'),
                  const SizedBox(height: 8),
                  _SectionCard(
                    children: [
                      Text(
                        museum.description!,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[700],
                                  height: 1.6,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // T4 사이클 1.5: kidsCategory 기준으로 어린이 정보 섹션 표시
                if (museum.isKidsDedicated) ...[  
                  const _SectionTitle(title: '🏛️ 어린이 전용 정보'),
                  const SizedBox(height: 8),
                  _SectionCard(
                    borderColor: const Color(0xFFD4622A),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🏛️', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              museum.kidsNote?.isNotEmpty == true
                                  ? museum.kidsNote!
                                  : '어린이를 위해 설계된 전용 시설입니다.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6D4C41),
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else if (museum.isKidsFriendlyTagged &&
                    museum.kidsNote?.isNotEmpty == true) ...[  
                  const _SectionTitle(title: '👶 어린이 친화 정보'),
                  const SizedBox(height: 8),
                  _SectionCard(
                    borderColor: const Color(0xFFF5E6D3),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('👶', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              museum.kidsNote!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 액션 버튼
                _ActionButtons(museum: museum),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 배지 행 ──────────────────────────────────────────────────────────────────

class _BadgeRow extends StatelessWidget {
  final Museum museum;
  const _BadgeRow({required this.museum});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        _Badge(label: museum.typeLabel, color: const Color(0xFFE8A87C)),
        if (museum.ownershipLabel.isNotEmpty)
          _Badge(
            label: museum.ownershipLabel,
            color: _ownershipColor(museum.ownershipLabel),
          ),
        if (museum.region1.isNotEmpty)
          _Badge(label: museum.region1, color: Colors.blueGrey),
        // kidsCategory 기반 어린이 태그 (T4 사이클1)
        if (museum.isKidsDedicated)
          _Badge(
            label: '어린이 전용',
            color: const Color(0xFFD4622A),
            textColor: Colors.white,
            fontSize: 13,
          )
        else if (museum.isKidsFriendlyTagged)
          _Badge(
            label: '어린이 친화',
            color: const Color(0xFFF5E6D3),
            textColor: const Color(0xFF6D4C41),
            fontSize: 13,
          ),
      ],
    );
  }

  Color _ownershipColor(String o) {
    switch (o) {
      case '국립':
        return const Color(0xFF1565C0);
      case '공립':
        return const Color(0xFF2E7D32);
      case '사립':
        return const Color(0xFF6A1B9A);
      default:
        return Colors.grey;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final double? fontSize;
  const _Badge({
    required this.label,
    required this.color,
    this.textColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? color;
    final effectiveBgColor = textColor != null
        ? color  // 직접 배경색 지정 시 그대로 사용
        : color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor != null
              ? color.withValues(alpha: 0.0)
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: effectiveTextColor,
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── 섹션 카드 / 타이틀 ────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2C3E50),
          ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  final Color? borderColor;
  const _SectionCard({required this.children, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
    );
  }
}

// ─── 정보 행 ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF2C3E50).withValues(alpha: 0.6),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? const Color(0xFF2C3E50),
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w400,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 액션 버튼 ─────────────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  final Museum museum;
  const _ActionButtons({required this.museum});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisited =
        ref.watch(visitedMuseumIdsProvider).contains(museum.id);
    return Column(
      children: [
        if (museum.homepageUrl != null &&
            museum.homepageUrl!.trim().isNotEmpty) ...[
          _ActionButton(
            icon: Icons.language_outlined,
            label: '홈페이지 방문',
            color: const Color(0xFF2C3E50),
            onTap: () => _launchUrl(context, museum.homepageUrl!),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: isVisited
                    ? Icons.add_location_alt
                    : Icons.check_circle_outline,
                label: isVisited ? '또 다녀왔어요' : '다녀왔어요',
                color: const Color(0xFFE8A87C),
                onTap: () => _onVisitTap(context, ref, museum),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.directions_outlined,
                label: '길찾기',
                color: Colors.blueGrey,
                onTap: () => _launchDirections(context, museum),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ReviewSummaryButton(museum: museum),
      ],
    );
  }

  Future<void> _onVisitTap(
      BuildContext context, WidgetRef ref, Museum museum) async {
    try {
      // v1.10: 기존 방문 여부 사전 차단 제거 — 항상 VisitAddDialog를 열고
      // 같은 날 중복은 DB unique index / DuplicateVisitException으로 처리
      if (context.mounted) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => VisitAddDialog(
            museumId: museum.id,
            museumName: museum.name,
          ),
        );
      }
    } on AuthRequiredException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on DuplicateVisitException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${DateTime.now().year}년 ${DateTime.now().month}월 ${DateTime.now().day}일에 이미 ${museum.name} 방문 기록이 있어요',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  Future<void> _launchDirections(BuildContext context, Museum museum) async {
    final lat = museum.latitude;
    final lng = museum.longitude;
    final name = Uri.encodeComponent(museum.name);

    if (lat == null || lng == null) {
      // 좌표 없으면 주소로 네이버 지도 웹 검색
      final addr = museum.roadAddress ?? museum.address;
      final query = Uri.encodeComponent(addr);
      final webUri = Uri.parse('https://map.naver.com/v5/search/$query');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }

    // 네이버 지도 앱 딥링크 (목적지 좌표 방식)
    final appUri = Uri.parse(
      'nmap://route/public?dlat=$lat&dlng=$lng&dname=$name&appname=com.muselry.muselry',
    );
    // 웹 폴백 URL
    final webUri = Uri.parse(
      'https://map.naver.com/v5/directions/-/-/-/transit?c=$lng,$lat,15,0,0,0,dh',
    );

    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('길찾기를 열 수 없습니다: $e')),
        );
      }
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('홈페이지를 열 수 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }
}

// ─── 리뷰 요약 버튼 ────────────────────────────────────────────────────────────

class _ReviewSummaryButton extends ConsumerWidget {
  final Museum museum;
  const _ReviewSummaryButton({required this.museum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsForMuseumProvider(museum.id));
    final avgRating = museum.averageRating ?? 0.0;
    final reviewCount = museum.reviewCount ?? 0;

    return Material(
      color: const Color(0xFF9B59B6).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push(
          '/museum/${museum.id}/reviews?name=${Uri.encodeComponent(museum.name)}',
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.rate_review_outlined,
                  size: 20, color: Color(0xFF9B59B6)),
              const SizedBox(width: 8),
              Text(
                '리뷰',
                style: const TextStyle(
                  color: Color(0xFF9B59B6),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (reviewCount > 0) ...
                [
                  ...List.generate(5, (i) {
                    final filled = i < avgRating.floor();
                    final half = !filled && (i < avgRating);
                    return Icon(
                      half
                          ? Icons.star_half
                          : (filled ? Icons.star : Icons.star_border),
                      size: 14,
                      color: const Color(0xFFE8A87C),
                    );
                  }),
                  const SizedBox(width: 4),
                  Text(
                    '${avgRating.toStringAsFixed(1)} ($reviewCount개)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9B59B6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]
              else
                reviewsAsync.when(
                  data: (reviews) => Text(
                    reviews.isEmpty ? '첫 리뷰를 작성해보세요!' : '리뷰 보기',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9B59B6),
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: Color(0xFF9B59B6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 에러 / 없음 뷰 ────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

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
              '데이터를 불러오지 못했습니다.',
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
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '박물관 정보를 찾을 수 없습니다.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('돌아가기'),
          ),
        ],
      ),
    );
  }
}
