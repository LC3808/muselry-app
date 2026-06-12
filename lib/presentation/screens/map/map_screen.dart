import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/museum.dart';
import '../../providers/museum_provider.dart';

// 앱 색상 상수
const _kNavy = Color(0xFF2C3E50);

// R14: type별 마커 색상 — 3종 노출(박물관=초록, 미술관=앰버, 과학관=빨강)
// R26: 미술관 파랑(#1565C0) → 앰버(#FFB300) — 지도에서 박물관 초록과 구분 강화
// 기념관/전시관은 예약값으로 상수만 유지, 마커는 미노출
const _kColorMuseum = Color(0xFF388E3C);   // 초록
const _kColorArt    = Color(0xFFFFB300);   // 앰버 (R26)
const _kColorScience = Color(0xFFD32F2F);  // 빨강
const _kColorMemorial = Color(0xFF00897B); // 예약값 (미노출)
const _kColorExhibit  = Color(0xFFB8860B); // 예약값 (미노출)
const _kColorDefault  = _kNavy;

// R14: 지도에 그릴 3종 type 목록
const _kVisibleTypes = {'박물관', '미술관', '과학관'};

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  NaverMapController? _mapController;
  NLatLng _initialPosition = const NLatLng(37.5665, 126.9780);
  int _lastDrawnCount = -1;

  // lifecycle guard
  bool _isDisposed = false;
  bool _isDrawingMarkers = false;
  int _markerDrawGeneration = 0;

  // R14: 실제 그려진 마커 수 (3종 기준)
  int _visibleMarkerCount = 0;

  // M4: 검색 상태
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<Museum> _searchResults = [];
  bool _isSearching = false;
  bool _searchActive = false; // 검색 모드 활성화 여부

  // R9+R10: 패널 표시 여부 (검색어/마커는 유지하면서 패널만 접기)
  bool _panelVisible = true;

  // R4-2: 커스텀 마커 아이콘 캐시 (type → NOverlayImage)
  final Map<String, NOverlayImage?> _markerIconCache = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _markerDrawGeneration++;
    _mapController = null;
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      setState(() => _initialPosition = NLatLng(pos.latitude, pos.longitude));
      _mapController?.updateCamera(
        NCameraUpdate.withParams(target: _initialPosition, zoom: 13),
      );
    } catch (_) {
      // 위치 실패 시 서울 기본값 유지
    }
  }

  // R4-2: type별 커스텀 마커 아이콘 생성 (색상 원형)
  Future<NOverlayImage?> _getMarkerIcon(String? type) async {
    final key = type ?? 'default';
    if (_markerIconCache.containsKey(key)) return _markerIconCache[key];

    final color = _typeColor(type);
    try {
      final icon = await NOverlayImage.fromWidget(
        widget: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
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
      _markerIconCache[key] = icon;
      return icon;
    } catch (_) {
      _markerIconCache[key] = null;
      return null;
    }
  }

  void _onMapReady(NaverMapController controller) {
    if (_isDisposed || !mounted) return;

    _mapController = controller;

    final museumsAsync = ref.read(mapMuseumsProvider);
    museumsAsync.whenData((museums) {
      if (_isDisposed || !mounted || _mapController != controller) return;
      _addMuseumMarkers(museums);
    });
  }

  void _onMuseumsLoaded(List<Museum> museums) {
    if (_isDisposed || !mounted) return;
    if (_mapController == null) return;
    if (_searchActive) return; // 검색 모드 중에는 전체 마커 갱신 안 함

    if (museums.length != _lastDrawnCount) {
      _addMuseumMarkers(museums);
    }
  }

  Future<void> _addMuseumMarkers(List<Museum> museums) async {
    if (_isDisposed || !mounted) return;
    if (_isDrawingMarkers) return;

    final controller = _mapController;
    if (controller == null) return;

    final generation = ++_markerDrawGeneration;
    _isDrawingMarkers = true;

    try {
      if (_isDisposed ||
          !mounted ||
          _mapController != controller ||
          generation != _markerDrawGeneration) {
        return;
      }

      if (_lastDrawnCount > 0) {
        try {
          await controller.clearOverlays();
        } catch (e) {
          debugPrint('[Map] clearOverlays failed ignored: $e');
        }
      }

      if (_isDisposed ||
          !mounted ||
          _mapController != controller ||
          generation != _markerDrawGeneration) {
        return;
      }

      _lastDrawnCount = museums.length;

      if (museums.isEmpty) return;

      final Set<NMarker> markers = {};
      int visibleCount = 0;
      for (final museum in museums) {
        if (museum.latitude == null || museum.longitude == null) continue;
        // R14: 3종(박물관/미술관/과학관)만 마커 그리기
        if (!_kVisibleTypes.contains(museum.type)) continue;

        // R4-2: 커스텀 원형 아이콘 사용
        final icon = await _getMarkerIcon(museum.type);
        if (_isDisposed || !mounted || generation != _markerDrawGeneration) return;

        final markerBuilder = NMarker(
          id: museum.id,
          position: NLatLng(museum.latitude!, museum.longitude!),
          caption: NOverlayCaption(
            text: museum.name,
            textSize: 10,
            color: _kNavy,
            haloColor: Colors.white,
          ),
          size: const Size(18, 18),
        );

        if (icon != null) {
          markerBuilder.setIcon(icon);
        } else {
          markerBuilder.setIconTintColor(_typeColor(museum.type));
        }

        markerBuilder.setOnTapListener((_) {
          context.push('/museum/${museum.id}');
        });

        markers.add(markerBuilder);
        visibleCount++;
      }
      _visibleMarkerCount = visibleCount;

      if (markers.isEmpty) return;

      if (_isDisposed ||
          !mounted ||
          _mapController != controller ||
          generation != _markerDrawGeneration) {
        return;
      }

      try {
        await controller.addOverlayAll(markers);
      } catch (e) {
        debugPrint('[Map] addOverlayAll failed ignored: $e');
      }
    } finally {
      if (generation == _markerDrawGeneration) {
        _isDrawingMarkers = false;
      }
    }
  }

  // M4: 검색 실행
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      _clearSearch();
      return;
    }
    setState(() {
      _isSearching = true;
      _searchActive = true;
      _panelVisible = true; // 새 검색 시 패널 다시 열기
    });
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted || _isDisposed) return;
      try {
        final repo = ref.read(museumRepositoryProvider);
        final results = await repo.searchForMap(value, limit: 50); // R9: 최대 50건
        if (!mounted || _isDisposed) return;
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
        await _drawSearchResultMarkers(results);
      } catch (e) {
        if (!mounted || _isDisposed) return;
        setState(() => _isSearching = false);
      }
    });
  }

  // M4: 검색 결과 마커 표시
  Future<void> _drawSearchResultMarkers(List<Museum> results) async {
    if (_isDisposed || !mounted) return;
    final controller = _mapController;
    if (controller == null) return;

    final generation = ++_markerDrawGeneration;
    _isDrawingMarkers = true;

    try {
      try {
        await controller.clearOverlays();
      } catch (_) {}

      if (_isDisposed || !mounted || generation != _markerDrawGeneration) return;

      _lastDrawnCount = -1; // 전체 마커 재그리기 필요 표시

      final Set<NMarker> markers = {};
      for (final museum in results) {
        if (museum.latitude == null || museum.longitude == null) continue;

        // R4-2: 커스텀 원형 아이콘 사용
        final icon = await _getMarkerIcon(museum.type);
        if (_isDisposed || !mounted || generation != _markerDrawGeneration) return;

        final marker = NMarker(
          id: museum.id,
          position: NLatLng(museum.latitude!, museum.longitude!),
          caption: NOverlayCaption(
            text: museum.name,
            textSize: 11,
            color: _kNavy,
            haloColor: Colors.white,
          ),
          size: const Size(22, 22),
        );

        if (icon != null) {
          marker.setIcon(icon);
        } else {
          marker.setIconTintColor(_typeColor(museum.type));
        }

        marker.setOnTapListener((_) {
          context.push('/museum/${museum.id}');
        });

        markers.add(marker);
      }

      if (markers.isEmpty) return;

      if (_isDisposed || !mounted || generation != _markerDrawGeneration) return;

      try {
        await controller.addOverlayAll(markers);
      } catch (e) {
        debugPrint('[Map] addOverlayAll search failed: $e');
      }

      // 첫 번째 결과로 카메라 이동
      if (results.isNotEmpty) {
        final first = results.first;
        if (first.latitude != null && first.longitude != null) {
          try {
            await controller.updateCamera(
              NCameraUpdate.withParams(
                target: NLatLng(first.latitude!, first.longitude!),
                zoom: results.length == 1 ? 15 : 11,
              ),
            );
          } catch (_) {}
        }
      }
    } finally {
      if (generation == _markerDrawGeneration) {
        _isDrawingMarkers = false;
      }
    }
  }

  // M4: 검색 초기화 → 전체 마커 복원
  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
      _isSearching = false;
      _searchActive = false;
      _panelVisible = true;
    });
    // 전체 마커 재그리기
    _lastDrawnCount = -1;
    final museumsAsync = ref.read(mapMuseumsProvider);
    museumsAsync.whenData((museums) => _addMuseumMarkers(museums));
  }

  // R10: 패널만 닫기 (검색어/마커 유지)
  void _dismissPanel() {
    setState(() => _panelVisible = false);
    _searchFocusNode.unfocus();
  }

  // R4-2: type별 색상 (범례와 1:1)
  Color _typeColor(String? type) {
    switch (type) {
      case '박물관':
        return _kColorMuseum;
      case '미술관':
        return _kColorArt;
      case '과학관':
        return _kColorScience;
      case '기념관':
        return _kColorMemorial;
      case '전시관':
        return _kColorExhibit;
      default:
        return _kColorDefault;
    }
  }

  @override
  Widget build(BuildContext context) {
    final museumsAsync = ref.watch(mapMuseumsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ─── 지도 ──────────────────────────────────────────────────────
          // R10: 지도 영역 탭 시 패널 닫기
          GestureDetector(
            onTap: _searchActive && _panelVisible ? _dismissPanel : null,
            behavior: HitTestBehavior.translucent,
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: _initialPosition,
                  zoom: 11,
                ),
                locationButtonEnable: true,
                consumeSymbolTapEvents: false,
              ),
              onMapReady: _onMapReady,
            ),
          ),

          // ─── M4: 검색바 (실제 검색 기능) ──────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _MapSearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              isSearching: _isSearching,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
          ),

          // ─── 범례 ──────────────────────────────────────────────────────
          if (!_searchActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              right: 16,
              child: const _TypeLegend(),
            ),

          // ─── R9+R10+R15: 검색 결과 목록 패널 (스크롤 가능, 최대 50건) ──────
          if (_searchActive && _searchResults.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 16,
              right: 16,
              child: _panelVisible
                  ? _SearchResultPanel(
                      results: _searchResults,
                      onTap: (museum) {
                        _searchFocusNode.unfocus();
                        // R16: 목록 탭 → 카메라 이동 + 마커 강조 (상세 직행 제거)
                        if (museum.latitude != null &&
                            museum.longitude != null) {
                          _mapController?.updateCamera(
                            NCameraUpdate.withParams(
                              target:
                                  NLatLng(museum.latitude!, museum.longitude!),
                              zoom: 15,
                            ),
                          );
                        }
                        _dismissPanel();
                      },
                      onLocate: (museum) {
                        _searchFocusNode.unfocus();
                        if (museum.latitude != null &&
                            museum.longitude != null) {
                          _mapController?.updateCamera(
                            NCameraUpdate.withParams(
                              target:
                                  NLatLng(museum.latitude!, museum.longitude!),
                              zoom: 15,
                            ),
                          );
                        }
                      },
                      // R10: 패널 상단 접기 핸들
                      onDismiss: _dismissPanel,
                    )
                  // R15: 패널 접힘 → 재오픈 바 상시 노출
                  : GestureDetector(
                      onTap: () => setState(() => _panelVisible = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.keyboard_arrow_down,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              '결과 ${_searchResults.length}곳',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

          // ─── M4: 검색 결과 없음 안내 ──────────────────────────────────
          if (_searchActive && !_isSearching && _searchResults.isEmpty && _searchController.text.trim().isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  '"${_searchController.text.trim()}" 검색 결과가 없습니다',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // ─── 하단 배지 ─────────────────────────────────────────────────
          museumsAsync.when(
            data: (museums) {
              _onMuseumsLoaded(museums);
              return Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: _searchActive
                      ? GestureDetector(
                          // R11: 검색 결과 배지 탭 → 탐색 화면 검색어 연동
                          onTap: () {
                            final query = _searchController.text.trim();
                            if (query.isNotEmpty) {
                              ref.read(exploreFilterProvider.notifier).setSearchQuery(query);
                            }
                            context.go('/explore');
                          },
                          child: _CountBadge(
                            count: _searchResults.length,
                            label: '검색 결과',
                            tappable: true,
                          ),
                        )
                      : _CountBadge(count: _visibleMarkerCount > 0 ? _visibleMarkerCount : museums.where((m) => _kVisibleTypes.contains(m.type)).length),
                ),
              );
            },
            loading: () => Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('전시 공간 불러오는 중...',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            error: (e, _) => Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    '데이터를 불러오지 못했습니다.',
                    style:
                        TextStyle(color: Colors.red.shade700, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── M4: 지도 위 검색바 ────────────────────────────────────────────────────────
class _MapSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _MapSearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearching,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: _kNavy),
        decoration: InputDecoration(
          hintText: '전시 공간 검색',
          hintStyle: TextStyle(
            color: _kNavy.withValues(alpha: 0.45),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: _kNavy.withValues(alpha: 0.45),
            size: 20,
          ),
          suffixIcon: isSearching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close,
                          color: _kNavy.withValues(alpha: 0.45), size: 18),
                      onPressed: onClear,
                    )
                  : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

// ─── R9+R10: 검색 결과 패널 (스크롤 가능, 최대 50건, 접기 핸들) ──────────────
class _SearchResultPanel extends StatelessWidget {
  final List<Museum> results;
  final ValueChanged<Museum> onTap;
  final ValueChanged<Museum> onLocate;
  final VoidCallback onDismiss; // R10

  const _SearchResultPanel({
    required this.results,
    required this.onTap,
    required this.onLocate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // R9: 최대 화면 높이의 45%로 패널 높이 제한 (스크롤 가능)
    final maxHeight = MediaQuery.of(context).size.height * 0.45;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // R10: 패널 상단 접기 핸들
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // R9: 결과 수 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Row(
              children: [
                Text(
                  '검색 결과 ${results.length}곳',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // R9: 스크롤 가능한 결과 목록
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final museum = results[index];
                return _ResultItem(
                  museum: museum,
                  onTap: () => onTap(museum),
                  onLocate: () => onLocate(museum),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final Museum museum;
  final VoidCallback onTap;
  final VoidCallback onLocate;

  const _ResultItem({
    required this.museum,
    required this.onTap,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(museum.typeIcon,
                style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    museum.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kNavy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        '${museum.region1} · ${museum.type}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      // R21: 별점 (0건 생략)
                      if ((museum.reviewCount ?? 0) > 0) ...
                        [
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded,
                              size: 11, color: Color(0xFFF5A623)),
                          const SizedBox(width: 2),
                          Text(
                            museum.averageRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFF5A623),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                    ],
                  ),
                ],
              ),
            ),
            if (museum.latitude != null && museum.longitude != null)
              IconButton(
                icon: const Icon(Icons.my_location,
                    size: 18, color: _kNavy),
                onPressed: onLocate,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeLegend extends StatelessWidget {
  const _TypeLegend();

  @override
  Widget build(BuildContext context) {
    // R14: 3종만 범례 표시
    const items = [
      ('박물관', _kColorMuseum),
      ('미술관', _kColorArt),
      ('과학관', _kColorScience),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Color.fromRGBO(255, 255, 255, 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: item.$2,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(item.$1,
                        style: const TextStyle(
                            fontSize: 11, color: _kNavy)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final String? label;
  // R11: 탭 가능 여부 표시 (화살표 아이콘)
  final bool tappable;
  const _CountBadge({required this.count, this.label, this.tappable = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _kNavy.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label != null ? '$label $count곳' : '전시 공간 $count곳',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          // R11: 탭 가능 배지에 화살표 아이콘
          if (tappable) ...[
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 11),
          ],
        ],
      ),
    );
  }
}
