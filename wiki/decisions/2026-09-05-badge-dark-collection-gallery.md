# 결정: Badge Dark Collection Gallery와 Home Compact UI

- **날짜**: 2026-09-05
- **상태**: 유효
- **맥락(왜 필요했나)**:
  Home + Badge MVP v3의 기능 구조는 유지한 채, Home의 Greeting/Quick Access가 세로 공간을 과도하게 사용하는 문제와 Badge 화면이 통계 화면처럼 보이는 문제를 개선할 필요가 있었다. Badge는 장기적으로 사용자가 다음 방문 목표를 정하고 수집 성취를 느끼게 하는 Muselry의 핵심 gamification 경험으로 확장한다.

- **결정 내용**:
  1. Home은 정보 구조와 기능을 바꾸지 않고 vertical density를 높인다. Greeting의 좌/우 구조를 유지하며, 문화 레벨과 문화 지도 CTA를 white 계열 design family로 통일한다. Material 기본 tap target으로 커진 CTA 높이는 compact 방식으로 조정하고, Quick Access 2×2 카드의 높이와 내부 빈 공간을 축소한다. 이달의 문화여행 Banner는 위치와 SnackBar 동작을 유지하며 소폭 compact화한다.
  2. BadgeScreen은 `Dark Collection Gallery`를 기본 시각 방향으로 사용한다. 완전한 검정이 아닌 Deep Navy/Charcoal 배경을 적용하며, 미획득 Badge는 어둡고 비활성화된 수집품처럼, 획득 Badge는 accent·metallic rim·절제된 glow로 전시 조명이 켜진 것처럼 표현한다. 강한 neon 효과는 사용하지 않는다.
  3. Milestone Badge는 서로 다른 훈장으로 표현한다. 첫 발걸음은 시작/발자국, 문화 산책자는 path, 문화 탐험가는 compass, 문화 여행자는 map/route 의미를 각각 icon·inner ring·marker·rim으로 구분한다.
  4. 전국 국립박물관 Collection은 milestone과 달리 통일된 `museum souvenir medallion` 문법을 사용한다. 현재 generic museum icon은 placeholder이며, 향후 박물관별 소장품·건축·지역 심벌 artwork로 교체할 수 있게 Badge medal component를 유지한다.
  5. National Museum Collection은 3-column compact grid와 `mainAxisExtent` 기반 layout을 사용한다. Collection section은 화면 local UI state로 접기/펼치기를 지원하며 기본값은 펼침이다.
  6. Badge 최초 획득 연출은 future 방향으로만 남기며, earned-history DB가 없는 MVP에는 새 overlay·modal·애니메이션을 추가하지 않는다.

- **이유**:
  Badge의 핵심 가치는 통계 표시보다 목표 달성과 수집에 대한 감정적 보상에 있다. 어두운 전시실에서 획득한 수집품에 조명이 켜지는 Dark Gallery 방식은 Muselry의 박물관·문화공간 정체성과 자연스럽게 결합한다. Home은 새 기능을 추가하기보다 같은 화면에서 더 많은 문화 콘텐츠를 노출할 수 있도록 공간 효율을 높이는 것이 우선이다.

- **관련 파일/경로**:
  - `lib/presentation/screens/home/home_screen.dart`
  - `lib/presentation/screens/badge/badge_screen.dart`
  - `lib/features/badge/badge_model.dart`
  - `lib/features/badge/badge_provider.dart`

- **고려한 대안**:
  1. 기존 밝은 Badge 화면 유지: 일반 통계·설정 화면처럼 보여 수집 보상감이 약하다.
  2. 강한 neon/glow 사용: 게임·자동차 UI 인상이 강해 Muselry의 문화공간 정체성과 충돌할 수 있다.
  3. 모든 Badge에 강한 색을 독립 적용: 브랜드 일관성과 향후 museum artwork 확장성이 떨어진다.
  4. Collection collapse를 위한 전역 Riverpod 상태 추가: 단순 화면 UI 상태에 과도한 구조다.

- **Trade-off**:
  Dark Badge 화면은 밝은 Home과 분위기가 다르지만, Badge를 별도의 컬렉션 공간으로 인식시키는 장점이 크다. 국립박물관별 artwork는 placeholder이므로 향후 artwork 제작에서 완성도를 추가 향상할 수 있다. 마일스톤의 raw UUID distinct count inflation 가능성은 기존 Badge MVP의 known limitation이며 이번 UI 결정에서는 변경하지 않는다.

- **검증 방법**(코드/Git 근거):
  - `flutter analyze lib`
  - `git diff --check`
  - iPhone 및 Android 실기기에서 Home layout, Badge Dark Gallery, milestone 4종 구분, National Museum 3-column grid, Collection collapse, 기존 unlock/count 회귀 확인
