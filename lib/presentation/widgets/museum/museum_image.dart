import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// M2: kids_category=dedicated 우선 fallback 지원
// W4 수정: 이미지/플레이스홀더 로직을 재사용 가능한 위젯으로 분리
// MuseumCard와 MuseumDetailScreen에서 공통 사용
class MuseumImage extends StatelessWidget {
  final String? imageUrl;
  final String? type;
  /// M2: kids_category 값 ('dedicated' | 'friendly' | null)
  final String? kidsCategory;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const MuseumImage({
    super.key,
    required this.imageUrl,
    this.type,
    this.kidsCategory,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  /// M2: dedicated 우선 → type별 fallback 순서
  String _typeIcon() {
    // kids_category=dedicated는 type보다 먼저 판정
    if (kidsCategory == 'dedicated') return '🧒';
    switch (type) {
      case '박물관':
        return '🏛️';
      case '미술관':
        return '🖼️';
      case '기념관':
        return '🏅';
      case '전시관':
        return '🏢';
      case '과학관':
        return '🔭';
      default:
        return '🏛️';
    }
  }

  /// M2: dedicated 우선 → type별 색상
  Color _typeColor() {
    if (kidsCategory == 'dedicated') return const Color(0xFFD4622A);
    switch (type) {
      case '박물관':
        return const Color(0xFFB8860B);
      case '미술관':
        return const Color(0xFF7C4DFF);
      case '기념관':
        return const Color(0xFF00897B);
      case '전시관':
        return const Color(0xFF1565C0);
      case '과학관':
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF2C3E50);
    }
  }

  /// M2: dedicated 전용 부제목 레이블
  String? _subtitleLabel() {
    if (kidsCategory == 'dedicated') return '어린이 전용';
    return null;
  }

  Widget _placeholder() {
    final color = _typeColor();
    final subtitle = _subtitleLabel();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _typeIcon(),
              style: TextStyle(fontSize: (height ?? 80) * 0.35),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: _placeholder(),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      ),
    );
  }
}
