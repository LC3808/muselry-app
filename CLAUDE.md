# CLAUDE.md — Muselry LLM Wiki 운영 규칙 (schema)

이 파일은 Andrej Karpathy의 LLM Wiki 패턴을 Muselry 프로젝트에 적용한 **운영 schema**다.
새 세션에서 Claude는 프로젝트/과거 대화를 처음부터 다시 분석하지 말고, 먼저 `wiki/`를 활용한다.

> 참고 원문: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f

---

## 새 세션 시작 workflow (반드시 순서대로)

1. **`wiki/index.md`** 를 먼저 읽는다 — 어떤 페이지가 있고 언제 읽는지 파악 (짧은 탐색 지도).
2. **`wiki/current-status.md`** 로 현재 상태(branch·application code baseline·릴리스·진행중 작업)를 확인한다.
3. 현재 요청과 관련된 Wiki 페이지만 골라 찾는다.
4. **필요한 페이지만** 읽는다. Wiki 전체를 한 번에 읽지 않는다.
5. Wiki를 무조건 source of truth로 믿지 않는다.
6. 코드와 충돌하면 **실제 코드 → Git → 원본 문서** 순으로 우선 검증한다(아래 참조).
7. 작업 결과 새로운 **장기 지식**이 생기면 해당 Wiki 페이지를 업데이트한다.
8. 단순 대화·일회성 시행착오·터미널 로그는 기록하지 않는다.

---

## 코드가 최종 기술적 Source of Truth

기술 내용에서 Wiki와 실제 코드가 충돌하면 숨기지 말고 다음 순서로 확인한다:

```
Wiki  →  관련 실제 코드  →  Git history  →  (필요 시) 원본 문서/스펙
```

- Wiki가 outdated라고 판단되면 **Wiki를 수정**한다(코드를 Wiki에 맞추지 않는다).
- 예: `lib/core/app_constants.dart`의 `appVersion` 같은 상수는 실제 릴리스 버전과 다를 수 있으므로,
  버전은 항상 `pubspec.yaml`과 Git tag/commit을 우선한다.

---

## Wiki 업데이트 기준

모든 작업 후 무조건 여러 파일을 수정하지 않는다. 다음 한 가지 질문으로 판단한다:

> **"이 정보가 다음 세션이나 향후 비슷한 작업에서 다시 필요할 가능성이 높은가?"**

- **YES** → 적절한 Wiki 페이지에 통합(중복 없이, 압축해서).
- **NO** → 기록하지 않는다.

특히 다음은 반드시 축적한다:
- 중요한 architecture / 구현 **결정** → `wiki/decisions/` (형식: `_template.md`)
- 어렵게 해결한 **버그 지식** → `wiki/bugs/` (형식: `_template.md`)
- 릴리스/스토어 상태 변화 → `wiki/release/store-submission.md`
- 현재 상태 변화 → `wiki/current-status.md` (과거 상태 누적 금지, 최신만 유지)
- 시간순 작업 흐름 → `wiki/log.md` (append)

---

## Token 절약 규칙

- 기본 탐색 순서: `wiki/index.md → wiki/current-status.md → 관련 문서 → 필요한 실제 코드`.
- **Wiki 전체를 매번 읽는 행위 금지.**
- 긴 페이지는 관련 section만 읽는다.
- `wiki/index.md`와 `wiki/current-status.md`는 **짧게** 유지한다. 비대해지면 하위 페이지로 분리한다.
- Wiki 자체가 context 낭비의 원인이 되어서는 안 된다.

---

## Lint (필요 시 Wiki health check)

요청 시 다음을 점검한다: stale knowledge · 코드와 Wiki 불일치 · 모순 페이지 ·
중복 정보 · orphan 페이지 · broken link · 비대한 페이지 · 폐기된 결정 · 누락된 핵심 개념.

---

## 절대 금지사항

- Wiki 구축/유지를 이유로 **기존 application code를 변경하지 않는다.**
- 기존 **Git history를 변경하지 않는다.**
- **사용자 승인 없이 commit/push 하지 않는다.**
- 기존 문서(README, spec, 인수인계 등)를 **이동·이름변경·삭제·덮어쓰기 하지 않는다.**
- `.env` 등 **시크릿, 심사 데모 계정, 개인정보를 Wiki에 저장하지 않는다.**
- 추측을 Wiki의 "사실"로 기록하지 않는다.

---

## 다른 에이전트(Manus / ChatGPT / Codex 등)와의 공유

- Wiki 본문(`wiki/**`)은 **표준 Markdown**으로만 작성한다(Claude 전용 문법 금지).
- Claude 전용 행동 규칙은 이 `CLAUDE.md`에만 둔다.
- 루트 `AGENTS.md`는 동일 Wiki를 가리키는 얇은 포인터다 — 다른 에이전트도 같은 지식을 재사용한다.
