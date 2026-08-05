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
/// - 동일 sido 결과는 6시간 메모리 캐시 (여러 페이지 합산 결과를 캐시)
/// - realmName == '전시' 필터는 클라이언트에서 수행
/// - 페이지 호출: 1~3페이지 우선, '전시' 필터 후 6건 미만이면 4~5페이지 추가
/// - 최대 pageNo=5까지만 허용 (무한 호출 금지)
class ExhibitionApi {
  ExhibitionApi._();
  static final ExhibitionApi instance = ExhibitionApi._();

  static const _endpoint =
      'https://apis.data.go.kr/B553457/cultureinfo/period2';
  static const _cacheDuration = Duration(hours: 6);
  static const int _minResultsBeforeExpand = 6;

  // 메모리 캐시: sido → (timestamp, list)
  final Map<String, _CacheEntry> _cache = {};

  /// sido 기준 현재 진행 중인 전시 목록 반환
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

    final now = DateTime.now();
    final from =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final to90 = now.add(const Duration(days: 90));
    final to =
        '${to90.year}${to90.month.toString().padLeft(2, '0')}${to90.day.toString().padLeft(2, '0')}';

    if (kDebugMode) print('EXH-API: fetching sido=$sido from=$from to=$to');

    try {
      // 1단계: pageNo 1~3 호출
      final firstBatch = await _fetchPages(
        serviceKey: serviceKey,
        sido: sido,
        from: from,
        to: to,
        pages: [1, 2, 3],
      );

      List<Exhibition> allExhibitions = _deduplicateAndFilter(firstBatch);
      if (kDebugMode) {
        print('EXH-API: after pages 1-3 전시 filter=${allExhibitions.length}');
      }

      // 2단계: 6건 미만이면 pageNo 4~5 추가 호출
      if (allExhibitions.length < _minResultsBeforeExpand) {
        if (kDebugMode) {
          print(
              'EXH-API: ${allExhibitions.length}건 < $_minResultsBeforeExpand — expanding to pages 4-5');
        }
        final extraBatch = await _fetchPages(
          serviceKey: serviceKey,
          sido: sido,
          from: from,
          to: to,
          pages: [4, 5],
        );
        final combined = [...firstBatch, ...extraBatch];
        allExhibitions = _deduplicateAndFilter(combined);
        if (kDebugMode) {
          print(
              'EXH-API: after pages 1-5 전시 filter=${allExhibitions.length}');
        }
      }

      // 캐시 저장 (여러 페이지 합산 결과)
      _cache[sido] = _CacheEntry(
        timestamp: DateTime.now(),
        items: allExhibitions,
      );

      dev.log(
          '[ExhibitionApi] fetched ${allExhibitions.length} exhibitions for $sido',
          name: 'Exhibition');
      return allExhibitions;
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

  /// 지정된 페이지 목록을 순차 호출하여 raw XmlElement 리스트 반환
  Future<List<XmlElement>> _fetchPages({
    required String serviceKey,
    required String sido,
    required String from,
    required String to,
    required List<int> pages,
  }) async {
    final allItems = <XmlElement>[];
    for (final pageNo in pages) {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'serviceKey': serviceKey,
        'from': from,
        'to': to,
        'sido': sido,
        'numOfRows': '100',
        'pageNo': '$pageNo',
      });

      if (kDebugMode) print('EXH-API: GET pageNo=$pageNo sido=$sido');

      try {
        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));

        // response.body 사용 금지 — utf8.decode(response.bodyBytes) 사용
        final decodedBody = utf8.decode(response.bodyBytes);

        if (kDebugMode) {
          print('EXH-API: pageNo=$pageNo status=${response.statusCode}');
          if (pageNo == 1) {
            print(
                'EXH-API: body head=${decodedBody.substring(0, decodedBody.length > 300 ? 300 : decodedBody.length)}');
          }
        }

        if (response.statusCode != 200) {
          dev.log('[ExhibitionApi] HTTP ${response.statusCode} on page $pageNo',
              name: 'Exhibition');
          break; // 오류 페이지 이후 호출 중단
        }

        final document = XmlDocument.parse(decodedBody);
        final items = document.findAllElements('item').toList();
        if (kDebugMode) {
          print('EXH-API: pageNo=$pageNo raw items=${items.length}');
        }

        if (items.isEmpty) {
          // 빈 페이지 → 더 이상 데이터 없음
          break;
        }

        // 샘플 로그 (pageNo=1만)
        if (kDebugMode && pageNo == 1) {
          for (final item in items.take(3)) {
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
            if (kDebugMode) {
              print('EXH-API: sample realm=[$realm] title=[$title]');
              print(
                  'EXH-API: link fields url=[$url] homepage=[$homepage] detailUrl=[$detailUrl] referenceUrl=[$referenceUrl] link=[$link]');
            }
          }
        }

        allItems.addAll(items);
      } on TimeoutException {
        if (kDebugMode) print('EXH-API: pageNo=$pageNo timeout — stopping');
        break;
      } catch (e) {
        if (kDebugMode) print('EXH-API: pageNo=$pageNo error=$e — stopping');
        break;
      }
    }
    return allItems;
  }

  /// raw XmlElement 리스트 → 모델 변환 + 중복 seq 제거 + realmName='전시' 필터
  List<Exhibition> _deduplicateAndFilter(List<XmlElement> rawItems) {
    final seen = <String>{};
    final result = <Exhibition>[];

    for (final item in rawItems) {
      Exhibition? ex;
      try {
        ex = Exhibition.fromXmlItem(item);
      } catch (e) {
        dev.log('[ExhibitionApi] parse error: $e', name: 'Exhibition');
        if (kDebugMode) print('EXH-API: parse error=$e');
        continue;
      }

      // 중복 seq 제거
      if (seen.contains(ex.seq)) continue;
      seen.add(ex.seq);

      // realmName == '전시' 필터
      if (ex.realmName.trim() != '전시') continue;

      result.add(ex);
    }

    // mapped realm 로그 (처음 5건)
    if (kDebugMode) {
      for (final ex in result.take(5)) {
        print('EXH-API: mapped realm=[${ex.realmName}] title=[${ex.title}]');
      }
    }

    return result;
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
