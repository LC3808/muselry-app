import 'package:flutter/material.dart';
import '../../../core/utils/app_dimensions.dart';
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

  /// 카드용 관람료 요약 텍스트.
  /// admissionFee 문자열이 길면 앞 30자 + "…" 처리.
  String _buildFeeCompact() {
    if (museum.isFree) return '무료';
    final fee = museum.admissionFee;
    if (fee == null || fee.trim().isEmpty) return '';
    final trimmed = fee.trim();
    if (trimmed.length > 30) {
      return '${trimmed.substring(0, 30)}…';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardPad = AppSpacing.cardPadding(context);
    final feeText = _buildFeeCompact();

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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: museum.imageUrl != null
                    ? Image.network(
                        museum.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildPlaceholder(context),
                      )
                    : _buildPlaceholder(context),
              ),
            ),
            // 정보 영역
            Padding(
              padding: EdgeInsets.all(cardPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 유형 + 소유 배지 (Wrap — 태그가 넘쳐도 줄바꿈)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _TypeBadge(label: museum.typeLabel),
                            if (museum.ownershipLabel.isNotEmpty)
                              _TypeBadge(
                                label: museum.ownershipLabel,
                                color: _ownershipColor(museum.ownershipLabel),
                              ),
                          ],
                        ),
                      ),
                      // 북마크 버튼 (고정 폭)
                      SizedBox(
                        width: 32,
                        child: GestureDetector(
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
                  // 주소 (패턴 A)
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
                  // 관람료 + 운영시간 (패턴 B: 요약 텍스트 + Expanded)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (feeText.isNotEmpty) ...[
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
                        Expanded(
                          child: Text(
                            feeText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: museum.isFree
                                  ? Colors.green[600]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      if (museum.openingHours != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            museum.openingHours!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
