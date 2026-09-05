# 릴리스 & 스토어 제출 (store-submission)

> 원본: `Muselry_인수인계_2026-08-25_iOS제출완료.md`, `pubspec.yaml`, `android/app/build.gradle`, `ios/Runner.xcodeproj`.
> 상태 값이 바뀌면 이 페이지와 `current-status.md`를 함께 갱신.

## 현재 (2026-09-05)
- 앱 버전(pubspec): **1.0.1+46**.
- **iOS**: **App Store 정식 공개 상태 확인**. App Store Connect의 iOS App 1.0에 **Version 1.0.1 / Build 46** binary가 연결된 것을 확인. Bundle `com.muselry.muselry`.
- App Store: `https://apps.apple.com/kr/app/id6800217014`.
- **Android**: Google Play 1.0.1+45 / target API 36 — Production 100% 게시 확인.
- **Android Developer Verification**: com.muselry.muselry 패키지 등록 확인(키 1개), 현재 화면상 추가 조치 없음.

## iOS App Store 심사 및 출시 이력
- **심사 제출 단계 (과거)**: iOS App 1.0 / Build 44를 App Store 심사에 제출했고, 승인 즉시 자동 출시로 설정했다. 이 기록은 제출 이력으로 유지한다.
- **2026-09-04 — 재심사 대응**: Apple Guideline 2.1 Information Needed 및 UGC 요구사항에 대응해 Build 46으로 재심사를 제출했다. 실제 iPhone 촬영 App Review 영상, 심사용 계정, 계정 삭제 경로, 위치 권한, 외부 서비스 및 앱 기능 설명을 제공했다.
- **UGC 대응 범위**: `user_blocks` 기반 사용자 차단·차단 해제·차단 사용자 리뷰 필터링·관리 화면을 지원했다. 리뷰 신고는 `can_report_review(uuid)` SECURITY DEFINER helper와 INSERT RLS로 본인 리뷰 신고를 차단하고 `reporter_id`를 명시한다. DB unique 제약은 중복 신고를 유지하고 앱은 중복 시 "이미 신고한 리뷰입니다." 메시지를 표시한다.
- **2026-09-05 — Live 확인**: Apple App Store에서 실제 공개 상태를 확인했다. iOS 관련 blocking issue는 없다.
- **Release QA**: iPhone 12 Pro Max / iOS 26.6에서 Build 46 Release 앱의 core flow를 확인했다. `flutter analyze lib`는 `No issues found`, `flutter build ios --release`는 성공했다. Release target에는 `ENABLE_DEBUG_DYLIB = NO`를 적용했으며 Runner binary의 `Runner.debug.dylib` 미참조를 `otool`로 확인했다.

## 플랫폼 값
- Bundle/App ID: `com.muselry.muselry` (iOS·Android 공통).
- Android: compileSdk 36, minSdk 23, targetSdk 36, versionCode/Name = flutter 값.
- iOS: Deployment Target **13.0** → ⚠️ 2027 봄부터 15.0 필수(업로드 경고).
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
- iOS App Store 출시 이후 운영·업데이트 단계.
- 회원탈퇴 RPC에 Storage(avatar/review image) 삭제 추가 — DB cascade로는 사진 미삭제.
- iOS Deployment Target 15.0 상향.
- (선택) `Info.plist`에 `ITSAppUsesNonExemptEncryption=false` 추가 시 수출규정 질문 스킵.

> 심사 데모 계정·제출 ID 등 민감정보는 여기 저장하지 않는다. 원본 인수인계 문서 참조.
