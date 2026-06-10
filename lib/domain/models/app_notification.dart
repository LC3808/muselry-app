/// 인앱 알림 모델.
/// DB 테이블: notifications (comment_notifications 아님)
/// 알림 row는 DB 트리거(notify_review_author_on_comment)가 자동 생성.
/// 앱에서는 조회 + is_read UPDATE만 수행.
class AppNotification {
  final String id;
  final String userId;
  final String type;         // 현재는 'comment' 고정
  final String? commentId;
  final String? reviewId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    this.commentId,
    this.reviewId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String? ?? 'comment',
      commentId: json['comment_id'] as String?,
      reviewId: json['review_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      commentId: commentId,
      reviewId: reviewId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AppNotification && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
