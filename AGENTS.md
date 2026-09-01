# AGENTS.md — Muselry 프로젝트 에이전트 안내

이 저장소는 Andrej Karpathy의 **LLM Wiki 패턴**을 사용해, 프로젝트의 기술적 사실·아키텍처·
결정·버그 지식·현재 상태를 `wiki/` 아래에 구조화해 유지한다. 모든 AI 에이전트
(Claude, ChatGPT, Manus, Codex, Copilot 등)는 이 Wiki를 공유한다.

## 시작 순서

1. `wiki/index.md` — 무슨 페이지가 있고 언제 읽는지 (짧은 탐색 지도)
2. `wiki/current-status.md` — 현재 상태(branch·HEAD·릴리스·진행중)
3. 요청과 관련된 페이지만 읽는다. 전체를 한 번에 읽지 않는다.

## 원칙

- **코드가 최종 Source of Truth.** Wiki와 코드가 충돌하면 실제 코드 → Git → 원본 문서 순으로 검증하고, outdated Wiki는 수정한다.
- 새 장기 지식이 생기면 해당 Wiki 페이지를 **압축해서** 갱신한다. 일회성 시행착오·로그는 기록하지 않는다.
- 기존 코드·Git history·기존 문서를 변경/이동/삭제하지 않는다. commit/push는 운영자 승인 후.
- 시크릿·개인정보·심사 계정은 Wiki에 저장하지 않는다.

> Claude 전용 세부 행동 규칙: `CLAUDE.md` 참조.
