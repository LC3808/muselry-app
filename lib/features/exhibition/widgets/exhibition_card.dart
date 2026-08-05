import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../exhibition_api.dart';
import '../exhibition_model.dart';

class ExhibitionCard extends StatelessWidget {
  final Exhibition exhibition;
  final double? userLat;
  final double? userLng;
  final VoidCallback onTap;

  const ExhibitionCard({
    super.key,
    required this.exhibition,
    this.userLat,
    this.userLng,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDistance = userLat != null &&
        userLng != null &&
        exhibition.latitude != null &&
        exhibition.longitude != null;

    final distanceKm = hasDistance
        ? ExhibitionApi.distanceKm(userLat!, userLng!,
            exhibition.latitude!, exhibition.longitude!)
        : null;

    final distanceText = distanceKm != null
        ? distanceKm < 1.0
            ? '${(distanceKm * 1000).round()}m'
            : '${distanceKm.toStringAsFixed(1)}km'
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        // 분야 배지 + 제목(2줄) + 장소 + 기간 + 여백을 수용하는 높이
        // 이미지 100 + 패딩 8*2 + 배지 16 + 간격 4 + 제목 2줄 약 32 + 간격 4 + 장소 14 + 간격 2 + 기간 12 + 여백 = 228
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 내용에 맞게 최소 높이 사용
          children: [
            // 썸네일 (고정 높이 100)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  _Thumbnail(url: exhibition.thumbnail),
                  // 거리 배지 (위치 있을 때만)
                  if (distanceText != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          distanceText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 정보 영역 (패딩 8)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 분야 배지 (1줄, 고정)
                  _RealmBadge(realm: exhibition.realmName),
                  const SizedBox(height: 4),
                  // 제목 (최대 2줄)
                  Text(
                    exhibition.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 장소 (최대 1줄)
                  Text(
                    exhibition.place,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // 기간 (최대 1줄, 연도 포함 형식 유지)
                  Text(
                    exhibition.displayPeriod,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// realmName 분야 배지 (pill 형태)
class _RealmBadge extends StatelessWidget {
  final String realm;
  const _RealmBadge({required this.realm});

  @override
  Widget build(BuildContext context) {
    final trimmed = realm.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final (bgColor, textColor) = _realmColors(trimmed);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        trimmed,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// realmName별 배지 색상 (뮤즐리 톤)
  (Color, Color) _realmColors(String realm) {
    switch (realm) {
      case '전시':
        return (
          AppTheme.primaryColor.withValues(alpha: 0.12),
          AppTheme.primaryColor,
        );
      case '교육/체험':
        return (
          const Color(0xFF27AE60).withValues(alpha: 0.12),
          const Color(0xFF27AE60),
        );
      case '행사/축제':
        return (
          const Color(0xFFE67E22).withValues(alpha: 0.12),
          const Color(0xFFE67E22),
        );
      default:
        return (
          AppTheme.dividerColor,
          AppTheme.textSecondaryColor,
        );
    }
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  const _Thumbnail({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _placeholder();
    }
    return CachedNetworkImage(
      imageUrl: url!,
      height: 100,
      width: 160,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => _placeholder(),
      placeholder: (_, __) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        height: 100,
        width: 160,
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        child: const Center(
          child: Text('🎨', style: TextStyle(fontSize: 32)),
        ),
      );
}
