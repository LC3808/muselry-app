import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../domain/models/bookmark.dart';

// ─── Repository Provider ───────────────────────────────────────────────────
final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository();
});

// ─── Bookmarks Notifier ─────────────────────────────────────────────────────
class BookmarksNotifier extends AsyncNotifier<List<Bookmark>> {
  @override
  Future<List<Bookmark>> build() async {
    final repo = ref.read(bookmarkRepositoryProvider);
    return repo.fetchMyBookmarks();
  }

  /// 북마크 토글 (추가/삭제)
  Future<void> toggleBookmark(String museumId) async {
    final repo = ref.read(bookmarkRepositoryProvider);
    final current = state.valueOrNull ?? [];
    final isAlreadyBookmarked = current.any((b) => b.museumId == museumId);

    // 낙관적 업데이트: UI 즉시 반영
    if (isAlreadyBookmarked) {
      state = AsyncData(current.where((b) => b.museumId != museumId).toList());
      try {
        await repo.removeBookmark(museumId);
      } catch (e) {
        // 실패 시 롤백
        state = AsyncData(current);
        rethrow;
      }
    } else {
      try {
        final newBookmark = await repo.addBookmark(museumId);
        state = AsyncData([newBookmark, ...current]);
      } catch (e) {
        // 실패 시 상태 유지
        rethrow;
      }
    }
  }

  /// 북마크 목록 새로고침
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(bookmarkRepositoryProvider);
      return repo.fetchMyBookmarks();
    });
  }

  /// 특정 박물관 북마크 여부
  bool isBookmarked(String museumId) {
    return state.valueOrNull?.any((b) => b.museumId == museumId) ?? false;
  }
}

final bookmarksProvider =
    AsyncNotifierProvider<BookmarksNotifier, List<Bookmark>>(() {
  return BookmarksNotifier();
});

// ─── W3 수정: bookmarkedIds Set Provider (O(1) 조회 성능 개선) ──────────────────────
final bookmarkedIdsProvider = Provider<Set<String>>((ref) {
  final bookmarks = ref.watch(bookmarksProvider).valueOrNull ?? [];
  return bookmarks.map((b) => b.museumId).toSet();
});

// ─── 단일 박물관 북마크 여부 Provider (bookmarkedIdsProvider 기반으로 개선) ──────────────────────
final isBookmarkedProvider = Provider.family<bool, String>((ref, museumId) {
  // W3 수정: Set 기반 O(1) 조회
  return ref.watch(bookmarkedIdsProvider).contains(museumId);
});
