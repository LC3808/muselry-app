import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/profile.dart';

/// Supabase `profiles` 테이블 + `avatars` 스토리지 버킷 접근 레포지토리.
///
/// [설계 원칙]
/// - profiles 테이블은 Supabase Auth 트리거로 자동 생성됨 (INSERT 불필요).
/// - upsert 대신 update만 사용 (row가 없을 경우 null 반환으로 처리).
/// - 아바타 업로드: avatars/{userId}/avatar.jpg 경로로 upsert.
class ProfileRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// 내 프로필 조회. 없으면 null 반환.
  Future<Profile?> fetchMyProfile() async {
    final uid = _userId;
    if (uid == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  /// 닉네임 업데이트.
  Future<Profile?> updateNickname(String nickname) async {
    final uid = _userId;
    if (uid == null) throw Exception('로그인이 필요합니다');

    final trimmed = nickname.trim();
    if (trimmed.isEmpty) throw Exception('닉네임을 입력해주세요');
    if (trimmed.length > 20) throw Exception('닉네임은 20자 이하로 입력해주세요');

    final response = await _client
        .from('profiles')
        .upsert({
          'id': uid,
          'nickname': trimmed,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return Profile.fromJson(response);
  }

  /// 아바타 이미지 업로드 후 URL 반환.
  ///
  /// 경로: avatars/{userId}/avatar.jpg
  /// 기존 파일이 있으면 덮어쓰기(upsert).
  Future<String> uploadAvatar(File imageFile) async {
    final uid = _userId;
    if (uid == null) throw Exception('로그인이 필요합니다');

    final path = '$uid/avatar.jpg';
    await _client.storage.from('avatars').upload(
          path,
          imageFile,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final url = _client.storage.from('avatars').getPublicUrl(path);
    return url;
  }

  /// 아바타 URL 업데이트 (업로드 후 profiles 테이블 갱신).
  Future<Profile?> updateAvatarUrl(String avatarUrl) async {
    final uid = _userId;
    if (uid == null) throw Exception('로그인이 필요합니다');

    final response = await _client
        .from('profiles')
        .upsert({
          'id': uid,
          'avatar_url': avatarUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return Profile.fromJson(response);
  }
}
