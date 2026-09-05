# 작업 로그 (log) — 시간순, append 전용

> 무슨 일이 있었는지 압축 한두 줄. 상세 지식은 해당 architecture/decisions/bugs 페이지에.

## 2026-09-01
- LLM Wiki 초기 구축(Karpathy 패턴). `CLAUDE.md`(schema) + `AGENTS.md`(포인터) + `wiki/**` 생성.
- 코드·Git·기존 문서에서 확인된 사실만 seed. 기존 코드/Git history/문서 무변경, commit 안 함.

## 2026-09-02
- Android 1.0.1+45 / target API 36 Production 100% 게시 확인, 실제 Android 기기 업데이트 확인.
- Android Developer Verification: com.muselry.muselry 패키지 등록 확인(키 1개).
- iOS 최신 source release build + iOS 26.6 실기기 Release 설치·실행, KTO Nearby 동작 확인(서울: 국립경찰박물관 / 안동: 안동시립박물관). ASC 새 빌드 미제출.
- 안동 KTO 결과 확인 → 공모전 대표 지역 사례로 활용 가능.
- 발견(P2): 상세 화면과 동일 문화공간이 Nearby 결과에 재노출 가능 → dedup 개선 항목.

## 2026-09-03~04
- 사용자 차단 기능 구현·커밋(`befe085` feat: add user blocking and fix review reporting; lib/ + ios/project.pbxproj + review_screen.dart 포함).
- UGC 모더레이션 DB 마이그레이션 커밋(`4f3b995`: `20260904_user_blocks.sql`, `20260904_review_reports_rls_fix.sql`).
- pubspec iOS build 46 bump 커밋(`be21986`, 1.0.1+46) — 소스만, ASC 미제출.

## 2026-09-04
- **iOS 1.0.0(빌드 44) App Store 심사 승인 + 정식 출시(공개) 확인** — Apple lookup version 1.0 / seller Copacabana Co. / 2026-09-04 공개. iOS 최초 정식 출시.
- **Muselry Android/iOS 양대 스토어 정식 출시 완료** (Android 1.0.1+45 Play Production / iOS 1.0 빌드44).

## 2026-09-05
- 공모전 P0 구현 단계 전환: 홈 컴팩트 개편(P0-1) + 문화행사 미등록 venue 지도 fallback(P0-2). 구현=Manus, 검수=Claude.
- 원칙 재확인: 라이브 iOS 빌드44 무조작, 새 ASC 빌드/버전 변경/submit 없음(공모전 후 결정).
