import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/auth_required_exception.dart';
import '../../domain/models/review.dart';

/// 한국어 욕설/스팸/혐오 키워드 필터 (v1.4 명세서 6.1 PoC 결과: 키워드 필터 채택)
///
/// [선택 근거]
/// - 정확도 18/20 (90%), 평균 응답 0.02ms, 비용 $0
/// - Flutter 앱 내 Dart 코드로 처리 (오프라인 가능, 네트워크 지연 없음)
/// - OpenAI Moderation API는 RateLimitError 발생 및 네트워크 의존성 문제로 제외
/// - 향후 키워드 목록 확장 및 Edge Function 연동으로 고도화 가능
class KoreanContentFilter {
  static const List<String> _profanityKeywords = [
    '씨발', '시발', 'ㅅㅂ', '개같', '존나', 'ㅈ같', '병신', '개새끼',
    'ㅂㅅ', 'ㄲㅈ', '새끼', '지랄', '닥쳐', '꺼져', '죽어',
    'fuck', 'shit', 'bitch', 'asshole',
  ];

  static const List<String> _hateKeywords = [
    '조선족', '짱깨', '쪽바리', '흑형', '장애인들은', '노인네들은',
  ];

  // v1.9 이슈 10: 단순 substring 대신 정규식 기반 스팸 필터
  // 이유: '02-', '031-' 등이 일반 리덼 텍스트를 오탐으로 차단하는 문제 해결
  static final List<RegExp> _spamRegexPatterns = [
    // URL 형식 (example.com, test.co.kr 등)
    RegExp(r'[a-z0-9-]+\.(com|net|org|kr|co\.kr|co|io|app)\b', caseSensitive: false),
    // 전화번호 형식 (000-0000-0000)
    RegExp(r'\d{2,3}-\d{3,4}-\d{4}'),
    // 카카오톡 ID 형식
    RegExp(r'(?:카톡|카카오톡|kakao)\s*[::：]?\s*[a-z0-9_]{4,}', caseSensitive: false),
  ];

  /// 텍스트가 필터링 대상인지 확인.
  /// 반환값: null이면 정상, String이면 필터링 사유
  static String? check(String text) {
    final lower = text.toLowerCase();
    for (final kw in _profanityKeywords) {
      if (lower.contains(kw)) return '부적절한 표현이 포함되어 있습니다.';
    }
    for (final kw in _hateKeywords) {
      if (lower.contains(kw)) return '혁오 표현이 포함되어 있습니다.';
    }
    for (final regex in _spamRegexPatterns) {
      if (regex.hasMatch(text)) return '광고성 콘텐츠가 의심됩니다.';
    }
    return null;
  }

  /// 필터링 결과에 따른 status 결정
  static ReviewStatus determineStatus(String text) {
    final reason = check(text);
    return reason != null ? ReviewStatus.pendingReview : ReviewStatus.published;
  }
}

class ReviewRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  String get _requireUserId {
    final uid = _userId;
    if (uid == null) throw const AuthRequiredException();
    return uid;
  }

  // ── 조회 ──────────────────────────────────────────────────────────────────

  /// 단일 리뷰 조회 (R5: 알림 딥링크용)
  Future<Review?> fetchReviewById(String reviewId) async {
    final response = await _client
        .from('reviews')
        .select('*, profiles(nickname, avatar_url, avatar_storage_path)')
        .eq('id', reviewId)
        .eq('status', 'published')
        .maybeSingle();
    if (response == null) return null;
    return Review.fromJson(response);
  }

  Future<List<Review>> fetchReviewsForMuseum(
    String museumId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client
        .from('reviews')
        .select('*, profiles(nickname, avatar_url, avatar_storage_path)')
        .eq('museum_id', museumId)
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (response as List).map((e) => Review.fromJson(e)).toList();
  }

  /// 내 리뷰 전체 목록 (published + pending_review, Museum 조인, created_at DESC)
  Future<List<Review>> fetchMyReviews() async {
    final uid = _userId;
    if (uid == null) return [];
    final response = await _client
        .from('reviews')
        .select('*, museums(id, name, type, image_url, region_1)')
        .eq('user_id', uid)
        .inFilter('status', ['published', 'pending_review'])
        .order('created_at', ascending: false);
    return (response as List).map((e) => Review.fromJson(e)).toList();
  }

  /// 특정 박물관에 대한 내 리뷰 목록 (1방문 1리뷰 정책 확인용)
  /// v1.6: museum_id 기준 조회 유지 (여러 방문에 각각 리뷰 가능)
  Future<List<Review>> fetchMyReviewsForMuseum(String museumId) async {
    final uid = _userId;
    if (uid == null) return [];
    final response = await _client
        .from('reviews')
        .select('*, profiles(nickname, avatar_url, avatar_storage_path)')
        .eq('user_id', uid)
        .eq('museum_id', museumId)
        .not('status', 'eq', 'removed')
        .order('created_at', ascending: false);
    return (response as List).map((e) => Review.fromJson(e)).toList();
  }

  /// 특정 방문 기록에 대한 내 리뷰 (1방문 1리뷰 정책 확인용, v1.6)
  Future<Review?> fetchMyReviewForVisit(String visitId) async {
    final uid = _userId;
    if (uid == null) return null;
    final response = await _client
        .from('reviews')
        .select('*, profiles(nickname, avatar_url, avatar_storage_path)')
        .eq('user_id', uid)
        .eq('visit_id', visitId)
        .not('status', 'eq', 'removed')
        .maybeSingle();
    if (response == null) return null;
    return Review.fromJson(response);
  }

  /// 특정 박물관에 대한 내 리뷰 단건 조회 (하위 호환용, 가장 최근 리뷰 반환)
  /// @deprecated v1.6 이후 fetchMyReviewForVisit 사용 권장
  Future<Review?> fetchMyReviewForMuseum(String museumId) async {
    final reviews = await fetchMyReviewsForMuseum(museumId);
    return reviews.isEmpty ? null : reviews.first;
  }

  // ── 작성 ──────────────────────────────────────────────────────────────────

  /// 리뷰 작성 (v1.6: visitId 필수 파라미터 추가)
  /// - 클라이언트 사이드 필터링 후 status 결정 (published / pending_review)
  /// - average_rating / review_count는 DB 트리거가 자동 갱신 (클라이언트 직접 수정 금지)
  /// - 1방문 1리뷰: DB 부분 인덱스(reviews_unique_active_visit)로 강제
  Future<Review> createReview({
    required String museumId,
    required String visitId,
    required double rating,
    required String content,
    DateTime? visitedOn, // R27
  }) async {
    final uid = _requireUserId;

    // 콘텐츠 필터링
    final status = KoreanContentFilter.determineStatus(content);

    final payload = {
      'user_id': uid,
      'museum_id': museumId,
      'visit_id': visitId,
      'rating': rating,
      'content': content,
      'status': status.toJson(),
      if (visitedOn != null)
        'visited_on':
            '${visitedOn.year}-${visitedOn.month.toString().padLeft(2, '0')}-${visitedOn.day.toString().padLeft(2, '0')}',
    };

    final response = await _client
        .from('reviews')
        .insert(payload)
        .select('*, profiles(nickname, avatar_url, avatar_storage_path)')
        .single();
    return Review.fromJson(response);
  }

  // ── 수정 ──────────────────────────────────────────────────────────────────

  /// 리뷰 수정 (작성 후 7일 이내 본인만 가능, v1.6 명세서 6.3)
  /// - status는 재필터링하여 재결정
  /// - average_rating / review_count는 DB 트리거가 자동 갱신
  Future<Review> updateReview({
    required String reviewId,
    required double rating,
    required String content,
    DateTime? visitedOn, // R27
  }) async {
    _requireUserId;

    // 수정 시에도 콘텐츠 재필터링
    final status = KoreanContentFilter.determineStatus(content);

    final payload = {
      'rating': rating,
      'content': content,
      'status': status.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
      if (visitedOn != null)
        'visited_on':
            '${visitedOn.year}-${visitedOn.month.toString().padLeft(2, '0')}-${visitedOn.day.toString().padLeft(2, '0')}',
    };

    final response = await _client
        .from('reviews')
        .update(payload)
        .eq('id', reviewId)
        .select('*, profiles(nickname, avatar_url, avatar_storage_path)')
        .single();
    return Review.fromJson(response);
  }

  // ── 삭제 (소프트 삭제) ────────────────────────────────────────────────────

  /// 리뷰 소프트 삭제: status = 'removed' 처리 (v1.4 명세서 데이터 처리 원칙)
  /// - 실제 DELETE는 GDPR/개인정보보호법 대응 등 법적 요구 시에만 사용
  /// - average_rating / review_count는 DB 트리거가 자동 갱신 (removed 제외)
  Future<void> softDeleteReview(String reviewId) async {
    _requireUserId;
    await _client
        .from('reviews')
        .update({
          'status': 'removed',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reviewId);
  }

  // ── 신고 ──────────────────────────────────────────────────────────────────

  /// 리뷰 신고.
  /// - UNIQUE(review_id, reporter_id) 제약으로 중복 신고 차단 (DB 레벨)
  /// - 본인 리뷰 신고 금지 (RLS 레벨 + UI 레이어 분기)
  /// - 3건 누적 시 DB 트리거가 자동으로 status = 'hidden' 처리
  Future<void> reportReview({
    required String reviewId,
    required String reason, // 'spam' | 'inappropriate' | 'fake' | 'other'
  }) async {
    _requireUserId;
    await _client.from('review_reports').insert({
      'review_id': reviewId,
      'reason': reason,
      // reporter_id는 RLS WITH CHECK(reporter_id = auth.uid())가 처리
    });
  }

   // ── 커뮤니티 피드 (P0-2 픽스) ─────────────────────────────────────

  /// 커뮤니티 피드: 전체 published 리뷰 목록 (작성자+박물관 조인, 페이지 단위 20건)
  /// [page] 0부터 시작하는 페이지 번호
  Future<List<Review>> fetchCommunityReviews({int page = 0}) async {
    const pageSize = 20;
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final data = await _client
      .from('reviews')
      .select(
        'id, museum_id, user_id, visit_id, rating, content, status, created_at, updated_at, visited_on, '
        'profiles!user_id(nickname, avatar_url), '
        'museums!museum_id(id, name, region_1, image_url)',
      )
      .eq('status', 'published')
      .order('created_at', ascending: false)
      .range(from, to);
    return (data as List).map((e) => Review.fromJson(e)).toList();
  }

  // ── 좋아요 (Phase 1.5 예정) ───────────────────────────────────
  // TODO: review_likes 테이블 구현 (Phase 1.5)
}