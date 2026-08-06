import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/review_image_repository.dart';
import '../../../domain/models/review_image.dart';

/// 리뷰 사진 업로드 서비스 (v0.5.1 핫픽스)
///
/// 처리 순서:
///   ① image_picker 갤러리 선택
///   ② crop (자유 비율)
///   ③ 1280px 이하 resize + WebP 품질80 (실패 시 JPEG 폴백) + keepExif:false
///   ④ Storage 업로드 (upsert=false)
///   ⑤ review_images DB insert
///
/// 금지:
///   - Storage overwrite 금지 (upsert=false)
///   - review 테이블에 URL 저장 금지
///   - service_role 사용 금지
///   - 크래시를 catch만 하고 원인 숨기기 금지
class ReviewImageUploadService {
  final SupabaseClient _client;
  final ReviewImageRepository _repo;
  final _picker = ImagePicker();
  final _uuid = const Uuid();
  static const String _bucket = 'media';
  static const int _maxImages = 5;
  static const int _maxLongEdge = 1280; // B: 구형 기기 메모리 보수화

  ReviewImageUploadService(this._client, this._repo);

  /// 갤러리에서 사진 1장 선택 → crop → compress → 임시 File 반환
  ///
  /// 반환: 압축된 임시 File (null = 사용자 취소)
  /// 예외: ReviewImageException (사용자 문구 포함)
  Future<File?> pickAndCompress() async {
    // ① 갤러리 선택
    XFile? picked;
    try {
      if (kDebugMode) print('REVIEW_IMAGE: picker start');
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) {
        if (kDebugMode) print('REVIEW_IMAGE: picker cancelled');
        return null;
      }
      if (kDebugMode) print('REVIEW_IMAGE: picker success');
    } on PlatformException catch (e) {
      if (kDebugMode) print('REVIEW_IMAGE: picker PlatformException: $e');
      throw ReviewImageException('갤러리에 접근할 수 없습니다. 권한을 확인해 주세요.');
    } catch (e) {
      if (kDebugMode) print('REVIEW_IMAGE: picker error: $e');
      throw ReviewImageException('이미지를 처리하지 못했습니다. 다른 사진으로 다시 시도해 주세요.');
    }

    // ② crop (자유 비율)
    CroppedFile? cropped;
    try {
      if (kDebugMode) print('REVIEW_IMAGE: crop start');
      cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
      );
      if (cropped == null) {
        if (kDebugMode) print('REVIEW_IMAGE: crop cancelled');
        return null;
      }
      if (kDebugMode) print('REVIEW_IMAGE: crop success');
    } on PlatformException catch (e) {
      if (kDebugMode) print('REVIEW_IMAGE: crop PlatformException: $e');
      throw ReviewImageException('이미지를 처리하지 못했습니다. 다른 사진으로 다시 시도해 주세요.');
    } catch (e) {
      if (kDebugMode) print('REVIEW_IMAGE: crop error: $e');
      throw ReviewImageException('이미지를 처리하지 못했습니다. 다른 사진으로 다시 시도해 주세요.');
    }

    // ③ compress (1280px 이하, WebP 우선, JPEG 폴백)
    try {
      if (kDebugMode) print('REVIEW_IMAGE: compress start');
      final File compressed = await _compress(cropped.path);
      final bytes = await compressed.length();
      if (kDebugMode) print('REVIEW_IMAGE: compress success bytes=$bytes');
      return compressed;
    } on PlatformException catch (e) {
      if (kDebugMode) print('REVIEW_IMAGE: compress PlatformException: $e');
      throw ReviewImageException('이미지를 처리하지 못했습니다. 다른 사진으로 다시 시도해 주세요.');
    } catch (e) {
      if (kDebugMode) print('REVIEW_IMAGE: compress error: $e');
      throw ReviewImageException('이미지를 처리하지 못했습니다. 다른 사진으로 다시 시도해 주세요.');
    }
  }

  /// Storage 업로드 + review_images DB insert
  ///
  /// [reviewId]: 리뷰 저장 후 획득한 ID
  /// [file]: pickAndCompress()가 반환한 임시 파일
  /// [displayOrder]: 0부터 시작하는 순서
  /// [isJpeg]: true이면 JPEG 폴백 파일
  ///
  /// 반환: 삽입된 ReviewImage (실패 시 예외)
  Future<ReviewImage> uploadAndInsert({
    required String reviewId,
    required File file,
    required int displayOrder,
    bool isJpeg = false,
  }) async {
    final uid = _requireUid();
    final ext = isJpeg ? 'jpg' : 'webp';
    final contentType = isJpeg ? 'image/jpeg' : 'image/webp';
    final fileName = '${_uuid.v4()}.$ext';
    final storagePath = 'reviews/$uid/$reviewId/$fileName';

    // ④ Storage 업로드
    try {
      if (kDebugMode) print('REVIEW_IMAGE: storage upload start');
      await _client.storage
          .from(_bucket)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false, // overwrite 금지
            ),
          );
      if (kDebugMode) print('REVIEW_IMAGE: storage upload success');
    } catch (e) {
      if (kDebugMode) print('REVIEW_IMAGE: storage upload failed: $e');
      throw ReviewImageException('사진 업로드에 실패했습니다. 다시 시도해 주세요.');
    }

    // ⑤ review_images DB insert
    try {
      if (kDebugMode) print('REVIEW_IMAGE: db insert start');
      final stat = await file.stat();
      final image = ReviewImage(
        id: '', // DB가 생성
        reviewId: reviewId,
        storagePath: storagePath,
        displayOrder: displayOrder,
        fileSize: stat.size,
        mimeType: contentType,
        createdAt: DateTime.now(),
      );
      final inserted = await _repo.insertImage(image);
      return inserted;
    } catch (e) {
      // DB insert 실패 → Storage 파일 rollback
      if (kDebugMode) print('REVIEW_IMAGE: db insert failed, rolling back storage');
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

  /// B: 이미지 압축
  ///   - 긴 변이 _maxLongEdge(1280) 초과 → 축소
  ///   - 긴 변이 _maxLongEdge 이하 → 원본 크기 유지 (확대 금지)
  ///   - WebP 1차 시도, PlatformException/null → JPEG 폴백
  ///
  /// 반환: (File, isJpeg)
  Future<File> _compress(String sourcePath) async {
    final dir = await getTemporaryDirectory();

    // WebP 1차 시도
    try {
      final targetPath = '${dir.path}/${_uuid.v4()}.webp';
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        minWidth: _maxLongEdge,
        minHeight: _maxLongEdge,
        quality: 80,
        format: CompressFormat.webp,
        keepExif: false,
      );
      if (result != null) {
        return File(result.path); // WebP 성공
      }
      if (kDebugMode) print('REVIEW_IMAGE: webp compress returned null, trying jpeg');
    } on PlatformException catch (e) {
      if (kDebugMode) print('REVIEW_IMAGE: webp compress PlatformException: $e, trying jpeg');
    }

    // JPEG 폴백
    final jpegPath = '${dir.path}/${_uuid.v4()}.jpg';
    final jpegResult = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      jpegPath,
      minWidth: _maxLongEdge,
      minHeight: _maxLongEdge,
      quality: 82,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (jpegResult == null) {
      throw ReviewImageException('이미지 압축에 실패했습니다.');
    }
    return File(jpegResult.path); // JPEG 폴백
  }
}

/// ReviewImageUploadService 전용 예외
class ReviewImageException implements Exception {
  final String message;
  const ReviewImageException(this.message);
  @override
  String toString() => message;
}
