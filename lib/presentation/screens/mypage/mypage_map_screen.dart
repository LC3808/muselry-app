import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/museum.dart';
import '../../providers/bookmark_provider.dart';
import '../../providers/museum_provider.dart';
import '../../providers/visit_provider.dart';

// ─── 색상 상수 ────────────────────────────────────────────────────────────────
const _kVisitedColor = Color(0xFFE8A87C); // 방문 마커 (진한 주황)
const _kBookmarkColor = Color(0xFF90CAF9); // 북마크 마커 (연한 파랑)
const _kDefaultColor = Color(0xFFBDBDBD); // 미방문 마커 (회색)
const _kVisitedTintColor = Color(0xFFD4622A); // 방문 마커 틴트
const _kBookmarkTintColor = Color(0xFF1565C0); // 북마크 마커 틴트

// ─── 필터 열거형 ──────────────────────────────────────────────────────────────
enum _MapFilter { all, visited, bookmarked }

// ─── 기간 필터 ────────────────────────────────────────────────────────────────
enum _PeriodFilter { all, thisMonth, thisYear }

/// 마이페이지 내 "내가 다녀온 박물관 지도" 전체 화면.
///
/// v1.6 신규 기능:
/// - 방문(진한색) / 북마크(연한색) / 미방문(회색) 마커 색상 분리
/// - 방문 횟수에 따른 마커 크기 차등 (최대 3배)
/// - 마커 클러스터링 (NClusterableMarker + NaverMapClusteringOptions)
/// - 필터: 전체/방문/북마크, 기간별
/// - 통계 오버레이: 총 방문 수, 이번 달 방문, 가장 많이 방문한 지역
/// - 클릭 인터랙션: 방문 마커 → 방문 기록 표시, 미방문 → 박물관 정보
class MypageMapScreen extends ConsumerStatefulWidget {
  const MypageMapScreen({super.key});

  @override
  ConsumerState<MypageMapScreen> createState() => _MypageMapScreenState();
}

class _MypageMapScreenState extends ConsumerState<MypageMapScreen> {
  NaverMapController? _mapController;

  // 필터 상태
  _MapFilter _filter = _MapFilter.all;
  _PeriodFilter _periodFilter = _PeriodFilter.all;
  String? _typeFilter; // null = 전체

  // 통계 오버레이 표시 여부
  bool _showStats = true;

  // 선택된 박물관 정보 패널
  Museum? _selectedMuseum;
  int _selectedVisitCount = 0;

  @override
  void initState() {
    super.initState();
    // v1.9 이슈 4: 데이터 변경 감지 리스너 등록
    // build() 안에서 addPostFrameCallback를 매 프레임 등록하는 패턴 제거
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(mapMuseumsProvider, (_, __) => _maybeRefreshMarkers());
      ref.listenManual(myVisitsProvider, (_, __) => _maybeRefreshMarkers());
      ref.listenManual(bookmarkedIdsProvider, (_, __) => _maybeRefreshMarkers());
    });
  }

  @override
  void dispose() {
    // dispose 시 controller 참조 해제 — 늦게 도착한 async 작업이 무효화된 controller를 건드리지 않도록
    _mapController = null;
    super.dispose();
  }

  /// 지도가 준비된 경우에만 마커 갱신 (이슈 4 픽스)
  void _maybeRefreshMarkers() {
    if (_mapController == null || !mounted) return;
    final museums = ref.read(mapMuseumsProvider).valueOrNull;
    if (museums == null) return;
    final visits = ref.read(myVisitsProvider).valueOrNull ?? [];
    final bookmarkedIds = ref.read(bookmarkedIdsProvider);
    final visitedIds = ref.read(visitedMuseumIdsProvider);
    final visitCountMap = <String, int>{};
    for (final v in visits) {
      visitCountMap[v.museumId] = (visitCountMap[v.museumId] ?? 0) + 1;
    }
    final filteredVisitIds = _buildFilteredVisitIds(visits);
    _refreshMarkers(
      museums: museums,
      visitedIds: visitedIds,
      filteredVisitIds: filteredVisitIds,
      bookmarkedIds: bookmarkedIds,
      visitCountMap: visitCountMap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final museumsAsync = ref.watch(mapMuseumsProvider);
    final visits = ref.watch(myVisitsProvider).valueOrNull ?? [];
    final bookmarkedIds = ref.watch(bookmarkedIdsProvider);
    final visitedIds = ref.watch(visitedMuseumIdsProvider);

    // 방문 횟수 맵 (museumId → count)
    final visitCountMap = <String, int>{};
    for (final v in visits) {
      visitCountMap[v.museumId] = (visitCountMap[v.museumId] ?? 0) + 1;
    }

    // 기간 필터 적용 방문 집합
    final filteredVisitIds = _buildFilteredVisitIds(visits);

    // 통계 계산
    final stats = _buildStats(visits, visitedIds);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '내가 다녀온 박물관 지도',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          // 통계 오버레이 토글
          IconButton(
            icon: Icon(
              _showStats ? Icons.bar_chart : Icons.bar_chart_outlined,
              color: _showStats ? AppTheme.primaryColor : null,
            ),
            tooltip: '통계 표시',
            onPressed: () => setState(() => _showStats = !_showStats),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 지도
          museumsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(
              onRetry: () => ref.invalidate(mapMuseumsProvider),
            ),
            data: (museums) {
              // v1.9 이슈 4: build() 내 addPostFrameCallback 제거
              // 마커 갱신은 onMapReady + listenManual에서만 수행
              return NaverMap(
                options: const NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: NLatLng(36.5, 127.8), // 한국 중심
                    zoom: 6.5,
                  ),
                  minZoom: 5,
                  maxZoom: 18,
                  mapType: NMapType.basic,
                  activeLayerGroups: [
                    NLayerGroup.building,
                    NLayerGroup.transit,
                  ],
                ),
                clusterOptions: NaverMapClusteringOptions(
                  enableZoomRange: const NInclusiveRange(0, 14),
                  clusterMarkerBuilder: _buildClusterMarker,
                ),
                onMapReady: (controller) {
                  _mapController = controller;
                  _refreshMarkers(
                    museums: museums,
                    visitedIds: visitedIds,
                    filteredVisitIds: filteredVisitIds,
                    bookmarkedIds: bookmarkedIds,
                    visitCountMap: visitCountMap,
                  );
                },
              );
            },
          ),

          // 상단 필터 바
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _FilterBar(
              filter: _filter,
              periodFilter: _periodFilter,
              typeFilter: _typeFilter,
              onFilterChanged: (f) {
                setState(() {
                  _filter = f;
                });
              },
              onPeriodChanged: (p) {
                setState(() {
                  _periodFilter = p;
                });
              },
              onTypeChanged: (t) {
                setState(() {
                  _typeFilter = t;
                });
              },
            ),
          ),

          // 통계 오버레이
          if (_showStats)
            Positioned(
              bottom: _selectedMuseum != null ? 200 : 24,
              left: 16,
              right: 16,
              child: _StatsOverlay(stats: stats),
            ),

          // 선택된 박물관 정보 패널
          if (_selectedMuseum != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _MuseumInfoPanel(
                museum: _selectedMuseum!,
                visitCount: _selectedVisitCount,
                isVisited: visitedIds.contains(_selectedMuseum!.id),
                isBookmarked: bookmarkedIds.contains(_selectedMuseum!.id),
                onClose: () => setState(() => _selectedMuseum = null),
                onNavigate: () {
                  setState(() => _selectedMuseum = null);
                  context.push('/museum/${_selectedMuseum!.id}');
                },
              ),
            ),

          // 범례
          Positioned(
            top: 80,
            right: 16,
            child: const _MapLegend(),
          ),
        ],
      ),
    );
  }

  // ── 마커 갱신 ──────────────────────────────────────────────────────────────

  Future<void> _refreshMarkers({
    required List<Museum> museums,
    required Set<String> visitedIds,
    required Set<String> filteredVisitIds,
    required Set<String> bookmarkedIds,
    required Map<String, int> visitCountMap,
  }) async {
        if (_mapController == null) return;
    // 기존 마커 제거
    // clearOverlays는 try-catch로 방어 처리
    // 빈 overlay 상태에서 호출하면 flutter_naver_map에서 PlatformException이 발생할 수 있음
    try {
      await _mapController!.clearOverlays();
    } catch (e) {
      debugPrint('[MypageMap] clearOverlays failed ignored: $e');
    }
    final Set<NClusterableMarker> markers = {};

    for (final museum in museums) {
      if (museum.latitude == null || museum.longitude == null) continue;

      final isVisited = filteredVisitIds.contains(museum.id);
      final isBookmarked = bookmarkedIds.contains(museum.id);

      // 필터 적용
      if (_filter == _MapFilter.visited && !isVisited) continue;
      if (_filter == _MapFilter.bookmarked && !isBookmarked) continue;
      if (_typeFilter != null && museum.type != _typeFilter) continue;

      final visitCount = visitCountMap[museum.id] ?? 0;

      // 마커 크기 (방문 횟수 기반: 1회=24, 2회=30, 3회+=36)
      final markerSize = isVisited
          ? NSize(
              (24 + (visitCount.clamp(1, 3) - 1) * 6).toDouble(),
              (24 + (visitCount.clamp(1, 3) - 1) * 6).toDouble(),
            )
          : const NSize(20, 20);

      // 마커 색상
      final Color tintColor;
      if (isVisited) {
        tintColor = _kVisitedTintColor;
      } else if (isBookmarked) {
        tintColor = _kBookmarkTintColor;
      } else {
        tintColor = _kDefaultColor;
      }

      // 태그 (클러스터 구분용)
      final tag = isVisited
          ? 'visited'
          : (isBookmarked ? 'bookmarked' : 'default');

      final marker = NClusterableMarker(
        id: museum.id,
        position: NLatLng(museum.latitude!, museum.longitude!),
        iconTintColor: tintColor,
        size: markerSize,
        tags: {'type': tag, 'museumId': museum.id},
        caption: isVisited && visitCount > 1
            ? NOverlayCaption(
                text: '×$visitCount',
                color: _kVisitedTintColor,
                haloColor: Colors.white,
                textSize: 10,
              )
            : null,
      );

      // 클릭 이벤트
      marker.setOnTapListener((overlay) {
        final tappedMuseum =
            museums.firstWhere((m) => m.id == museum.id);
        setState(() {
          _selectedMuseum = tappedMuseum;
          _selectedVisitCount = visitCount;
        });
      });

      markers.add(marker);
    }

    if (_mapController != null) {
      try {
        await _mapController!.addOverlayAll(markers);
      } catch (e) {
        debugPrint('[MypageMap] addOverlayAll failed ignored: $e');
      }
    }
  }

  // ── 클러스터 마커 빌더 ─────────────────────────────────────────────────────

  static void _buildClusterMarker(
      NClusterInfo info, NClusterMarker clusterMarker) {
    // 클러스터 내 방문 마커 수 계산
    final visitedCount = info.children
        .whereType<NClusterableMarkerInfo>()
        .where((c) => c.tags['type'] == 'visited')
        .length;
    final hasVisited = visitedCount > 0;

    final color = hasVisited ? _kVisitedTintColor : _kBookmarkTintColor;
    final size = (32 + (info.size / 10).clamp(0, 20)).toDouble();

    clusterMarker
      ..setSize(NSize(size, size))
      ..setIconTintColor(color)
      ..setCaption(NOverlayCaption(
        text: info.size.toString(),
        color: Colors.white,
        haloColor: Colors.transparent,
        textSize: 12,
      ));
  }

  // ── 기간 필터 적용 방문 집합 ───────────────────────────────────────────────

  Set<String> _buildFilteredVisitIds(List visits) {
    final now = DateTime.now();
    return visits.where((v) {
      switch (_periodFilter) {
        case _PeriodFilter.all:
          return true;
        case _PeriodFilter.thisMonth:
          return v.visitedAt.year == now.year &&
              v.visitedAt.month == now.month;
        case _PeriodFilter.thisYear:
          return v.visitedAt.year == now.year;
      }
    }).map<String>((v) => v.museumId as String).toSet();
  }

  // ── 통계 계산 ──────────────────────────────────────────────────────────────

  _MapStats _buildStats(List visits, Set<String> visitedIds) {
    final now = DateTime.now();
    final thisMonthVisits = visits
        .where((v) =>
            v.visitedAt.year == now.year && v.visitedAt.month == now.month)
        .length;

    // 가장 많이 방문한 지역
    final regionCount = <String, int>{};
    for (final v in visits) {
      if (v.museum != null) {
        final r = v.museum!.region1;
        if (r.isNotEmpty) regionCount[r] = (regionCount[r] ?? 0) + 1;
      }
    }
    final topRegion = regionCount.isEmpty
        ? null
        : regionCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return _MapStats(
      totalVisitedMuseums: visitedIds.length,
      totalVisits: visits.length,
      thisMonthVisits: thisMonthVisits,
      topRegion: topRegion,
    );
  }
}

// ─── 통계 데이터 클래스 ────────────────────────────────────────────────────────

class _MapStats {
  final int totalVisitedMuseums;
  final int totalVisits;
  final int thisMonthVisits;
  final String? topRegion;

  const _MapStats({
    required this.totalVisitedMuseums,
    required this.totalVisits,
    required this.thisMonthVisits,
    required this.topRegion,
  });
}

// ─── 필터 바 ──────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final _MapFilter filter;
  final _PeriodFilter periodFilter;
  final String? typeFilter;
  final ValueChanged<_MapFilter> onFilterChanged;
  final ValueChanged<_PeriodFilter> onPeriodChanged;
  final ValueChanged<String?> onTypeChanged;

  const _FilterBar({
    required this.filter,
    required this.periodFilter,
    required this.typeFilter,
    required this.onFilterChanged,
    required this.onPeriodChanged,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 주 필터 (전체/방문/북마크)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: '전체',
                selected: filter == _MapFilter.all,
                onTap: () => onFilterChanged(_MapFilter.all),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: '방문',
                selected: filter == _MapFilter.visited,
                color: _kVisitedTintColor,
                onTap: () => onFilterChanged(_MapFilter.visited),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: '북마크',
                selected: filter == _MapFilter.bookmarked,
                color: _kBookmarkTintColor,
                onTap: () => onFilterChanged(_MapFilter.bookmarked),
              ),
              const SizedBox(width: 12),
              // 기간 필터
              _FilterChip(
                label: '전기간',
                selected: periodFilter == _PeriodFilter.all,
                onTap: () => onPeriodChanged(_PeriodFilter.all),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: '이번 달',
                selected: periodFilter == _PeriodFilter.thisMonth,
                onTap: () => onPeriodChanged(_PeriodFilter.thisMonth),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: '올해',
                selected: periodFilter == _PeriodFilter.thisYear,
                onTap: () => onPeriodChanged(_PeriodFilter.thisYear),
              ),
              const SizedBox(width: 12),
              // 유형 필터
              _FilterChip(
                label: '유형 전체',
                selected: typeFilter == null,
                onTap: () => onTypeChanged(null),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: '박물관',
                selected: typeFilter == '박물관',
                onTap: () => onTypeChanged(typeFilter == '박물관' ? null : '박물관'),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: '미술관',
                selected: typeFilter == '미술관',
                onTap: () => onTypeChanged(typeFilter == '미술관' ? null : '미술관'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppTheme.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textPrimaryColor,
          ),
        ),
      ),
    );
  }
}

// ─── 통계 오버레이 ─────────────────────────────────────────────────────────────

class _StatsOverlay extends StatelessWidget {
  final _MapStats stats;

  const _StatsOverlay({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.place,
            label: '방문 박물관',
            value: '${stats.totalVisitedMuseums}곳',
            color: _kVisitedTintColor,
          ),
          _StatDivider(),
          _StatItem(
            icon: Icons.history,
            label: '총 방문',
            value: '${stats.totalVisits}회',
            color: AppTheme.primaryColor,
          ),
          _StatDivider(),
          _StatItem(
            icon: Icons.calendar_today,
            label: '이번 달',
            value: '${stats.thisMonthVisits}회',
            color: Colors.blue.shade600,
          ),
          if (stats.topRegion != null) ...[
            _StatDivider(),
            _StatItem(
              icon: Icons.location_on,
              label: '최다 방문',
              value: stats.topRegion!,
              color: Colors.green.shade600,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
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
        Icon(icon, size: 16, color: color),
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
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppTheme.dividerColor,
    );
  }
}

// ─── 박물관 정보 패널 ──────────────────────────────────────────────────────────

class _MuseumInfoPanel extends StatelessWidget {
  final Museum museum;
  final int visitCount;
  final bool isVisited;
  final bool isBookmarked;
  final VoidCallback onClose;
  final VoidCallback onNavigate;

  const _MuseumInfoPanel({
    required this.museum,
    required this.visitCount,
    required this.isVisited,
    required this.isBookmarked,
    required this.onClose,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들 + 닫기
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: AppTheme.textSecondaryColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 박물관 이름 + 유형 배지
          Row(
            children: [
              Expanded(
                child: Text(
                  museum.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _TypeBadge(type: museum.type),
            ],
          ),
          const SizedBox(height: 6),
          // 지역
          if (museum.region1.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppTheme.textSecondaryColor),
                const SizedBox(width: 4),
                Text(
                  '${museum.region1} ${museum.region2}'.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          // 방문 상태 행
          Row(
            children: [
              if (isVisited) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kVisitedColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 14, color: _kVisitedTintColor),
                      const SizedBox(width: 4),
                      Text(
                        '$visitCount회 방문',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kVisitedTintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isBookmarked)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kBookmarkColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bookmark,
                          size: 14, color: _kBookmarkTintColor),
                      SizedBox(width: 4),
                      Text(
                        '북마크',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kBookmarkTintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              // 상세 보기 버튼
              ElevatedButton.icon(
                onPressed: () {
                  context.push('/museum/${museum.id}');
                },
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('상세 보기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == '미술관' ? Colors.purple.shade400 : _kVisitedTintColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── 범례 ─────────────────────────────────────────────────────────────────────

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendItem(color: _kVisitedTintColor, label: '방문'),
          SizedBox(height: 4),
          _LegendItem(color: _kBookmarkTintColor, label: '북마크'),
          SizedBox(height: 4),
          _LegendItem(color: _kDefaultColor, label: '미방문'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── 오류 상태 ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            '지도를 불러오지 못했습니다.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
