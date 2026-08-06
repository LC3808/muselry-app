/// 사용자 프로필 모델.
///
/// Supabase `profiles` 테이블과 1:1 매핑.
/// Auth 사용자 생성 시 트리거로 자동 생성됨.
///
/// 프로필 이미지 우선순위 (v0.5.0):
///   1순위: avatarStoragePath (사용자 직접 업로드)
///   2순위: avatarUrl (Google/Kakao OAuth 기본 이미지, 수정 금지)
///   3순위: 기본 아바타 (이니셜)
class Profile {
  final String id;          // auth.users.id와 동일
  final String? nickname;
  final String? avatarUrl;          // OAuth 기본 이미지 (수정 금지)
  final String? avatarStoragePath;  // v0.5.0: Supabase Storage 경로 (우선순위 1)
  final DateTime? updatedAt;

  const Profile({
    required this.id,
    this.nickname,
    this.avatarUrl,
    this.avatarStoragePath,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      avatarStoragePath: json['avatar_storage_path'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Profile copyWith({
    String? id,
    String? nickname,
    String? avatarUrl,
    String? avatarStoragePath,
    DateTime? updatedAt,
    bool clearAvatarStoragePath = false,
  }) {
    return Profile(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarStoragePath: clearAvatarStoragePath
          ? null
          : (avatarStoragePath ?? this.avatarStoragePath),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Profile && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
