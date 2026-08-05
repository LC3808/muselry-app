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
  factory Exhibition.fromXmlItem(dynamic item) {
    String getText(String tag) {
      try {
        return item.findElements(tag).first.innerText.trim();
      } catch (_) {
        return '';
      }
    }

    String? getNullable(String tag) {
      try {
        final v = item.findElements(tag).first.innerText.trim();
        return v.isEmpty ? null : v;
      } catch (_) {
        return null;
      }
    }

    double? getDouble(String tag) {
      try {
        final v = item.findElements(tag).first.innerText.trim();
        return v.isEmpty ? null : double.tryParse(v);
      } catch (_) {
        return null;
      }
    }

    // realmName: getElement 직접 추출 + trim (findElements 대신 getElement 사용)
    // serviceName을 fallback으로 사용 (빈 문자열인 경우)
    final realmRaw = item.getElement('realmName')?.innerText.trim() ?? '';
    final realmName = realmRaw.isNotEmpty
        ? realmRaw
        : (item.getElement('serviceName')?.innerText.trim() ?? '');

    return Exhibition(
      seq: getText('seq'),
      title: getText('title'),
      place: getText('place'),
      startDate: getText('startDate'),
      endDate: getText('endDate'),
      realmName: realmName,
      thumbnail: getNullable('thumbnail'),
      longitude: getDouble('gpsX'),
      latitude: getDouble('gpsY'),
      area: getNullable('area'),
      sigungu: getNullable('sigungu'),
    );
  }

  /// 화면 표시용 날짜 포맷 변환 (원본 필드 수정 없음)
  /// 20260804 → 8.4
  static String formatDate(String yyyymmdd) {
    if (yyyymmdd.length != 8) return yyyymmdd;
    final month = int.tryParse(yyyymmdd.substring(4, 6)) ?? 0;
    final day = int.tryParse(yyyymmdd.substring(6, 8)) ?? 0;
    return '$month.$day';
  }

  String get displayPeriod =>
      '${formatDate(startDate)} – ${formatDate(endDate)}';
}
