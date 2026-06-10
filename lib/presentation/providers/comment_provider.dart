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

// ── 댓글 CRUD Notifier ────────────────────────────────────────────────────────

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

class CommentListNotifier extends Notifier<CommentListState> {
  @override
  CommentListState build() => const CommentListState();

  CommentRepository get _repo => ref.read(commentRepositoryProvider);

  Future<void> fetchComments(String reviewId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final comments = await _repo.fetchCommentsForReview(reviewId);
      state = state.copyWith(comments: comments, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '댓글을 불러오지 못했어요.',
      );
    }
  }

  Future<void> addComment({
    required String reviewId,
    required String content,
  }) async {
    final comment = await _repo.createComment(
      reviewId: reviewId,
      content: content,
    );
    state = state.copyWith(
      comments: [...state.comments, comment],
    );
    // 알림 뱃지 갱신
    ref.invalidate(unreadNotificationCountProvider);
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
  }
}

final commentListProvider =
    NotifierProvider<CommentListNotifier, CommentListState>(
  CommentListNotifier.new,
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
