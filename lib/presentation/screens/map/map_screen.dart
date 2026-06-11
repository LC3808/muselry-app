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
const _kGold = Color(0xFFB8860B);

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

  // M4: 검색 상태
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<Museum> _searchResults = [];
  bool _isSearching = false;
  bool _searchActive = false; // 검색 모드 활성화 여부

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
      for (final museum in museums) {
        if (museum.latitude == null || museum.longitude == null) continue;

        final color = _typeColor(museum.type);
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
          context.push('/museum/${museum.id}');
        });

        markers.add(marker);
      }

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
    });
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted || _isDisposed) return;
      try {
        final repo = ref.read(museumRepositoryProvider);
        final results = await repo.searchForMap(value);
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

        final color = _typeColor(museum.type);
        final marker = NMarker(
          id: museum.id,
          position: NLatLng(museum.latitude!, museum.longitude!),
          caption: NOverlayCaption(
            text: museum.name,
            textSize: 11,
            color: _kNavy,
            haloColor: Colors.white,
          ),
          iconTintColor: color,
          size: const Size(28, 28),
        );

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
    });
    // 전체 마커 재그리기
    _lastDrawnCount = -1;
    final museumsAsync = ref.read(mapMuseumsProvider);
    museumsAsync.whenData((museums) => _addMuseumMarkers(museums));
  }

  Color _typeColor(String? type) {
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

  @override
  Widget build(BuildContext context) {
    final museumsAsync = ref.watch(mapMuseumsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // ─── 지도 ──────────────────────────────────────────────────────
          NaverMap(
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

          // ─── M4: 검색 결과 목록 패널 ──────────────────────────────────
          if (_searchActive && _searchResults.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 16,
              right: 16,
              child: _SearchResultPanel(
                results: _searchResults,
                onTap: (museum) {
                  _searchFocusNode.unfocus();
                  context.push('/museum/${museum.id}');
                },
                onLocate: (museum) {
                  _searchFocusNode.unfocus();
                  if (museum.latitude != null && museum.longitude != null) {
                    _mapController?.updateCamera(
                      NCameraUpdate.withParams(
                        target: NLatLng(museum.latitude!, museum.longitude!),
                        zoom: 15,
                      ),
                    );
                  }
                },
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
                      ? _CountBadge(
                          count: _searchResults.length,
                          label: '검색 결과',
                        )
                      : _CountBadge(count: museums.length),
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
                      Text('박물관 불러오는 중...',
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
          hintText: '전시시설 검색',
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

// ─── M4: 검색 결과 패널 ────────────────────────────────────────────────────────
class _SearchResultPanel extends StatelessWidget {
  final List<Museum> results;
  final ValueChanged<Museum> onTap;
  final ValueChanged<Museum> onLocate;

  const _SearchResultPanel({
    required this.results,
    required this.onTap,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    final displayResults = results.take(5).toList();

    return Container(
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
          ...displayResults.map((museum) => _ResultItem(
                museum: museum,
                onTap: () => onTap(museum),
                onLocate: () => onLocate(museum),
              )),
          if (results.length > 5)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '외 ${results.length - 5}곳 더 있습니다',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                  Text(
                    '${museum.region1} · ${museum.type}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
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
    const items = [
      ('박물관', _kGold),
      ('미술관', Color(0xFF7C4DFF)),
      ('과학관', Color(0xFFE65100)),
      ('기념관', Color(0xFF00897B)),
      ('전시관', Color(0xFF1565C0)),
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
  const _CountBadge({required this.count, this.label});

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
      child: Text(
        label != null ? '$label $count곳' : '전시시설 $count곳',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
