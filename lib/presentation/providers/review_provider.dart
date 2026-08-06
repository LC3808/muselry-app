import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/review_repository.dart';
import '../../domain/models/review.dart';
import '../../data/repositories/review_image_repository.dart';
import '../../domain/models/review_image.dart';

// ─── Repository Provider ────────────────────────────────────────────────────
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository();
});

// ─── 박물관별 리뷰 목록 ─────────────────────────────────────────────────────

/// 특정 박물관의 published 리뷰 목록 (created_at DESC, 최대 20건)
final reviewsForMuseumProvider =
    FutureProvider.family.autoDispose<List<Review>, String>(
  (ref, museumId) async {
    final repo = ref.read(reviewRepositoryProvider);
    return repo.fetchReviewsForMuseum(museumId);
  },
);

/// 특정 박물관에 대한 내 리뷰 목록 (v1.6: 여러 방문에 각각 리뷰 가능)
final myReviewsForMuseumProvider =
    FutureProvider.family.autoDispose<List<Review>, String>(
  (ref, museumId) async {
    final repo = ref.read(reviewRepositoryProvider);
    return repo.fetchMyReviewsForMuseum(museumId);
  },
);

/// 특정 방문 기록에 대한 내 리뷰 (1방문 1리뷰 정책 확인용, v1.6)
final myReviewForVisitProvider =
    FutureProvider.family.autoDispose<Review?, String>(
  (ref, visitId) async {
    final repo = ref.read(reviewRepositoryProvider);
    return repo.fetchMyReviewForVisit(visitId);
  },
);

/// 특정 박물관에 대한 내 리뷰 단건 (하위 호환용, 가장 최근 리뷰)
/// @deprecated v1.6 이후 myReviewForVisitProvider 사용 권장
final myReviewForMuseumProvider =
    FutureProvider.family.autoDispose<Review?, String>(
  (ref, museumId) async {
    final repo = ref.read(reviewRepositoryProvider);
    return repo.fetchMyReviewForMuseum(museumId);
  },
);

// ─── 내 리뷰 전체 목록 ──────────────────────────────────────────────────────

/// 내 리뷰 전체를 관리하는 AsyncNotifier.
///
/// [설계 원칙]
/// - published + pending_review 상태만 포함 (removed/hidden 제외)
/// - 작성/수정/삭제 후 로컬 상태 즉시 갱신 (낙관적 업데이트)
/// - average_rating / review_count는 클라이언트에서 직접 수정하지 않음
///   (DB 트리거가 자동 갱신, v1.6 명세서 데이터 처리 원칙)
class MyReviewsNotifier extends AsyncNotifier<List<Review>> {
  @override
  Future<List<Review>> build() async {
    final repo = ref.read(reviewRepositoryProvider);
    return repo.fetchMyReviews();
  }

  /// 리뷰 작성 후 로컬 상태 갱신 (v1.6: visitId 필수)
  Future<Review> createReview({
    required String museumId,
    required String visitId,
    required double rating,
    required String content,
    DateTime? visitedOn, // R27
  }) async {
    final repo = ref.read(reviewRepositoryProvider);
    final newReview = await repo.createReview(
      museumId: museumId,
      visitId: visitId,
      rating: rating,
      content: content,
      visitedOn: visitedOn,
    );
    final current = state.valueOrNull ?? [];
    state = AsyncData([newReview, ...current]);
    return newReview;
  }

  /// 리뷰 수정 후 로컬 상태 갱신
  Future<Review> updateReview({
    required String reviewId,
    required double rating,
    required String content,
    DateTime? visitedOn, // R27
  }) async {
    final repo = ref.read(reviewRepositoryProvider);
    final updated = await repo.updateReview(
      reviewId: reviewId,
      rating: rating,
      content: content,
      visitedOn: visitedOn,
    );
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((r) => r.id == reviewId ? updated : r).toList(),
    );
    return updated;
  }

  /// 리뷰 소프트 삭제 후 로컬 상태에서 제거
  Future<void> deleteReview(String reviewId) async {
    final repo = ref.read(reviewRepositoryProvider);
    await repo.softDeleteReview(reviewId);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((r) => r.id != reviewId).toList());
  }

  /// 새로고침
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(reviewRepositoryProvider);
      return repo.fetchMyReviews();
    });
  }
}

final myReviewsProvider =
    AsyncNotifierProvider<MyReviewsNotifier, List<Review>>(() {
  return MyReviewsNotifier();
});

// ─── 박물관별 리뷰 관리 Notifier ─────────────────────────────────────────────

/// 특정 박물관의 리뷰 목록을 관리하는 Notifier.
/// 작성/수정/삭제 후 해당 박물관 리뷰 목록을 즉시 갱신.
class MuseumReviewsNotifier
    extends FamilyAsyncNotifier<List<Review>, String> {
  @override
  Future<List<Review>> build(String arg) async {
    final repo = ref.read(reviewRepositoryProvider);
    return repo.fetchReviewsForMuseum(arg);
  }

  /// 리뷰 작성 후 목록 앞에 추가
  void addReview(Review review) {
    if (review.status == ReviewStatus.published) {
      final current = state.valueOrNull ?? [];
      state = AsyncData([review, ...current]);
    }
    // pending_review 상태는 목록에 노출하지 않음
  }

  /// 리뷰 수정 후 목록 갱신
  void updateReview(Review updated) {
    final current = state.valueOrNull ?? [];
    if (updated.status == ReviewStatus.published) {
      state = AsyncData(
        current.map((r) => r.id == updated.id ? updated : r).toList(),
      );
    } else {
      // published → pending_review로 변경된 경우 목록에서 제거
      state = AsyncData(current.where((r) => r.id != updated.id).toList());
    }
  }

  /// 리뷰 삭제 후 목록에서 제거
  void removeReview(String reviewId) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((r) => r.id != reviewId).toList());
  }

  /// 새로고침
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(reviewRepositoryProvider);
      return repo.fetchReviewsForMuseum(arg);
    });
  }
}

final museumReviewsProvider =
    AsyncNotifierProviderFamily<MuseumReviewsNotifier, List<Review>, String>(
  () => MuseumReviewsNotifier(),
);

// ─── 커뮤니티 피드 (P0-2 픽스) ──────────────────────────────────────────────

/// 커뮤니티 피드 상태 모델
class CommunityReviewsState {
  final List<Review> reviews;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const CommunityReviewsState({
    this.reviews = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  CommunityReviewsState copyWith({
    List<Review>? reviews,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return CommunityReviewsState(
      reviews: reviews ?? this.reviews,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

/// 커뮤니티 피드 Notifier (무한 스크롤 + pull-to-refresh 지원)
class CommunityReviewsNotifier extends Notifier<CommunityReviewsState> {
  @override
  CommunityReviewsState build() {
    // 초기 빌드 시 첫 페이지 로드
    Future.microtask(() => fetchInitial());
    return const CommunityReviewsState();
  }

  /// 첫 페이지 로드 (pull-to-refresh 포함)
  Future<void> fetchInitial() async {
      state = state.copyWith(isLoading: true, error: null);
      try {
        final repo = ref.read(reviewRepositoryProvider);
        final reviews = await repo.fetchCommunityReviews(page: 0);
        state = CommunityReviewsState(
          reviews: reviews,
          isLoading: false,
          hasMore: reviews.length >= 20,
          currentPage: 0,
        );
      } catch (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }

  /// 다음 페이지 로드 (무한 스크롤)
  Future<void> fetchMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(reviewRepositoryProvider);
      final nextPage = state.currentPage + 1;
      final newReviews = await repo.fetchCommunityReviews(page: nextPage);
      state = state.copyWith(
        reviews: [...state.reviews, ...newReviews],
        isLoading: false,
        hasMore: newReviews.length >= 20,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final communityReviewsProvider =
    NotifierProvider<CommunityReviewsNotifier, CommunityReviewsState>(
  () => CommunityReviewsNotifier(),
);

// ─── v0.5.1: 리뷰 사진 Provider ─────────────────────────────────────────────

/// 특정 리뷰의 사진 목록 (display_order 오름차순)
final reviewImagesProvider =
    FutureProvider.family.autoDispose<List<ReviewImage>, String>(
  (ref, reviewId) async {
    final repo = ref.read(reviewImageRepositoryProvider);
    return repo.loadImages(reviewId);
  },
);

/// 여러 리뷰의 대표사진 일괄 조회 (커뮤니티/리뷰목록 카드용)
/// key: reviewIds를 join(',')한 문자열
final reviewThumbnailsProvider =
    FutureProvider.family.autoDispose<Map<String, ReviewImage>, String>(
  (ref, reviewIdsKey) async {
    if (reviewIdsKey.isEmpty) return {};
    final ids = reviewIdsKey.split(',');
    final repo = ref.read(reviewImageRepositoryProvider);
    return repo.loadThumbnails(ids);
  },
);
