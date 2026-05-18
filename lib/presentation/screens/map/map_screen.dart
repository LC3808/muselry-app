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

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
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
    _mapController = controller;
    final museumsAsync = ref.read(mapMuseumsProvider);
    museumsAsync.whenData((museums) => _addMuseumMarkers(museums));
  }

  void _onMuseumsLoaded(List<Museum> museums) {
    if (_mapController != null && museums.length != _lastDrawnCount) {
      _addMuseumMarkers(museums);
    }
  }

  Future<void> _addMuseumMarkers(List<Museum> museums) async {
    if (_mapController == null) return;

    await _mapController!.clearOverlays();
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

    await _mapController!.addOverlayAll(markers);
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
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _SearchBarTile(onTap: () => context.go('/explore')),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            right: 16,
            child: const _TypeLegend(),
          ),
          museumsAsync.when(
            data: (museums) {
              _onMuseumsLoaded(museums);
              return Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(child: _CountBadge(count: museums.length)),
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

class _SearchBarTile extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBarTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        child: Row(
          children: [
            Icon(Icons.search,
                color: _kNavy.withValues(alpha: 0.45), size: 20),
            const SizedBox(width: 8),
            Text(
              '박물관·미술관 검색',
              style: TextStyle(
                color: _kNavy.withValues(alpha: 0.45),
                fontSize: 14,
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
  const _CountBadge({required this.count});

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
        '박물관·미술관 $count곳',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}