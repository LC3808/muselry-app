import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/museum_provider.dart';
import '../../providers/bookmark_provider.dart'; // bookmarkedIdsProvider, bookmarksProvider
import '../../widgets/museum/museum_card.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  // C4 수정: 검색 디바운싱 타이머 (350ms)
  Timer? _searchDebounce;

  // v1.9: 유형 필터 (기념관/전시관 제외)
  static const _typeFilters = ['전체', '박물관', '미술관', '과학관'];
  // v1.8: 운영 필터 (공공=국립+공립, 민간=사립+대학+기업)
  static const _ownershipFilters = ['전체', '공공', '민간'];

  @override
  void initState() {
    super.initState();
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitial();
    });
    // 무한 스크롤: 하단 200px 이내 진입 시 추가 로드
    _scrollController.addListener(_onScroll);
  }

  void _loadInitial() {
    final filter = ref.read(exploreFilterProvider);
    ref.read(museumListProvider.notifier).loadInitial(
          searchQuery: filter.searchQuery.isEmpty ? null : filter.searchQuery,
          region: filter.selectedRegion == '전체' ? null : filter.selectedRegion,
          type: filter.selectedType == '전체' ? null : filter.selectedType,
          ownership: filter.selectedOwnership == '전체' ? null : filter.selectedOwnership,
          isKidsFriendly: filter.isKidsFriendly ? true : null,
          isFree: filter.isFree ? true : null,
        );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    if (current >= maxScroll - 200) {
      final filter = ref.read(exploreFilterProvider);
      ref.read(museumListProvider.notifier).loadMore(
            searchQuery: filter.searchQuery.isEmpty ? null : filter.searchQuery,
            region: filter.selectedRegion == '전체' ? null : filter.selectedRegion,
            type: filter.selectedType == '전체' ? null : filter.selectedType,
            ownership: filter.selectedOwnership == '전체' ? null : filter.selectedOwnership,
            isKidsFriendly: filter.isKidsFriendly ? true : null,
            isFree: filter.isFree ? true : null,
          );
    }
  }

  void _onFilterChanged() {
    // 필터 변경 시 목록 초기화 후 재로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitial();
    });
  }

  // C4 수정: 검색 디바운싱 메서드
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(exploreFilterProvider.notifier).setSearchQuery(value);
      _onFilterChanged();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel(); // C4 수정: 타이머 정리
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(exploreFilterProvider);
    final listState = ref.watch(museumListProvider);
    final regionsAsync = ref.watch(regionsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ─── 앱바 + 검색바 ──────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: false,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            expandedHeight: 132,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(16, 60, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '탐색',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SearchBar(
                      controller: _searchController,
                      onChanged: _onSearchChanged, // C4 수정: 디바운싱 적용
                      onClear: () {
                        _searchController.clear();
                        ref
                            .read(exploreFilterProvider.notifier)
                            .setSearchQuery('');
                        _onFilterChanged();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── 지역 필터 ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: regionsAsync.when(
              data: (regions) => _RegionFilterBar(
                regions: regions,
                selectedRegion: filter.selectedRegion,
                onRegionSelected: (region) {
                  ref.read(exploreFilterProvider.notifier).setRegion(region);
                  _onFilterChanged();
                },
              ),
              loading: () => const SizedBox(height: 44),
              error: (_, __) => const SizedBox(height: 44),
            ),
          ),

          // ─── v1.8: 추천 태그 줄 (유형 필터와 분리) ──────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '추천 태그',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('아이와 함께'),
                        avatar: const Text('👶', style: TextStyle(fontSize: 14)),
                        selected: filter.isKidsFriendly,
                        onSelected: (val) {
                          ref.read(exploreFilterProvider.notifier).setKidsFriendly(val);
                          _onFilterChanged();
                        },
                        selectedColor: const Color(0xFF27AE60).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF27AE60),
                        labelStyle: TextStyle(
                          color: filter.isKidsFriendly
                              ? const Color(0xFF27AE60)
                              : Colors.grey[600],
                          fontSize: 13,
                          fontWeight: filter.isKidsFriendly
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: filter.isKidsFriendly
                                ? const Color(0xFF27AE60)
                                : Colors.grey[300]!,
                          ),
                        ),
                        backgroundColor: Colors.transparent,
                        showCheckmark: false,
                      ),
                      // v1.9 이슈 7: 무료 관람 태그
                      FilterChip(
                        label: const Text('무료 관람'),
                        avatar: const Text('🆓', style: TextStyle(fontSize: 14)),
                        selected: filter.isFree,
                        onSelected: (val) {
                          ref.read(exploreFilterProvider.notifier).setFree(val);
                          _onFilterChanged();
                        },
                        selectedColor: const Color(0xFF3498DB).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF3498DB),
                        labelStyle: TextStyle(
                          color: filter.isFree
                              ? const Color(0xFF3498DB)
                              : Colors.grey[600],
                          fontSize: 13,
                          fontWeight: filter.isFree
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: filter.isFree
                                ? const Color(0xFF3498DB)
                                : Colors.grey[300]!,
                          ),
                        ),
                        backgroundColor: Colors.transparent,
                        showCheckmark: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── v1.8: 유형 필터 줄 (museums.type 기준) ────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '유형',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _TypeFilterBar(
              types: _typeFilters,
              selectedType: filter.selectedType,
              onTypeSelected: (type) {
                ref.read(exploreFilterProvider.notifier).setType(type);
                _onFilterChanged();
              },
            ),
          ),

          // ─── v1.8: 운영 필터 줄 (공공/민간 그룹핑) ─────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '운영',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _OwnershipFilterBar(
              ownerships: _ownershipFilters,
              selectedOwnership: filter.selectedOwnership,
              onOwnershipSelected: (ownership) {
                ref.read(exploreFilterProvider.notifier).setOwnership(ownership);
                _onFilterChanged();
              },
            ),
          ),

          // ─── 결과 수 + 필터 초기화 ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    listState.museums.isEmpty && listState.isLoading
                        ? '로딩 중...'
                        : '전 ${listState.museums.length}곳${listState.hasMore ? '+' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (filter.hasActiveFilter) ...[
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        ref.read(exploreFilterProvider.notifier).reset();
                        _onFilterChanged();
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '필터 초기화',
                        style:
                            TextStyle(color: Color(0xFFE8A87C), fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ─── 목록 ────────────────────────────────────────────────────────
          if (listState.museums.isEmpty && listState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (listState.museums.isEmpty && listState.error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('데이터를 불러올 수 없습니다'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadInitial,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            )
          else if (listState.museums.isEmpty)
            SliverFillRemaining(
              child: _EmptyState(
                query: filter.searchQuery,
                onReset: () {
                  _searchController.clear();
                  ref.read(exploreFilterProvider.notifier).reset();
                  _onFilterChanged();
                },
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final museum = listState.museums[index];
                  return Consumer(
                    builder: (context, ref, _) {
                      // W3 수정: bookmarkedIdsProvider로 O(1) 조회
                      final isBookmarked = ref
                          .watch(bookmarkedIdsProvider)
                          .contains(museum.id);
                      return MuseumCard(
                        museum: museum,
                        isBookmarked: isBookmarked,
                        onTap: () => context.push('/museum/${museum.id}'),
                        onBookmarkToggle: () {
                          ref
                              .read(bookmarksProvider.notifier)
                              .toggleBookmark(museum.id);
                        },
                      );
                    },
                  );
                },
                childCount: listState.museums.length,
              ),
            ),

          // ─── 하단 로딩 인디케이터 ────────────────────────────────────────
          if (listState.isLoading && listState.museums.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),

          // ─── 하단 여백 ───────────────────────────────────────────────────
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}

// ─── 검색바 ──────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar(
      {required this.controller,
      required this.onChanged,
      required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: '박물관, 미술관, 지역 검색',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon:
              Icon(Icons.search, color: Colors.grey[400], size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon:
                      Icon(Icons.close, color: Colors.grey[400], size: 18),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

// ─── 지역 필터 바 ─────────────────────────────────────────────────────────────
class _RegionFilterBar extends StatelessWidget {
  final List<String> regions;
  final String selectedRegion;
  final ValueChanged<String> onRegionSelected;

  const _RegionFilterBar(
      {required this.regions,
      required this.selectedRegion,
      required this.onRegionSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: regions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final region = regions[index];
          final isSelected = region == selectedRegion;
          return GestureDetector(
            onTap: () => onRegionSelected(region),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2C3E50)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                region,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── 유형 필터 바 ─────────────────────────────────────────────────────────────
class _TypeFilterBar extends StatelessWidget {
  final List<String> types;
  final String selectedType;
  final ValueChanged<String> onTypeSelected;

  const _TypeFilterBar(
      {required this.types,
      required this.selectedType,
      required this.onTypeSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = types[index];
          final isSelected = type == selectedType;
          return GestureDetector(
            onTap: () => onTypeSelected(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE8A87C).withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFE8A87C)
                      : Colors.grey[300]!,
                ),
              ),
              child: Text(
                type,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFE8A87C)
                      : Colors.grey[600],
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── v1.8: 운영 필터 바 ───────────────────────────────────────────────────────
/// 운영 주체 그룹핑 필터: 전체 / 공공(국립+공립) / 민간(사립+대학+기업)
/// DB ownership 원본 값은 유지하며 UI에서만 그룹핑 표시.
class _OwnershipFilterBar extends StatelessWidget {
  final List<String> ownerships;
  final String selectedOwnership;
  final ValueChanged<String> onOwnershipSelected;

  const _OwnershipFilterBar({
    required this.ownerships,
    required this.selectedOwnership,
    required this.onOwnershipSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: ownerships.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final ownership = ownerships[index];
          final isSelected = ownership == selectedOwnership;
          // 운영 필터 색상: 남색 계열로 유형 필터(주황)와 시각적 구분
          const activeColor = Color(0xFF1565C0);
          return GestureDetector(
            onTap: () => onOwnershipSelected(ownership),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? activeColor : Colors.grey[300]!,
                ),
              ),
              child: Text(
                ownership,
                style: TextStyle(
                  color: isSelected ? activeColor : Colors.grey[600],
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── 빈 상태 ──────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String query;
  final VoidCallback onReset;

  const _EmptyState({required this.query, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            query.isNotEmpty
                ? '"$query" 검색 결과가 없습니다'
                : '조건에 맞는 박물관이 없습니다',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onReset, child: const Text('전체 보기')),
        ],
      ),
    );
  }
}
