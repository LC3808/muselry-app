import 'package:supabase_flutter/supabase_flutter.dart';

import 'nearby_place.dart';

/// 얇은 Repository — Supabase Edge Function `kto-nearby-places`를 호출해
/// 박물관 주변 관광정보를 가져온다. 서비스키/외부 API는 서버(Edge Function)가 담당하며,
/// 앱은 TourAPI를 직접 호출하지 않는다.
///
/// 오류 정책: invoke 실패(FunctionException/네트워크)는 삼키지 않고 상위(Provider)로
/// 전파해 AsyncValue.error로 보존한다. UI(NearbyPlacesSection)에서 섹션 숨김 처리.
class KtoNearbyRepository {
  KtoNearbyRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<NearbyPlace>> fetchNearbyPlaces({
    required double latitude,
    required double longitude,
    int radius = 5000,
    int limit = 5,
  }) async {
    final res = await _client.functions.invoke(
      'kto-nearby-places',
      body: {
        'lat': latitude,
        'lng': longitude,
        'radius': radius,
        'limit': limit,
      },
    );

    final data = res.data;
    if (data is! Map) return const [];
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => NearbyPlace.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
