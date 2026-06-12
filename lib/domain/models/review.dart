import 'museum.dart';

/// 리뷰 상태값 (v1.6 명세서 4.4 기준)
enum ReviewStatus {
  published,      // 정상 노출
  pendingReview,  // 자동 필터링 의심, 운영자 검토 대기
  hidden,         // 신고 누적 또는 운영자 판단으로 비공개
  removed,        // 소프트 삭제 (작성자 본인 또는 운영자)

  unknown;        // 알 수 없는 상태 (폴백)

  static ReviewStatus fromString(String? value) {
    switch (value) {
      case 'published':      return ReviewStatus.published;
      case 'pending_review': return ReviewStatus.pendingReview;
      case 'hidden':         return ReviewStatus.hidden;
      case 'removed':        return ReviewStatus.removed;
      default:               return ReviewStatus.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ReviewStatus.published:     return 'published';
      case ReviewStatus.pendingReview: return 'pending_review';
      case ReviewStatus.hidden:        return 'hidden';
      case ReviewStatus.removed:       return 'removed';
      case ReviewStatus.unknown:       return 'unknown';
    }
  }

  /// 사용자에게 표시할 레이블
  String get displayLabel {
    switch (this) {
      case ReviewStatus.published:     return '공개';
      case ReviewStatus.pendingReview: return '검토 중';
      case ReviewStatus.hidden:        return '비공개';
      case ReviewStatus.removed:       return '삭제됨';
      case ReviewStatus.unknown:       return '알 수 없음';
    }
  }
}

/// 공개 리뷰 모델.
/// freezed 미사용 — 프로젝트 전체 손코딩 패턴 유지.
/// museum 필드는 옵셔널 (조인 쿼리 시 채워짐).
///
/// v1.6 변경: visitId 필드 추가 (1방문 1리뷰 정책, NOT NULL FK)
class Review {
  final String id;
  final String userId;
  final String museumId;

  /// 연결된 방문 기록 ID (1방문 1리뷰 정책, v1.6)
  final String visitId;

  final double rating;       // 1.0 ~ 5.0, 0.5 단위
  final String content;      // 최대 500자
  final ReviewStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// R27: 방문일 (nullable — 기존 리뷰는 null, 신규 리뷰는 date picker로 입력)
  final DateTime? visitedOn;

  /// 조인 쿼리 시 채워지는 옵셔널 Museum 객체
  final Museum? museum;

  /// 작성자 닉네임 (profiles 조인 시 채워짐)
  final String? authorNickname;

  /// 작성자 아바타 URL (profiles 조인 시 채워짐)
  final String? authorAvatarUrl;

  const Review({
    required this.id,
    required this.userId,
    required this.museumId,
    required this.visitId,
    required this.rating,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.museum,
    this.authorNickname,
    this.authorAvatarUrl,
    this.visitedOn,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    // profiles 조인 데이터 파싱
    final profiles = json['profiles'] as Map<String, dynamic>?;

    return Review(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      museumId: json['museum_id'] as String,
      visitId: json['visit_id'] as String? ?? '',  // Case A 실행 전 null 방어 처리
      rating: double.tryParse(json['rating'].toString()) ?? 0.0,
      content: json['content'] as String? ?? '',
      status: ReviewStatus.fromString(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      museum: json['museums'] != null
          ? Museum.fromJson(json['museums'] as Map<String, dynamic>)
          : null,
      authorNickname: profiles?['nickname'] as String?,
      authorAvatarUrl: profiles?['avatar_url'] as String?,
      visitedOn: json['visited_on'] != null
          ? DateTime.tryParse(json['visited_on'] as String)
          : null,
    );
  }

  /// 리뷰 작성 시 서버로 전송하는 페이로드
  /// user_id는 RLS WITH CHECK가 처리하므로 포함하지 않음
  Map<String, dynamic> toInsertJson() {
    return {
      'museum_id': museumId,
      'visit_id': visitId,
      'rating': rating,
      'content': content,
      'status': status.toJson(),
      if (visitedOn != null)
        'visited_on':
            '${visitedOn!.year}-${visitedOn!.month.toString().padLeft(2, '0')}-${visitedOn!.day.toString().padLeft(2, '0')}',
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'rating': rating,
      'content': content,
      'updated_at': DateTime.now().toIso8601String(),
      if (visitedOn != null)
        'visited_on':
            '${visitedOn!.year}-${visitedOn!.month.toString().padLeft(2, '0')}-${visitedOn!.day.toString().padLeft(2, '0')}',
    };
  }

  Review copyWith({
    String? id,
    String? userId,
    String? museumId,
    String? visitId,
    double? rating,
    String? content,
    ReviewStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Museum? museum,
    String? authorNickname,
    String? authorAvatarUrl,
    DateTime? visitedOn,
  }) {
    return Review(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      museumId: museumId ?? this.museumId,
      visitId: visitId ?? this.visitId,
      rating: rating ?? this.rating,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      museum: museum ?? this.museum,
      authorNickname: authorNickname ?? this.authorNickname,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      visitedOn: visitedOn ?? this.visitedOn,
    );
  }

  /// 수정 가능 여부: 작성 후 7일 이내 본인만 수정 가능 (v1.6 명세서 6.3)
  bool get isEditable {
    final now = DateTime.now();
    return now.difference(createdAt).inDays < 7;
  }

  /// 수정 가능 잔여 일수
  int get editableDaysLeft {
    final elapsed = DateTime.now().difference(createdAt).inDays;
    return (7 - elapsed).clamp(0, 7);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Review && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
