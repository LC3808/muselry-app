/// 문의/건의 카테고리
/// DB CHECK: category IN ('bug','suggestion','data_error','other')
enum FeedbackCategory {
  bug,
  suggestion,
  dataError,
  other;

  static FeedbackCategory fromString(String? value) {
    switch (value) {
      case 'bug':         return FeedbackCategory.bug;
      case 'suggestion':  return FeedbackCategory.suggestion;
      case 'data_error':  return FeedbackCategory.dataError;
      case 'other':       return FeedbackCategory.other;
      default:            return FeedbackCategory.other;
    }
  }

  String toJson() {
    switch (this) {
      case FeedbackCategory.bug:        return 'bug';
      case FeedbackCategory.suggestion: return 'suggestion';
      case FeedbackCategory.dataError:  return 'data_error';
      case FeedbackCategory.other:      return 'other';
    }
  }

  String get label {
    switch (this) {
      case FeedbackCategory.bug:        return '버그 신고';
      case FeedbackCategory.suggestion: return '기능 건의';
      case FeedbackCategory.dataError:  return '데이터 오류';
      case FeedbackCategory.other:      return '기타';
    }
  }
}

/// 문의/건의 모델
/// R20: admin_reply / replied_at / status 필드 추가
class FeedbackItem {
  final String id;
  final String userId;
  final FeedbackCategory category;
  final String content;
  final DateTime createdAt;
  final String? adminReply;   // R20: 관리자 답변 (null = 미답변)
  final DateTime? repliedAt;  // R20: 답변 등록 시각
  final String status;        // R20: 'pending' | 'answered' | 'closed'

  const FeedbackItem({
    required this.id,
    required this.userId,
    required this.category,
    required this.content,
    required this.createdAt,
    this.adminReply,
    this.repliedAt,
    this.status = 'pending',
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    return FeedbackItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      category: FeedbackCategory.fromString(json['category'] as String?),
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      adminReply: json['admin_reply'] as String?,
      repliedAt: json['replied_at'] != null
          ? DateTime.parse(json['replied_at'] as String)
          : null,
      status: json['status'] as String? ?? 'pending',
    );
  }
}
