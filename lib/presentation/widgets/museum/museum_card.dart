import 'package:flutter/material.dart';
import '../../../domain/models/museum.dart';

class MuseumCard extends StatelessWidget {
  final Museum museum;
  final bool isBookmarked;
  final VoidCallback? onTap;
  final VoidCallback? onBookmarkToggle;

  const MuseumCard({
    super.key,
    required this.museum,
    this.isBookmarked = false,
    this.onTap,
    this.onBookmarkToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 영역
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: museum.imageUrl != null
                    ? Image.network(
                        museum.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                      )
                    : _buildPlaceholder(context),
              ),
            ),
            // 정보 영역
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 유형 + 소유 배지
                  Row(
                    children: [
                      _TypeBadge(label: museum.typeLabel),
                      if (museum.ownershipLabel.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _TypeBadge(
                          label: museum.ownershipLabel,
                          color: _ownershipColor(museum.ownershipLabel),
                        ),
                      ],
                      const Spacer(),
                      // 북마크 버튼
                      GestureDetector(
                        onTap: onBookmarkToggle,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            key: ValueKey(isBookmarked),
                            color: isBookmarked
                                ? const Color(0xFFE8A87C)
                                : Colors.grey[400],
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 박물관 이름
                  Text(
                    museum.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 주소
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          museum.address,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 관람료 + 휴관일
                  Row(
                    children: [
                      if (museum.admissionFee != null) ...[
                        Icon(
                          museum.isFree
                              ? Icons.money_off
                              : Icons.attach_money,
                          size: 14,
                          color: museum.isFree
                              ? Colors.green[600]
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 3),
                        Text(
                          museum.isFree ? '무료' : museum.admissionFee!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: museum.isFree
                                ? Colors.green[600]
                                : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      if (museum.openingHours != null)
                        Text(
                          museum.openingHours!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: const Color(0xFF2C3E50).withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              museum.typeLabel == '미술관'
                  ? Icons.palette_outlined
                  : Icons.museum_outlined,
              size: 40,
              color: const Color(0xFF2C3E50).withValues(alpha: 0.3),
            ),
            const SizedBox(height: 6),
            Text(
              museum.typeLabel,
              style: TextStyle(
                color: const Color(0xFF2C3E50).withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _ownershipColor(String ownership) {
    switch (ownership) {
      case '국립':
        return const Color(0xFF1565C0);
      case '공립':
        return const Color(0xFF2E7D32);
      case '사립':
        return const Color(0xFF6A1B9A);
      default:
        return Colors.grey;
    }
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color? color;

  const _TypeBadge({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? const Color(0xFFE8A87C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
