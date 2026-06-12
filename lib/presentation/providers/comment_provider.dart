import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/comment_repository.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/comment.dart';

// ── Repository Provider ───────────────────────────────────────────────────────

final commentRepositoryProvider = Provider<CommentRepository>(
  (_) => CommentRepository(),
);

// ── 댓글 목록 (리뷰별) ────────────────────────────────────────────────────────

final commentsForReviewProvider = FutureProvider.family<List<Comment>, String>(
  (ref, reviewId) async {
    final repo = ref.watch(commentRepositoryProvider);
    return repo.fetchCommentsForReview(reviewId);
  },
);

// ── 댓글 CRUD Notifier (R25 fix: family로 변경 — review_id별 독립 인스턴스) ────────
//
// 버그 원인: 기존 commentListProvider는 NotifierProvider(싱글턴)였음.
// 여러 리뷰 카드가 동일 인스턴스를 watch하여 마지막 fetch된 댓글이 모든 카드에 표시됨.
// 수정: NotifierProvider.family<..., String>으로 변경 → review_id별 분리.

class CommentListState {
  final List<Comment> comments;
  final bool isLoading;
  final String? error;

  const CommentListState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
  });

  CommentListState copyWith({
    List<Comment>? comments,
    bool? isLoading,
    String? error,
  }) {
    return CommentListState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// R25 fix: FamilyNotifier — 각 review_id마다 독립 인스턴스 생성
class CommentListNotifier extends FamilyNotifier<CommentListState, String> {
  @override
  CommentListState build(String reviewId) => const CommentListState();

  CommentRepository get _repo => ref.read(commentRepositoryProvider);

  // arg == reviewId (build 인자)
  Future<void> fetchComments() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final comments = await _repo.fetchCommentsForReview(arg);
      state = state.copyWith(comments: comments, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '댓글을 불러오지 못했어요.',
      );
    }
  }

  Future<void> addComment({required String content}) async {
    final comment = await _repo.createComment(
      reviewId: arg,
      content: content,
    );
    state = state.copyWith(
      comments: [...state.comments, comment],
    );
    // 알림 뱃지 갱신
    ref.invalidate(unreadNotificationCountProvider);
    // R22 fix: 커뮤니티 피드 ↔ 시설 리뷰 목록 댓글 수 동기화
    ref.invalidate(commentCountsProvider);
  }

  Future<void> editComment({
    required String commentId,
    required String content,
  }) async {
    final updated = await _repo.updateComment(
      commentId: commentId,
      content: content,
    );
    state = state.copyWith(
      comments: state.comments
          .map((c) => c.id == commentId ? updated : c)
          .toList(),
    );
  }

  Future<void> removeComment(String commentId) async {
    await _repo.deleteComment(commentId);
    state = state.copyWith(
      comments: state.comments.where((c) => c.id != commentId).toList(),
    );
    // R22 fix: 댓글 삭제 후 커뮤니티 피드 ↔ 시설 리뷰 목록 댓글 수 동기화
    ref.invalidate(commentCountsProvider);
  }
}

// R25 fix: NotifierProvider → NotifierProvider.family (review_id 키)
final commentListProvider =
    NotifierProvider.family<CommentListNotifier, CommentListState, String>(
  CommentListNotifier.new,
);

// ── R12/R18: 댓글 수 일괄 조회 Provider ─────────────────────────────────────────

/// 리뷰 ID 목록(쉼표 join 문자열) → reviewId:count 맵 (단일 쿼리, N+1 방지)
/// R18: family 키를 String으로 변경 — List(String)은 == 인스턴스 비교라 캐시 미스 발생
final commentCountsProvider =
    FutureProvider.family<Map<String, int>, String>(
  (ref, reviewIdsKey) async {
    final repo = ref.watch(commentRepositoryProvider);
    final ids = reviewIdsKey.isEmpty ? <String>[] : reviewIdsKey.split(',');
    return repo.fetchCommentCounts(ids);
  },
);

// ── 알림 Providers ────────────────────────────────────────────────────────────

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final repo = ref.watch(commentRepositoryProvider);
  return repo.fetchMyNotifications();
});

final unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(commentRepositoryProvider);
  return repo.fetchUnreadCount();
});

class NotificationNotifier extends Notifier<AsyncValue<List<AppNotification>>> {
  @override
  AsyncValue<List<AppNotification>> build() => const AsyncValue.loading();

  CommentRepository get _repo => ref.read(commentRepositoryProvider);

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final list = await _repo.fetchMyNotifications();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(String id) async {
    await _repo.markAsRead(id);
    state.whenData((list) {
      state = AsyncValue.data(
        list.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
      );
    });
    ref.invalidate(unreadNotificationCountProvider);
  }

  Future<void> markAllAsRead() async {
    await _repo.markAllAsRead();
    state.whenData((list) {
      state = AsyncValue.data(
        list.map((n) => n.copyWith(isRead: true)).toList(),
      );
    });
    ref.invalidate(unreadNotificationCountProvider);
  }
}

final notificationNotifierProvider =
    NotifierProvider<NotificationNotifier, AsyncValue<List<AppNotification>>>(
  NotificationNotifier.new,
);
