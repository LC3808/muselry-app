import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 프로필 이미지 URL 우선순위 resolver (v0.5.0)
///
/// 우선순위:
///   1순위: avatarStoragePath (Supabase Storage)
///   2순위: avatarUrl (Google/Kakao OAuth)
///   3순위: null → 호출자가 이니셜 fallback 처리
///
/// 금지:
///   - avatar_url 수정 금지
///   - Storage URL DB 중복 저장 금지
///   - 화면마다 복붙 금지 (이 함수 단일 사용)
String? resolveAvatarUrl({
  String? avatarStoragePath,
  String? avatarUrl,
  bool debug = false,
}) {
  if (avatarStoragePath != null && avatarStoragePath.trim().isNotEmpty) {
    final url = Supabase.instance.client.storage
        .from('media')
        .getPublicUrl(avatarStoragePath);
    if (kDebugMode && debug) debugPrint('AVATAR: source=storage');
    return url;
  }

  if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
    if (kDebugMode && debug) debugPrint('AVATAR: source=oauth');
    return avatarUrl;
  }

  if (kDebugMode && debug) debugPrint('AVATAR: source=initial');
  return null;
}
