import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/museum.dart';
import '../../providers/profile_provider.dart';

enum _BookmarksFilter { all, museum, art, science, kids }

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  _BookmarksFilter _filter = _BookmarksFilter.all;

  List<Museum> _applyFilter(List<Museum> all) {
    switch (_filter) {
      case _BookmarksFilter.all:
        return all;
      case _BookmarksFilter.museum:
        return all.where((m) => m.type == '박물관').toList();
      case _BookmarksFilter.art:
        return all.where((m) => m.type == '미술관').toList();
      case _BookmarksFilter.science:
        return all.where((m) => m.type == '과학관').toList();
      case _BookmarksFilter.kids:
        return all.where((m) => m.type.contains('어린이')).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkedAsync = ref.watch(bookmarkedMuseumsProvider);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('북마크한 박물관'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      body: bookmarkedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '북마크 목록을 불러오지 못했어요.',
            style: TextStyle(color: AppTheme.textSecondaryColor),
          ),
        ),
        data: (museums) {
          if (museums.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 56,
                      color: AppTheme.textSecondaryColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '아직 북마크한 박물관이 없어요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '마음에 드는 박물관을 북마크하면\n여기서 한눈에 볼 수 있어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final filtered = _applyFilter(museums);
          return Column(
            children: [
              // 필터 칩
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: '전체 ${museums.length}',
                        selected: _filter == _BookmarksFilter.all,
                        onTap: () => setState(
                            () => _filter = _BookmarksFilter.all),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: '박물관',
                        selected: _filter == _BookmarksFilter.museum,
                        onTap: () => setState(
                            () => _filter = _BookmarksFilter.museum),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: '미술관',
                        selected: _filter == _BookmarksFilter.art,
                        onTap: () => setState(
                            () => _filter = _BookmarksFilter.art),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: '과학관',
                        selected: _filter == _BookmarksFilter.science,
                        onTap: () => setState(
                            () => _filter = _BookmarksFilter.science),
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: '어린이박물관',
                        selected: _filter == _BookmarksFilter.kids,
                        onTap: () => setState(
                            () => _filter = _BookmarksFilter.kids),
                      ),
                    ],
                  ),
                ),
              ),
              // 결과 카운트
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length}곳',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 리스트
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          '이 유형에 해당하는 북마크가 없어요',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final museum = filtered[index];
                          return _BookmarkListItem(
                            museum: museum,
                            onTap: () =>
                                context.push('/museum/${museum.id}'),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? AppTheme.primaryColor : AppTheme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textPrimaryColor,
          ),
        ),
      ),
    );
  }
}

class _BookmarkListItem extends StatelessWidget {
  final Museum museum;
  final VoidCallback onTap;

  const _BookmarkListItem({required this.museum, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: museum.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: museum.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _placeholder(),
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 12),
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    museum.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          museum.type,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (museum.region1.isNotEmpty)
                        Expanded(
                          child: Text(
                            '${museum.region1} ${museum.region2}'.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppTheme.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(
          Icons.museum_outlined,
          color: AppTheme.primaryColor,
          size: 28,
        ),
      ),
    );
  }
}
