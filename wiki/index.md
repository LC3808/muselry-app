# Muselry Wiki — 탐색 지도 (index)

> 이 파일은 **짧게** 유지한다. 무슨 페이지가 있고 언제 읽는지만 적는다. 내용 서술 금지.

## 먼저 읽기
- [current-status.md](current-status.md) — 현재 branch·HEAD·릴리스·진행중 작업 (세션 시작 시 필독)
- [overview.md](overview.md) — 앱이 무엇인지, 기술 스택 요약

## 아키텍처 (필요할 때만)
- [architecture/app-structure.md](architecture/app-structure.md) — lib/ 계층, presentation↔features 이중 구조
- [architecture/state-management.md](architecture/state-management.md) — Riverpod + go_router
- [architecture/backend-supabase.md](architecture/backend-supabase.md) — Supabase 테이블·RLS·Storage·Edge Function
- [architecture/integrations.md](architecture/integrations.md) — Naver Map, 소셜 로그인, KTO/문화정보 OpenAPI

## 지식 축적
- [decisions/](decisions/) — 중요 기술 결정 (형식: `decisions/_template.md`)
- [bugs/](bugs/) — 해결한 어려운 버그 (형식: `bugs/_template.md`)
- [features/](features/) — 기능별 심화 지식 (내용 생길 때만 생성)
- [release/store-submission.md](release/store-submission.md) — iOS/Android 스토어 제출 상태·규칙

## 흐름 기록
- [log.md](log.md) — 시간순 작업/ingest 로그 (append 전용)

## raw source of truth (복사본 아님 — 원본 파일 직접 참조)
프로젝트 루트의 기존 문서/코드/Git이 원본이다. 충돌 시 아래를 우선 검증한다.
- 코드: `lib/`, `android/`, `ios/`, `supabase/` · 형상: `git log`, `pubspec.yaml`
- 스펙: `muselry_specification_v1.7.md` / `v1.8.md` / `v1.9.md`
- 빌드 노트: `build-notes.md` · QA: `day10_qa_checklist.md`
- 인수인계: `Muselry_인수인계_2026-08-25_iOS제출완료.md`, `Manus_인수인계_2026-08-25.md`, `Muselry_작업명세서_2026-08-25.md`
- 앱 README: `README.md` · Edge Function: `supabase/functions/kto-nearby-places/README.md`
