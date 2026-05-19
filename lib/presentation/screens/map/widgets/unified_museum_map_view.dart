import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../../domain/models/museum.dart';

// ─── 지도 모드 ────────────────────────────────────────────────────────────────

/// 공통 지도 컴포넌트의 표시 모드.
///
/// - [explore]: 지도 탭 — 전체 박물관을 유형별 색상으로 표시
/// - [myMap]: 마이페이지 — 방문/북마크/미방문 상태별 색상으로 표시
enum MuseumMapMode { explore, myMap }

// ─── 색상 상수 ────────────────────────────────────────────────────────────────

const _kNavy = Color(0xFF2C3E50);
const _kGold = Color(0xFFB8860B);

// explore 모드 유형별 색상
Color _exploreTypeColor(String? type) {
  switch (type) {
    case '박물관':
      return _kGold;
    case '미술관':
      return const Color(0xFF7C4DFF);
    case '기념관':
      return const Color(0xFF00897B);
    case '전시관':
      return const Color(0xFF1565C0);
    case '과학관':
      return const Color(0xFFE65100);
    default:
      return _kNavy;
  }
}

// myMap 모드 상태별 색상
const _kVisitedTintColor = Color(0xFFD4622A);
const _kBookmarkTintColor = Color(0xFF1565C0);
const _kDefaultColor = Color(0xFFBDBDBD);

// ─── 마커 클릭 콜백 타입 ──────────────────────────────────────────────────────

typedef OnMuseumTap = void Function(Museum museum, int visitCount);

// ─── 공통 지도 컴포넌트 ────────────────────────────────────────────────────────

/// NaverMap overlay 관리를 단일 컴포넌트로 통합한 공통 지도 위젯.
///
/// ## 설계 원칙
/// 1. [NaverMapController]는 이 위젯 내부에서만 생성·관리한다.
/// 2. clearOverlays / addOverlayAll 호출은 이 위젯 내부에서만 수행한다.
/// 3. 상위 화면(map_screen, mypage_map_screen)은 데이터를 props로 전달하기만 한다.
/// 4. dispose 이후 overlay 작업은 [_disposed] 플래그로 차단한다.
/// 5. onMapReady 이후에만 marker sync가 실행된다.
/// 6. marker sync 중복 실행은 [_isSyncing] 플래그로 방지한다.
/// 7. clearOverlays / addOverlayAll은 try-catch로 방어한다.
class UnifiedMuseumMapView extends StatefulWidget {
  final MuseumMapMode mode;
  final List<Museum> museums;
  final Set<String> visitedIds;
  final Set<String> bookmarkedIds;
  final Map<String, int> visitCountMap;

  /// explore 모드: 마커 클릭 시 호출
  final OnMuseumTap? onMuseumTap;

  /// myMap 모드: 마커 클릭 시 호출 (방문 횟수 포함)
  final OnMuseumTap? onMarkerTap;

  /// myMap 모드: 현재 활성 필터 (전체/방문/북마크)
  final String? activeFilter; // 'all' | 'visited' | 'bookmarked'

  /// myMap 모드: 현재 기간 필터 적용 방문 집합
  final Set<String>? filteredVisitIds;

  /// myMap 모드: 유형 필터 (null = 전체)
  final String? typeFilter;

  /// 지도 초기 카메라 위치
  final NLatLng initialTarget;
  final double initialZoom;

  const UnifiedMuseumMapView({
    super.key,
    required this.mode,
    required this.museums,
    required this.visitedIds,
    required this.bookmarkedIds,
    this.visitCountMap = const {},
    this.onMuseumTap,
    this.onMarkerTap,
    this.activeFilter,
    this.filteredVisitIds,
    this.typeFilter,
    this.initialTarget = const NLatLng(36.5, 127.8),
    this.initialZoom = 6.5,
  });

  @override
  State<UnifiedMuseumMapView> createState() => _UnifiedMuseumMapViewState();
}

class _UnifiedMuseumMapViewState extends State<UnifiedMuseumMapView> {
  NaverMapController? _controller;
  bool _mapReady = false;
  bool _disposed = false;
  bool _isSyncing = false;

  // 마지막으로 그린 데이터 시그니처 (중복 sync 방지)
  String _lastSyncKey = '';

  @override
  void dispose() {
    _disposed = true;
    _controller = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(UnifiedMuseumMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapReady) {
      _scheduleMarkerSync();
    }
  }

  void _onMapReady(NaverMapController controller) {
    if (_disposed) return;
    _controller = controller;
    _mapReady = true;
    _scheduleMarkerSync();
  }

  /// 다음 프레임에 marker sync를 예약한다.
  /// 중복 sync는 [_isSyncing] 플래그로 방지한다.
  void _scheduleMarkerSync() {
    if (_disposed || !_mapReady) return;
    final key = _buildSyncKey();
    if (key == _lastSyncKey) return; // 데이터 변경 없으면 skip
    _syncMarkers();
  }

  /// 현재 props 기반 sync key 생성 (중복 실행 방지용)
  String _buildSyncKey() {
    return '${widget.mode.name}'
        '|${widget.museums.length}'
        '|${widget.visitedIds.length}'
        '|${widget.bookmarkedIds.length}'
        '|${widget.activeFilter}'
        '|${widget.typeFilter}'
        '|${widget.filteredVisitIds?.length}';
  }

  Future<void> _syncMarkers() async {
    if (_disposed || !_mapReady || _controller == null) return;
    if (_isSyncing) return;

    _isSyncing = true;
    final key = _buildSyncKey();

    try {
      // 기존 overlay 제거
      await _controller!.clearOverlays();
    } catch (_) {
      // overlay가 null이거나 이미 제거된 경우 무시
    }

    if (_disposed || _controller == null) {
      _isSyncing = false;
      return;
    }

    try {
      if (widget.mode == MuseumMapMode.explore) {
        final markers = _buildExploreMarkers();
        if (markers.isNotEmpty && !_disposed && _controller != null) {
          await _controller!.addOverlayAll(markers);
        }
      } else {
        final markers = _buildMyMapMarkers();
        if (markers.isNotEmpty && !_disposed && _controller != null) {
          await _controller!.addOverlayAll(markers);
        }
      }
      _lastSyncKey = key;
    } catch (_) {
      // overlay 추가 실패 시 무시 (lifecycle 문제)
    } finally {
      _isSyncing = false;
    }
  }

  // ── explore 모드 마커 ────────────────────────────────────────────────────────

  Set<NAddableOverlay> _buildExploreMarkers() {
    final Set<NAddableOverlay> markers = {};
    for (final museum in widget.museums) {
      if (museum.latitude == null || museum.longitude == null) continue;

      final color = _exploreTypeColor(museum.type);
      final marker = NMarker(
        id: museum.id,
        position: NLatLng(museum.latitude!, museum.longitude!),
        caption: NOverlayCaption(
          text: museum.name,
          textSize: 10,
          color: _kNavy,
          haloColor: Colors.white,
        ),
        iconTintColor: color,
        size: const Size(24, 24),
      );

      marker.setOnTapListener((_) {
        widget.onMuseumTap?.call(museum, 0);
      });

      markers.add(marker);
    }
    return markers;
  }

  // ── myMap 모드 마커 ──────────────────────────────────────────────────────────

  Set<NAddableOverlay> _buildMyMapMarkers() {
    final Set<NAddableOverlay> markers = {};
    final filteredVisitIds =
        widget.filteredVisitIds ?? widget.visitedIds;

    for (final museum in widget.museums) {
      if (museum.latitude == null || museum.longitude == null) continue;

      final isVisited = filteredVisitIds.contains(museum.id);
      final isBookmarked = widget.bookmarkedIds.contains(museum.id);

      // 필터 적용
      if (widget.activeFilter == 'visited' && !isVisited) continue;
      if (widget.activeFilter == 'bookmarked' && !isBookmarked) continue;
      if (widget.typeFilter != null && museum.type != widget.typeFilter) {
        continue;
      }

      final visitCount = widget.visitCountMap[museum.id] ?? 0;

      // 마커 크기 (방문 횟수 기반)
      final markerSize = isVisited
          ? NSize(
              (24 + (visitCount.clamp(1, 3) - 1) * 6).toDouble(),
              (24 + (visitCount.clamp(1, 3) - 1) * 6).toDouble(),
            )
          : const NSize(20, 20);

      // 마커 색상 (visited > bookmarked > unvisited)
      final Color tintColor;
      if (isVisited) {
        tintColor = _kVisitedTintColor;
      } else if (isBookmarked) {
        tintColor = _kBookmarkTintColor;
      } else {
        tintColor = _kDefaultColor;
      }

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

      marker.setOnTapListener((_) {
        widget.onMarkerTap?.call(museum, visitCount);
      });

      markers.add(marker);
    }
    return markers;
  }

  // ── 클러스터 마커 빌더 ────────────────────────────────────────────────────────

  static void _buildClusterMarker(
      NClusterInfo info, NClusterMarker clusterMarker) {
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

  @override
  Widget build(BuildContext context) {
    // myMap 모드에서만 클러스터링 옵션 적용
    final clusterOptions = widget.mode == MuseumMapMode.myMap
        ? NaverMapClusteringOptions(
            enableZoomRange: const NInclusiveRange(0, 14),
            clusterMarkerBuilder: _buildClusterMarker,
          )
        : const NaverMapClusteringOptions(
            enableZoomRange: NInclusiveRange(20, 20), // 사실상 비활성화
          );

    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: widget.initialTarget,
          zoom: widget.initialZoom,
        ),
        minZoom: 5,
        maxZoom: 18,
        mapType: NMapType.basic,
        locationButtonEnable: widget.mode == MuseumMapMode.explore,
        consumeSymbolTapEvents: false,
        activeLayerGroups: const [
          NLayerGroup.building,
          NLayerGroup.transit,
        ],
      ),
      clusterOptions: clusterOptions,
      onMapReady: _onMapReady,
    );
  }
}
