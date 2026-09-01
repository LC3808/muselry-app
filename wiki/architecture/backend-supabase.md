# 백엔드 — Supabase (backend-supabase)

> 원본: `supabase/migrations/`, `db/migrations/`, `lib/data/repositories/`, `lib/core/app_constants.dart`.
> 스키마 충돌 시 실제 마이그레이션 SQL과 Supabase 대시보드 우선.

## 구성
- Supabase: PostgreSQL + Auth + Storage + RLS (`supabase_flutter` ^2.8.4).

## 테이블 (원본: `app_constants.dart` 상수 + `supabase/migrations/museuly_supabase_schema.sql`)
- `profiles`, `museums`, `bookmarks`, `visits`, `reviews`
- `review_likes`, `reports`, `edit_suggestions`
- (스키마 파일의 CREATE TABLE 확인분: profiles·museums·bookmarks·visits·reviews. 나머지는 상수/후속 마이그레이션 참조 — 사용 전 실제 SQL 검증.)

## Storage 버킷 (원본: `app_constants.dart`)
- `avatars`, `review-images`, `museum-images`.

## 마이그레이션 위치 (⚠️ 두 곳)
- `supabase/migrations/` — day8~day11 다수(reviews, ranking RPC, popularity, kakao patch, kids fields, triggers 등).
- `db/migrations/` — `v1_10_reviews_rating_numeric.sql`.
→ 스키마 이력 볼 때 **두 폴더 모두** 확인.

## 주요 RPC/트리거 (원본: 마이그레이션 파일명)
- `day9_museum_ranking_rpc.sql` — 인기 순위(베이지안 평균).
- `day10_profile_trigger.sql`, `hotfix_email_signup_trigger.sql` — 가입 시 profiles 생성.
- `delete_my_account` RPC — repo에 본문 없음(대시보드 전용). Storage 사진은 DB cascade로 안 지워짐(후속 과제).

## Edge Function
- `supabase/functions/kto-nearby-places/` (Deno/TS) — KTO 주변 관광지. `_shared/kto.ts`, `_shared/cors.ts`.
  세부 계약은 [../features](../features/) 또는 함수 `README.md` 참조.
