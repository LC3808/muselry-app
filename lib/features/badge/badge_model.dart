enum BadgeCategory {
  milestone,
  nationalMuseum,
}

/// Badge의 정적 정의입니다.
///
/// 획득 내역은 DB에 저장하지 않고, 기존 방문 기록을 기준으로 [BadgeProgress]에서
/// 계산합니다. [visualKey]는 향후 디자인 asset으로 교체할 때 사용할 식별자입니다.
class BadgeDefinition {
  final String id;
  final String title;
  final String description;
  final BadgeCategory category;
  final int target;
  final String visualKey;

  /// 국립박물관 Collection의 운영 기준 active UUID입니다.
  final String? museumId;

  /// 과거 inactive/legacy museum UUID입니다. 기존 Visit의 museum_id를
  /// 동일 Collection Badge에 안전하게 연결하기 위한 명시적 alias 목록입니다.
  final List<String> legacyMuseumIds;

  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.target,
    required this.visualKey,
    this.museumId,
    this.legacyMuseumIds = const [],
  });

  /// canonical UUID와 명시적으로 검증된 legacy UUID를 함께 반환합니다.
  /// museumId가 없는 일반 마일스톤 Badge는 빈 Set입니다.
  Set<String> get validMuseumIds => {
        if (museumId != null) museumId!,
        ...legacyMuseumIds,
      };
}

/// 현재 사용자의 방문 기록에서 계산한 Badge 진행 상태입니다.
class BadgeProgress {
  final BadgeDefinition definition;
  final int current;

  const BadgeProgress({
    required this.definition,
    required this.current,
  });

  int get target => definition.target;

  bool get isEarned => current >= target;

  double get progressRatio {
    if (target <= 0) return 0;
    return (current / target).clamp(0.0, 1.0);
  }
}
