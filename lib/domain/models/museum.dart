/// Museum 모델
///
/// 어린이 분류 관련:
/// - is_kids_friendly: 기존 boolean (DB 호환 유지, legacy)
/// - kids_category: 신규 분류 (null / 'friendly' / 'dedicated')
///   - 현재 검색/필터/카드/상세 모두 kids_category 기준 (사이클 1.5)
///
/// TODO (T6 이후): 사용자 추천 기반 어린이 친화 시스템
/// 3단계 승격 구조:
///
/// 1단계: 사용자 신호 별도 저장
///   - museum_kids_feedback 테이블 (또는 reviews/visits 확장)
///   - museum_id, user_id, visit_id, is_recommended, age_group, tags, memo
///   - 방문 기록/리뷰 작성 시 "아이와 함께 방문하기 좋았나요?" 체크
///
/// 2단계: 앱에 "이용자 추천"으로 표시 (공식 분류와 분리)
///   - 어린이 친화: 운영자/DB 검토 완료 (kids_category)
///   - 이용자 추천: 사용자 피드백 기반 (별도 표시)
///
/// 3단계: 기준 충족 시 운영자 검토 후 승격
///   - 서로 다른 사용자 3~5명 이상 추천
///   - 부정 피드백 비율 낙음
///   - 운영자 확인 → kids_category=friendly로 승격
///
/// 주의: 사용자 추천을 바로 공식 분류로 매핑하지 말 것
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
  final String? kidsCategory; // 'dedicated' | 'friendly' | null
  /// M3: Bayesian 보정 별점 (DB 콜럼: bayesian_score)
  final double? bayesianScore;

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
    this.kidsCategory,
    this.bayesianScore,
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
      kidsCategory: json['kids_category'] as String?,
      bayesianScore: (json['bayesian_score'] as num?)?.toDouble(),
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
        'kids_category': kidsCategory,
        'bayesian_score': bayesianScore,
      };

  Museum copyWith({
    String? id,
    String? name,
    String? type,
    String? ownership,
    String? region1,
    String? region2,
    String? address,
    String? roadAddress,
    double? latitude,
    double? longitude,
    String? phone,
    String? homepageUrl,
    String? openingHours,
    String? closedDays,
    String? admissionFee,
    String? description,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    double? averageRating,
    int? reviewCount,
    bool? isKidsFriendly,
    String? kidsNote,
    String? kidsCategory,
    double? bayesianScore,
  }) {
    return Museum(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ownership: ownership ?? this.ownership,
      region1: region1 ?? this.region1,
      region2: region2 ?? this.region2,
      address: address ?? this.address,
      roadAddress: roadAddress ?? this.roadAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      phone: phone ?? this.phone,
      homepageUrl: homepageUrl ?? this.homepageUrl,
      openingHours: openingHours ?? this.openingHours,
      closedDays: closedDays ?? this.closedDays,
      admissionFee: admissionFee ?? this.admissionFee,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      isKidsFriendly: isKidsFriendly ?? this.isKidsFriendly,
      kidsNote: kidsNote ?? this.kidsNote,
      kidsCategory: kidsCategory ?? this.kidsCategory,
      bayesianScore: bayesianScore ?? this.bayesianScore,
    );
  }

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

  /// 어린이 전용 박물관 (dedicated)
  bool get isKidsDedicated => kidsCategory == 'dedicated';

  /// 어린이 친화 박물관 (friendly)
  bool get isKidsFriendlyTagged => kidsCategory == 'friendly';

  /// 어린이 태그 존재 여부
  bool get hasKidsTag => kidsCategory != null;

  /// null/빈값 → "정보 없음" 헬퍼
  static String orEmpty(String? value) =>
      (value == null || value.trim().isEmpty) ? '정보 없음' : value.trim();
}
