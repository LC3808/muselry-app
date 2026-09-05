# 결정: Badge Archive와 National Museum Prototype Visual System

- **날짜**: 2026-09-05
- **상태**: 유효
- **맥락(왜 필요했나)**:
  Badge MVP v3는 방문 데이터에서 목표와 획득 상태를 계산할 수 있지만, 획득한 Badge를 개인 소유 컬렉션으로 분리해 보는 화면과 국립박물관별 시각적 구분이 필요했다. 기존 Deep Navy Gallery는 실기기에서 blue/teal tint가 강하게 보였으므로, 획득 Badge에만 조명이 켜지는 neutral near-black 전시장 방향을 명확히 한다.
- **결정 내용**:
  1. BadgeScreen은 목표와 진행 상황을 보여주는 목표판으로 유지하고, 로컬 palette를 near-black background `#080808`, panel `#141416`, elevated panel `#1C1C20`, primary text `#F2F2F3`, secondary text white 60%, hairline border white 10%로 전환한다. 전역 AppTheme는 수정하지 않는다.
  2. BadgeScreen Hero에 `/badges/archive`의 배지함 entry를 둔다. BadgeArchive는 현재 방문 데이터에서 계산되는 획득 Badge만 category별로 표시하며, earned_at persistence가 없으므로 최근 획득과 분모는 표시하지 않는다.
  3. National Museum Collection은 동일한 gold rim·inner ring·shadow hierarchy를 공유하는 souvenir medallion visual system을 사용한다. 중앙·경주·제주만 대표 3종 prototype으로 구현하고, 나머지 11종은 generic museum placeholder를 유지한다.
  4. 중앙 prototype은 반가사유상 silhouette와 deep blue/charcoal navy, 경주는 신라 금관 silhouette와 deep royal purple/burgundy, 제주는 돌하르방 silhouette와 low-saturation dark green/teal을 사용한다. 모두 warm gold rim을 공유한다.
  5. Seasonal Cultural Trip Badge, 공유, earned-history DB, 획득 animation, 나머지 11종 artwork는 다음 단계로 보류한다.
- **이유**:
  목표판과 보관함을 분리하면 사용자는 진행 중인 목표와 이미 획득한 소유 컬렉션을 혼동하지 않는다. 공통 medallion 규격에 각 박물관의 대표 유물·지역 모티프만 달리 적용하면 60~80px 모바일 크기에서도 같은 시리즈이면서 서로 다른 박물관이라는 인상을 유지할 수 있다.
- **관련 파일/경로**:
  - `lib/presentation/screens/badge/badge_screen.dart`
  - `lib/presentation/screens/badge/badge_archive_screen.dart`
  - `lib/presentation/screens/badge/widgets/national_museum_badge_medal.dart`
  - `lib/config/router.dart`
- **고려한 대안**:
  1. 국립박물관 14종 artwork를 한 번에 제작: 실기기 prototype 검증 전 시각 규칙을 과도하게 고정하게 된다.
  2. 일반 Material icon만 계속 사용: 중앙·경주·제주의 문화적 지역성과 collection 차별성이 약하다.
  3. 강한 neon/glow: 게임 또는 자동차 UI 인상이 강해 문화공간 전시 언어와 충돌한다.
  4. BadgeArchive에 최근 획득을 표시: earned_at 데이터가 없어 정확한 순서를 보장할 수 없다.
- **Trade-off**:
  3종만 prototype이므로 나머지 11종은 당분간 generic placeholder로 보인다. 반면 canonical UUID·legacy alias·방문 기반 unlock 계산을 전혀 바꾸지 않아 기존 획득 상태의 데이터 정합성을 보존한다.
- **검증 방법**(코드/Git 근거):
  - `flutter analyze lib`
  - `git diff --check`
  - iPhone/Android에서 Black Gallery 명도 차이, Hero 배지함 entry, Archive의 earned-only 표시, 중앙·경주·제주 prototype 구분, locked/unlocked contrast, 14개 collection count와 기존 milestone unlock 회귀를 확인한다.
