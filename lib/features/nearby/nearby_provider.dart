import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kto_nearby_repository.dart';
import 'nearby_place.dart';

/// FutureProvider.family 조회 키 — 동일 박물관 재진입 시 재호출 최소화.
/// (Edge Function의 24h in-memory 캐시와 역할이 다르므로 앱-side 캐시는 추가하지 않음)
class NearbyQuery {
  final String museumId;
  final double lat;
  final double lng;
  const NearbyQuery({
    required this.museumId,
    required this.lat,
    required this.lng,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyQuery &&
          other.museumId == museumId &&
          other.lat == lat &&
          other.lng == lng;

  @override
  int get hashCode => Object.hash(museumId, lat, lng);
}

final ktoNearbyRepositoryProvider =
    Provider<KtoNearbyRepository>((ref) => KtoNearbyRepository());

/// 박물관 주변 "함께 가볼 만한 곳" 목록. 실패/네트워크 오류는 AsyncValue.error로 보존.
final nearbyPlacesProvider =
    FutureProvider.family<List<NearbyPlace>, NearbyQuery>((ref, q) async {
  final repo = ref.watch(ktoNearbyRepositoryProvider);
  return repo.fetchNearbyPlaces(
    latitude: q.lat,
    longitude: q.lng,
    radius: 5000,
    limit: 5,
  );
});
