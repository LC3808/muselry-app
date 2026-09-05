# 작업 로그 (log) — 시간순, append 전용

> 무슨 일이 있었는지 압축 한두 줄. 상세 지식은 해당 architecture/decisions/bugs 페이지에.

## 2026-09-01
- LLM Wiki 초기 구축(Karpathy 패턴). `CLAUDE.md`(schema) + `AGENTS.md`(포인터) + `wiki/**` 생성.
- 코드·Git·기존 문서에서 확인된 사실만 seed. 기존 코드/Git history/문서 무변경, commit 안 함.

## 2026-09-02
- Android 1.0.1+45 / target API 36 Production 100% 게시 확인, 실제 Android 기기 업데이트 확인.
- Android Developer Verification: com.muselry.muselry 패키지 등록 확인(키 1개).

## 2026-09-05
- Apple App Store에서 Muselry 정식 공개 확인 — 앱 `뮤즐리(Muselry) - 나만의 문화 지도`, iOS Version 1.0.1 / Build 46.
- App Store: `https://apps.apple.com/kr/app/id6800217014`.
- Apple Guideline 2.1 대응 완료: physical-device App Review recording 및 심사용 계정 제공, 위치 권한·외부 서비스·앱 기능·계정 삭제 경로 안내.
- UGC 대응 완료: 사용자 차단·차단 해제·차단 사용자 리뷰 필터링·관리 화면, 리뷰 신고 RLS 및 중복 신고 UX 수정.
- iPhone 12 Pro Max / iOS 26.6에서 Build 46 Release core flow QA 완료. iOS 최초 App Store 출시 milestone 달성.
