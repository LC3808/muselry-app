import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/review_image.dart';

/// 리뷰 사진 Repository (v0.5.1)
///
/// 금지:
///   - service_role 사용 금지
///   - Storage overwrite 금지
///   - review 테이블에 이미지 URL 저장 금지
///   - SQL/RLS 변경 금지
class ReviewImageRepository {
  final SupabaseClient _client;
  static const String _bucket = 'media';

  ReviewImageRepository(this._client);

  /// 리뷰 사진 목록 조회 (display_order 오름차순)
  Future<List<ReviewImage>> loadImages(String reviewId) async {
    final response = await _client
        .from('review_images')
        .select()
        .eq('review_id', reviewId)
        .eq('status', 'published')
        .order('display_order', ascending: true);

    return (response as List)
        .map((e) => ReviewImage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 여러 리뷰의 대표사진(displayOrder=0) 일괄 조회
  /// 커뮤니티/리뷰목록 카드용
  Future<Map<String, ReviewImage>> loadThumbnails(
      List<String> reviewIds) async {
    if (reviewIds.isEmpty) return {};
    final response = await _client
        .from('review_images')
        .select()
        .inFilter('review_id', reviewIds)
        .eq('display_order', 0)
        .eq('status', 'published');

    final result = <String, ReviewImage>{};
    for (final row in response as List) {
      final img = ReviewImage.fromJson(row as Map<String, dynamic>);
      result[img.reviewId] = img;
    }
    return result;
  }

  /// 리뷰 사진 DB 삽입
  /// Repository가 현재 세션 UID를 강제 주입 (클라이언트가 임의 UID 전달 불가)
  Future<ReviewImage> insertImage(ReviewImage image) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final payload = {
      ...image.toInsertJson(),
      'user_id': uid, // RLS: user_id = auth.uid() 요구
    };

    try {
      final response = await _client
          .from('review_images')
          .insert(payload)
          .select()
          .single();
      return ReviewImage.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        print(
          'REVIEW_IMAGE: db insert failed '
          'code=${e is PostgrestException ? e.code : 'unknown'} '
          'message=${e is PostgrestException ? e.message : e.runtimeType}',
        );
      }
      rethrow;
    }
  }

  /// 단일 사진 삭제 (DB soft delete + Storage 파일 삭제)
  Future<void> deleteImage(ReviewImage image) async {
    // 1. DB 소프트 삭제
    await _client
        .from('review_images')
        .update({'status': 'removed'})
        .eq('id', image.id);

    // 2. Storage 파일 삭제 (실패 허용 — orphan 허용)
    try {
      await _client.storage.from(_bucket).remove([image.storagePath]);
      if (kDebugMode) {
        print('REVIEW: image delete done path=${image.storagePath}');
      }
    } catch (e) {
      if (kDebugMode) print('REVIEW: image delete failed (orphan): $e');
    }
  }

  /// 리뷰 삭제 전 storage_path 목록을 메모리에 확보
  /// (ON DELETE CASCADE로 review_images 행이 사라지기 전에 호출해야 함)
  Future<List<String>> loadStoragePaths(String reviewId) async {
    try {
      final response = await _client
          .from('review_images')
          .select('storage_path')
          .eq('review_id', reviewId)
          .eq('status', 'published');
      return (response as List)
          .map((e) => e['storage_path'] as String)
          .toList();
    } catch (e) {
      if (kDebugMode) print('REVIEW: loadStoragePaths failed: $e');
      return [];
    }
  }

  /// 미리 확보한 paths 목록으로 Storage 파일 삭제 (orphan 허용)
  /// 리뷰 DB 삭제 성공 후 호출
  Future<void> deleteStorageFilesByPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove(paths);
      if (kDebugMode) {
        print('REVIEW: deleted ${paths.length} storage files');
      }
    } catch (e) {
      // orphan 허용 — Storage 후처리 실패는 리뷰 삭제 성공에 영향 없음
      if (kDebugMode) print('REVIEW: deleteStorageFilesByPaths failed (orphan): $e');
    }
  }

  /// Storage path → public URL
  String getPublicUrl(String storagePath) {
    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }
}

/// Provider
final reviewImageRepositoryProvider = Provider<ReviewImageRepository>((ref) {
  return ReviewImageRepository(Supabase.instance.client);
});
