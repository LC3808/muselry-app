
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart'; // M8-3

import '../../../config/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/comment_provider.dart'; // unreadNotificationCountProvider
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
          // 알림 버튼 + 빨간 점 뱃지
          Consumer(
            builder: (context, ref, _) {
              final unreadAsync =
                  ref.watch(unreadNotificationCountProvider);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: '알림',
                    onPressed: () => context.push(AppRoutes.notifications),
                  ),
                  unreadAsync.whenOrNull(
                    data: (count) => count > 0
                        ? Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE74C3C),
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ) ??
                      const SizedBox.shrink(),
                ],
              );
            },
          ),
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
            ref.invalidate(bookmarksProvider);
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: const [
              // §1: 프로필 영역
              _ProfileSection(),
              SizedBox(height: 12),
              // §1: 나의 문화 지도 카드 (첫 번째 핵심 카드)
              _CultureMapCard(),
              SizedBox(height: 12),
              // §1: 내 방문 기록 카드 (레벨 + 통계)
              _VisitStatsCard(),
              SizedBox(height: 12),
              // §1: 북마크한 공간
              _BookmarkSection(),
              SizedBox(height: 12),
              // §1: 내가 쓴 리뷰 / 알림 / 문의·건의 / 설정·계정
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
// §1: 나의 문화 지도 카드 (첫 번째 핵심 카드)
// ─────────────────────────────────────────────────────────────────────────────
class _CultureMapCard extends ConsumerWidget {
  const _CultureMapCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitedIds = ref.watch(visitedMuseumIdsProvider);
    final bookmarkedIds = ref.watch(bookmarkedIdsProvider);
    final stats = ref.watch(visitStatsProvider);
    final thisMonthCount = stats?.thisMonthCount ?? 0;

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
                    '나의 문화 지도',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
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
                  label: '다녀온 공간',
                  value: '${visitedIds.length}곳',
                  color: const Color(0xFFD32F2F),
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
// §1: 내 방문 기록 카드 (레벨 + 통계)
// ─────────────────────────────────────────────────────────────────────────────
class _VisitStatsCard extends ConsumerWidget {
  const _VisitStatsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(myVisitsProvider);
    final stats = ref.watch(visitStatsProvider);
    final level = ref.watch(cultureLevelProvider);

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
            error: (_, __) => Center(
              child: Text(
                '방문 기록을 불러오지 못했어요.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
            data: (_) {
              if (stats == null || stats.totalCount == 0) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '첫 방문을 기록해 보세요.\n박물관·미술관·과학관 방문을 남기면 문화 레벨이 올라가요.',
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
              return _VisitStatsContent(stats: stats, level: level);
            },
          ),
        ],
      ),
    );
  }
}

class _VisitStatsContent extends StatelessWidget {
  final VisitStats stats;
  final CultureLevel level;

  const _VisitStatsContent({required this.stats, required this.level});

  @override
  Widget build(BuildContext context) {
    // 유형별 상위 1개 (가장 많이 간 유형)
    final topTypes = stats.byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // 지역별 TOP 3
    final topRegions = stats.byRegion.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 총 방문 + 다녀온 공간
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: '총 방문 횟수',
                value: '${stats.totalCount}',
                unit: '회',
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: '다녀온 공간',
                value: '${stats.distinctMuseumCount}',
                unit: '곳',
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 나의 문화 레벨 + 프로그레스
        _LevelBar(level: level),
        // 가장 많이 간 유형 (있을 때만)
        if (topTypes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StatCard(
            label: '가장 많이 간 유형',
            value: topTypes.first.key,
            unit: '${topTypes.first.value}회',
            color: AppTheme.primaryColor.withValues(alpha: 0.7),
          ),
        ],
        // 지역별 방문 TOP 3 (있을 때만)
        if (topRegions.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RegionBar(topRegions: topRegions.take(3).toList()),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 레벨 바 위젯
// ─────────────────────────────────────────────────────────────────────────────
class _LevelBar extends StatelessWidget {
  final CultureLevel level;

  const _LevelBar({required this.level});

  // M9.2-1: 하드코딩 제거 — profile_provider.dart의 cultureLevelMeta 단일 소스 직접 참조

  void _showLevelGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문화 레벨 6단계',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            ...cultureLevelMeta.map((e) { // M9.2-1: cultureLevelMeta 참조
              final isCurrentLevel = e.$1 == level.level;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: isCurrentLevel
                    ? BoxDecoration(
                        color: _levelColor(e.$1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrentLevel
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isCurrentLevel
                              ? _levelColor(e.$1)
                              : AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    Text(
                      e.$3,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCurrentLevel
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: isCurrentLevel
                            ? _levelColor(e.$1)
                            : AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                '기준: 다녀온 공간 수\n(같은 곳을 여러 번 방문해도 1곳으로 계산)',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryColor),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor(level.level);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: levelColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: levelColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                level.level == 0 ? '문화 레벨' : level.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: levelColor,
                ),
              ),
              // M9-3: ⓘ 아이콘 — 탭 시 레벨 안내 다이얼로그
              GestureDetector(
                onTap: () => _showLevelGuide(context),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: levelColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                level.progressLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          if (level.level > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: level.progressRatio,
                backgroundColor: AppTheme.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                minHeight: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _levelColor(int level) {
    switch (level) {
      case 1: return const Color(0xFF66BB6A); // 초록
      case 2: return const Color(0xFF42A5F5); // 파랑
      case 3: return const Color(0xFFAB47BC); // 보라
      case 4: return const Color(0xFFFF7043); // 주황
      case 5: return const Color(0xFFFFB300); // 앰버
      case 6: return const Color(0xFFE53935); // 빨강
      default: return AppTheme.textSecondaryColor;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 통계 카드 위젯
// ─────────────────────────────────────────────────────────────────────────────
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
    return Container(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 지역 바 위젯
// ─────────────────────────────────────────────────────────────────────────────
class _RegionBar extends StatelessWidget {
  final List<MapEntry<String, int>> topRegions;

  const _RegionBar({required this.topRegions});

  @override
  Widget build(BuildContext context) {
    if (topRegions.isEmpty) return const SizedBox.shrink();
    final total = topRegions.fold<int>(0, (sum, e) => sum + e.value);
    if (total == 0) return const SizedBox.shrink();
    final validRegions = topRegions.where((e) => e.value > 0).toList();
    if (validRegions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '지역별 방문 TOP 3',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...validRegions.map((entry) {
          final ratio = entry.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// §1: 북마크한 공간 섹션 (명칭 변경: 박물관 → 공간)
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
                '북마크한 공간',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              bookmarkedAsync.when(
                data: (museums) => museums.isNotEmpty
                    ? GestureDetector(
                        onTap: () => context.push('/mypage/bookmarks'),
                        child: Row(
                          children: [
                            Text(
                              '전체 ${museums.length}개',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                          ],
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
                      '가보고 싶은 공간을 북마크해 보세요.',
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
              // 최대 3개만 미리보기로 표시
              final previewMuseums = museums.take(3).toList();
              return Column(
                children: previewMuseums
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
// §1: 내 활동 섹션 (내가 쓴 리뷰 / 알림 / 문의·건의 / 설정·계정)
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
            icon: Icons.rate_review_outlined,
            label: '내가 쓴 리뷰',
            onTap: () => context.push(AppRoutes.myReviews),
          ),
          Divider(height: 1, indent: 56, color: AppTheme.dividerColor),
          _MenuItem(
            icon: Icons.notifications_outlined,
            label: '알림',
            onTap: () => context.push(AppRoutes.notifications),
          ),
          Divider(height: 1, indent: 56, color: AppTheme.dividerColor),
          _MenuItem(
            icon: Icons.feedback_outlined,
            label: '문의 / 건의',
            onTap: () => context.push(AppRoutes.feedback),
          ),
          Divider(height: 1, indent: 56, color: AppTheme.dividerColor),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: '설정 / 계정',
            onTap: () => _showSettingsSheet(context, ref),
          ),
        ],
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

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: Icon(Icons.chevron_right, size: 20, color: AppTheme.textSecondaryColor),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 설정 Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSheet extends ConsumerStatefulWidget {
  final WidgetRef outerRef;

  const _SettingsSheet({required WidgetRef ref}) : outerRef = ref;

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = 'v${info.version}');
    });
  }

  // M8-2: 1차 경고 모달
  Future<bool> _showFirstWarning(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정을 삭제하시겠어요?'),
        content: const Text(
          '계정을 삭제하면 방문기록, 북마크, 리뷰, 댓글, 문의 내역이\n'
          '함께 삭제되며 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('계속', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
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
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('앱 정보'),
              trailing: Text(
                _appVersion.isEmpty ? 'v...' : _appVersion, // M8-3: 동적 버전
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
            const Divider(height: 1),
            // M8-2: 계정 삭제 메뉴 (가장 하단, 빨간색)
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: AppTheme.errorColor),
              title: Text(
                '계정 삭제',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              onTap: () async {
                // fix(M8): 시트를 닫기 전에 다이얼로그를 먼저 실행해야
                // context가 유효한 상태에서 다이얼로그를 호출해야 함
                // async gap 전 ScaffoldMessenger 미리 캡청 (use_build_context_synchronously 해소)
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                // 시트 닫기 전 1차 모달
                final first = await _showFirstWarning(context);
                if (!first) return;
                if (!mounted) return;
                // 1차 모달 통과 후 2차 모달
                // 두 번째 async gap 전 context 기반 호출을 피하기 위해
                // _showFinalConfirm에 context 대신 navigator를 사용
                final final_ = await showDialog<bool>(
                  context: navigator.context,
                  barrierDismissible: false,
                  builder: (ctx) => const _DeleteConfirmDialog(),
                );
                if (final_ != true) return;
                // 모달 확인 후 시트 닫기
                navigator.pop();

                // RPC 호출 + signOut
                try {
                  await ref.read(authNotifierProvider.notifier).deleteAccount();
                  // 라우터가 signedOut 이벤트를 감지하여 /login으로 자동 리다이렉트
                  messenger.showSnackBar(
                    const SnackBar(content: Text('계정이 삭제되었습니다.')),
                  );
                } catch (e) {
                  final msg = e.toString().contains('네트워크')
                      ? '네트워크 연결을 확인해 주세요'
                      : '계정 삭제 중 오류가 발생했습니다. 문의를 통해 알려주세요';
                  messenger.showSnackBar(SnackBar(content: Text(msg)));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// M8-2: 2차 최종 확인 다이얼로그 (체크박스 포함)
class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog();

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('정말 삭제하시겠어요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이 작업은 되돌릴 수 없습니다.'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                activeColor: AppTheme.errorColor,
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    '위 내용을 모두 이해했으며 계정 삭제에 동의합니다.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _agreed ? () => Navigator.pop(context, true) : null,
          child: Text(
            '삭제',
            style: TextStyle(
              color: _agreed ? AppTheme.errorColor : AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
