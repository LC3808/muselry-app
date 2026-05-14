import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/museum.dart';

class MuseumRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// 전체 박물관 목록 조회 (검색 + 필터 지원)
  Future<List<Museum>> fetchMuseums({
    String? searchQuery,
    String? region,
    String? type,
    /// 운영 필터: '공공' = 국립+공립, '민간' = 사립+대학+기업 (v1.8)
    String? ownership,
    bool? isKidsFriendly,
    /// 무료 관람 필터 (v1.9 이슈 7): true이면 is_free=true 조건 추가
    bool? isFree,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('museums')
        .select()
        .eq('is_active', true);

    // W2 수정: 검색어 sanitize (trim + 최대 50자 제한)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.trim();
      final sanitized = q.length > 50 ? q.substring(0, 50) : q;
      if (sanitized.isNotEmpty) {
        query = query.or('name.ilike.%$sanitized%,description.ilike.%$sanitized%,address.ilike.%$sanitized%');
      }
    }

    if (region != null && region != '전체') {
      query = query.eq('region_1', region);
    }

    if (type != null && type != '전체') {
      query = query.ilike('type', '%$type%');
    }

    // v1.8: 운영 필터 (공공/민간 그룹핑 → DB ownership 원본 값 매핑)
    // DB에는 국립/공립/사립/대학/기업 원본 값 유지, UI에서만 그룹핑
    if (ownership != null && ownership != '전체') {
      if (ownership == '공공') {
        query = query.inFilter('ownership', ['국립', '공립']);
      } else if (ownership == '민간') {
        query = query.inFilter('ownership', ['사립', '대학', '기업']);
      }
    }

    // Day 9: 어린이 친화 필터
    if (isKidsFriendly == true) {
      query = query.eq('is_kids_friendly', true);
    }

    // v1.9: 무료 관람 필터 (is_free 콼럼 기반)
    if (isFree == true) {
      query = query.eq('is_free', true);
    }

    final response = await query
        .order('name', ascending: true)
        .range(offset, offset + limit - 1);

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

  /// 지역 목록 조회
  Future<List<String>> fetchRegions() async {
    final response = await _client
        .from('museums')
        .select('region_1')
        .eq('is_active', true);

    final regions = (response as List)
        .map((e) => e['region_1'] as String)
        .toSet()
        .toList()
      ..sort();

    return ['전체', ...regions];
  }

  /// ID 목록으로 박물관 일괄 조회 (북마크 목록 등에서 사용)
  ///
  /// [설계 근거]
  /// Supabase PostgREST에서 IN 필터는 `.in_('id', ids)` 사용.
  /// ids가 비어 있으면 빈 리스트 반환 (불필요한 API 호출 방지).
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

  /// 인기 박물관 조회 (v1.9 이슈 3: 정적 랭킹 우선, NULL은 average_rating 기준 후순위)
  ///
  /// 정렬 우선순위:
  ///   1. static_popularity_rank ASC (NULL last) — 통계청 방문객 기반 정적 순위
  ///   2. average_rating DESC (NULL last) — 리뷰 평점 기반 폴백
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
}
