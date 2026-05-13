class Museum {
  final String id;
  final String name;
  final String type;
  final String ownership;
  final String region1;
  final String region2;
  final String address;
  final String? roadAddress;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? homepageUrl;
  final String? openingHours;
  final String? closedDays;
  final String? admissionFee;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final double? averageRating;
  final int? reviewCount;
  final bool isKidsFriendly;
  final String? kidsNote;

  const Museum({
    required this.id,
    required this.name,
    required this.type,
    required this.ownership,
    required this.region1,
    required this.region2,
    required this.address,
    this.roadAddress,
    this.latitude,
    this.longitude,
    this.phone,
    this.homepageUrl,
    this.openingHours,
    this.closedDays,
    this.admissionFee,
    this.description,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    this.averageRating,
    this.reviewCount,
    this.isKidsFriendly = false,
    this.kidsNote,
  });

  factory Museum.fromJson(Map<String, dynamic> json) {
    return Museum(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? '박물관',
      ownership: json['ownership'] as String? ?? '공립',
      region1: json['region_1'] as String? ?? '',
      region2: json['region_2'] as String? ?? '',
      address: json['address'] as String? ?? '',
      roadAddress: json['road_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      homepageUrl: json['homepage_url'] as String?,
      openingHours: json['opening_hours'] as String?,
      closedDays: json['closed_days'] as String?,
      admissionFee: json['admission_fee'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      reviewCount: json['review_count'] as int?,
      isKidsFriendly: json['is_kids_friendly'] as bool? ?? false,
      kidsNote: json['kids_note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'ownership': ownership,
        'region_1': region1,
        'region_2': region2,
        'address': address,
        'road_address': roadAddress,
        'latitude': latitude,
        'longitude': longitude,
        'phone': phone,
        'homepage_url': homepageUrl,
        'opening_hours': openingHours,
        'closed_days': closedDays,
        'admission_fee': admissionFee,
        'description': description,
        'image_url': imageUrl,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
        'average_rating': averageRating,
        'review_count': reviewCount,
        'is_kids_friendly': isKidsFriendly,
        'kids_note': kidsNote,
      };

  /// 무료 여부
  bool get isFree {
    if (admissionFee == null || admissionFee!.trim().isEmpty) return true;
    final fee = admissionFee!.trim();
    return fee == '무료' || fee == '0' || fee == '0원';
  }

  /// 유형 레이블
  String get typeLabel => type;

  /// 소유 형태
  String get ownershipLabel => ownership;

  /// 표시용 관람료 문자열
  String get admissionFeeDisplay {
    if (isFree) return '무료';
    return admissionFee ?? '정보 없음';
  }

  /// 유형별 이모지 아이콘
  String get typeIcon {
    switch (type) {
      case '미술관':
        return '🎨';
      case '과학관':
        return '🔬';
      case '기념관':
        return '🏛️';
      case '전시관':
        return '🖼️';
      default:
        return '🏺';
    }
  }

  /// null/빈값 → "정보 없음" 헬퍼
  static String orEmpty(String? value) =>
      (value == null || value.trim().isEmpty) ? '정보 없음' : value.trim();
}
