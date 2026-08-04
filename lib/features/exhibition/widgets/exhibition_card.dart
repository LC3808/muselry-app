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
          children: [
            // 썸네일
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  _Thumbnail(url: exhibition.thumbnail),
                  // 거리 배지
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
            // 정보
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exhibition.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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
