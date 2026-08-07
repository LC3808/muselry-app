import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/review_image.dart';

/// Storage 삭제 결과 집계 (v0.5.2)
class StorageDeleteResult {
  final int requested;
  final int succeeded;
  final int failed;

  const StorageDeleteResult({
    required this.requested,
    required this.succeeded,
    required this.failed,
  });

  bool get allSucceeded => failed == 0;
}

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
  /// 리뷰 삭제 전 storage_path 목록을 메모리에 확보
  /// status 무관 전체 조회 (published + removed 모두 포함)
  /// ON DELETE CASCADE로 review_images 행이 사라지기 전에 호출해야 함
  Future<List<String>> loadStoragePaths(String reviewId) async {
    try {
      final response = await _client
          .from('review_images')
          .select('storage_path')
          .eq('review_id', reviewId);
      return (response as List)
          .map((e) => e['storage_path'] as String)
          .where((p) => p.isNotEmpty)
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

  /// 리뷰 사진 행 soft delete (status = removed)
  /// 실패 시 예외 rethrow — Storage 삭제는 호출자가 별도 수행
  Future<void> softDeleteImageRow(String imageId) async {
    await _client
        .from('review_images')
        .update({'status': 'removed'})
        .eq('id', imageId);
  }

  /// Storage 파일 삭제 (반환값 검증 + 파일 존재 확인 포함)
  ///
  /// - bucket 이름을 storagePath 앞에 중복 포함 금지
  /// - remove()에는 bucket 내부 상대 경로만 전달 (예: reviews/{uid}/{reviewId}/{uuid}.webp)
  /// - public URL 전달 금지
  ///
  /// 반환: true = 삭제 확인, false = 삭제 미확인 또는 실패
  Future<bool> deleteStorageFile(String storagePath) async {
    try {
      if (kDebugMode) {
        print('REVIEW_EDIT: storage delete request path=$storagePath');
      }

      final removedFiles = await _client.storage
          .from(_bucket)
          .remove([storagePath]);

      if (kDebugMode) {
        print('REVIEW_EDIT: storage delete result count=${removedFiles.length}');
      }

      // remove()가 1건 이상 반환하면 성공으로 판정
      // (f.name이 파일명이 아닌 전체 경로 등 다른 형식일 수 있어 path 비교 대신 count 기반 사용)
      final confirmed = removedFiles.isNotEmpty;
      if (!confirmed) {
        if (kDebugMode) {
          print('REVIEW_EDIT: storage delete not confirmed (empty result) path=$storagePath');
        }
        return false;
      }

      if (kDebugMode) {
        print('REVIEW_EDIT: storage delete success path=$storagePath');
      }

      return true;
    } on StorageException catch (e) {
      if (kDebugMode) {
        print(
          'REVIEW_EDIT: storage delete failed '
          'code=${e.statusCode} '
          'message=${e.message} '
          'path=$storagePath',
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print(
          'REVIEW_EDIT: storage delete failed '
          'type=${e.runtimeType} '
          'path=$storagePath',
        );
      }
      return false;
    }
  }



  /// 여러 Storage 파일 삭제 + 결과 집계
  ///
  /// DB soft delete 성공 항목만 전달받아야 함
  Future<StorageDeleteResult> deleteStorageFiles(
      List<String> storagePaths) async {
    if (storagePaths.isEmpty) {
      return const StorageDeleteResult(requested: 0, succeeded: 0, failed: 0);
    }

    int succeeded = 0;
    int failed = 0;

    for (final path in storagePaths) {
      final ok = await deleteStorageFile(path);
      if (ok) {
        succeeded++;
      } else {
        failed++;
      }
    }

    if (kDebugMode) {
      print(
        'REVIEW_EDIT: storage delete requested=${storagePaths.length} '
        'success=$succeeded failed=$failed',
      );
    }

    return StorageDeleteResult(
      requested: storagePaths.length,
      succeeded: succeeded,
      failed: failed,
    );
  }

  /// 리뷰 삭제 시 해당 review_id의 모든 published 사진을 removed로 변경
  /// ON DELETE CASCADE가 없으므로 명시 호출 필수
  Future<void> softDeleteAllByReviewId(String reviewId) async {
    await _client
        .from('review_images')
        .update({'status': 'removed'})
        .eq('review_id', reviewId)
        .eq('status', 'published');
    if (kDebugMode) print('REVIEW_DELETE: image rows removed for reviewId=$reviewId');
  }

  /// 리뷰 사진 display_order 재정렬 (0,1,2,...)
  /// 삭제/추가 후 남은 published 사진에 적용
  Future<void> reorderImages(List<String> orderedImageIds) async {
    for (int i = 0; i < orderedImageIds.length; i++) {
      await _client
          .from('review_images')
          .update({'display_order': i})
          .eq('id', orderedImageIds[i]);
    }
    if (kDebugMode) print('REVIEW_EDIT: reordered ${orderedImageIds.length} images');
  }
}

/// Provider
final reviewImageRepositoryProvider = Provider<ReviewImageRepository>((ref) {
  return ReviewImageRepository(Supabase.instance.client);
});
