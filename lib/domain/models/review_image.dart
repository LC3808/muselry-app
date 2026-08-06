/// 리뷰 사진 모델 (v0.5.1)
///
/// DB 테이블: review_images
/// Storage: media/reviews/{uid}/{review_id}/{uuid}.webp
class ReviewImage {
  final String id;
  final String reviewId;
  final String storagePath;
  final int displayOrder;
  final int? width;
  final int? height;
  final int? fileSize;
  final String? mimeType;
  final String status;
  final DateTime createdAt;

  const ReviewImage({
    required this.id,
    required this.reviewId,
    required this.storagePath,
    required this.displayOrder,
    this.width,
    this.height,
    this.fileSize,
    this.mimeType,
    this.status = 'published',
    required this.createdAt,
  });

  factory ReviewImage.fromJson(Map<String, dynamic> json) {
    return ReviewImage(
      id: json['id'] as String,
      reviewId: json['review_id'] as String,
      storagePath: json['storage_path'] as String,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      fileSize: (json['file_size'] as num?)?.toInt(),
      mimeType: json['mime_type'] as String?,
      status: json['status'] as String? ?? 'published',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'review_id': reviewId,
      'storage_path': storagePath,
      'display_order': displayOrder,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fileSize != null) 'file_size': fileSize,
      if (mimeType != null) 'mime_type': mimeType,
      'status': status,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ReviewImage && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
