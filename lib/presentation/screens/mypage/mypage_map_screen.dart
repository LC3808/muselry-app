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
// M7-G-2 확정 (2026-06-13): 운영자 확정 색상 적용
// 방문 = Orange 700 (#F57C00) — 뮤즐리 메인 주황
// 북마크 = Light Blue 400 (#29B6F6) — 차가운 하늘
// 칩·범례·통계·바텀시트 모두 아래 상수 자동 참조
const _kVisitedTintColor = Color(0xFFF57C00); // Orange 700 — 방문 마커/칩/범례
const _kBookmarkTintColor = Color(0xFF29B6F6); // Light Blue 400 — 북마크 마커/칩/범례
const _kDefaultColor = Color(0xFFBDBDBD); // 미방문 마커 (회색)

// 유형별 색상 (탐색 지도 type 색상과 1:1 일치 — _TypeBadge 전용)
const _kMuseumTypeColor = Color(0xFF388E3C); // 박물관 — 초록
const _kGalleryTypeColor = Color(0xFFFFB300); // 미술관 — 앰버
const _kScienceTypeColor = Color(0xFFD32F2F); // 과학관 — 빨강

// ─── 필터 열거형 ──────────────────────────────────────────────────────────────
enum _MapFilter { all, visited, bookmarked }

// ─── 기간 필터 ────────────────────────────────────────────────────────────────
enum _PeriodFilter { all, thisMonth, thisYear }

/// 마이페이지 내 "내가 다녀온 박물관 지도" 전체 화면.
///
/// T3 안정화 (fix/t3-map-clear-overlays-minimal):
/// - visibleMuseums 필터: 방문 + 북마크만 마커 표시 (413개 전체 → 소수)
/// - NClusterableMarker → NMarker (clustering 임시 비활성화)
/// - clusterOptions 제거 (NaverMap native overlay race condition 해소)
/// - 지역별 진행률 카드 추가 (미방문 인식 UX 대체)
/// - 빈 상태 안내 추가
class MypageMapScreen extends ConsumerStatefulWidget {
  const MypageMapScreen({super.key});

  @override
  ConsumerState<MypageMapScreen> createState() => _MypageMapScreenState();
}

class _MypageMapScreenState extends ConsumerState<MypageMapScreen> {
  NaverMapController? _mapController;

  // M7-C: 커스텀 마커 아이콘 캐시 (key → NOverlayImage?)
  final Map<String, NOverlayImage?> _markerIconCache = {};

  // lifecycle guard
  bool _isDisposed = false;
  bool _isRefreshingMarkers = false;
  int _markerRefreshGeneration = 0;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(mapMuseumsProvider, (_, __) => _maybeRefreshMarkers());
      ref.listenManual(myVisitsProvider, (_, __) => _maybeRefreshMarkers());
      ref.listenManual(bookmarkedIdsProvider, (_, __) => _maybeRefreshMarkers());
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _markerRefreshGeneration++;
    _mapController = null;
    super.dispose();
  }

  /// 지도가 준비된 경우에만 마커 갱신
  void _maybeRefreshMarkers() {
    if (_isDisposed || !mounted || _mapController == null) return;
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

    // T3: 지역별 진행률 계산 (미방문 인식 UX)
    final allMuseums = museumsAsync.valueOrNull ?? [];
    final regionStats = <String, _RegionProgress>{};
    for (final museum in allMuseums) {
      final region = museum.region1;
      if (region.isEmpty) continue;
      regionStats.putIfAbsent(region, () => _RegionProgress(region: region));
      regionStats[region]!.totalCount++;
      if (visitedIds.contains(museum.id)) {
        regionStats[region]!.visitedCount++;
      }
    }
    final topRegions = regionStats.values.toList()
      ..sort((a, b) {
        if (a.visitedCount != b.visitedCount) {
          return b.visitedCount.compareTo(a.visitedCount);
        }
        return b.totalCount.compareTo(a.totalCount);
      });
    final topRegionList = topRegions.take(5).toList();
    final totalUnvisited = allMuseums.length - visitedIds.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '나의 문화 지도',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
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
              return NaverMap(
                options: const NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: NLatLng(36.5, 127.8),
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
                // T3 안정화: clusterOptions 제거. T5+ 재도입 예정.
                onMapReady: (controller) {
                  if (_isDisposed || !mounted) return;
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
                setState(() => _filter = f);
                _maybeRefreshMarkers();
              },
              onPeriodChanged: (p) {
                setState(() => _periodFilter = p);
                _maybeRefreshMarkers();
              },
              onTypeChanged: (t) {
                setState(() => _typeFilter = t);
                _maybeRefreshMarkers();
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
          // 지역별 진행률 카드 (T3: 미방문 인식 UX)
          if (totalUnvisited > 0 && topRegionList.isNotEmpty)
            Positioned(
              bottom: _selectedMuseum != null
                  ? 200
                  : (_showStats ? 120 : 24),
              left: 16,
              right: 16,
              child: _RegionProgressCard(
                regions: topRegionList,
                totalUnvisited: totalUnvisited,
              ),
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
                  final id = _selectedMuseum!.id;
                  setState(() => _selectedMuseum = null);
                  context.push('/museum/$id');
                },
              ),
            ),
          // 범례
          Positioned(
            top: 80,
            right: 16,
            child: const _MapLegend(),
          ),
          // 빈 상태 안내 (방문 0건 + 북마크 0건)
          if (visitedIds.isEmpty && bookmarkedIds.isEmpty)
            Positioned(
              top: 200,
              left: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined,
                        size: 32, color: AppTheme.textSecondaryColor),
                    const SizedBox(height: 8),
                    const Text(
                      '아직 기록된 공간이 없어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '방문한 공간을 기록하면 나만의 문화지도가 만들어져요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
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
    if (_isDisposed || !mounted || _mapController == null) return;
    if (_isRefreshingMarkers) return;
    final controller = _mapController!;
    final generation = ++_markerRefreshGeneration;
    _isRefreshingMarkers = true;
    try {
      if (_isDisposed ||
          !mounted ||
          _mapController != controller ||
          generation != _markerRefreshGeneration) {
        return;
      }
      try {
        await controller.clearOverlays();
      } catch (e) {
        debugPrint('[MypageMap] clearOverlays failed ignored: $e');
      }
      if (_isDisposed ||
          !mounted ||
          _mapController != controller ||
          generation != _markerRefreshGeneration) {
        return;
      }

      // T3 안정화: 방문 + 북마크만 실제 마커로 표시.
      // 미방문 413개 전체 addOverlayAll → NaverMap native overlay sender race condition.
      // 기획 의도(미방문 인식)는 지역별 진행률 요약 UI로 대체.
      final visibleMuseums = museums.where((museum) {
        final isVisited = visitedIds.contains(museum.id);
        final isBookmarked = bookmarkedIds.contains(museum.id);
        switch (_filter) {
          case _MapFilter.visited:
            return isVisited;
          case _MapFilter.bookmarked:
            return isBookmarked;
          case _MapFilter.all:
            return isVisited || isBookmarked;
        }
      }).toList();
      final Set<NMarker> markers = {};
      for (final museum in visibleMuseums) {
        if (museum.latitude == null || museum.longitude == null) continue;
        final isVisited = filteredVisitIds.contains(museum.id);
        final isBookmarked = bookmarkedIds.contains(museum.id);
        if (_typeFilter != null && museum.type != _typeFilter) continue;
        final visitCount = visitCountMap[museum.id] ?? 0;
        final Color markerColor;
        if (isVisited) {
          markerColor = _kVisitedTintColor;
        } else if (isBookmarked) {
          markerColor = _kBookmarkTintColor;
        } else {
          markerColor = _kDefaultColor;
        }
        // M7-C: NOverlayImage.fromWidget 캐시 방식 (탐색 지도 동일 패턴)
        final cacheKey = isVisited ? 'visited' : (isBookmarked ? 'bookmark' : 'default');
        if (!_markerIconCache.containsKey(cacheKey)) {
          try {
            final icon = await NOverlayImage.fromWidget(
              widget: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              size: const Size(18, 18),
              context: context,
            );
            _markerIconCache[cacheKey] = icon;
          } catch (_) {
            _markerIconCache[cacheKey] = null;
          }
        }
        final cachedIcon = _markerIconCache[cacheKey];
        // M7-G-3: 기본 크기 축소(탐색 지도 동일), 크기 변화 제거, N회 방문은 x배지로
        const markerSize = NSize(18, 18);
        final marker = NMarker(
          id: museum.id,
          position: NLatLng(museum.latitude!, museum.longitude!),
          size: markerSize,
          caption: isVisited && visitCount > 1
              ? NOverlayCaption(
                  text: '×$visitCount',
                  color: _kVisitedTintColor,
                  haloColor: Colors.white,
                  textSize: 10,
                )
              : null,
        );
        if (cachedIcon != null) {
          marker.setIcon(cachedIcon);
        } else {
          marker.setIconTintColor(markerColor);
        }
        marker.setOnTapListener((overlay) {
          final tappedMuseum = museums.firstWhere((m) => m.id == museum.id);
          if (!mounted) return;
          setState(() {
            _selectedMuseum = tappedMuseum;
            _selectedVisitCount = visitCount;
          });
        });
        markers.add(marker);
      }

      if (markers.isEmpty) {
        return;
      }

      if (_isDisposed ||
          !mounted ||
          _mapController != controller ||
          generation != _markerRefreshGeneration) {
        return;
      }
      try {
        await controller.addOverlayAll(markers);
      } catch (e) {
        debugPrint('[MypageMap] addOverlayAll failed ignored: $e');
      }
    } finally {
      if (generation == _markerRefreshGeneration) {
        _isRefreshingMarkers = false;
      }
    }
  }

  // ── 기간 필터 적용 방문 집합 ───────────────────────────────────────────────
  Set<String> _buildFilteredVisitIds(List<dynamic> visits) {
    if (_periodFilter == _PeriodFilter.all) {
      return visits.map<String>((v) => v.museumId as String).toSet();
    }
    final now = DateTime.now();
    return visits.where((v) {
      final date = v.visitedAt as DateTime;
      if (_periodFilter == _PeriodFilter.thisMonth) {
        return date.year == now.year && date.month == now.month;
      } else {
        return date.year == now.year;
      }
    }).map<String>((v) => v.museumId as String).toSet();
  }

  // ── 통계 계산 ──────────────────────────────────────────────────────────────
  _MapStats _buildStats(List<dynamic> visits, Set<String> visitedIds) {
    final now = DateTime.now();
    final thisMonthVisits = visits.where((v) {
      final date = v.visitedAt as DateTime;
      return date.year == now.year && date.month == now.month;
    }).length;
    final regionCount = <String, int>{};
    for (final v in visits) {
      final museum = v.museum;
      if (museum != null) {
        final r = museum.region1 as String;
        if (r.isNotEmpty) {
          regionCount[r] = (regionCount[r] ?? 0) + 1;
        }
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

// ─── 지역별 진행률 데이터 클래스 ──────────────────────────────────────────────
class _RegionProgress {
  final String region;
  int totalCount = 0;
  int visitedCount = 0;

  _RegionProgress({required this.region});

  double get progress =>
      totalCount == 0 ? 0.0 : visitedCount / totalCount;
}

// ─── 지역별 진행률 카드 ────────────────────────────────────────────────────────
class _RegionProgressCard extends StatefulWidget {
  final List<_RegionProgress> regions;
  final int totalUnvisited;

  const _RegionProgressCard({
    required this.regions,
    required this.totalUnvisited,
  });

  @override
  State<_RegionProgressCard> createState() => _RegionProgressCardState();
}

class _RegionProgressCardState extends State<_RegionProgressCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  Icons.explore_outlined,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '아직 ${widget.totalUnvisited}곳이 기다리고 있어요',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppTheme.textSecondaryColor,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            ...widget.regions.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          r.region,
                          style: const TextStyle(
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
                            value: r.progress,
                            backgroundColor: AppTheme.dividerColor,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${r.visitedCount}/${r.totalCount}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
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
    return SingleChildScrollView(
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
          _FilterChip(
            label: '유형 전체',
            selected: typeFilter == null,
            onTap: () => onTypeChanged(null),
          ),
          const SizedBox(width: 6),
          // M7-G-4: 유형 칩에 type 색상 미리보기 적용
          _FilterChip(
            label: '박물관',
            selected: typeFilter == '박물관',
            color: const Color(0xFF388E3C), // 탐색 지도 박물관 색 (초록)
            onTap: () =>
                onTypeChanged(typeFilter == '박물관' ? null : '박물관'),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: '미술관',
            selected: typeFilter == '미술관',
            color: const Color(0xFFFFB300), // 탐색 지도 미술관 색 (앨버)
            onTap: () =>
                onTypeChanged(typeFilter == '미술관' ? null : '미술관'),
          ),
          const SizedBox(width: 6),
          // M7-6 + M7-G-4: 과학관 칩 (유형 색 미리보기)
          _FilterChip(
            label: '과학관',
            selected: typeFilter == '과학관',
            color: const Color(0xFFD32F2F), // 탐색 지도 과학관 색 (빨강)
            onTap: () =>
                onTypeChanged(typeFilter == '과학관' ? null : '과학관'),
          ),
        ],
      ),
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
          border: Border.all(
            color: selected ? activeColor : AppTheme.dividerColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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

// ─── 통계 오버레이 ────────────────────────────────────────────────────────────
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
            label: '방문 공간',
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
          if (museum.region1.isNotEmpty)
            Text(
              '${museum.region1} ${museum.region2}'.trim(),
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isVisited)
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 14, color: _kVisitedTintColor),
                    const SizedBox(width: 4),
                    Text(
                      visitCount > 1 ? '$visitCount회 방문' : '방문 완료',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kVisitedTintColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              if (isBookmarked)
                Padding(
                  padding: EdgeInsets.only(left: isVisited ? 12 : 0),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark,
                          size: 14, color: _kBookmarkTintColor),
                      const SizedBox(width: 4),
                      const Text(
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
              ElevatedButton.icon(
                onPressed: onNavigate,
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
    // M7-G-2: 유형별 고유 색상 (탐색 지도 type 색상과 1:1 일치)
    final color = type == '박물관'
        ? _kMuseumTypeColor
        : type == '미술관'
            ? _kGalleryTypeColor
            : _kScienceTypeColor; // 과학관 (기본)
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
