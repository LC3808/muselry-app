/// 사용자 프로필 모델.
///
/// Supabase `profiles` 테이블과 1:1 매핑.
/// Auth 사용자 생성 시 트리거로 자동 생성됨.
class Profile {
  final String id;          // auth.users.id와 동일
  final String? nickname;
  final String? avatarUrl;
  final DateTime? updatedAt;

  const Profile({
    required this.id,
    this.nickname,
    this.avatarUrl,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Profile copyWith({
    String? id,
    String? nickname,
    String? avatarUrl,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Profile && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
