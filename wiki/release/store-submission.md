# 릴리스 & 스토어 제출 (store-submission)

> 원본: `Muselry_인수인계_2026-08-25_iOS제출완료.md`, `pubspec.yaml`, `android/app/build.gradle`, `ios/Runner.xcodeproj`.
> 상태 값이 바뀌면 이 페이지와 `current-status.md`를 함께 갱신.

## 현재 (2026-09-05)
- 앱 버전(pubspec): **1.0.2+47**.
- Release source ref: **`83a3772`** (`feature/kto-nearby-places`, origin push 완료 시점).
- **iOS**: **1.0.2 (47) — App Store 심사 대기 중**. Bundle `com.muselry.muselry`.
- **Android**: **1.0.2 (47) — Google Play Production 검토 중**, target API 36.
- 양 플랫폼 모두 동일 버전 업데이트 제출 완료. **아직 1.0.2(47)를 Approved/Released/Live로 기록하지 않는다.**
- App Store: `https://apps.apple.com/kr/app/id6800217014`.
- **Android Developer Verification**: com.muselry.muselry 패키지 등록 확인(키 1개), 현재 화면상 추가 조치 없음.

## iOS App Store 심사 및 출시 이력
- **최초 제출/출시**: iOS App 1.0 / Build 44를 심사 제출했고 2026-09-04 최초 정식 공개를 확인했다.
- **Build 46 대응**: Apple Guideline 2.1 Information Needed 및 UGC 요구사항에 대응해 Build 46 관련 심사/QA를 진행했다. 실제 iPhone 촬영 App Review 영상, 심사용 계정, 계정 삭제 경로, 위치 권한, 외부 서비스 및 앱 기능 설명을 제공했다.
- **UGC 대응 범위**: `user_blocks` 기반 사용자 차단·차단 해제·차단 사용자 리뷰 필터링·관리 화면을 지원했다. 리뷰 신고는 `can_report_review(uuid)` SECURITY DEFINER helper와 INSERT RLS로 본인 리뷰 신고를 차단하고 `reporter_id`를 명시한다. DB unique 제약은 중복 신고를 유지하고 앱은 중복 시 "이미 신고한 리뷰입니다." 메시지를 표시한다.
- **2026-09-05 — 1.0.2(47) 제출**: 기존 승인 버전 `1.0.1`의 pre-release train이 신규 build 제출에 닫혀 있어 `CFBundleShortVersionString 1.0.1`로 Build 47 업로드가 거부됨. source를 `1.0.2+47`로 상향한 뒤 archive/IPA를 재생성했다.
- Xcode Organizer에서 Version **1.0.2 / Build 47** 업로드 성공 후 App Store Connect에서 심사 제출 완료. 현재 상태는 **심사 대기 중**.
- 업로드 warning: `MinimumOSVersion=13.0`은 2027년 봄부터 iOS 15.0 이상이 필요하다는 사전 경고. `NMapsGeometry.framework`, `NMapsMap.framework` dSYM 누락 warning도 확인. 둘 다 이번 delivery/submission을 차단하지 않았다.

## Android Google Play 업데이트 이력
- 기존 Production: **1.0.1 (45)** / target API 36, 100% 게시 확인 및 실제 기기 업데이트 확인.
- **2026-09-05 — 1.0.2(47) 제출**: `flutter build appbundle --release` 성공 후 `app-release.aab`를 Google Play Production에 업로드.
- Play Console에서 **47 (1.0.2)**, API 수준 23 이상 / target SDK 36을 확인하고 **전체 출시 시작**으로 제출했다.
- 현재 상태는 **검토 중인 변경사항**. 자동 사전 검사가 진행되며 승인/게시 전이므로 Live로 기록하지 않는다.

## 플랫폼 값
- Bundle/App ID: `com.muselry.muselry` (iOS·Android 공통).
- Android: compileSdk 36, minSdk 23, targetSdk 36, versionCode/Name = flutter 값.
- iOS: Deployment Target **13.0** → ⚠️ Apple 안내 기준 2027년 봄부터 15.0 이상 필요.
- iOS: iPhone 전용(`TARGETED_DEVICE_FAMILY=1`) — iPad 스크린샷 회피.

## 공식 URL / 메타 (원본: 인수인계 문서)
- App Store: `https://apps.apple.com/kr/app/id6800217014`.
- 개인정보 `https://muselry.com/privacy` · 지원 `/support` · 마케팅 `muselry.com` · 계정삭제 `/delete-account`.
- 카테고리 라이프스타일/여행 · 연령 4+ · 무료. 수출규정: HTTPS만(해당 없음).
- 공식 웹은 **별도 repo** `LC3808/muselry-web` (Cloudflare Pages). 서로 건드리지 않음.
- 홈페이지의 Google Play / App Store 공식 Store Badge 제공은 별도 후속 작업으로 관리한다. 이 Wiki는 해당 홈페이지 디자인 작업을 완료 상태로 기록하지 않는다.

## 릴리스 절대 규칙 (원본: 인수인계 "절대 규칙")
- main 임의 병합·시크릿 커밋·기존 인증(Google/Kakao/Apple) 변경·Bundle ID 변경·dependency 일괄 upgrade·무관 파일 커밋 금지.
- production 배포/push는 운영자 승인 후. 추측 API 금지(공식 문서 확인).

## 후속 과제
- **1.0.2(47) 양대 스토어 심사 결과 확인 후 실제 승인/게시 상태로 Wiki 갱신.**
- iOS Deployment Target 15.0 상향 — 2027년 봄 이전 대응.
- Naver Map SDK dSYM warning 점검 — 현재 release blocker 아님.
- 회원탈퇴 RPC에 Storage(avatar/review image) 삭제 추가 — DB cascade로는 사진 미삭제.
- (선택) `Info.plist`에 `ITSAppUsesNonExemptEncryption=false` 추가 시 수출규정 질문 스킵.

> 심사 데모 계정·제출 ID·Key Hash·secret 등 민감/운영정보는 여기 저장하지 않는다.
