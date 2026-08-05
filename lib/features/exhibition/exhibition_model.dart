import 'package:xml/xml.dart';

/// 문화정보 OpenAPI period2 응답 item 모델
/// 원본 필드값은 수정하지 않음 (지시서 §4, §절대규칙 4)
class Exhibition {
  final String seq;
  final String title;
  final String place;
  final String startDate;
  final String endDate;
  final String realmName;
  final String? thumbnail;
  final double? longitude; // gpsX
  final double? latitude; // gpsY
  final String? area;
  final String? sigungu;

  const Exhibition({
    required this.seq,
    required this.title,
    required this.place,
    required this.startDate,
    required this.endDate,
    required this.realmName,
    this.thumbnail,
    this.longitude,
    this.latitude,
    this.area,
    this.sigungu,
  });

  /// XML item 노드에서 파싱
  factory Exhibition.fromXmlItem(XmlElement item) {
    // innerText 사용 금지 (xml ^6.5.0 이하에서 미지원)
    // XmlText.value 기반 helper로 텍스트 추출
    String text(String tag) {
      final element = item.getElement(tag);
      if (element == null) return '';
      return element.children
          .whereType<XmlText>()
          .map((node) => node.value)
          .join()
          .trim();
    }

    String? nullable(String tag) {
      final v = text(tag);
      return v.isEmpty ? null : v;
    }

    double? asDouble(String tag) {
      final v = text(tag);
      return v.isEmpty ? null : double.tryParse(v);
    }

    // realmName: 직접 추출 + serviceName fallback
    final realmRaw = text('realmName');
    final serviceNameRaw = text('serviceName');
    final realm = realmRaw.isNotEmpty ? realmRaw : serviceNameRaw;

    return Exhibition(
      seq: text('seq'),
      title: text('title'),
      place: text('place'),
      startDate: text('startDate'),
      endDate: text('endDate'),
      realmName: realm,
      thumbnail: nullable('thumbnail'),
      longitude: asDouble('gpsX'),
      latitude: asDouble('gpsY'),
      area: nullable('area'),
      sigungu: nullable('sigungu'),
    );
  }

  /// 화면 표시용 날짜 포맷 변환 (원본 필드 수정 없음)
  /// 20260804 → 2026.8.4
  static String formatDate(String yyyymmdd) {
    if (yyyymmdd.length != 8) return yyyymmdd;
    final year = int.tryParse(yyyymmdd.substring(0, 4)) ?? 0;
    final month = int.tryParse(yyyymmdd.substring(4, 6)) ?? 0;
    final day = int.tryParse(yyyymmdd.substring(6, 8)) ?? 0;
    if (year == 0 || month == 0 || day == 0) return yyyymmdd;
    return '$year.$month.$day';
  }

  /// 전시 기간 표시: 2025.10.1 – 2026.8.30
  String get displayPeriod =>
      '${formatDate(startDate)} – ${formatDate(endDate)}';
}
