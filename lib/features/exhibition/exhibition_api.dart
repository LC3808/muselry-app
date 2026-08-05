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
/// - 실시간 호출만 사용 (Supabase/로컬 DB 저장 금지)
/// - 동일 sido 결과는 6시간 메모리 캐시
/// - realmName == '전시' 필터는 클라이언트에서 수행
class ExhibitionApi {
  ExhibitionApi._();
  static final ExhibitionApi instance = ExhibitionApi._();

  static const _endpoint =
      'https://apis.data.go.kr/B553457/cultureinfo/period2';
  static const _cacheDuration = Duration(hours: 6);

  // 메모리 캐시: sido → (timestamp, list)
  final Map<String, _CacheEntry> _cache = {};

  /// sido 기준 현재 진행 중인 전시 목록 반환 (최대 numOfRows개 중 '전시' 필터 후)
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
      return null; // 키 없으면 null 반환 → 섹션 숨김
    }

    final now = DateTime.now();
    final from =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final to90 = now.add(const Duration(days: 90));
    final to =
        '${to90.year}${to90.month.toString().padLeft(2, '0')}${to90.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'serviceKey': serviceKey,
      'from': from,
      'to': to,
      'sido': sido,
      'numOfRows': '100', // §5-1: numOfRows 대소문자 확인
      'pageNo': '1',
    });

    if (kDebugMode) print('EXH-API: fetching sido=$sido from=$from to=$to');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      // 원인 확정: response.body 사용 금지
      // Dart http의 response.body는 latin-1 기본 디코딩 → UTF-8 한글 mojibake 발생
      // response.bodyBytes를 utf8.decode()로 명시 디코딩해야 함
      final decodedBody = utf8.decode(response.bodyBytes);

      if (kDebugMode) {
        print('EXH-API: status=${response.statusCode}');
        print(
            'EXH-API: body head=${decodedBody.substring(0, decodedBody.length > 300 ? 300 : decodedBody.length)}');
      }

      if (response.statusCode != 200) {
        dev.log('[ExhibitionApi] HTTP ${response.statusCode}',
            name: 'Exhibition');
        return cached?.items;
      }

      final document = XmlDocument.parse(decodedBody);
      final items = document.findAllElements('item');
      final itemList = items.toList();
      if (kDebugMode) print('EXH-API: raw items=${itemList.length}');

      // realmName 샘플 출력 (진단용)
      // innerText 사용 금지 — XmlText.value 기반 helper 사용
      if (kDebugMode) {
        for (final item in itemList.take(5)) {
          String nodeText(String tag) {
            final el = item.getElement(tag);
            if (el == null) return '';
            return el.children
                .whereType<XmlText>()
                .map((n) => n.value)
                .join()
                .trim();
          }
          final realm = nodeText('realmName');
          final title = nodeText('title');
          // 링크 필드 확인 (어떤 필드명으로 제공되는지 실기기 로그로 확인)
          final url = nodeText('url');
          final homepage = nodeText('homepage');
          final detailUrl = nodeText('detailUrl');
          final referenceUrl = nodeText('referenceUrl');
          final link = nodeText('link');
          print('EXH-API: sample realm=[$realm] title=[$title]');
          if (kDebugMode) {
            print('EXH-API: link fields url=[$url] homepage=[$homepage] detailUrl=[$detailUrl] referenceUrl=[$referenceUrl] link=[$link]');
          }
        }
      }

      final mapped = itemList.map((item) {
        try {
          return Exhibition.fromXmlItem(item);
        } catch (e) {
          dev.log('[ExhibitionApi] parse error: $e', name: 'Exhibition');
          if (kDebugMode) print('EXH-API: parse error=$e');
          return null;
        }
      }).whereType<Exhibition>().toList();

      // mapped realm 로그 (모델 변환 후 realmName 확인)
      if (kDebugMode) {
        for (final ex in mapped.take(5)) {
          print('EXH-API: mapped realm=[${ex.realmName}] title=[${ex.title}]');
        }
      }

      // §5: realmName == '전시' 클라이언트 필터 (trim 포함)
      final exhibitions = mapped
          .where((e) => e.realmName.trim() == '전시')
          .toList();

      if (kDebugMode) print('EXH-API: after 전시 filter=${exhibitions.length}');

      _cache[sido] = _CacheEntry(
        timestamp: DateTime.now(),
        items: exhibitions,
      );

      dev.log(
          '[ExhibitionApi] fetched ${exhibitions.length} exhibitions for $sido',
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
