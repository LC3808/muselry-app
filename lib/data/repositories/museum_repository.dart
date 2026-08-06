import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/museum.dart';
import '../../presentation/providers/museum_provider.dart';

class MuseumRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// 전체 박물관 목록 조회 (검색 + 필터 + 정렬 지원)
  ///
  /// M3 정렬 기준:
  /// - relevance: 검색어 있을 때 관련도(name 우선), 없으면 name ASC
  /// - distance:  위치 기반 거리순 (DB 지원 없어 name ASC fallback)
  /// - popularity: static_visitor_count DESC (NULL last)
  /// - rating:    bayesian_score DESC, review_count DESC (리뷰 0건 하단)
  Future<List<Museum>> fetchMuseums({
    String? searchQuery,
    String? region,
    String? type,
    /// 운영 필터: '공공' = 국립+공립, '민간' = 사립+대학+기업 (v1.8)
    String? ownership,
    bool? isKidsFriendly,
    /// 무료 관람 필터 (v1.9 이슈 7): true이면 is_free=true 조건 추가
    bool? isFree,
    /// M3: 정렬 기준
    SortOrder sortOrder = SortOrder.relevance,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('museums')
        .select()
        .eq('is_active', true);

    // W2 수정: 검색어 sanitize (trim + 최대 50자 제한)
    // M9-2: name 필드만 매칭 (description/address 제외 — 무관련 결과 노출 방지)
    String? sanitizedQuery;
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.trim();
      final sanitized = q.length > 50 ? q.substring(0, 50) : q;
      if (sanitized.isNotEmpty) {
        sanitizedQuery = sanitized;
        query = query.ilike('name', '%$sanitized%'); // M9-2: name 매칭만
      }
    }

    if (region != null && region != '전체') {
      query = query.eq('region_1', region);
    }

    if (type != null && type != '전체') {
      query = query.ilike('type', '%$type%');
    }

    // v1.8: 운영 필터 (공공/민간 그룹핑 → DB ownership 원본 값 매핑)
    if (ownership != null && ownership != '전체') {
      if (ownership == '공공') {
        query = query.inFilter('ownership', ['국립', '공립']);
      } else if (ownership == '민간') {
        query = query.inFilter('ownership', ['사립', '대학', '기업']);
      }
    }

    // T4 사이클 1.5: kids_category 기준으로 통일
    if (isKidsFriendly == true) {
      query = query.not('kids_category', 'is', null);
    }

    // v1.9: 무료 관람 필터
    if (isFree == true) {
      query = query.eq('is_free', true);
    }

    // M3: 정렬 기준 적용 — order()는 PostgrestFilterBuilder에서 호출하면 PostgrestTransformBuilder 반환
    // 따라서 모든 filter 조건 적용 후 마지막에 order+range 체이닝
    final List<Museum> result;

    switch (sortOrder) {
      case SortOrder.rating:
        final response = await query
            .order('bayesian_score', ascending: false, nullsFirst: false)
            .order('review_count', ascending: false, nullsFirst: false)
            .order('average_rating', ascending: false, nullsFirst: false)
            .order('name', ascending: true)
            .range(offset, offset + limit - 1);
        result = (response as List).map((e) => Museum.fromJson(e)).toList();
        break;
      case SortOrder.popularity:
        final response = await query
            .order('static_popularity_rank', ascending: true, nullsFirst: false)
            .order('static_visitor_count', ascending: false, nullsFirst: false)
            .order('name', ascending: true)
            .range(offset, offset + limit - 1);
        result = (response as List).map((e) => Museum.fromJson(e)).toList();
        break;
      case SortOrder.distance:
        // R1: RPC 호출 전 fallback 안전망 (lat/lng 없으면 relevance로 fallback)
        // 실제 distance 호출은 fetchMuseumsByDistance() 사용
        final response = await query
            .order('name', ascending: true)
            .range(offset, offset + limit - 1);
        result = (response as List).map((e) => Museum.fromJson(e)).toList();
        break;
      case SortOrder.relevance:
        final response = await query
            .order('name', ascending: true)
            .range(offset, offset + limit - 1);
        result = (response as List).map((e) => Museum.fromJson(e)).toList();
        break;
    }

    // M9-2: 검색어 있을 때 relevance 모드에서 클라이언트 재정렬
    // ① name이 검색어로 시작하는 항목 우선
    // ② name에 검색어가 포함되는 항목
    if (sanitizedQuery != null && sanitizedQuery.isNotEmpty && sortOrder == SortOrder.relevance) {
      final kw = sanitizedQuery.toLowerCase();
      result.sort((a, b) {
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        final aStarts = aName.startsWith(kw) ? 0 : 1;
        final bStarts = bName.startsWith(kw) ? 0 : 1;
        if (aStarts != bStarts) return aStarts - bStarts;
        return aName.compareTo(bName);
      });
    }

    return result;
  }

  /// R1: 거리순 RPC 호출 (museums_by_distance)
  ///
  /// 운영자가 적용한 RPC를 호출하여 하버사인 거리 오름차순으로 반환.
  /// RETURNS SETOF museums 이므로 기존 Museum.fromJson 그대로 파싱 가능.
  Future<List<Museum>> fetchMuseumsByDistance({
    required double lat,
    required double lng,
    String? type,
    String? region1,
    String? region2,
    bool kidsOnly = false,
    bool? isFree,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'p_lat': lat,
      'p_lng': lng,
      'p_limit': limit,
      'p_offset': offset,
    };
    if (type != null) params['p_type'] = type;
    if (region1 != null) params['p_region_1'] = region1;
    if (region2 != null) params['p_region_2'] = region2;
    if (kidsOnly) params['p_kids_only'] = true;
    if (isFree != null) params['p_is_free'] = isFree;
    if (search != null && search.isNotEmpty) params['p_search'] = search;

    final response = await _client.rpc('museums_by_distance', params: params);
    return (response as List).map((e) => Museum.fromJson(e)).toList();
  }

  /// 박물관 상세 조회
  Future<Museum?> fetchMuseumById(String id) async {
    final response = await _client
        .from('museums')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Museum.fromJson(response);
  }

  /// 지역 목록 조회 (v1.10: 행정구역 순서 고정)
  static const _regionOrder = [
    '서울', '경기', '인천',
    '부산', '대구', '대전', '광주', '울산', '세종',
    '강원', '충북', '충남', '전북', '전남', '경북', '경남', '제주',
  ];

  Future<List<String>> fetchRegions() async {
    final response = await _client
        .from('museums')
        .select('region_1')
        .eq('is_active', true);

    final dbRegions = (response as List)
        .map((e) => e['region_1'] as String)
        .toSet();

    final ordered = [
      ..._regionOrder.where((r) => dbRegions.contains(r)),
      ...dbRegions.where((r) => !_regionOrder.contains(r)).toList()..sort(),
    ];

    return ['전체', ...ordered];
  }

  /// ID 목록으로 박물관 일괄 조회 (북마크 목록 등에서 사용)
  Future<List<Museum>> fetchMuseumsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final response = await _client
        .from('museums')
        .select()
        .inFilter('id', ids)
        .eq('is_active', true)
        .order('name', ascending: true);

    return (response as List).map((e) => Museum.fromJson(e)).toList();
  }

  /// 인기 장소 조회 (v1.9 이슈 3: 정적 랭킹 우선, NULL은 average_rating 기준 후순위)
  Future<List<Museum>> fetchPopularMuseums({int limit = 10}) async {
    final response = await _client
        .from('museums')
        .select()
        .eq('is_active', true)
        .order('static_popularity_rank', ascending: true, nullsFirst: false)
        .order('average_rating', ascending: false, nullsFirst: false)
        .limit(limit);
    return (response as List).map((e) => Museum.fromJson(e)).toList();
  }

  /// 지도용 전체 박물관 조회 (좌표 있는 것만, 최대 1000건)
  Future<List<Museum>> fetchAllForMap() async {
    final response = await _client
        .from('museums')
        .select()
        .eq('is_active', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .order('name', ascending: true)
        .limit(1000);
    return (response as List).map((e) => Museum.fromJson(e)).toList();
  }

  /// 지도용 검색 결과 조회 (M4: 지도 탭 내 검색)
  Future<List<Museum>> searchForMap(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    final sanitized = q.length > 50 ? q.substring(0, 50) : q;

    final response = await _client
        .from('museums')
        .select()
        .eq('is_active', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .or('name.ilike.%$sanitized%,address.ilike.%$sanitized%,region_1.ilike.%$sanitized%')
        .order('name', ascending: true)
        .limit(limit);

    return (response as List).map((e) => Museum.fromJson(e)).toList();
  }

  // museum_aliases 메모리 캐시 (세션 내 재사용)
  // 키: normalized_alias, 값: museum_id
  Map<String, String>? _aliasCache;

  /// museum_aliases 테이블에서 alias 매핑 로드 (normalized_alias → museum_id)
  /// 이미 로드된 경우 캐시 반환
  Future<Map<String, String>> _loadAliases() async {
    if (_aliasCache != null) return _aliasCache!;
    try {
      final response = await _client
          .from('museum_aliases')
          .select('normalized_alias, museum_id');
      _aliasCache = {
        for (final row in response as List)
          (row['normalized_alias'] as String): (row['museum_id'] as String),
      };
    } catch (_) {
      _aliasCache = {};
    }
    return _aliasCache!;
  }

  /// 문화행사 장소명으로 museums 테이블에서 정규화 일치 조회
  /// normalize(s) = 공백 전부 제거 + trim
  /// 1차: normalize(place) == normalize(museum.name) 정확일치
  /// 2차: normalize(place) == normalize(museum.name) 정규화 일치 (대소문자 동일)
  /// 3차: museum_aliases.normalized_alias 일치 (DB 기반, 코드 내부 Map 제거)
  /// 실패 시 null 반환 + kDebugMode 미매칭 로그
  Future<Museum?> findMuseumByName(String place) async {
    final normalized = place.replaceAll(' ', '').trim();
    if (normalized.isEmpty) return null;
    try {
      // museums 목록 로드
      final response = await _client
          .from('museums')
          .select()
          .eq('is_active', true)
          .limit(500);
      final museums = (response as List).map((e) => Museum.fromJson(e)).toList();

      // 1차: 정확일치 (name 원본)
      for (final m in museums) {
        if (m.name == place.trim()) return m;
      }
      // 2차: 정규화 일치 (normalize 후 비교)
      for (final m in museums) {
        final mNorm = m.name.replaceAll(' ', '').trim();
        if (mNorm == normalized) return m;
      }

      // 3차: museum_aliases DB 룩업
      final aliases = await _loadAliases();
      final museumId = aliases[normalized];
      if (museumId != null) {
        for (final m in museums) {
          if (m.id == museumId) return m;
        }
      }

      // 미매칭 로그 (kDebugMode)
      if (kDebugMode) {
        // ignore: avoid_print
        print('EXH: unmatched place=$place');
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
