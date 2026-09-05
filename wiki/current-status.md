# 현재 상태 (current-status)

> **최신 상태만** 압축 유지한다. 과거 상태를 누적하지 않는다(흐름은 `log.md`로).
> 갱신 시 낡은 줄은 교체한다.
> 역할 분리: **Git = 순간값(작업 시작 시 `git rev-parse HEAD`로 확인), Wiki = 장기 상태.**
> 순간적으로 변하는 Git HEAD를 여기 고정값으로 박지 않는다.

- **갱신일**: 2026-09-05
- **Branch**: `feature/kto-nearby-places`
- **Application code baseline**: `6dfc3d4`
  - 의미: 현재 Wiki가 설명하는 실제 application 코드 기준 commit. Badge/Badge Archive/National Museum Collection UI 및 Home compact responsive가 반영됨. UGC 사용자 차단·신고 대응은 `befe085`·`4f3b995`에 포함.
  - 버전 전용 commit은 기능 코드 변경과 구분한다.
  - Git HEAD는 순간값이며 **작업 시작 시 실제 Git에서 확인**한다. 현재 HEAD를 Wiki에 고정값으로 저장하지 않는다.
  - `lib/`·`android/`·`ios/`·`supabase/` 등 실제 구현이 바뀔 때만 갱신한다.
  - **Wiki/documentation-only commit으로는 이 baseline을 갱신하지 않는다.**
- **Release source ref**: `83a3772` — `1.0.2+47` 버전 반영 및 origin push 완료 시점.
- **앱 버전 (pubspec)**: `1.0.2+47`.
- **Remote**: `https://github.com/LC3808/muselry-app.git` (LC3808/muselry-app)

## 릴리스 상태
- **iOS**: Version **1.0.2 / Build 47** App Store 제출 완료 — **심사 대기 중**. Bundle `com.muselry.muselry`.
  - 기존 승인 train `1.0.1`은 신규 build 제출이 닫혀 있어 1.0.2로 상향했다.
  - Xcode Organizer 업로드 성공. `MinimumOSVersion 13.0`과 Naver Map dSYM 관련 warning은 이번 업로드/제출의 blocker가 아니었다.
- **Android**: Google Play Production **1.0.2 (47) / target API 36** 제출 완료 — **검토 중**.
- **양대 스토어**: 동일 버전 `1.0.2 (47)` 업데이트가 심사/검토 단계에 진입했다. 아직 승인·출시 완료로 기록하지 않는다.
- **Android Developer Verification**: com.muselry.muselry 패키지 등록 확인(키 1개), 현재 화면상 추가 조치 없음.

## 진행 중 / 최근 작업
- **Badge Phase 2A 구현 완료** — near-black Black Gallery, 목표판의 배지함 entry, earned-only BadgeArchive, 중앙·경주·제주 National Museum medallion prototype 3종을 추가했다. 기존 방문 기반 unlock·canonical/legacy UUID 정의는 유지한다.
- **Home compact UI / Small Android responsive 대응 완료** — 직전 실기기 검증 결과를 유지한다.
- **Android local release Kakao 로그인 해결 완료** — 오류 원인은 Kakao Developers의 local release certificate Key Hash 미등록으로 확인. Key Hash 추가 후 Kakao access token 획득 및 Supabase session 발급 성공을 실기기에서 재검증. Auth/Supabase 코드 변경 없음.
- **App Review 재심사 대응 완료** — 실제 iPhone 심사 영상·심사용 계정 제공, 리뷰 신고·사용자 차단·차단 해제·차단 리뷰 숨김/재노출 흐름 검증.
- KTO "함께 가볼 만한 곳" — Museum 상세화면에 주변 관광지 표시 (Edge Function `kto-nearby-places` + `lib/features/nearby/`). iOS/Android 실기기 동작 확인(서울·안동).

## 다음 개발 우선순위
1. **안동 문화 코스 설계·구성 — 공모전 핵심 포인트**
   - 공모전에서 Muselry의 차별점을 보여주는 대표 시나리오로 안동 지역 문화여행 코스를 설계한다.
   - 단순 장소 나열이 아니라 박물관·문화공간·주변 관광지·이동 흐름을 하나의 사용 경험으로 연결한다.
   - 현재 KTO Nearby 실기기 검증이 완료된 안동 사례를 활용하되, 공모전용 스토리·동선·추천 이유·화면 흐름을 별도로 기획한다.
   - 구현 전에 코스 구조, 대표 장소, 사용자 여정, 홈 배너/상세 진입 방식, 공모전 시연 포인트를 먼저 설계한다.
2. **배지 비주얼 고도화**
   - 현재 Black Gallery 방향은 유지하되, 중앙·경주·제주 프로토타입을 포함해 배지를 더 세련되고 성인 취향의 컬렉터블로 개선한다.
   - 목표 방향: Tesla-like clean black gallery, museum-specific motif, luminous/neon line-art, restrained glow, warm metallic rim.
   - 14개 전체를 한 번에 제작하지 않고 대표 3종 시안 → 실기기 QA → 비주얼 시스템 확정 → 나머지 확장 순서로 진행한다.
3. **검색 결과 정렬 오류 수정**
   - `별점순` 선택 시 실제 결과가 별점 내림차순으로 정렬되지 않는 현상 확인. 이번 1.0.2(47) 심사 빌드는 건드리지 않는다.
   - 다음 세션에서 UI 선택값 → Search provider/state → Repository/Supabase ordering → `average_rating` null/0 처리 → 클라이언트 재정렬 → pagination → 동일 평점 secondary sort 순으로 원인 분석한다.
   - 목표 정렬 옵션 및 표시 순서: **별점순 | 이름순 | 관련순**. 기존 `거리순`은 `이름순`으로 대체하고 관련순 로직은 유지한다.
4. **App Store / Google Play 소개 이미지 전면 개편**
   - 현재 단순 앱 화면 나열형 스크린샷에서 벗어나, 상용 앱 사례처럼 각 이미지가 하나의 핵심 기능/가치를 강하게 설명하는 프로모션형 스토어 이미지 세트로 재설계한다.
   - 큰 헤드라인 + 브랜드 배경 + 핵심 기능 중심의 앱 목업/화면 조합을 사용하고, 첫 3~5장만 봐도 Muselry의 가치가 이해되도록 구성한다.
   - 공모전 준비와 별개로 다음 스토어 업데이트 전 디자인 작업 목록에 포함한다.

## 미커밋(untracked) 참고
- 데이터 매칭 스크립트/CSV (`tourapi_*.py`, `museums.csv`, `conflicts.csv`, `matched_auto.csv` 등) — 앱 코드 아님, 일회성 데이터 작업 산출물.
- 인수인계 `.md` 3종 — raw 참조용(그대로 둠).

## 다음 후보 / 기술부채
- iOS Deployment Target 13.0 → 15.0: Apple 경고 기준 **2027년 봄 이전 대응**.
- Naver Map SDK의 `NMapsGeometry.framework`, `NMapsMap.framework` dSYM warning 점검 — 현재 release blocker 아님.
- 회원탈퇴 RPC에 Storage 사진 삭제 추가(개인정보 완전삭제).
- KTO Phase 1B(아동/가족).
- KTO Nearby 중복 제거(dedup): 상세 화면과 동일/유사 문화공간이 Nearby 결과에 재노출 가능(안동시립박물관에서 확인) → P2.

> 세부 릴리스 규칙·참조값은 [release/store-submission.md](release/store-submission.md).
