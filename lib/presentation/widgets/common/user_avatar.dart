import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/media/avatar_url_resolver.dart';
import '../../../core/theme/app_theme.dart';

/// 공통 작성자 아바타 위젯 (v0.5.0)
///
/// 이미지 우선순위:
///   1순위: avatarStoragePath (Supabase Storage)
///   2순위: avatarUrl (OAuth)
///   3순위: 이니셜 fallback
///
/// 사용 예:
///   UserAvatar(
///     avatarStoragePath: comment.authorAvatarStoragePath,
///     avatarUrl: comment.authorAvatarUrl,
///     displayName: comment.authorNickname ?? '',
///     radius: 16,
///   )
class UserAvatar extends StatelessWidget {
  final String? avatarStoragePath;
  final String? avatarUrl;
  final String displayName;
  final double radius;

  const UserAvatar({
    super.key,
    this.avatarStoragePath,
    this.avatarUrl,
    required this.displayName,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = resolveAvatarUrl(
      avatarStoragePath: avatarStoragePath,
      avatarUrl: avatarUrl,
    );

    if (effectiveUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: effectiveUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (_, __) => _initialsWidget(),
            errorWidget: (_, __, ___) => _initialsWidget(),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryColor,
      child: _initialsWidget(),
    );
  }

  Widget _initialsWidget() {
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';
    return Text(
      initial,
      style: TextStyle(
        color: Colors.white,
        fontSize: radius * 0.75,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
