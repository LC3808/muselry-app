import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/badge/badge_model.dart';
import '../../../features/badge/badge_provider.dart';
import 'widgets/national_museum_badge_medal.dart';

const _galleryBackground = Color(0xFF080808);
const _galleryPanel = Color(0xFF141416);
const _galleryPanelElevated = Color(0xFF1C1C20);
const _galleryText = Color(0xFFF2F2F3);
const _galleryMutedText = Color(0x99F2F2F3);
const _galleryDivider = Color(0x1AFFFFFF);
const _galleryGold = Color(0xFFE8A87C);

class BadgeScreen extends ConsumerWidget {
  const BadgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeAsync = ref.watch(badgeCollectionProvider);

    return Scaffold(
      backgroundColor: _galleryBackground,
      appBar: AppBar(
        title: const Text('배지'),
        backgroundColor: _galleryBackground,
        foregroundColor: _galleryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: badgeAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _galleryGold),
        ),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '방문 기록을 불러오지 못했어요.\n잠시 후 다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _galleryMutedText, height: 1.5),
            ),
          ),
        ),
        data: (state) => _BadgeCollectionBody(
          state: state,
          onArchiveTap: () => context.push(AppRoutes.badgeArchive),
        ),
      ),
    );
  }
}

class _BadgeCollectionBody extends StatelessWidget {
  final BadgeCollectionState state;
  final VoidCallback onArchiveTap;

  const _BadgeCollectionBody({
    required this.state,
    required this.onArchiveTap,
  });

  @override
  Widget build(BuildContext context) {
    final earnedTotal =
        state.earnedMilestoneCount + state.earnedNationalMuseumCount;
    final total = state.milestones.length + state.nationalMuseums.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BadgeHero(
            earnedCount: earnedTotal,
            totalCount: total,
            onArchiveTap: onArchiveTap,
          ),
          const SizedBox(height: 28),
          const _SectionTitle(
            title: '마일스톤',
            subtitle: '문화공간을 탐험하며 다음 목표를 채워보세요.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 188,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.milestones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final badge = state.milestones[index];
                return _MilestoneBadgeCard(
                  badge: badge,
                  onTap: () => _showBadgeDetail(context, badge),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          _CollapsibleCollectionSection(
            badges: state.nationalMuseums,
            earnedCount: state.earnedNationalMuseumCount,
            onBadgeTap: (badge) => _showBadgeDetail(context, badge),
          ),
        ],
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, BadgeProgress badge) {
    final isNationalMuseum =
        badge.definition.category == BadgeCategory.nationalMuseum;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _galleryPanelElevated,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              isNationalMuseum
                  ? NationalMuseumBadgeMedal(badge: badge, size: 76)
                  : _BadgeMedal(badge: badge, size: 76),
              const SizedBox(height: 14),
              Text(
                badge.definition.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _galleryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge.definition.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _galleryMutedText, height: 1.45),
              ),
              const SizedBox(height: 14),
              Text(
                badge.isEarned
                    ? '획득 완료'
                    : isNationalMuseum
                        ? '미획득'
                        : '현재 ${badge.current} / ${badge.target}',
                style: TextStyle(
                  color: badge.isEarned ? _galleryGold : _galleryMutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeHero extends StatelessWidget {
  final int earnedCount;
  final int totalCount;
  final VoidCallback onArchiveTap;

  const _BadgeHero({
    required this.earnedCount,
    required this.totalCount,
    required this.onArchiveTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = totalCount == 0 ? 0.0 : earnedCount / totalCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _galleryPanelElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _galleryDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _galleryGold.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                color: _galleryGold.withValues(alpha: 0.84),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: _galleryGold,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '나의 문화 컬렉션',
                        style: TextStyle(
                          color: _galleryText,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onArchiveTap,
                      icon: const Icon(Icons.inventory_2_outlined, size: 15),
                      label: const Text('배지함'),
                      style: TextButton.styleFrom(
                        foregroundColor: _galleryGold,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$earnedCount / $totalCount 획득',
                  style: const TextStyle(
                    color: _galleryMutedText,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_galleryGold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _galleryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: _galleryMutedText),
        ),
      ],
    );
  }
}

class _CollapsibleCollectionSection extends StatefulWidget {
  final List<BadgeProgress> badges;
  final int earnedCount;
  final ValueChanged<BadgeProgress> onBadgeTap;

  const _CollapsibleCollectionSection({
    required this.badges,
    required this.earnedCount,
    required this.onBadgeTap,
  });

  @override
  State<_CollapsibleCollectionSection> createState() =>
      _CollapsibleCollectionSectionState();
}

class _CollapsibleCollectionSectionState
    extends State<_CollapsibleCollectionSection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _galleryPanel.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _galleryDivider),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '전국 국립박물관 컬렉션',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _galleryText,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.earnedCount} / ${widget.badges.length}',
                      style: const TextStyle(
                        color: _galleryGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _galleryMutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '국립박물관을 방문하고 특별한 배지를 모아보세요.',
                    style: TextStyle(fontSize: 12, color: _galleryMutedText),
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.badges.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 11,
                      mainAxisExtent: 118,
                    ),
                    itemBuilder: (context, index) {
                      final badge = widget.badges[index];
                      return _NationalMuseumBadgeItem(
                        badge: badge,
                        onTap: () => widget.onBadgeTap(badge),
                      );
                    },
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _MilestoneBadgeCard extends StatelessWidget {
  final BadgeProgress badge;
  final VoidCallback onTap;

  const _MilestoneBadgeCard({
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 142,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _galleryPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badge.isEarned
                ? _BadgeVisual.accentFor(
                    badge.definition.visualKey,
                  ).withValues(alpha: 0.62)
                : _galleryDivider,
          ),
          boxShadow: badge.isEarned
              ? [
                  BoxShadow(
                    color: _BadgeVisual.accentFor(
                      badge.definition.visualKey,
                    ).withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            _BadgeMedal(badge: badge, size: 72),
            const SizedBox(height: 10),
            Text(
              badge.definition.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: badge.isEarned ? _galleryText : _galleryMutedText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              badge.isEarned ? '획득 완료' : '${badge.current} / ${badge.target}',
              style: TextStyle(
                fontSize: 12,
                color: badge.isEarned ? _galleryGold : _galleryMutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NationalMuseumBadgeItem extends StatelessWidget {
  final BadgeProgress badge;
  final VoidCallback onTap;

  const _NationalMuseumBadgeItem({
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          NationalMuseumBadgeMedal(badge: badge, size: 68),
          const SizedBox(height: 6),
          Text(
            badge.definition.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.22,
              fontWeight: badge.isEarned ? FontWeight.w700 : FontWeight.w500,
              color: badge.isEarned ? _galleryText : _galleryMutedText,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BadgeMedal extends StatelessWidget {
  final BadgeProgress badge;
  final double size;

  const _BadgeMedal({
    required this.badge,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final visualKey = badge.definition.visualKey;
    final accent = _BadgeVisual.accentFor(visualKey);
    final isEarned = badge.isEarned;
    final isMilestone = badge.definition.category == BadgeCategory.milestone;
    final icon =
        isEarned ? _BadgeVisual.iconFor(visualKey) : Icons.lock_outline;
    final fill = isEarned
        ? accent.withValues(alpha: 0.30)
        : Colors.white.withValues(alpha: 0.055);
    final rim = isEarned
        ? _galleryGold.withValues(alpha: 0.80)
        : Colors.white.withValues(alpha: 0.13);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(size * 0.10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: rim, width: size * 0.055),
              boxShadow: isEarned
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 10,
                        spreadRadius: 0.4,
                      ),
                    ]
                  : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isEarned
                      ? Colors.white.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.07),
                ),
                color: Colors.black.withValues(alpha: isEarned ? 0.10 : 0.12),
              ),
              child: Icon(
                icon,
                size: size * 0.37,
                color: isEarned
                    ? _galleryText
                    : _galleryMutedText.withValues(alpha: 0.50),
              ),
            ),
          ),
          if (isMilestone)
            _MilestoneMedalMarker(
              visualKey: visualKey,
              accent: isEarned ? accent : _galleryMutedText,
              isEarned: isEarned,
              size: size,
            ),
        ],
      ),
    );
  }
}

class _MilestoneMedalMarker extends StatelessWidget {
  final String visualKey;
  final Color accent;
  final bool isEarned;
  final double size;

  const _MilestoneMedalMarker({
    required this.visualKey,
    required this.accent,
    required this.isEarned,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final markerColor = accent.withValues(alpha: isEarned ? 0.95 : 0.30);
    final markerSize = size * 0.13;

    switch (visualKey) {
      case 'first-step':
        return Positioned(
          top: size * 0.12,
          child: Container(
            width: markerSize,
            height: markerSize,
            decoration:
                BoxDecoration(color: markerColor, shape: BoxShape.circle),
          ),
        );
      case 'cultural-walker':
        return Container(
          width: size * 0.70,
          height: size * 0.70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: markerColor, width: 1.2),
          ),
        );
      case 'cultural-explorer':
        return Stack(
          children: [
            Positioned(
                top: size * 0.08,
                left: size * 0.46,
                child: _marker(markerColor, markerSize)),
            Positioned(
                bottom: size * 0.08,
                left: size * 0.46,
                child: _marker(markerColor, markerSize)),
            Positioned(
                left: size * 0.08,
                top: size * 0.46,
                child: _marker(markerColor, markerSize)),
            Positioned(
                right: size * 0.08,
                top: size * 0.46,
                child: _marker(markerColor, markerSize)),
          ],
        );
      case 'cultural-traveler':
        return Transform.rotate(
          angle: -0.55,
          child: Container(
            width: size * 0.52,
            height: 1.4,
            color: markerColor,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _marker(Color color, double markerSize) {
    return Container(
      width: markerSize,
      height: markerSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _BadgeVisual {
  static IconData iconFor(String visualKey) {
    switch (visualKey) {
      case 'first-step':
        return Icons.directions_walk_outlined;
      case 'cultural-walker':
        return Icons.route_outlined;
      case 'cultural-explorer':
        return Icons.explore_outlined;
      case 'cultural-traveler':
        return Icons.map_outlined;
      default:
        return Icons.account_balance_outlined;
    }
  }

  static Color accentFor(String visualKey) {
    switch (visualKey) {
      case 'first-step':
        return const Color(0xFF5B8C85);
      case 'cultural-walker':
        return const Color(0xFF6F83A8);
      case 'cultural-explorer':
        return const Color(0xFFB07B3E);
      case 'cultural-traveler':
        return const Color(0xFF527A9B);
      case 'gyeongju':
        return const Color(0xFF9C7040);
      case 'buyeo':
        return const Color(0xFF9A6B4A);
      case 'gongju':
        return const Color(0xFF8B6F47);
      case 'gwangju':
        return const Color(0xFF6B7A8F);
      case 'jeonju':
        return const Color(0xFF9B6C75);
      case 'jinju':
        return const Color(0xFF607D6B);
      case 'jeju':
        return const Color(0xFF4F7C86);
      case 'gimhae':
        return const Color(0xFF7A6C5D);
      case 'cheongju':
        return const Color(0xFF6E7691);
      case 'daegu':
        return const Color(0xFF8B5E5E);
      case 'chuncheon':
        return const Color(0xFF617B64);
      case 'naju':
        return const Color(0xFF856C93);
      default:
        return AppTheme.primaryColor;
    }
  }
}
