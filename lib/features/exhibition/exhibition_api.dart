import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'exhibition_model.dart';

/// 한국문화정보원 문화정보 OpenAPI period2 클라이언트
///
/// 확정된 파라미터 (2026-08-05 실기기 진단 결과):
/// - `numOfrows=100` (소문자 r) — 대문자 numOfRows는 서버에서 무시됨
/// - `pageNo` 다중 호출 전략 폐기 — 서버에서 pageNo가 무시되어 같은 데이터 반복
/// - `sido` 파라미터 포함하되 서버 필터 신뢰 금지 — 앱 내부 거리 필터로 처리
///
/// 호출 전략:
/// - `numOfrows=100` 단일 호출 → 최대 100건 수집
/// - allowedRealms 필터 → 거리 필터 → 최대 10건 표시
/// - 동일 sido 결과 6시간 메모리 캐시
class ExhibitionApi {
  ExhibitionApi._();
  static final ExhibitionApi instance = ExhibitionApi._();

  static const _endpoint =
      'https://apis.data.go.kr/B553457/cultureinfo/period2';
  static const _cacheDuration = Duration(hours: 6);

  // 메모리 캐시: sido → (timestamp, list)
  final Map<String, _CacheEntry> _cache = {};

  // 날짜 파라미터 캐시 (같은 날 재사용)
  String? _cachedFrom;
  String? _cachedTo;
  DateTime? _cachedDate;

  /// 허용 realmName 목록 (문화행사)
  /// 뮤즐리는 박물관·미술관·과학관 중심 앱 — 연극·뮤지컬/오페라·음악/콘서트 제외
  static const Set<String> allowedRealms = {
    '전시',
    '교육/체험',
    '행사/축제',
  };

  /// sido 기준 현재 진행 중인 문화행사 목록 반환 (캐시 우선)
  /// numOfrows=100 단일 호출
  /// 실패 시 null 반환 (섹션 숨김 처리는 호출자 담당)
  Future<List<Exhibition>?> fetchExhibitions(String sido) async {
    // 캐시 확인
    final cached = _cache[sido];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _cacheDuration) {
      dev.log('[ExhibitionApi] cache hit: $sido', name: 'Exhibition');
      return cached.items;
    }

    final serviceKey = dotenv.env['CULTURE_API_KEY'] ?? '';
    if (serviceKey.isEmpty) {
      dev.log('[ExhibitionApi] CULTURE_API_KEY not set', name: 'Exhibition');
      if (kDebugMode) print('EXH-API: CULTURE_API_KEY not set — returning null');
      return null;
    }

    final (from, to) = _getDateRange();
    if (kDebugMode) {
      print('EXH-API: GET numOfrows=100 sido=$sido from=$from to=$to');
    }

    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'serviceKey': serviceKey,
        'from': from,
        'to': to,
        'sido': sido,
        'numOfrows': '100', // 확정: 소문자 r (대문자 R은 서버에서 무시됨)
        'pageNo': '1',
      });

      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));

      // response.body 사용 금지 — utf8.decode(response.bodyBytes) 사용
      final decodedBody = utf8.decode(response.bodyBytes);

      if (kDebugMode) {
        print('EXH-API: status=${response.statusCode}');
      }

      if (response.statusCode != 200) {
        dev.log('[ExhibitionApi] HTTP ${response.statusCode}',
            name: 'Exhibition');
        return cached?.items;
      }

      final document = XmlDocument.parse(decodedBody);
      final rawItems = document.findAllElements('item').toList();

      if (kDebugMode) {
        print('EXH-API: raw items=${rawItems.length}');
      }

      final exhibitions = deduplicateAndFilter(rawItems);

      // 캐시 저장
      _cache[sido] = _CacheEntry(
        timestamp: DateTime.now(),
        items: exhibitions,
      );

      dev.log(
          '[ExhibitionApi] fetched ${exhibitions.length} events for $sido',
          name: 'Exhibition');
      return exhibitions;
    } on TimeoutException {
      dev.log('[ExhibitionApi] timeout', name: 'Exhibition');
      if (kDebugMode) print('EXH-API: timeout');
      return cached?.items;
    } catch (e) {
      dev.log('[ExhibitionApi] error: $e', name: 'Exhibition');
      if (kDebugMode) print('EXH-API: error=$e');
      return cached?.items;
    }
  }

  /// raw XmlElement 리스트 → 모델 변환 + 중복 seq 제거 + allowedRealms 필터
  List<Exhibition> deduplicateAndFilter(List<XmlElement> rawItems) {
    final seen = <String>{};
    final result = <Exhibition>[];
    // realm counts: 전체 파싱 데이터 기준 (allowedRealms 필터 전)
    final realmCounts = <String, int>{};
    // area counts: 지역 분포 확인
    final areaCounts = <String, int>{};

    for (final item in rawItems) {
      Exhibition? ex;
      try {
        ex = Exhibition.fromXmlItem(item);
      } catch (e) {
        dev.log('[ExhibitionApi] parse error: $e', name: 'Exhibition');
        if (kDebugMode) print('EXH-API: parse error=$e');
        continue;
      }

      if (seen.contains(ex.seq)) continue;
      seen.add(ex.seq);

      // realm counts 집계 (필터 전 전체 데이터 기준)
      final realm = ex.realmName.trim();
      if (realm.isNotEmpty) {
        realmCounts[realm] = (realmCounts[realm] ?? 0) + 1;
      }

      // area counts 집계
      final area = (ex.area ?? '').trim();
      if (area.isNotEmpty) {
        areaCounts[area] = (areaCounts[area] ?? 0) + 1;
      }

      // 허용 목록에 없거나 빈 realmName 노출 금지
      if (realm.isEmpty || !allowedRealms.contains(realm)) continue;

      result.add(ex);
    }

    if (kDebugMode) {
      print('EXH-API: realm counts=$realmCounts');
      print('EXH-API: area counts=$areaCounts');
      print('EXH-API: allowed realm filter=${result.length}');
    }

    return result;
  }

  /// 오늘 기준 from/to 날짜 파라미터 반환 (당일 캐시)
  (String, String) _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_cachedDate == null || _cachedDate != today) {
      _cachedFrom =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final to90 = now.add(const Duration(days: 90));
      _cachedTo =
          '${to90.year}${to90.month.toString().padLeft(2, '0')}${to90.day.toString().padLeft(2, '0')}';
      _cachedDate = today;
    }
    return (_cachedFrom!, _cachedTo!);
  }

  /// 두 좌표 간 거리 계산 (km, Haversine)
  static double distanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

class _CacheEntry {
  final DateTime timestamp;
  final List<Exhibition> items;
  const _CacheEntry({required this.timestamp, required this.items});
}
