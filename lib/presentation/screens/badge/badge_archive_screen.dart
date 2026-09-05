import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/badge/badge_model.dart';
import '../../../features/badge/badge_provider.dart';
import 'widgets/national_museum_badge_medal.dart';

const _archiveBackground = Color(0xFF080808);
const _archivePanel = Color(0xFF141416);
const _archiveElevatedPanel = Color(0xFF1C1C20);
const _archiveText = Color(0xFFF2F2F3);
const _archiveMutedText = Color(0x99F2F2F3);
const _archiveDivider = Color(0x1AFFFFFF);
const _archiveGold = Color(0xFFE8A87C);

/// 이미 획득한 Badge만 보여주는 개인 보관함입니다.
///
/// earned_at 영속 데이터가 없으므로 최근 획득 순서는 표시하지 않으며,
/// 기존 방문 기반 [badgeCollectionProvider] 계산 결과만 재사용합니다.
class BadgeArchiveScreen extends ConsumerWidget {
  const BadgeArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeAsync = ref.watch(badgeCollectionProvider);

    return Scaffold(
      backgroundColor: _archiveBackground,
      appBar: AppBar(
        title: const Text('배지함'),
        backgroundColor: _archiveBackground,
        foregroundColor: _archiveText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: badgeAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _archiveGold),
        ),
        error: (_, __) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '배지함을 불러오지 못했어요.\n잠시 후 다시 시도해 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _archiveMutedText, height: 1.5),
            ),
          ),
        ),
        data: (state) => _BadgeArchiveBody(state: state),
      ),
    );
  }
}

class _BadgeArchiveBody extends StatelessWidget {
  final BadgeCollectionState state;

  const _BadgeArchiveBody({required this.state});

  @override
  Widget build(BuildContext context) {
    final earnedMilestones =
        state.milestones.where((badge) => badge.isEarned).toList();
    final earnedMuseums =
        state.nationalMuseums.where((badge) => badge.isEarned).toList();
    final earnedTotal = earnedMilestones.length + earnedMuseums.length;

    if (earnedTotal == 0) {
      return const _ArchiveEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ArchiveHero(earnedCount: earnedTotal),
          if (earnedMilestones.isNotEmpty) ...[
            const SizedBox(height: 30),
            _ArchiveSection(
              title: '마일스톤',
              subtitle: '나의 문화 탐험 기록',
              badges: earnedMilestones,
              onBadgeTap: (badge) => _showBadgeDetail(context, badge),
              isNationalMuseum: false,
            ),
          ],
          if (earnedMuseums.isNotEmpty) ...[
            const SizedBox(height: 30),
            _ArchiveSection(
              title: '전국 국립박물관',
              subtitle: '방문으로 완성한 박물관 컬렉션',
              badges: earnedMuseums,
              onBadgeTap: (badge) => _showBadgeDetail(context, badge),
              isNationalMuseum: true,
            ),
          ],
        ],
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, BadgeProgress badge) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _archiveElevatedPanel,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              badge.definition.category == BadgeCategory.nationalMuseum
                  ? NationalMuseumBadgeMedal(badge: badge, size: 82)
                  : _ArchiveMilestoneMedal(badge: badge, size: 82),
              const SizedBox(height: 16),
              Text(
                badge.definition.title,
                style: const TextStyle(
                  color: _archiveText,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badge.definition.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _archiveMutedText, height: 1.45),
              ),
              const SizedBox(height: 14),
              const Text(
                '획득 완료',
                style: TextStyle(
                  color: _archiveGold,
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

class _ArchiveHero extends StatelessWidget {
  final int earnedCount;

  const _ArchiveHero({required this.earnedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _archiveElevatedPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _archiveDivider),
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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _archiveGold.withValues(alpha: 0.16),
              border: Border.all(
                color: _archiveGold.withValues(alpha: 0.86),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _archiveGold,
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '내가 모은 배지 $earnedCount개',
                  style: const TextStyle(
                    color: _archiveText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '방문한 문화공간의 기록이에요.',
                  style: TextStyle(color: _archiveMutedText, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<BadgeProgress> badges;
  final ValueChanged<BadgeProgress> onBadgeTap;
  final bool isNationalMuseum;

  const _ArchiveSection({
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.onBadgeTap,
    required this.isNationalMuseum,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _archiveText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: _archiveMutedText, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _archivePanel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _archiveDivider),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: badges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              mainAxisExtent: 122,
            ),
            itemBuilder: (context, index) {
              final badge = badges[index];
              return InkWell(
                onTap: () => onBadgeTap(badge),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    isNationalMuseum
                        ? NationalMuseumBadgeMedal(badge: badge, size: 70)
                        : _ArchiveMilestoneMedal(badge: badge, size: 70),
                    const SizedBox(height: 7),
                    Text(
                      badge.definition.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _archiveText,
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArchiveMilestoneMedal extends StatelessWidget {
  final BadgeProgress badge;
  final double size;

  const _ArchiveMilestoneMedal({required this.badge, required this.size});

  @override
  Widget build(BuildContext context) {
    final accent = _milestoneAccent(badge.definition.visualKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.28),
        border: Border.all(
          color: _archiveGold.withValues(alpha: 0.82),
          width: size * 0.055,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 10,
          ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(size * 0.10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Icon(
          _milestoneIcon(badge.definition.visualKey),
          color: _archiveText,
          size: size * 0.35,
        ),
      ),
    );
  }

  IconData _milestoneIcon(String visualKey) {
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
        return Icons.workspace_premium_outlined;
    }
  }

  Color _milestoneAccent(String visualKey) {
    switch (visualKey) {
      case 'first-step':
        return const Color(0xFF5B8C85);
      case 'cultural-walker':
        return const Color(0xFF6F83A8);
      case 'cultural-explorer':
        return const Color(0xFFB07B3E);
      case 'cultural-traveler':
        return const Color(0xFF527A9B);
      default:
        return _archiveGold;
    }
  }
}

class _ArchiveEmptyState extends StatelessWidget {
  const _ArchiveEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _archivePanel,
                border: Border.all(color: _archiveDivider),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: _archiveMutedText.withValues(alpha: 0.65),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '아직 모은 배지가 없어요.',
              style: TextStyle(
                color: _archiveText,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '첫 문화공간을 방문하고 나만의 배지를 모아보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _archiveMutedText, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
