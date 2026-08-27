/// 한국관광공사 TourAPI 기반 "함께 가볼 만한 곳" 장소 모델.
///
/// Edge Function(`kto-nearby-places`)의 응답 계약(README)과 1:1 대응한다.
/// 원본 무가공 — 서버(Edge Function)에서 정규화된 값을 그대로 담는다.
class NearbyPlace {
  final String externalId; // KTO contentid
  final int contentTypeId; // 12 관광지 / 14 문화시설 / 25 여행코스 / 28 레포츠
  final String category; // 한글 라벨
  final String title;
  final String address;
  final double lat;
  final double lng;
  final int distanceM;
  final String imageUrl; // firstimage (없을 수 있음)
  final String thumbnailUrl; // firstimage2 (없을 수 있음)
  final String copyrightCode; // cpyrhtDivCd

  const NearbyPlace({
    required this.externalId,
    required this.contentTypeId,
    required this.category,
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.copyrightCode,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    return NearbyPlace(
      externalId: (json['externalId'] ?? '').toString(),
      contentTypeId: (json['contentTypeId'] as num?)?.toInt() ?? 0,
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      distanceM: (json['distanceM'] as num?)?.toInt() ?? 0,
      imageUrl: (json['imageUrl'] ?? '').toString(),
      thumbnailUrl: (json['thumbnailUrl'] ?? '').toString(),
      copyrightCode: (json['copyrightCode'] ?? '').toString(),
    );
  }

  /// 거리 표기: 350m / 1.2km (Edge Function의 distanceM 사용, 앱에서 재계산 안 함)
  String get distanceText =>
      distanceM < 1000 ? '${distanceM}m' : '${(distanceM / 1000).toStringAsFixed(1)}km';

  /// 대표 이미지 우선순위: firstimage → firstimage2 → 없음(null)
  String? get bestImageUrl {
    if (imageUrl.isNotEmpty) return imageUrl;
    if (thumbnailUrl.isNotEmpty) return thumbnailUrl;
    return null;
  }
}
