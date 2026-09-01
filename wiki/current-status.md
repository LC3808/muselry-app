# 현재 상태 (current-status)

> **최신 상태만** 압축 유지한다. 과거 상태를 누적하지 않는다(흐름은 `log.md`로).
> 갱신 시 낡은 줄은 교체한다.
> 역할 분리: **Git = 순간값(작업 시작 시 `git rev-parse HEAD`로 확인), Wiki = 장기 상태.**
> 순간적으로 변하는 Git HEAD를 여기 고정값으로 박지 않는다.

- **갱신일**: 2026-09-01
- **Branch**: `feature/kto-nearby-places`
- **Application code baseline**: `2f128ab`
  - 의미: 현재 Wiki가 설명하는 실제 application/backend 코드의 기준 commit (chore(android): target API 36, 1.0.1+45).
  - Git HEAD는 순간값이며 **작업 시작 시 실제 Git에서 확인**한다. 현재 HEAD를 Wiki에 고정값으로 저장하지 않는다.
  - `lib/`·`android/`·`ios/`·`supabase/` 등 실제 구현이 바뀔 때만 갱신한다.
  - **Wiki/documentation-only commit으로는 이 baseline을 갱신하지 않는다.**
- **앱 버전 (pubspec)**: `1.0.1+45`
- **Remote**: `https://github.com/LC3808/muselry-app.git` (LC3808/muselry-app)

## 릴리스 상태
- **iOS**: 1.0.0(빌드 44) App Store 심사 제출됨(Waiting for Review). Bundle `com.muselry.muselry`.
- **Android**: Google Play 업데이트 준비(1.0.1+45, target API 36).

## 진행 중 / 최근 작업
- KTO "함께 가볼 만한 곳" — Museum 상세화면에 주변 관광지 표시 (Edge Function `kto-nearby-places` + `lib/features/nearby/`).

## 미커밋(untracked) 참고
- 데이터 매칭 스크립트/CSV (`tourapi_*.py`, `museums.csv`, `conflicts.csv`, `matched_auto.csv` 등) — 앱 코드 아님, 일회성 데이터 작업 산출물.
- 인수인계 `.md` 3종 — raw 참조용(그대로 둠).

## 다음 후보 (원본: 인수인계 문서)
- iOS Deployment Target 13.0 → 15.0 (2027 봄 필수).
- 회원탈퇴 RPC에 Storage 사진 삭제 추가(개인정보 완전삭제).
- KTO Phase 1B(아동/가족), 1C(상세 "함께 가볼 만한 곳" 확장).

> 세부 릴리스 규칙·참조값은 [release/store-submission.md](release/store-submission.md).
