import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/museum.dart';
import '../../providers/museum_provider.dart';
import '../../providers/profile_provider.dart';
import '../../../features/exhibition/widgets/exhibition_section.dart';

/// 홈 화면 (Day 9 업데이트)
/// - 인기 장소 가로 스크롤 섹션 추가 (museum_ranking 기준, 폴백: average_rating)
/// - §8-3: 빠른 탐색 섹션 삭제
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularAsync = ref.watch(popularMuseumsProvider);
    final displayName = ref.watch(displayNameProvider);
    final cultureLevel = ref.watch(cultureLevelProvider);
    final displayNameWithHonorific =
        displayName.endsWith('님') ? displayName : '$displayName 님';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('🏛️ 뮤즐리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () =>
                context.go(AppRoutes.mypage), // M7-A: mypage is now shell tab
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(popularMuseumsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 인사말 배너 ──────────────────────────────────────────
                _GreetingBanner(
                  displayName: displayNameWithHonorific,
                  cultureLevelTitle:
                      cultureLevel.level == 0 ? '문화 레벨' : cultureLevel.title,
                  onCultureLevelTap: () => context.go(AppRoutes.mypage),
                  onCultureMapTap: () => context.push(AppRoutes.mypageMap),
                ),

                const SizedBox(height: 16),

                // ── 탐색·추천 중심 빠른 접근 ────────────────────────────────
                _QuickAccessGrid(
                  onBadgeTap: () => context.push(AppRoutes.badges),
                ),
                const SizedBox(height: 16),
                _CultureTripBanner(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('문화여행 코스를 준비 중입니다.')),
                  ),
                ),
                const SizedBox(height: 24),

                // ── 인기 장소 섹션 ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🏆 인기 장소',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.explore),
                      child: Text(
                        '전체 보기',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                popularAsync.when(
                  loading: () => _PopularMuseumsLoading(),
                  error: (_, __) => _PopularMuseumsError(
                    onRetry: () => ref.invalidate(popularMuseumsProvider),
                  ),
                  data: (museums) {
                    if (museums.isEmpty) {
                      return _PopularMuseumsEmpty();
                    }
                    return _PopularMuseumsList(
                      museums: museums,
                      onTap: (museum) => context.push(
                        AppRoutes.museumDetail.replaceFirst(':id', museum.id),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // ── 내 주변 문화행사 섹션 (v0.4.0: 문화정보 OpenAPI 실시간) ──────
                const ExhibitionSection(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 인사말 배너 ──────────────────────────────────────────────────────────────

class _GreetingBanner extends StatelessWidget {
  final String displayName;
  final String cultureLevelTitle;
  final VoidCallback onCultureLevelTap;
  final VoidCallback onCultureMapTap;

  const _GreetingBanner({
    required this.displayName,
    required this.cultureLevelTitle,
    required this.onCultureLevelTap,
    required this.onCultureMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안녕하세요 👋',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '오늘은 어떤 공간을 탐험해볼까요?', // §8-2 M7-F-2
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 126,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GreetingActionButton(
                  icon: Icons.auto_awesome_outlined,
                  label: cultureLevelTitle,
                  isCultureLevel: true,
                  onTap: onCultureLevelTap,
                ),
                const SizedBox(height: 6),
                _GreetingActionButton(
                  icon: Icons.map_outlined,
                  label: '나의 문화 지도',
                  onTap: onCultureMapTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isCultureLevel;
  final VoidCallback onTap;

  const _GreetingActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isCultureLevel = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isCultureLevel ? AppTheme.primaryColor : Colors.white;
    final background = isCultureLevel
        ? Colors.white.withValues(alpha: 0.93)
        : Colors.white.withValues(alpha: 0.14);
    final border = isCultureLevel
        ? Colors.white.withValues(alpha: 0.76)
        : Colors.white.withValues(alpha: 0.42);

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class _CultureTripBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _CultureTripBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: AppTheme.accentColor.withValues(alpha: 0.42)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withValues(alpha: 0.32),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.route_outlined,
                size: 20,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이달의 문화여행 · “안동”',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3),
                  Text(
                    '전통과 문화가 이어지는 특별한 여행',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 인기 장소 가로 스크롤 리스트 ──────────────────────────────────────────

class _PopularMuseumsList extends StatelessWidget {
  final List<Museum> museums;
  final void Function(Museum museum) onTap;

  const _PopularMuseumsList({
    required this.museums,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: museums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final museum = museums[index];
          return _PopularMuseumCard(
            museum: museum,
            rank: index + 1,
            onTap: () => onTap(museum),
          );
        },
      ),
    );
  }
}

class _PopularMuseumCard extends StatelessWidget {
  final Museum museum;
  final int rank;
  final VoidCallback onTap;

  const _PopularMuseumCard({
    required this.museum,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerColor),
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
          children: [
            // 이미지 or 플레이스홀더
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                children: [
                  museum.imageUrl != null
                      ? Image.network(
                          museum.imageUrl!,
                          height: 100,
                          width: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _ImagePlaceholder(type: museum.type),
                        )
                      : _ImagePlaceholder(type: museum.type),
                  // 순위 배지
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? AppTheme.accentColor
                            : AppTheme.primaryColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$rank위',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // 어린이 친화 배지
                  if (museum.isKidsFriendly)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '👶',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 정보
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      museum.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (museum.averageRating != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
                            color: Color(0xFFF5A623),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            museum.averageRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            museum.region1,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondaryColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final String type;
  const _ImagePlaceholder({required this.type});

  @override
  Widget build(BuildContext context) {
    final emoji = type.contains('미술') ? '🎨' : '🏛️';
    return Container(
      height: 100,
      width: 150,
      color: AppTheme.primaryColor.withValues(alpha: 0.08),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}

// ─── 로딩 / 에러 / 빈 상태 ───────────────────────────────────────────────────

class _PopularMuseumsLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 150,
          decoration: BoxDecoration(
            color: AppTheme.dividerColor.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _PopularMuseumsError extends StatelessWidget {
  final VoidCallback onRetry;
  const _PopularMuseumsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('인기 장소를 불러오지 못했어요. 다시 시도'),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }
}

class _PopularMuseumsEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: Text(
        '아직 인기 장소 데이터가 없어요.',
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }
}

// ─── 빠른 접근 그리드 ───────────────────────────────────────────────────────

class _QuickAccessGrid extends StatelessWidget {
  final VoidCallback onBadgeTap;

  const _QuickAccessGrid({
    required this.onBadgeTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.45,
      children: [
        // M7-G-5-1: 하늘색 파스텔 카드 (공간 탐색)
        _QuickAccessCard(
          emoji: '🔍',
          label: '공간 탐색',
          color: const Color(0xFF3498DB),
          onTap: () => context.go(AppRoutes.explore),
        ),
        // M7-G-5-1: 연두색 파스텔 카드 (지도로 찾기)
        _QuickAccessCard(
          emoji: '🗺️',
          label: '지도로 찾기',
          color: const Color(0xFF27AE60),
          onTap: () => context.go(AppRoutes.map),
        ),
        _QuickAccessCard(
          emoji: '🏅',
          label: '배지',
          color: AppTheme.accentColor,
          onTap: onBadgeTap,
        ),
        _QuickAccessCard(
          emoji: '💬',
          label: '커뮤니티',
          color: const Color(0xFF9B59B6),
          onTap: () => context.go(AppRoutes.community),
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessCard({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.9),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
