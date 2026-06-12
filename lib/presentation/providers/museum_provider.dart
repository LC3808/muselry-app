import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/museum_repository.dart';
import '../../domain/models/museum.dart';

// ─── Repository Provider ───────────────────────────────────────────────────
final museumRepositoryProvider = Provider<MuseumRepository>((ref) {
  return MuseumRepository();
});

/// M3: 정렬 기준 열거형
/// - relevance: 관련도 (검색어 있을 때 1차, 없으면 거리 fallback)
/// - distance:  거리순 (위치 허용 시)
/// - popularity: 인기순 (static_visitor_count)
/// - rating:    별점순 (bayesian_score DESC)
enum SortOrder { relevance, distance, popularity, rating }

// ─── 검색/필터 상태 ─────────────────────────────────────────────────────────
class ExploreFilter {
  final String searchQuery;
  final String selectedRegion;
  final String selectedType;
  /// 운영 필터: '전체' / '공공' / '민간' (v1.8)
  final String selectedOwnership;
  /// 추천 태그: 어린이 친화 (Day 9, v1.8에서 추천 태그 줄로 분리)
  final bool isKidsFriendly;
  /// 추천 태그: 무료 관람 (v1.9 이슈 7)
  final bool isFree;
  /// M3: 정렬 기준
  final SortOrder sortOrder;

  const ExploreFilter({
    this.searchQuery = '',
    this.selectedRegion = '전체',
    this.selectedType = '전체',
    this.selectedOwnership = '전체',
    this.isKidsFriendly = false,
    this.isFree = false,
    this.sortOrder = SortOrder.relevance,
  });

  ExploreFilter copyWith({
    String? searchQuery,
    String? selectedRegion,
    String? selectedType,
    String? selectedOwnership,
    bool? isKidsFriendly,
    bool? isFree,
    SortOrder? sortOrder,
  }) {
    return ExploreFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedRegion: selectedRegion ?? this.selectedRegion,
      selectedType: selectedType ?? this.selectedType,
      selectedOwnership: selectedOwnership ?? this.selectedOwnership,
      isKidsFriendly: isKidsFriendly ?? this.isKidsFriendly,
      isFree: isFree ?? this.isFree,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get hasActiveFilter =>
      searchQuery.isNotEmpty ||
      selectedRegion != '전체' ||
      selectedType != '전체' ||
      selectedOwnership != '전체' ||
      isKidsFriendly ||
      isFree;
}

// ─── 필터 Notifier ──────────────────────────────────────────────────────────
class ExploreFilterNotifier extends StateNotifier<ExploreFilter> {
  ExploreFilterNotifier() : super(const ExploreFilter());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setRegion(String region) {
    state = state.copyWith(selectedRegion: region);
  }

  void setType(String type) {
    state = state.copyWith(selectedType: type);
  }

  /// 운영 필터 설정 (v1.8)
  void setOwnership(String ownership) {
    state = state.copyWith(selectedOwnership: ownership);
  }

  void setKidsFriendly(bool value) {
    state = state.copyWith(isKidsFriendly: value);
  }

  /// 무료 관람 필터 설정 (v1.9)
  void setFree(bool value) {
    state = state.copyWith(isFree: value);
  }

  /// M3: 정렬 기준 설정
  void setSortOrder(SortOrder order) {
    state = state.copyWith(sortOrder: order);
  }

  void reset() {
    state = const ExploreFilter();
  }
}

final exploreFilterProvider =
    StateNotifierProvider<ExploreFilterNotifier, ExploreFilter>((ref) {
  return ExploreFilterNotifier();
});

// ─── 페이지네이션 상태 ────────────────────────────────────────────────────────
class MuseumListState {
  final List<Museum> museums;
  final bool isLoading;
  final bool hasMore;
  final int currentOffset;
  final String? error;

  const MuseumListState({
    this.museums = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentOffset = 0,
    this.error,
  });

  MuseumListState copyWith({
    List<Museum>? museums,
    bool? isLoading,
    bool? hasMore,
    int? currentOffset,
    String? error,
  }) {
    return MuseumListState(
      museums: museums ?? this.museums,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentOffset: currentOffset ?? this.currentOffset,
      error: error,
    );
  }
}

// ─── 무한 스크롤 Notifier ────────────────────────────────────────────────────
class MuseumListNotifier extends StateNotifier<MuseumListState> {
  final MuseumRepository _repo;
  static const int _pageSize = 20;

  MuseumListNotifier(this._repo) : super(const MuseumListState());

  Future<void> loadInitial({
    String? searchQuery,
    String? region,
    String? type,
    String? ownership,
    bool? isKidsFriendly,
    bool? isFree,
    SortOrder sortOrder = SortOrder.relevance,
    // R1: 거리순 RPC용 좌표
    double? lat,
    double? lng,
  }) async {
    state = const MuseumListState(isLoading: true);
    try {
      List<Museum> museums;
      if (sortOrder == SortOrder.distance && lat != null && lng != null) {
        // R1: 좌표 있으면 RPC 호출
        museums = await _repo.fetchMuseumsByDistance(
          lat: lat,
          lng: lng,
          type: type,
          region1: region,
          kidsOnly: isKidsFriendly ?? false,
          isFree: isFree,
          search: searchQuery,
          limit: _pageSize,
          offset: 0,
        );
      } else {
        museums = await _repo.fetchMuseums(
          searchQuery: searchQuery,
          region: region,
          type: type,
          ownership: ownership,
          isKidsFriendly: isKidsFriendly,
          isFree: isFree,
          sortOrder: sortOrder,
          limit: _pageSize,
          offset: 0,
        );
      }
      state = MuseumListState(
        museums: museums,
        isLoading: false,
        hasMore: museums.length >= _pageSize,
        currentOffset: museums.length,
      );
    } catch (e) {
      state = MuseumListState(
        isLoading: false,
        hasMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMore({
    String? searchQuery,
    String? region,
    String? type,
    String? ownership,
    bool? isKidsFriendly,
    bool? isFree,
    SortOrder sortOrder = SortOrder.relevance,
    // R1: 거리순 RPC용 좌표
    double? lat,
    double? lng,
  }) async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);
    try {
      List<Museum> more;
      if (sortOrder == SortOrder.distance && lat != null && lng != null) {
        // R1: 거리순 페이지네이션도 RPC 호출
        more = await _repo.fetchMuseumsByDistance(
          lat: lat,
          lng: lng,
          type: type,
          region1: region,
          kidsOnly: isKidsFriendly ?? false,
          isFree: isFree,
          search: searchQuery,
          limit: _pageSize,
          offset: state.currentOffset,
        );
      } else {
        more = await _repo.fetchMuseums(
          searchQuery: searchQuery,
          region: region,
          type: type,
          ownership: ownership,
          isKidsFriendly: isKidsFriendly,
          isFree: isFree,
          sortOrder: sortOrder,
          limit: _pageSize,
          offset: state.currentOffset,
        );
      }
      state = state.copyWith(
        museums: [...state.museums, ...more],
        isLoading: false,
        hasMore: more.length >= _pageSize,
        currentOffset: state.currentOffset + more.length,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final museumListProvider =
    StateNotifierProvider.autoDispose<MuseumListNotifier, MuseumListState>(
        (ref) {
  final repo = ref.read(museumRepositoryProvider);
  return MuseumListNotifier(repo);
});

// ─── 지역 목록 Provider ──────────────────────────────────────────────────────
final regionsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(museumRepositoryProvider);
  return repo.fetchRegions();
});

// ─── 박물관 상세 Provider ────────────────────────────────────────────────────
final museumDetailProvider =
    FutureProvider.autoDispose.family<Museum?, String>((ref, id) async {
  final repo = ref.read(museumRepositoryProvider);
  return repo.fetchMuseumById(id);
});

// ─── 지도용 전체 박물관 Provider ─────────────────────────────────────────────
final mapMuseumsProvider = FutureProvider<List<Museum>>((ref) async {
  final repo = ref.read(museumRepositoryProvider);
  return repo.fetchAllForMap();
});

// ─── 인기 장소 Provider (Day 9) ─────────────────────────────────────────
final popularMuseumsProvider = FutureProvider<List<Museum>>((ref) async {
  final repo = ref.read(museumRepositoryProvider);
  return repo.fetchPopularMuseums(limit: 10);
});
