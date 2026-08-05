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
/// - allowedRealms 필터는 클라이언트에서 수행
/// - 페이지 확장 여부는 호출자(ExhibitionNotifier)가 거리 필터 후 결정
/// - 최대 pageNo=20까지 허용 (케이스 C: 행수/지역 파라미터 미적용 시 순차 수집)
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
  static const Set<String> allowedRealms = {
    '전시',
    '뮤지컬/오페라',
    '연극',
  };

  // ── 파라미터 진단 플래그 (첫 호출 1회만 실행) ──────────────────────────────
  bool _paramDiagDone = false;

  /// sido 기준 현재 진행 중인 문화행사 목록 반환 (캐시 우선)
  /// 캐시 없을 때 pageNo 1~3 호출
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
    if (kDebugMode) print('EXH-API: fetching sido=$sido from=$from to=$to');

    // ── 파라미터 진단 (첫 호출 1회만) ────────────────────────────────────────
    if (kDebugMode && !_paramDiagDone) {
      _paramDiagDone = true;
      _runParamDiagnostics(serviceKey: serviceKey, sido: sido, from: from, to: to);
    }

    try {
      final rawItems = await _fetchPages(
        serviceKey: serviceKey,
        sido: sido,
        from: from,
        to: to,
        pages: [1, 2, 3],
        logTag: '1-3',
      );

      final exhibitions = deduplicateAndFilter(rawItems, logTag: '1-3');
      if (kDebugMode) {
        print('EXH-API: pages loaded=1-3 allowed realm filter=${exhibitions.length}');
      }

      // 캐시 저장 (1~3페이지 결과)
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

  /// pageNo 4~5 추가 호출 (거리 필터 후 6건 미만일 때 provider가 호출)
  /// 기존 캐시 결과와 합산 후 캐시 갱신
  /// 실패 시 null 반환
  Future<List<Exhibition>?> fetchExhibitionsExtra(
    String sido,
    List<Exhibition> existing,
  ) async {
    final serviceKey = dotenv.env['CULTURE_API_KEY'] ?? '';
    if (serviceKey.isEmpty) return null;

    final (from, to) = _getDateRange();
    if (kDebugMode) print('EXH-API: expanding to pages 4-5 sido=$sido');

    try {
      final extraRaw = await _fetchPages(
        serviceKey: serviceKey,
        sido: sido,
        from: from,
        to: to,
        pages: [4, 5],
        logTag: '4-5',
      );

      // 기존 항목의 seq 집합 (중복 제거용)
      final existingSeqs = existing.map((e) => e.seq).toSet();

      // 추가 페이지에서 새로운 항목만 필터
      final extraExhibitions = deduplicateAndFilter(
        extraRaw,
        excludeSeqs: existingSeqs,
        logTag: '4-5',
      );

      final combined = [...existing, ...extraExhibitions];
      if (kDebugMode) {
        print(
            'EXH-API: pages loaded=1-5 allowed realm filter=${combined.length} (extra=${extraExhibitions.length})');
      }

      // 캐시 갱신 (1~5페이지 합산 결과)
      _cache[sido] = _CacheEntry(
        timestamp: _cache[sido]?.timestamp ?? DateTime.now(),
        items: combined,
      );

      return combined;
    } on TimeoutException {
      if (kDebugMode) print('EXH-API: extra pages timeout');
      return null;
    } catch (e) {
      if (kDebugMode) print('EXH-API: extra pages error=$e');
      return null;
    }
  }

  // ── 파라미터 진단 (비동기, 결과는 로그로만 출력) ──────────────────────────

  /// API 파라미터 진단: 행수/페이지/지역 파라미터 효과 검증
  /// 결과는 EXH-DIAG: 로그로 출력, 코드 변경 없음
  void _runParamDiagnostics({
    required String serviceKey,
    required String sido,
    required String from,
    required String to,
  }) {
    // 비동기로 실행 (홈 화면 블로킹 없음)
    Future(() async {
      if (kDebugMode) print('EXH-DIAG: === API 파라미터 진단 시작 ===');

      // ── 행 수 파라미터 검증 ────────────────────────────────────────────────
      // A: numOfRows=100 (현재 사용 중)
      await _diagTest(
        label: 'rows-A numOfRows=100',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'sido': sido, 'numOfRows': '100', 'pageNo': '1'},
      );

      // B: numOfrows=100 (소문자 r)
      await _diagTest(
        label: 'rows-B numOfrows=100',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'sido': sido, 'numOfrows': '100', 'pageNo': '1'},
      );

      // C: rows=100
      await _diagTest(
        label: 'rows-C rows=100',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'sido': sido, 'rows': '100', 'pageNo': '1'},
      );

      // D: cPage=1 rows=100
      await _diagTest(
        label: 'rows-D cPage=1 rows=100',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'sido': sido, 'rows': '100', 'cPage': '1'},
      );

      // E: numOfRows=50
      await _diagTest(
        label: 'rows-E numOfRows=50',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'sido': sido, 'numOfRows': '50', 'pageNo': '1'},
      );

      // ── 페이지 파라미터 검증 ───────────────────────────────────────────────
      // pageNo=2 vs cPage=2 (첫 번째 seq 비교)
      await _diagTest(
        label: 'page-A pageNo=2',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'sido': sido, 'numOfRows': '10', 'pageNo': '2'},
      );

      await _diagTest(
        label: 'page-B cPage=2',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'sido': sido, 'numOfRows': '10', 'cPage': '2'},
      );

      // ── 지역 파라미터 검증 ─────────────────────────────────────────────────
      // A: sido=서울 (현재)
      await _diagAreaTest(
        label: 'area-A sido=서울',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'sido': '서울', 'numOfRows': '10', 'pageNo': '1'},
      );

      // B: sido=서울특별시
      await _diagAreaTest(
        label: 'area-B sido=서울특별시',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'sido': '서울특별시', 'numOfRows': '10', 'pageNo': '1'},
      );

      // C: area=서울
      await _diagAreaTest(
        label: 'area-C area=서울',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'area': '서울', 'numOfRows': '10', 'pageNo': '1'},
      );

      // D: 지역 파라미터 없음
      await _diagAreaTest(
        label: 'area-D 지역없음',
        serviceKey: serviceKey,
        params: {'from': from, 'to': to, 'numOfRows': '10', 'pageNo': '1'},
      );

      if (kDebugMode) print('EXH-DIAG: === API 파라미터 진단 완료 ===');
    });
  }

  /// 단일 파라미터 조합 테스트 → itemCount/numOfrows/첫seq 로그 출력
  Future<void> _diagTest({
    required String label,
    required String serviceKey,
    required Map<String, String> params,
  }) async {
    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'serviceKey': serviceKey,
        ...params,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final body = utf8.decode(response.bodyBytes);
      final doc = XmlDocument.parse(body);
      final items = doc.findAllElements('item').toList();
      // 응답 메타 필드 추출
      String meta(String tag) {
        final el = doc.findAllElements(tag).firstOrNull;
        if (el == null) return '';
        return el.children.whereType<XmlText>().map((n) => n.value).join().trim();
      }
      final numOfrows = meta('numOfrows').isNotEmpty ? meta('numOfrows') : meta('numOfRows');
      final totalCount = meta('totalCount');
      final firstSeq = items.isNotEmpty
          ? items.first.getElement('seq')?.children
              .whereType<XmlText>().map((n) => n.value).join().trim() ?? ''
          : '';
      if (kDebugMode) {
        print('EXH-DIAG: $label → itemCount=${items.length} numOfrows=$numOfrows totalCount=$totalCount firstSeq=$firstSeq');
      }
    } catch (e) {
      if (kDebugMode) print('EXH-DIAG: $label → ERROR=$e');
    }
  }

  /// 지역 파라미터 테스트 → area 분포 로그 출력
  Future<void> _diagAreaTest({
    required String label,
    required String serviceKey,
    required Map<String, String> params,
  }) async {
    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'serviceKey': serviceKey,
        ...params,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final body = utf8.decode(response.bodyBytes);
      final doc = XmlDocument.parse(body);
      final items = doc.findAllElements('item').toList();
      // area 분포 집계
      final areaCounts = <String, int>{};
      for (final item in items) {
        String nodeText(String tag) {
          final el = item.getElement(tag);
          if (el == null) return '';
          return el.children.whereType<XmlText>().map((n) => n.value).join().trim();
        }
        final area = nodeText('area');
        if (area.isNotEmpty) areaCounts[area] = (areaCounts[area] ?? 0) + 1;
      }
      if (kDebugMode) {
        print('EXH-DIAG: $label → itemCount=${items.length} area counts=$areaCounts');
      }
    } catch (e) {
      if (kDebugMode) print('EXH-DIAG: $label → ERROR=$e');
    }
  }

  // ── 내부 메서드 ────────────────────────────────────────────────────────────

  /// 지정된 페이지 목록을 순차 호출하여 raw XmlElement 리스트 반환
  Future<List<XmlElement>> _fetchPages({
    required String serviceKey,
    required String sido,
    required String from,
    required String to,
    required List<int> pages,
    required String logTag,
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
          if (pageNo == pages.first) {
            print(
                'EXH-API: body head=${decodedBody.substring(0, decodedBody.length > 300 ? 300 : decodedBody.length)}');
          }
        }

        if (response.statusCode != 200) {
          dev.log('[ExhibitionApi] HTTP ${response.statusCode} on page $pageNo',
              name: 'Exhibition');
          break;
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

        // 샘플 로그 (각 페이지 첫 번째 item)
        if (kDebugMode) {
          final item = items.first;
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
          final area = nodeText('area');
          final seq = nodeText('seq');
          print('EXH-API: pageNo=$pageNo sample realm=[$realm] title=[$title] area=[$area] seq=[$seq]');

          // 링크 필드 확인 (pageNo=1만)
          if (pageNo == 1) {
            final url = nodeText('url');
            final homepage = nodeText('homepage');
            final detailUrl = nodeText('detailUrl');
            final referenceUrl = nodeText('referenceUrl');
            final link = nodeText('link');
            print('EXH-API: link fields url=[$url] homepage=[$homepage] detailUrl=[$detailUrl] referenceUrl=[$referenceUrl] link=[$link]');
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

  /// raw XmlElement 리스트 → 모델 변환 + 중복 seq 제거 + allowedRealms 필터
  /// [excludeSeqs]: 이미 처리된 seq 집합 (추가 페이지 중복 방지용)
  /// [logTag]: 로그 구분용 태그 (예: '1-3', '4-5')
  List<Exhibition> deduplicateAndFilter(
    List<XmlElement> rawItems, {
    Set<String>? excludeSeqs,
    String logTag = '',
  }) {
    final seen = <String>{...?excludeSeqs};
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
      final tag = logTag.isNotEmpty ? ' pages=$logTag' : '';
      print('EXH-API:$tag realm counts=$realmCounts');
      print('EXH-API:$tag area counts=$areaCounts');
      print('EXH-API:$tag allowed realm filter=${result.length}');
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
