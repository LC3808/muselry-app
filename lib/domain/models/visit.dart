import 'museum.dart';

/// 방문 기록 모델.
/// freezed 미사용 — Museum/Bookmark와 동일한 손코딩 패턴.
/// museum 필드는 옵셔널 (조인 쿼리 시 채워짐, 별도 wrapper 클래스 없음).
class Visit {
  final String id;
  final String userId;
  final String museumId;
  final DateTime visitedAt;
  final double? rating;       // 0.5 단위, nullable
  final String? privateNote;  // 최대 500자, nullable
  final DateTime createdAt;

  /// 조인 쿼리 시 채워지는 옵셔널 Museum 객체.
  final Museum? museum;

  const Visit({
    required this.id,
    required this.userId,
    required this.museumId,
    required this.visitedAt,
    this.rating,
    this.privateNote,
    required this.createdAt,
    this.museum,
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      museumId: json['museum_id'] as String,
      visitedAt: DateTime.parse(json['visited_at'] as String),
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
      privateNote: json['private_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      museum: json['museums'] != null
          ? Museum.fromJson(json['museums'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'museum_id': museumId,
      // visited_at은 'yyyy-MM-dd' 문자열로 전송 (DATE 타입 캐스팅 에러 방지)
      'visited_at': _formatDate(visitedAt),
      if (rating != null) 'rating': rating,
      if (privateNote != null && privateNote!.isNotEmpty)
        'private_note': privateNote,
      // user_id는 RLS WITH CHECK가 처리하므로 페이로드에 포함하지 않음
    };
  }

  Visit copyWith({
    String? id,
    String? userId,
    String? museumId,
    DateTime? visitedAt,
    double? rating,
    String? privateNote,
    DateTime? createdAt,
    Museum? museum,
  }) {
    return Visit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      museumId: museumId ?? this.museumId,
      visitedAt: visitedAt ?? this.visitedAt,
      rating: rating ?? this.rating,
      privateNote: privateNote ?? this.privateNote,
      createdAt: createdAt ?? this.createdAt,
      museum: museum ?? this.museum,
    );
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Visit && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
