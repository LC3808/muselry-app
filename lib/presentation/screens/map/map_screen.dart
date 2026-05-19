import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../providers/museum_provider.dart';
import 'widgets/unified_museum_map_view.dart';

// 앱 색상 상수
const _kNavy = Color(0xFF2C3E50);

/// 지도 탭 화면.
///
/// overlay 관리는 [UnifiedMuseumMapView]에 위임한다.
/// 이 화면은 데이터를 조회하여 props로 전달하는 wrapper 역할만 한다.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  NLatLng _initialPosition = const NLatLng(37.5665, 126.9780);

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
    } catch (_) {
      // 위치 실패 시 서울 기본값 유지
    }
  }

  @override
  Widget build(BuildContext context) {
    final museumsAsync = ref.watch(mapMuseumsProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 공통 지도 컴포넌트 — overlay 관리는 내부에서 처리
          museumsAsync.when(
            data: (museums) => UnifiedMuseumMapView(
              mode: MuseumMapMode.explore,
              museums: museums,
              visitedIds: const {},
              bookmarkedIds: const {},
              initialTarget: _initialPosition,
              initialZoom: 11,
              onMuseumTap: (museum, _) {
                context.push('/museum/${museum.id}');
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 검색 바
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _SearchBarTile(onTap: () => context.go('/explore')),
          ),

          // 유형 범례
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            right: 16,
            child: const _TypeLegend(),
          ),

          // 박물관 수 배지 / 로딩 / 에러
          museumsAsync.when(
            data: (museums) => Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(child: _CountBadge(count: museums.length)),
            ),
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
    const kGold = Color(0xFFB8860B);
    const items = [
      ('박물관', kGold),
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
