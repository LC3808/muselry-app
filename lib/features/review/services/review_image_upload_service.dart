import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/review_image_repository.dart';
import '../../../domain/models/review_image.dart';

/// 리뷰 사진 업로드 서비스 (v0.5.1)
///
/// 처리 순서:
///   ① image_picker 갤러리 선택
///   ② crop (선택사항 — 자유 비율)
///   ③ 1600px 이하 resize + WebP 품질80 + keepExif:false
///   ④ Storage 업로드 (upsert=false)
///   ⑤ review_images DB insert
///
/// 금지:
///   - Storage overwrite 금지 (upsert=false)
///   - review 테이블에 URL 저장 금지
///   - service_role 사용 금지
class ReviewImageUploadService {
  final SupabaseClient _client;
  final ReviewImageRepository _repo;
  final _picker = ImagePicker();
  final _uuid = const Uuid();
  static const String _bucket = 'media';
  static const int _maxImages = 5;

  ReviewImageUploadService(this._client, this._repo);

  /// 갤러리에서 사진 1장 선택 → crop → compress → 임시 File 반환
  ///
  /// 반환: 압축된 임시 File (null = 사용자 취소 또는 실패)
  Future<File?> pickAndCompress() async {
    if (kDebugMode) print('REVIEW: image upload start');

    // ① 갤러리 선택
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) {
      if (kDebugMode) print('REVIEW: image pick cancelled');
      return null;
    }

    // ② crop (자유 비율)
    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
    );
    if (cropped == null) {
      if (kDebugMode) print('REVIEW: image crop cancelled');
      return null;
    }

    // ③ compress (1600px 이하, WebP 품질80, keepExif:false)
    final File compressed = await _compress(cropped.path);
    return compressed;
  }

  /// Storage 업로드 + review_images DB insert
  ///
  /// [reviewId]: 리뷰 저장 후 획득한 ID
  /// [file]: pickAndCompress()가 반환한 임시 파일
  /// [displayOrder]: 0부터 시작하는 순서
  ///
  /// 반환: 삽입된 ReviewImage (실패 시 예외)
  Future<ReviewImage> uploadAndInsert({
    required String reviewId,
    required File file,
    required int displayOrder,
  }) async {
    final uid = _requireUid();
    final fileName = '${_uuid.v4()}.webp';
    final storagePath = 'reviews/$uid/$reviewId/$fileName';

    // ④ Storage 업로드
    try {
      await _client.storage
          .from(_bucket)
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              contentType: 'image/webp',
              upsert: false, // overwrite 금지
            ),
          );
      if (kDebugMode) {
        print('REVIEW: image upload success path=$storagePath');
      }
    } catch (e) {
      if (kDebugMode) print('REVIEW: image upload failed: $e');
      throw ReviewImageException('사진 업로드에 실패했습니다. 다시 시도해 주세요.');
    }

    // ⑤ review_images DB insert
    try {
      final stat = await file.stat();
      final image = ReviewImage(
        id: '', // DB가 생성
        reviewId: reviewId,
        storagePath: storagePath,
        displayOrder: displayOrder,
        fileSize: stat.size,
        mimeType: 'image/webp',
        createdAt: DateTime.now(),
      );
      final inserted = await _repo.insertImage(image);
      return inserted;
    } catch (e) {
      // DB insert 실패 → Storage 파일 rollback
      if (kDebugMode) print('REVIEW: image db insert failed, rolling back storage');
      try {
        await _client.storage.from(_bucket).remove([storagePath]);
      } catch (_) {}
      throw ReviewImageException('사진 저장에 실패했습니다. 다시 시도해 주세요.');
    }
  }

  /// 최대 사진 수 초과 여부 확인
  bool isMaxReached(int currentCount) => currentCount >= _maxImages;

  int get maxImages => _maxImages;

  // ─── 내부 헬퍼 ────────────────────────────────────────────────────────────

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw ReviewImageException('로그인이 필요합니다.');
    return uid;
  }

  Future<File> _compress(String sourcePath) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/${_uuid.v4()}.webp';
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      minWidth: 1600,
      minHeight: 1600,
      quality: 80,
      format: CompressFormat.webp,
      keepExif: false,
    );
    if (result == null) {
      throw ReviewImageException('이미지 압축에 실패했습니다.');
    }
    return File(result.path);
  }
}

/// ReviewImageUploadService 전용 예외
class ReviewImageException implements Exception {
  final String message;
  const ReviewImageException(this.message);
  @override
  String toString() => message;
}
