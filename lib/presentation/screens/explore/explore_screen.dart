import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/museum_provider.dart';
import '../../providers/bookmark_provider.dart';
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
  // R3: ownership 필터 UI MVP 숨김 — 상수도 주석 처리
  // static const _ownershipFilters = ['전체', '공공', '민간'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitial();
    });
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
          sortOrder: filter.sortOrder,
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
            sortOrder: filter.sortOrder,
          );
    }
  }

  void _onFilterChanged() {
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
    _searchDebounce?.cancel();
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
                      onChanged: _onSearchChanged,
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

          // ─── R2: 지역 필터 (순서: 지역 → 유형 → 운영(MVP숨김) → 추천태그) ───
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

          // ─── R2: 유형 필터 ────────────────────────────────────────────
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
                  Wrap(
                    spacing: 8,
                    children: _typeFilters.map((t) {
                      final isSelected = filter.selectedType == t;
                      return ChoiceChip(
                        label: Text(t),
                        selected: isSelected,
                        onSelected: (_) {
                          ref.read(exploreFilterProvider.notifier).setType(t);
                          _onFilterChanged();
                        },
                        selectedColor: const Color(0xFF2C3E50).withValues(alpha: 0.12),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF2C3E50)
                              : Colors.grey[600],
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF2C3E50)
                                : Colors.grey.shade300,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  // R3: 공공/민간(ownership) 필터 UI MVP 숨김
                  // TODO: 출시 후 ownership 전수조사 완료 시 아래 주석 해제
                  // Text('운영', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500], letterSpacing: 0.3)),
                  // const SizedBox(height: 6),
                  // Wrap(spacing: 8, children: _ownershipFilters.map((o) { ... }).toList()),
                  // const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ─── R2: 추천 태그 ────────────────────────────────────────────
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
                                : Colors.grey.shade300,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      // v1.9 이슈 7: 무료 관람 필터
                      FilterChip(
                        label: const Text('무료 관람'),
                        avatar: const Text('🎫', style: TextStyle(fontSize: 14)),
                        selected: filter.isFree,
                        onSelected: (val) {
                          ref.read(exploreFilterProvider.notifier).setFree(val);
                          _onFilterChanged();
                        },
                        selectedColor: const Color(0xFF1565C0).withValues(alpha: 0.12),
                        checkmarkColor: const Color(0xFF1565C0),
                        labelStyle: TextStyle(
                          color: filter.isFree
                              ? const Color(0xFF1565C0)
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
                                ? const Color(0xFF1565C0)
                                : Colors.grey.shade300,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),


          // ─── M3: 정렬 칩 UI ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SortChipBar(
              current: filter.sortOrder,
              onChanged: (order) {
                ref.read(exploreFilterProvider.notifier).setSortOrder(order);
                _onFilterChanged();
              },
            ),
          ),

          // ─── 결과 수 + 필터 초기화 ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${listState.museums.length}곳',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (filter.hasActiveFilter) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        ref.read(exploreFilterProvider.notifier).reset();
                        _onFilterChanged();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close,
                                size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 3),
                            Text(
                              '필터 초기화',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
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
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                region,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
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
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            query.isNotEmpty ? '"$query" 검색 결과가 없습니다' : '조건에 맞는 박물관이 없습니다',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onReset,
            child: const Text('필터 초기화'),
          ),
        ],
      ),
    );
  }
}

// ─── M3: 정렬 칩 바 ──────────────────────────────────────────────────────────
class _SortChipBar extends StatelessWidget {
  final SortOrder current;
  final ValueChanged<SortOrder> onChanged;

  const _SortChipBar({required this.current, required this.onChanged});

  static const _items = [
    (label: '관련도', order: SortOrder.relevance),
    (label: '거리순', order: SortOrder.distance),
    (label: '인기순', order: SortOrder.popularity),
    (label: '별점순', order: SortOrder.rating),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          final isSelected = current == item.order;
          return GestureDetector(
            onTap: () => onChanged(item.order),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2C3E50)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
