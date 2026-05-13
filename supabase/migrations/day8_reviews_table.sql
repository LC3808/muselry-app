-- ============================================================
-- Day 8: reviews 테이블 생성 SQL
-- 실행 전 확인: profiles, museums 테이블이 존재해야 합니다.
-- ============================================================

-- ─── 섹션 1: reviews 테이블 생성 ─────────────────────────────

CREATE TABLE IF NOT EXISTS reviews (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  museum_id    UUID NOT NULL REFERENCES museums(id)  ON DELETE CASCADE,
  rating       SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  content      TEXT NOT NULL CHECK (char_length(content) BETWEEN 10 AND 500),
  image_urls   TEXT[] DEFAULT '{}',
  status       TEXT NOT NULL DEFAULT 'published'
                 CHECK (status IN ('published', 'pending_review', 'hidden', 'removed')),
  report_count INTEGER NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 인덱스: 박물관별 리뷰 조회 (published 우선)
CREATE INDEX IF NOT EXISTS reviews_museum_id_idx
  ON reviews (museum_id, status, created_at DESC);

-- 인덱스: 사용자별 리뷰 조회
CREATE INDEX IF NOT EXISTS reviews_user_id_idx
  ON reviews (user_id, created_at DESC);

-- ─── 섹션 2: 1인 1리뷰 부분 인덱스 ──────────────────────────
-- 한 사용자가 같은 박물관에 활성 리뷰(removed 제외)를 1개만 작성 가능
-- removed 상태 리뷰는 제외 → 삭제 후 새 리뷰 작성 가능

CREATE UNIQUE INDEX IF NOT EXISTS reviews_unique_active_user_museum
  ON reviews (user_id, museum_id)
  WHERE status != 'removed';

-- ─── 섹션 3: updated_at 자동 갱신 트리거 ─────────────────────

CREATE OR REPLACE FUNCTION update_reviews_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reviews_updated_at ON reviews;
CREATE TRIGGER trg_reviews_updated_at
  BEFORE UPDATE ON reviews
  FOR EACH ROW EXECUTE FUNCTION update_reviews_updated_at();

-- ─── 섹션 4: RLS (Row Level Security) ────────────────────────

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- 정책 1: published 리뷰는 누구나 조회 가능
DROP POLICY IF EXISTS "Published reviews are viewable by everyone" ON reviews;
CREATE POLICY "Published reviews are viewable by everyone"
  ON reviews FOR SELECT
  USING (status = 'published');

-- 정책 2: 로그인 사용자는 본인 리뷰 전체 조회 가능 (pending/hidden 포함)
DROP POLICY IF EXISTS "Users can view own reviews" ON reviews;
CREATE POLICY "Users can view own reviews"
  ON reviews FOR SELECT
  USING (auth.uid() = user_id);

-- 정책 3: 로그인 사용자만 리뷰 작성 가능
DROP POLICY IF EXISTS "Authenticated users can insert reviews" ON reviews;
CREATE POLICY "Authenticated users can insert reviews"
  ON reviews FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 정책 4: 본인 리뷰만 수정 가능, removed 상태는 수정 불가
DROP POLICY IF EXISTS "Users can update own reviews" ON reviews;
CREATE POLICY "Users can update own reviews"
  ON reviews FOR UPDATE
  USING (auth.uid() = user_id AND status != 'removed')
  WITH CHECK (auth.uid() = user_id);

-- 정책 5: 실제 DELETE는 허용하지 않음 (소프트 삭제만 사용)
-- status = 'removed' UPDATE는 정책 4에서 허용됨

-- ─── 섹션 5: review_reports 외래키 확인 ──────────────────────
-- review_reports.review_id → reviews.id 외래키가 없다면 추가
-- (day8_pre_migration.sql에서 생성된 경우 이미 존재할 수 있음)

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'review_reports_review_id_fkey'
      AND table_name = 'review_reports'
  ) THEN
    ALTER TABLE review_reports
      ADD CONSTRAINT review_reports_review_id_fkey
      FOREIGN KEY (review_id) REFERENCES reviews(id) ON DELETE CASCADE;
  END IF;
END;
$$;

-- ─── 완료 확인 쿼리 ──────────────────────────────────────────
/*
-- 1. reviews 테이블 컬럼 확인
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'reviews'
ORDER BY ordinal_position;

-- 2. 1인 1리뷰 부분 인덱스 확인
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'reviews'
  AND indexname = 'reviews_unique_active_user_museum';

-- 3. RLS 정책 확인
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'reviews';

-- 4. 트리거 확인
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'reviews';
*/
