-- ============================================================
-- Day 8 확장: reviews 테이블 v2 마이그레이션 — Case B
-- 방식: ALTER TABLE로 visit_id 컬럼 추가 (기존 데이터 보존)
-- 정책 변경: 1인 1박물관 1리뷰 → 1방문 1리뷰 (visit_id 기반)
--
-- ✅  권장: 기존 reviews 데이터를 보존해야 하는 경우 사용
--          개발 환경에서 리뷰 데이터가 없다면 Case A가 더 간단합니다.
--
-- 실행 전 확인:
--   1. profiles, museums, visits 테이블이 존재해야 합니다.
--   2. 기존 reviews 행이 있는 경우 Step 2에서 visit_id를 NULL로 채운 뒤
--      수동으로 올바른 visit_id를 업데이트해야 합니다.
--   3. 기존 리뷰가 없는 경우 Step 2를 건너뛰고 바로 NOT NULL 제약을 추가합니다.
-- ============================================================

-- ─── Step 1: visit_id 컬럼 추가 (일단 NULL 허용) ─────────────

ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS visit_id UUID REFERENCES visits(id) ON DELETE CASCADE;

COMMENT ON COLUMN reviews.visit_id IS '리뷰가 연결된 방문 기록 ID. 1방문 1리뷰 정책 적용.';

-- ─── Step 2: 기존 리뷰 데이터 visit_id 채우기 ────────────────
-- ⚠️  기존 reviews 행이 있는 경우에만 실행합니다.
--     각 리뷰의 (user_id, museum_id)로 visits 테이블에서 가장 최근 방문을 매핑합니다.
--     매핑 불가능한 리뷰는 visit_id가 NULL로 남습니다 — 수동 처리 필요.

UPDATE reviews r
SET visit_id = (
  SELECT v.id
  FROM visits v
  WHERE v.user_id = r.user_id
    AND v.museum_id = r.museum_id
  ORDER BY v.visited_at DESC
  LIMIT 1
)
WHERE r.visit_id IS NULL;

-- ─── Step 2-1: 매핑 불가 리뷰 확인 (실행 후 결과 확인 권장) ──
/*
SELECT id, user_id, museum_id, created_at
FROM reviews
WHERE visit_id IS NULL;
-- 결과가 있으면 수동으로 visit_id를 채우거나 해당 리뷰를 removed 처리 후 진행
*/

-- ─── Step 3: visit_id NOT NULL 제약 추가 ─────────────────────
-- ⚠️  Step 2 실행 후 visit_id IS NULL 인 행이 없어야 합니다.
--     NULL 행이 남아 있으면 이 단계에서 오류가 발생합니다.

ALTER TABLE reviews
  ALTER COLUMN visit_id SET NOT NULL;

-- ─── Step 4: 기존 인덱스 제거 ────────────────────────────────
-- 기존 1인 1박물관 1리뷰 인덱스 (user_id + museum_id 기반) 제거

DROP INDEX IF EXISTS reviews_unique_active_user_museum;

-- ─── Step 5: 새 인덱스 생성 ──────────────────────────────────

-- visit_id 조회 인덱스
CREATE INDEX IF NOT EXISTS reviews_visit_id_idx
  ON reviews (visit_id);

-- 1방문 1리뷰 부분 인덱스 (visit_id 기반)
-- 같은 방문 기록(visit_id)에 활성 리뷰(removed 제외)를 1개만 허용
CREATE UNIQUE INDEX IF NOT EXISTS reviews_unique_active_visit
  ON reviews (visit_id)
  WHERE status != 'removed';

-- ─── Step 6: review_reports 트리거 추가 (없는 경우) ──────────
-- day8_pre_migration.sql에서 이미 생성된 경우 OR REPLACE로 덮어씁니다.

CREATE OR REPLACE FUNCTION auto_hide_review_on_reports()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE reviews
  SET status = 'hidden'
  WHERE id = NEW.review_id
    AND status = 'published'
    AND (SELECT COUNT(*) FROM review_reports WHERE review_id = NEW.review_id) >= 3;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_hide_review ON review_reports;
CREATE TRIGGER trg_auto_hide_review
  AFTER INSERT ON review_reports
  FOR EACH ROW EXECUTE FUNCTION auto_hide_review_on_reports();

-- ─── 완료 확인 쿼리 ──────────────────────────────────────────
/*
-- 1. visit_id 컬럼 추가 확인
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'reviews' AND column_name = 'visit_id';

-- 2. 기존 인덱스 제거 및 새 인덱스 생성 확인
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'reviews'
ORDER BY indexname;

-- 3. visit_id NULL 행 없음 확인
SELECT COUNT(*) AS null_visit_count FROM reviews WHERE visit_id IS NULL;

-- 4. 1방문 1리뷰 인덱스 확인
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'reviews'
  AND indexname = 'reviews_unique_active_visit';
*/
