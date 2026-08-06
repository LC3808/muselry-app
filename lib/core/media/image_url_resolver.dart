import 'package:supabase_flutter/supabase_flutter.dart';

/// 리뷰 사진 Storage path → public URL 변환 (v0.5.1)
///
/// avatar_url_resolver.dart 패턴 재사용.
/// Storage bucket: media
String resolveImageUrl(String storagePath) {
  return Supabase.instance.client.storage
      .from('media')
      .getPublicUrl(storagePath);
}
