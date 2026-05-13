class Bookmark {
  final String id;
  final String userId;
  final String museumId;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.userId,
    required this.museumId,
    required this.createdAt,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      museumId: json['museum_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
