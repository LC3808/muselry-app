import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../exhibition_model.dart';
import '../exhibition_provider.dart';
import 'exhibition_card.dart';

/// 홈 화면 "내 주변 전시" 섹션
/// - 비동기 독립 로딩 (홈 전체 렌더링 차단 없음)
/// - 결과 0건 또는 API 실패 시 섹션 자체 숨김
class ExhibitionSection extends ConsumerWidget {
  const ExhibitionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(exhibitionProvider);

    return asyncState.when(
      loading: () => const _ExhibitionLoading(),
      error: (_, __) => const SizedBox.shrink(), // 에러 시 섹션 숨김
      data: (state) {
        if (state.items.isEmpty) return const SizedBox.shrink();
        return _ExhibitionContent(state: state);
      },
    );
  }
}

class _ExhibitionContent extends StatelessWidget {
  final ExhibitionState state;
  const _ExhibitionContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더 (외부 padding 없음 — home_screen.dart EdgeInsets.all(20)에 정렬)
        Row(
            children: [
              const Text(
                '내 주변 전시',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(width: 6),
              if (state.hasLocation)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '거리순',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
        ),
        const SizedBox(height: 12),
        // 가로 스크롤 카드 리스트 (외부 padding 없음 — home_screen.dart EdgeInsets.all(20)에 정렬)
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final exhibition = state.items[index];
              return ExhibitionCard(
                exhibition: exhibition,
                userLat: state.userLat,
                userLng: state.userLng,
                onTap: () => _showDetail(context, exhibition),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, Exhibition exhibition) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExhibitionDetailSheet(exhibition: exhibition),
    );
  }
}

/// 전시 상세 모달 (§10: title/place/기간/thumbnail/realmName/area/sigungu만)
/// 금지: museums 연결, 방문기록, 북마크
class _ExhibitionDetailSheet extends StatelessWidget {
  final Exhibition exhibition;
  const _ExhibitionDetailSheet({required this.exhibition});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 드래그 핸들
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // 썸네일
            if (exhibition.thumbnail != null && exhibition.thumbnail!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  exhibition.thumbnail!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                children: [
                  // 분야 배지
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      exhibition.realmName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 제목
                  Text(
                    exhibition.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: exhibition.place,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    text: '전시 기간: ${exhibition.displayPeriod}',
                  ),
                  if (exhibition.area != null || exhibition.sigungu != null) ...[
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.map_outlined,
                      text: [exhibition.area, exhibition.sigungu]
                          .whereType<String>()
                          .join(' '),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// 로딩 shimmer (인기 장소 로딩과 동일한 높이)
class _ExhibitionLoading extends StatelessWidget {
  const _ExhibitionLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: 100,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Container(
              width: 160,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
