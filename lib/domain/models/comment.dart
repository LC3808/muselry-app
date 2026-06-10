/// 댓글 상태값 — 리뷰 패턴과 일관성 유지
/// DB 컬럼: status TEXT CHECK (status IN ('published','hidden','removed'))
enum CommentStatus {
  published,
  hidden,
  removed,
  unknown;

  static CommentStatus fromString(String? value) {
    switch (value) {
      case 'published': return CommentStatus.published;
      case 'hidden':    return CommentStatus.hidden;
      case 'removed':   return CommentStatus.removed;
      default:          return CommentStatus.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case CommentStatus.published: return 'published';
      case CommentStatus.hidden:    return 'hidden';
      case CommentStatus.removed:   return 'removed';
      case CommentStatus.unknown:   return 'unknown';
    }
  }
}

/// 댓글 모델.
/// - status 기반 소프트 삭제 (리뷰 패턴과 일관)
/// - 알림은 DB 트리거가 자동 생성 → 앱에서 직접 insert 금지
class Comment {
  final String id;
  final String reviewId;
  final String userId;
  final String content;
  final CommentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 작성자 닉네임 (profiles 조인 시 채워짐)
  final String? authorNickname;

  /// 작성자 아바타 URL (profiles 조인 시 채워짐)
  final String? authorAvatarUrl;

  const Comment({
    required this.id,
    required this.reviewId,
    required this.userId,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.authorNickname,
    this.authorAvatarUrl,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] as Map<String, dynamic>?;
    return Comment(
      id: json['id'] as String,
      reviewId: json['review_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String? ?? '',
      status: CommentStatus.fromString(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      authorNickname: profiles?['nickname'] as String?,
      authorAvatarUrl: profiles?['avatar_url'] as String?,
    );
  }

  Comment copyWith({
    String? id,
    String? reviewId,
    String? userId,
    String? content,
    CommentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorNickname,
    String? authorAvatarUrl,
  }) {
    return Comment(
      id: id ?? this.id,
      reviewId: reviewId ?? this.reviewId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorNickname: authorNickname ?? this.authorNickname,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Comment && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
