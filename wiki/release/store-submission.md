# 릴리스 & 스토어 제출 (store-submission)

> 원본: `Muselry_인수인계_2026-08-25_iOS제출완료.md`, `pubspec.yaml`, `android/app/build.gradle`, `ios/Runner.xcodeproj`.
> 상태 값이 바뀌면 이 페이지와 `current-status.md`를 함께 갱신.

## 현재 (2026-09-05)
- 앱 버전(pubspec): **1.0.1+46** (커밋 be21986). App Store 라이브: 1.0(빌드44).
- **iOS**: 1.0.0(빌드 44) App Store **심사 승인 + 정식 출시(공개) 확인** (2026-09-04 공개, Apple lookup version 1.0). iOS 최초 정식 출시.
- **iOS(최신 source)**: 사용자 차단/UGC 모더레이션 반영(befe085·4f3b995), pubspec build 46. ASC 새 빌드 미제출(라이브 빌드 44 유지). 다음 iOS 업데이트는 공모전 제출 후 별도 결정.
- **Android**: Google Play 1.0.1+45 / target API 36 — Production 100% 게시 확인.
- **Android Developer Verification**: com.muselry.muselry 패키지 등록 확인(키 1개), 현재 화면상 추가 조치 없음.

## 플랫폼 값
- Bundle/App ID: `com.muselry.muselry` (iOS·Android 공통).
- Android: compileSdk 36, minSdk 23, targetSdk 36, versionCode/Name = flutter 값.
- iOS: Deployment Target **13.0** → ⚠️ 2027 봄부터 15.0 필수(업로드 경고).
- iOS: iPhone 전용(`TARGETED_DEVICE_FAMILY=1`) — iPad 스크린샷 회피.

## 공식 URL / 메타 (원본: 인수인계 문서)
- 개인정보 `https://muselry.com/privacy` · 지원 `/support` · 마케팅 `muselry.com` · 계정삭제 `/delete-account`.
- 카테고리 라이프스타일/여행 · 연령 4+ · 무료. 수출규정: HTTPS만(해당 없음).
- 공식 웹은 **별도 repo** `LC3808/muselry-web` (Cloudflare Pages). 서로 건드리지 않음.

## 릴리스 절대 규칙 (원본: 인수인계 "절대 규칙")
- main 임의 병합·시크릿 커밋·기존 인증(Google/Kakao/Apple) 변경·Bundle ID 변경·dependency 일괄 upgrade·무관 파일 커밋 금지.
- production 배포/push는 운영자 승인 후. 추측 API 금지(공식 문서 확인).

## 후속 과제
- 회원탈퇴 RPC에 Storage(avatar/review image) 삭제 추가 — DB cascade로는 사진 미삭제.
- iOS Deployment Target 15.0 상향.
- (선택) `Info.plist`에 `ITSAppUsesNonExemptEncryption=false` 추가 시 수출규정 질문 스킵.

> 심사 데모 계정·제출 ID 등 민감정보는 여기 저장하지 않는다. 원본 인수인계 문서 참조.
