import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// W4 수정: 이미지/플레이스홀더 로직을 재사용 가능한 위젯으로 분리
// MuseumCard와 MuseumDetailScreen에서 공통 사용
class MuseumImage extends StatelessWidget {
  final String? imageUrl;
  final String? type;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const MuseumImage({
    super.key,
    required this.imageUrl,
    this.type,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  String _typeIcon() {
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

  Color _typeColor() {
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

  Widget _placeholder() {
    final color = _typeColor();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Text(
          _typeIcon(),
          style: TextStyle(fontSize: (height ?? 80) * 0.35),
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
