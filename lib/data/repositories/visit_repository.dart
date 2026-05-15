import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/auth_required_exception.dart';
import '../../core/errors/duplicate_visit_exception.dart';
import '../../domain/models/visit.dart';

class VisitRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  String get _requireUserId {
    final uid = _userId;
    if (uid == null) throw const AuthRequiredException();
    return uid;
  }

  /// 내 방문 기록 전체 조회 (Museum 정보 조인, visited_at DESC)
  Future<List<Visit>> fetchMyVisits() async {
    final uid = _userId;
    if (uid == null) return [];
    final response = await _client
        .from('visits')
        .select('*, museums(*)')
        .eq('user_id', uid)
        .order('visited_at', ascending: false)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Visit.fromJson(e)).toList();
  }

  /// 특정 박물관의 내 방문 기록 조회 (visited_at DESC)
  Future<List<Visit>> fetchVisitsForMuseum(String museumId) async {
    final uid = _userId;
    if (uid == null) return [];
    final response = await _client
        .from('visits')
        .select()
        .eq('user_id', uid)
        .eq('museum_id', museumId)
        .order('visited_at', ascending: false)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Visit.fromJson(e)).toList();
  }

  /// 방문 기록 추가 (rating 제거 — v1.10 정책: 별점은 review에만)
  /// visited_at은 'yyyy-MM-dd' 문자열로 전송 (DATE 타입 캐스팅 에러 방지)
  Future<Visit> addVisit({
    required String museumId,
    required DateTime visitedAt,
    String? privateNote,
  }) async {
    final uid = _requireUserId;
    final payload = {
      'user_id': uid,
      'museum_id': museumId,
      'visited_at': _formatDate(visitedAt),
      // rating은 항상 NULL (DB 기본값) — v1.10 정책
      if (privateNote != null && privateNote.isNotEmpty)
        'private_note': privateNote,
    };
    try {
      final response = await _client
          .from('visits')
          .insert(payload)
          .select('*, museums(*)')
          .single();
      return Visit.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // UNIQUE 제약 위반 = 같은 날 같은 박물관 중복
        throw const DuplicateVisitException();
      }
      rethrow;
    }
  }

  /// 방문 기록 삭제 (visitId 기준)
  Future<void> deleteVisit(String visitId) async {
    _requireUserId; // 인증 확인
    await _client.from('visits').delete().eq('id', visitId);
  }

  /// 방문한 박물관 ID Set 조회 (O(1) lookup용, 중복 제거)
  Future<Set<String>> fetchVisitedMuseumIds() async {
    final uid = _userId;
    if (uid == null) return {};
    final response = await _client
        .from('visits')
        .select('museum_id')
        .eq('user_id', uid);
    return (response as List)
        .map((e) => e['museum_id'] as String)
        .toSet();
  }

  /// 총 방문 횟수 (중복 포함)
  Future<int> countVisits() async {
    final uid = _userId;
    if (uid == null) return 0;
    final response = await _client
        .from('visits')
        .select()
        .eq('user_id', uid)
        .count(CountOption.exact);
    return response.count;
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
