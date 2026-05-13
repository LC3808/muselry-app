-- =============================================================
-- Muselry Day 8 어린이 친화 백필 SQL
-- 파일: supabase/migrations/day8_kids_backfill.sql
-- 작성: Manus AI  |  날짜: 2026-05-12
-- 실행 위치: Supabase Dashboard → SQL Editor
--
-- 실행 순서:
--   Step 1: NOT NULL 제약 추가 (review_count, average_rating)
--   Step 2: 자동 분류 25건 백필
--   Step 3: 완료 확인 쿼리
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- Step 1: review_count / average_rating NOT NULL 제약 추가
-- (현재 NULL 값 0건 확인 완료 — 안전하게 실행 가능)
-- ─────────────────────────────────────────────────────────────

ALTER TABLE museums ALTER COLUMN review_count   SET DEFAULT 0;
ALTER TABLE museums ALTER COLUMN review_count   SET NOT NULL;

ALTER TABLE museums ALTER COLUMN average_rating SET DEFAULT 0.0;
ALTER TABLE museums ALTER COLUMN average_rating SET NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- Step 2: 어린이 친화 자동 분류 25건 백필
-- (v1.1 분류 기준 5가지 원칙 적용, dry-run 검증 완료)
-- ─────────────────────────────────────────────────────────────

UPDATE museums
SET is_kids_friendly = true
WHERE id IN (
  '789c6173-3af4-48f1-9a3c-9cbda3f18516',
  '7a472dcd-650b-47d5-a50d-1c3ab1c3ce7e',
  'd7b532c4-ce88-4c37-92a9-271d4214c5bc',
  'aa430c36-2751-4c5f-9dcf-b983b5a24156',
  '7e41c5fa-ea0a-41b7-9419-044aea43f418',
  '1f1a0b27-cf69-4df0-8b8d-0ce48d222446',
  '14e67fc4-21f9-47c5-a971-752b202f1597',
  '5a517229-3c56-4bd9-83e3-cf305ea0feaa',
  'd592ae35-cfaf-4152-a5fa-045db457addb',
  'e372679c-0d2a-46ae-a503-47263ec801e1',
  '542b30c0-d88a-4b6f-94d7-7796e9a9cdca',
  'f8db0f7c-1fc7-4412-bed0-ae5a1794998e',
  'f571ca3c-246c-4f0f-8215-a157b3108741',
  'a47e43a8-134f-4c67-b4dc-b2206ee3b5df',
  'bcca36d2-355d-48b0-bf81-281ed9cbb6fa',
  '1f637680-d760-4ccf-9af2-4b6aae126353',
  '7bb2da5a-60a3-4871-9ff9-0478a4ea05a5',
  '4b19ef9d-0050-444a-b4c6-05d9822ca241',
  '6b574824-90e9-4198-9532-90c4393bf8d3',
  '510bbd44-2afb-47de-980c-6b649bbf34ba',
  'e40f5ac6-a0f7-4021-8b12-73af70cbe87a',
  '004cf6c1-9082-40b5-9613-72d5fcb2981c',
  '1247840a-d5f9-483f-ae6a-30ff1a1ac8c7',
  '3bc130e8-4221-45de-920c-ad745d19aad1',
  'e54b8cf4-89ae-4655-892c-eeb4b7e01fa1'
);


-- ─────────────────────────────────────────────────────────────
-- Step 3: 완료 확인 쿼리
-- ─────────────────────────────────────────────────────────────

-- 3-1. NOT NULL 제약 확인
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'museums'
  AND column_name IN ('average_rating', 'review_count', 'is_kids_friendly', 'kids_note')
ORDER BY column_name;

-- 3-2. 백필 결과 확인 (25건이 표시되어야 함)
SELECT id, name, is_kids_friendly
FROM museums
WHERE is_kids_friendly = true
ORDER BY name;
