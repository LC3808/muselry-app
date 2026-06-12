import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/museum.dart';
import '../../providers/museum_provider.dart';
import '../../providers/profile_provider.dart';

/// 홈 화면 (Day 9 업데이트)
/// - 인기 장소 가로 스크롤 섹션 추가 (museum_ranking 기준, 폴백: average_rating)
/// - §8-3: 빠른 탐색 섹션 삭제
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularAsync = ref.watch(popularMuseumsProvider);
    final displayName = ref.watch(displayNameProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('🏛️ 뮤즐리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.go(AppRoutes.mypage), // M7-A: mypage is now shell tab
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
                _GreetingBanner(displayName: displayName),

                // ── 빠른 탐색 버튼 그리드 (M7-G-1: 헤더 없이 4버튼만) ────────────
                _QuickAccessGrid(),
                const SizedBox(height: 20),

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
  const _GreetingBanner({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '안녕하세요 👋',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            '오늘은 어떤 공간을 탐험해볼까요?', // §8-2 M7-F-2
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
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

// ─── 빠른 탐색 그리드 (M7-G-5-1: 파스텔 카드 디자인 복원) ─────────────────────────

class _QuickAccessGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        // M7-G-5-1: 하늘색 파스텔 카드 (전시 공간 탐색)
        _QuickAccessCard(
          emoji: '🔍',
          label: '전시 공간 탐색',
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
        // M7-G-5-1: 오렌지 파스텔 카드 (내 방문 기록, 라우팅 /mypage 유지)
        _QuickAccessCard(
          emoji: '📖',
          label: '내 방문 기록',
          color: const Color(0xFFE67E22),
          onTap: () => context.go(AppRoutes.mypage), // M7-G-1: /records → /mypage
        ),
        // M7-G-5-1: 보라 파스텔 카드 (커뮤니티)
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
