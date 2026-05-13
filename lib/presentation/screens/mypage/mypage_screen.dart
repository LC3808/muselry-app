import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/visit_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MypageScreen
// ─────────────────────────────────────────────────────────────────────────────
class MypageScreen extends ConsumerWidget {
  const MypageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('마이페이지'),
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => _showSettingsSheet(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(myVisitsProvider);
            ref.invalidate(bookmarkedMuseumsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: const [
              _ProfileSection(),
              SizedBox(height: 12),
              _StatsSection(),
              SizedBox(height: 12),
              _BookmarkSection(),
              SizedBox(height: 12),
              _MapPreviewSection(),
              SizedBox(height: 12),
              _ActivitySection(),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SettingsSheet(ref: ref),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 프로필 섹션
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final displayName = ref.watch(displayNameProvider);
    final user = ref.watch(currentUserProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          // 아바타
          _AvatarWidget(
            avatarUrl: profileAsync.valueOrNull?.avatarUrl,
            displayName: displayName,
          ),
          const SizedBox(width: 16),
          // 이름 + 이메일
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    user!.email!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // 편집 버튼
          TextButton(
            onPressed: () => _showEditProfileSheet(context, ref, displayName),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: const Text('편집', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(
      BuildContext context, WidgetRef ref, String currentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditProfileSheet(
        currentNickname: currentName,
        ref: ref,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 아바타 위젯
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;

  const _AvatarWidget({this.avatarUrl, required this.displayName});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: avatarUrl!,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            placeholder: (_, __) => _initials(displayName),
            errorWidget: (_, __, ___) => _initials(displayName),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 30,
      backgroundColor: AppTheme.primaryColor,
      child: _initials(displayName),
    );
  }

  Widget _initials(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 방문 통계 섹션
// ─────────────────────────────────────────────────────────────────────────────
class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(myVisitsProvider);
    final stats = ref.watch(visitStatsProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '내 방문 기록',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/visits'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: const Text('전체 보기', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          visitsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => _StatsError(),
            data: (_) => _StatsContent(stats: stats),
          ),
        ],
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  final VisitStats? stats;

  const _StatsContent({this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats == null || stats!.totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '아직 방문 기록이 없어요.\n박물관을 방문하고 기록해 보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondaryColor,
              height: 1.6,
            ),
          ),
        ),
      );
    }

    final s = stats!;
    // 유형별 상위 3개
    final topTypes = s.byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topRegions = s.byRegion.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        // 총 방문 수 + 고유 박물관 수 (P1-2 픽스)
        Row(
          children: [
            _StatCard(
              label: '총 방문 횟수',
              value: '${s.totalCount}',
              unit: '회',
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: '방문한 박물관',
              value: '${s.distinctMuseumCount}',
              unit: '곳',
              color: AppTheme.accentColor,
            ),
          ],
        ),
        if (topTypes.isNotEmpty) ...[  
          const SizedBox(height: 12),
          _StatCard(
            label: '가장 많이 간 유형',
            value: topTypes.first.key,
            unit: '${topTypes.first.value}회',
            color: AppTheme.primaryColor.withValues(alpha: 0.7),
          ),
        ],
        if (topRegions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RegionBar(topRegions: topRegions.take(3).toList()),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionBar extends StatelessWidget {
  final List<MapEntry<String, int>> topRegions;

  const _RegionBar({required this.topRegions});

  @override
  Widget build(BuildContext context) {
    final total = topRegions.fold<int>(0, (sum, e) => sum + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '지역별 방문',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...topRegions.map((entry) {
          final ratio = total > 0 ? entry.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: AppTheme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor.withValues(alpha: 0.7)),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value}회',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StatsError extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '방문 기록을 불러오지 못했어요.',
        style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryColor),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 북마크 섹션
// ─────────────────────────────────────────────────────────────────────────────
class _BookmarkSection extends ConsumerWidget {
  const _BookmarkSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkedAsync = ref.watch(bookmarkedMuseumsProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '북마크한 박물관',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              bookmarkedAsync.when(
                data: (museums) => museums.isNotEmpty
                    ? Text(
                        '${museums.length}곳',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          bookmarkedAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Center(
              child: Text(
                '북마크 목록을 불러오지 못했어요.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
            data: (museums) {
              if (museums.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '북마크한 박물관이 없어요.\n마음에 드는 박물관을 저장해 보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                        height: 1.6,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: museums
                    .map((museum) => _BookmarkTile(
                          name: museum.name,
                          type: museum.type,
                          region: museum.region1,
                          imageUrl: museum.imageUrl,
                          onTap: () => context.push('/museum/${museum.id}'),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final String name;
  final String type;
  final String region;
  final String? imageUrl;
  final VoidCallback onTap;

  const _BookmarkTile({
    required this.name,
    required this.type,
    required this.region,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 52,
                height: 52,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _placeholder(),
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 12),
            // 이름 + 태그
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _SmallBadge(label: type),
                      const SizedBox(width: 6),
                      if (region.isNotEmpty)
                        Text(
                          region,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppTheme.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          _typeIcon(type),
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }

  String _typeIcon(String type) {
    switch (type) {
      case '미술관':
        return '🎨';
      case '과학관':
        return '🔬';
      case '기념관':
        return '🏛️';
      case '전시관':
        return '🖼️';
      default:
        return '🏺';
    }
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;

  const _SmallBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// v1.6: 내가 다녀온 박물관 지도 프리뷰 섹션
// ─────────────────────────────────────────────────────────────────────────────
class _MapPreviewSection extends ConsumerWidget {
  const _MapPreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitedIds = ref.watch(visitedMuseumIdsProvider);
    final bookmarkedIds = ref.watch(bookmarkedIdsProvider);
    final visits = ref.watch(myVisitsProvider).valueOrNull ?? [];

    // 이번 달 방문 횟수
    final now = DateTime.now();
    final thisMonthCount = visits
        .where((v) =>
            v.visitedAt.year == now.year && v.visitedAt.month == now.month)
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 18,
                  color: Color(0xFFE8A87C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '내가 다녀온 박물관 지도',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/mypage/map'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                  child: const Text('지도 보기',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          // 미니 통계 행
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                _MiniStatChip(
                  icon: Icons.place,
                  label: '방문 박물관',
                  value: '${visitedIds.length}곳',
                  color: const Color(0xFFD4622A),
                ),
                const SizedBox(width: 8),
                _MiniStatChip(
                  icon: Icons.bookmark,
                  label: '북마크',
                  value: '${bookmarkedIds.length}곳',
                  color: const Color(0xFF1565C0),
                ),
                const SizedBox(width: 8),
                _MiniStatChip(
                  icon: Icons.calendar_today,
                  label: '이번 달',
                  value: '$thisMonthCount회',
                  color: Colors.green.shade600,
                ),
                const Spacer(),
                // 지도 이동 버튼
                ElevatedButton(
                  onPressed: () => context.push('/mypage/map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8A87C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map, size: 14),
                      SizedBox(width: 4),
                      Text('지도 열기',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
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

class _MiniStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 내 활동 섹션
// ─────────────────────────────────────────────────────────────────────────────
class _ActivitySection extends ConsumerWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              '내 활동',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ),
          _MenuItem(
            icon: Icons.history,
            label: '방문 기록',
            onTap: () => context.push('/visits'),
          ),
          Divider(height: 1, indent: 56, color: AppTheme.dividerColor),
          _MenuItem(
            icon: Icons.bookmark_border,
            label: '북마크한 박물관',
            onTap: () {
              // 북마크 섹션으로 스크롤 (현재는 페이지 내 표시)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('위 북마크 섹션에서 확인하세요'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: AppTheme.dividerColor),
          _MenuItem(
            icon: Icons.rate_review_outlined,
            label: '내가 쓴 리뷰',
            trailing: _ComingSoonBadge(),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: trailing ??
          Icon(Icons.chevron_right, size: 20, color: AppTheme.textSecondaryColor),
      onTap: onTap,
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '준비 중',
        style: TextStyle(
          fontSize: 11,
          color: AppTheme.accentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 설정 Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSheet extends ConsumerWidget {
  final WidgetRef ref;

  const _SettingsSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('알림 설정'),
              trailing: _ComingSoonBadge(),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('앱 정보'),
              trailing: Text(
                'v0.1.0',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              onTap: () {},
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: AppTheme.errorColor),
              title: Text(
                '로그아웃',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('정말 로그아웃 하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          '로그아웃',
                          style: TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authNotifierProvider.notifier).signOut();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 프로필 편집 Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _EditProfileSheet extends ConsumerStatefulWidget {
  final String currentNickname;
  final WidgetRef ref;

  const _EditProfileSheet({
    required this.currentNickname,
    required this.ref,
  });

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final TextEditingController _controller;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentNickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) {
      setState(() => _errorText = '닉네임을 입력해주세요');
      return;
    }
    if (nickname.length > 20) {
      setState(() => _errorText = '닉네임은 20자 이하로 입력해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref.read(profileProvider.notifier).updateNickname(nickname);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = '저장에 실패했어요. 다시 시도해주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            '닉네임 편집',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 20,
            decoration: InputDecoration(
              hintText: '닉네임을 입력해주세요',
              errorText: _errorText,
              counterText: '${_controller.text.length}/20',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }
}
