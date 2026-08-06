import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// v0.5.0 프로필 사진 업로드 서비스
///
/// 업로드 순서 (지시서 §3):
///   ① 사진 선택 → ② Crop → ③ Compress → ④ Storage 업로드
///   → ⑤ profiles.avatar_storage_path UPDATE → ⑥ Provider refresh
///   → ⑦ 기존 파일 삭제
///
/// 실패 처리 (지시서 §4):
///   - Storage 실패 → DB 변경 금지
///   - DB UPDATE 실패 → 방금 업로드한 새 파일 삭제, 기존 프로필 유지
///   - 기존 파일 삭제 실패 → orphan 허용
///
/// 금지 (지시서 §11):
///   - service_role 사용 금지
///   - avatar_url 수정 금지
///   - 동일 Storage path overwrite 금지 (upsert=false)
///   - media_assets 생성 금지
class AvatarUploadService {
  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  static const String _bucket = 'media';
  static const _uuid = Uuid();

  // ─── 공개 API ──────────────────────────────────────────────────────────────

  /// 갤러리에서 사진 선택 → crop → compress → Storage 업로드 → DB 업데이트
  ///
  /// 반환: 새 avatar_storage_path (업로드 성공 시), null (취소/실패 시)
  /// 예외: [AvatarUploadException] — 호출자가 Snackbar 처리
  Future<String?> pickAndUpload({String? oldStoragePath}) async {
    if (kDebugMode) print('PROFILE: avatar upload start');

    // ① 사진 선택
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) {
      if (kDebugMode) print('PROFILE: avatar selection cancelled');
      return null; // 사용자 취소 — 예외 아님
    }

    // ② Crop (정사각형)
    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
    );
    if (cropped == null) {
      if (kDebugMode) print('PROFILE: avatar crop cancelled');
      return null; // 사용자 취소
    }

    // ③ Compress (512x512, WebP 품질80, keepExif:false)
    final File compressed = await _compress(cropped.path);

    // ④ Storage 업로드
    final String newPath = await _uploadToStorage(compressed);

    // ⑤ profiles.avatar_storage_path UPDATE
    await _updateDbPath(newPath);

    if (kDebugMode) print('PROFILE: avatar upload success path=$newPath');

    // ⑦ 기존 파일 삭제 (실패 허용 — orphan 허용)
    if (oldStoragePath != null && oldStoragePath.isNotEmpty) {
      await _deleteOld(oldStoragePath);
    }

    // 임시 파일 정리
    try { compressed.deleteSync(); } catch (_) {}

    return newPath;
  }

  /// avatar_storage_path를 NULL로 초기화 (기본 이미지로 변경)
  ///
  /// 반환: 성공 시 true, 실패 시 false
  Future<bool> resetToDefault({String? oldStoragePath}) async {
    if (kDebugMode) print('PROFILE: avatar reset to default');
    try {
      final uid = _uid;
      await _client
          .from('profiles')
          .update({
            'avatar_storage_path': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', uid);
      if (kDebugMode) print('PROFILE: avatar db reset done');

      // 기존 Storage 파일 삭제 (실패 허용)
      if (oldStoragePath != null && oldStoragePath.isNotEmpty) {
        await _deleteOld(oldStoragePath);
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('PROFILE: avatar reset failed: $e');
      return false;
    }
  }

  /// Storage path → public URL 변환
  String getPublicUrl(String storagePath) {
    return _client.storage.from(_bucket).getPublicUrl(storagePath);
  }

  // ─── 내부 헬퍼 ────────────────────────────────────────────────────────────

  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw AvatarUploadException('로그인이 필요합니다.');
    return uid;
  }

  Future<File> _compress(String sourcePath) async {
    final dir = await getTemporaryDirectory();
    final targetPath = '${dir.path}/${_uuid.v4()}.webp';
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      minWidth: 512,
      minHeight: 512,
      quality: 80,
      format: CompressFormat.webp,
      keepExif: false,
    );
    if (result == null) {
      throw AvatarUploadException('이미지 압축에 실패했습니다.');
    }
    return File(result.path);
  }

  Future<String> _uploadToStorage(File file) async {
    final uid = _uid;
    final fileName = '${_uuid.v4()}.webp';
    final storagePath = 'avatars/$uid/$fileName';
    try {
      await _client.storage
          .from(_bucket)
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              contentType: 'image/webp',
              upsert: false, // 동일 경로 덮어쓰기 금지
            ),
          );
      if (kDebugMode) print('PROFILE: avatar storage upload done path=$storagePath');
      return storagePath;
    } catch (e) {
      throw AvatarUploadException('사진 업로드에 실패했습니다. 다시 시도해 주세요.');
    }
  }

  Future<void> _updateDbPath(String storagePath) async {
    final uid = _uid;
    try {
      await _client
          .from('profiles')
          .update({
            'avatar_storage_path': storagePath,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', uid);
      if (kDebugMode) print('PROFILE: avatar db update done');
    } catch (e) {
      // DB 실패 → 방금 업로드한 새 파일 삭제
      if (kDebugMode) print('PROFILE: avatar db update failed, deleting new file');
      try {
        await _client.storage.from(_bucket).remove([storagePath]);
      } catch (_) {}
      throw AvatarUploadException('프로필 저장에 실패했습니다. 다시 시도해 주세요.');
    }
  }

  Future<void> _deleteOld(String oldPath) async {
    try {
      await _client.storage.from(_bucket).remove([oldPath]);
      if (kDebugMode) print('PROFILE: avatar delete old done path=$oldPath');
    } catch (e) {
      // orphan 허용 — 삭제 실패는 무시
      if (kDebugMode) print('PROFILE: avatar delete old failed (orphan): $e');
    }
  }
}

/// AvatarUploadService 전용 예외
class AvatarUploadException implements Exception {
  final String message;
  const AvatarUploadException(this.message);
  @override
  String toString() => message;
}
