import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/museum.dart';
import '../nearby_place.dart';
import '../nearby_provider.dart';

/// 박물관 상세 화면 "함께 가볼 만한 곳" 섹션 (한국관광공사 TourAPI).
///
/// - 박물관 좌표가 유효할 때만 Edge Function 1회 호출 (좌표 null/NaN/범위 밖이면 섹션 자체 숨김).
/// - 비동기 독립 로딩: 상세화면 본체를 막지 않는다.
/// - 결과 0건 또는 오류(timeout/function 실패)면 섹션 숨김 → 상세화면 정상 유지.
class NearbyPlacesSection extends ConsumerWidget {
  const NearbyPlacesSection({super.key, required this.museum});

  final Museum museum;

  bool get _hasValidCoords {
    final lat = museum.latitude;
    final lng = museum.longitude;
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 좌표 가드: 유효하지 않으면 호출조차 하지 않고 섹션 숨김
    if (!_hasValidCoords) return const SizedBox.shrink();

    final query = NearbyQuery(
      museumId: museum.id,
      lat: museum.latitude!,
      lng: museum.longitude!,
    );
    final async = ref.watch(nearbyPlacesProvider(query));

    return async.when(
      loading: () => const _NearbyLoading(),
      error: (err, _) {
        if (kDebugMode) debugPrint('[Nearby] load error: $err'); // serviceKey 미포함
        return const SizedBox.shrink(); // production UX: 섹션 숨김
      },
      data: (places) {
        if (places.isEmpty) return const SizedBox.shrink();
        return _NearbyContent(places: places);
      },
    );
  }
}

class _NearbyContent extends StatelessWidget {
  const _NearbyContent({required this.places});

  final List<NearbyPlace> places;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '함께 가볼 만한 곳',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C3E50),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '이 박물관 주변의 관광지·문화시설',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: places.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final place = places[index];
              return _NearbyCard(
                place: place,
                onTap: () => _showDetail(context, place),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '관광정보 제공: 한국관광공사 (TourAPI)',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _showDetail(BuildContext context, NearbyPlace place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NearbyDetailSheet(place: place),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.place, required this.onTap});

  final NearbyPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: _NearbyImage(place: place),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryChip(category: place.category),
                      const Spacer(),
                      Text(
                        place.distanceText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    place.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                      height: 1.25,
                    ),
                  ),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyImage extends StatelessWidget {
  const _NearbyImage({required this.place});

  final NearbyPlace place;

  @override
  Widget build(BuildContext context) {
    final url = place.bestImageUrl;
    const double h = 100;
    if (url == null) {
      return _placeholder(h);
    }
    return CachedNetworkImage(
      imageUrl: url,
      height: h,
      width: 168,
      fit: BoxFit.cover,
      placeholder: (_, __) => _placeholder(h),
      errorWidget: (_, __, ___) => _placeholder(h),
    );
  }

  Widget _placeholder(double h) => Container(
        height: h,
        width: 168,
        color: const Color(0xFFF0F1F3),
        alignment: Alignment.center,
        child: Icon(
          _categoryIcon(place.contentTypeId),
          size: 30,
          color: Colors.grey[400],
        ),
      );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    if (category.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}

/// 카드 탭 → 장소 정보 bottom sheet (장소명/카테고리/거리/주소 + 지도에서 보기).
/// 대형 관광지 상세페이지는 이번 Phase에서 만들지 않음(추가 TourAPI 호출 없음).
class _NearbyDetailSheet extends StatelessWidget {
  const _NearbyDetailSheet({required this.place});

  final NearbyPlace place;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            if (place.bestImageUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: place.bestImageUrl!,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    placeholder: (_, __) => const SizedBox(height: 170),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _CategoryChip(category: place.category),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    place.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SheetRow(icon: Icons.near_me_outlined, text: place.distanceText),
                  if (place.address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SheetRow(icon: Icons.location_on_outlined, text: place.address),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openMap(context, place),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('지도에서 보기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '관광정보 제공: 한국관광공사 (TourAPI)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        ),
      ],
    );
  }
}

class _NearbyLoading extends StatelessWidget {
  const _NearbyLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 120,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, __) => Container(
              width: 168,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

IconData _categoryIcon(int contentTypeId) {
  switch (contentTypeId) {
    case 12:
      return Icons.landscape_outlined; // 관광지
    case 14:
      return Icons.museum_outlined; // 문화시설
    case 25:
      return Icons.route_outlined; // 여행코스
    case 28:
      return Icons.directions_bike_outlined; // 레포츠
    default:
      return Icons.place_outlined;
  }
}

/// 네이버 지도 앱(nmap) 딥링크 → 실패 시 웹 지도 fallback.
/// 카카오 지도는 이번 Phase에서 추가하지 않음(§24).
Future<void> _openMap(BuildContext context, NearbyPlace place) async {
  final name = Uri.encodeComponent(place.title);
  final appUri = Uri.parse(
      'nmap://place?lat=${place.lat}&lng=${place.lng}&name=$name&appname=com.muselry.muselry');
  final webUri = Uri.parse('https://map.naver.com/p/search/$name');
  try {
    if (await canLaunchUrl(appUri)) {
      final ok = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지도를 열 수 없습니다.')),
      );
    }
  }
}
