import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/auth_required_exception.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/comment.dart';

/// 댓글 + 인앱 알림 저장소.
///
/// 핵심 원칙:
/// - 알림 row는 DB 트리거가 자동 생성 → 앱에서 notifications에 직접 INSERT 금지
/// - 앱은 notifications 조회 + is_read UPDATE만 수행
/// - 댓글 삭제는 status='removed' 소프트 삭제 (리뷰 패턴과 일관)
class CommentRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  String get _requireUserId {
    final uid = _userId;
    if (uid == null) throw const AuthRequiredException();
    return uid;
  }

  // ── 댓글 조회 ────────────────────────────────────────────────────────────

  /// 특정 리뷰의 published 댓글 목록 (작성자 프로필 조인, created_at ASC)
  Future<List<Comment>> fetchCommentsForReview(String reviewId) async {
    final response = await _client
        .from('comments')
        .select('*, profiles(nickname, avatar_url, avatar_storage_path)')
        .eq('review_id', reviewId)
        .eq('status', 'published')
        .order('created_at', ascending: true);
    return (response as List).map((e) => Comment.fromJson(e)).toList();
  }

  /// 특정 리뷰의 댓글 수 (published만)
  Future<int> fetchCommentCount(String reviewId) async {
    final response = await _client
        .from('comments')
        .select('id')
        .eq('review_id', reviewId)
        .eq('status', 'published');
    return (response as List).length;
  }

  /// R12: 여러 리뷰의 댓글 수 일괄 조회 (N+1 방지)
  /// 반환: { reviewId → count }
  Future<Map<String, int>> fetchCommentCounts(List<String> reviewIds) async {
    if (reviewIds.isEmpty) return {};
    // Supabase PostgREST: review_id=in.(id1,id2,...) + status=eq.published
    // group by는 PostgREST에서 직접 지원하지 않으므로
    // id 컬럼만 가져와서 Dart에서 집계한다.
    final response = await _client
        .from('comments')
        .select('review_id')
        .inFilter('review_id', reviewIds)
        .eq('status', 'published');
    final counts = <String, int>{};
    for (final row in (response as List)) {
      final rid = row['review_id'] as String;
      counts[rid] = (counts[rid] ?? 0) + 1;
    }
    return counts;
  }

  // ── 댓글 작성 ────────────────────────────────────────────────────────────

  /// 댓글 작성.
  /// - 알림은 DB 트리거(notify_review_author_on_comment)가 자동 생성
  /// - 앱에서 notifications에 직접 INSERT 금지
  Future<Comment> createComment({
    required String reviewId,
    required String content,
  }) async {
    final uid = _requireUserId;

    final response = await _client
        .from('comments')
        .insert({
          'review_id': reviewId,
          'user_id': uid,
          'content': content.trim(),
          'status': 'published',
        })
        .select('*, profiles(nickname, avatar_url, avatar_storage_path)')
        .single();
    return Comment.fromJson(response);
  }

  // ── 댓글 수정 ────────────────────────────────────────────────────────────

  /// 댓글 수정 (본인만, RLS 보장)
  Future<Comment> updateComment({
    required String commentId,
    required String content,
  }) async {
    _requireUserId;

    final response = await _client
        .from('comments')
        .update({
          'content': content.trim(),
          // updated_at은 DB 트리거(trg_comments_updated_at)가 자동 갱신
        })
        .eq('id', commentId)
        .select('*, profiles(nickname, avatar_url, avatar_storage_path)')
        .single();
    return Comment.fromJson(response);
  }

  // ── 댓글 삭제 ────────────────────────────────────────────────────────────

  /// 댓글 소프트 삭제 (status='removed', 본인만, RLS 보장)
  Future<void> deleteComment(String commentId) async {
    _requireUserId;

    await _client
        .from('comments')
        .update({'status': 'removed'})
        .eq('id', commentId);
  }

  // ── 알림 조회 ────────────────────────────────────────────────────────────

  /// 내 알림 목록 (최신 50건, 읽지 않은 것 우선)
  Future<List<AppNotification>> fetchMyNotifications() async {
    final uid = _userId;
    if (uid == null) return [];

    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('is_read', ascending: true)
        .order('created_at', ascending: false)
        .limit(50);
    return (response as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  /// 읽지 않은 알림 수 (뱃지 표시용)
  Future<int> fetchUnreadCount() async {
    final uid = _userId;
    if (uid == null) return 0;

    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .eq('is_read', false);
    return (response as List).length;
  }

  // ── 알림 읽음 처리 ────────────────────────────────────────────────────────

  /// 단건 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    _requireUserId;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// 전체 알림 읽음 처리
  Future<void> markAllAsRead() async {
    final uid = _requireUserId;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }
}
