-- ============================================================
-- Day 8 확장: reviews 테이블 v2 마이그레이션 — Case A
-- 방식: reviews 테이블 DROP 후 visit_id NOT NULL FK 포함 재생성
-- 정책 변경: 1인 1박물관 1리뷰 → 1방문 1리뷰 (visit_id 기반)
--
-- ⚠️  주의: 기존 reviews 데이터가 모두 삭제됩니다.
--          리뷰 데이터가 없는 개발/스테이징 환경에서만 사용하세요.
--          운영 환경에서는 Case B(ALTER TABLE)를 사용하세요.
--
-- 실행 전 확인:
--   1. profiles, museums, visits 테이블이 존재해야 합니다.
--   2. review_reports 테이블이 존재하면 FK 제약으로 인해 먼저 DROP됩니다.
-- ============================================================

-- ─── 섹션 0: 의존 테이블 정리 ────────────────────────────────

-- review_reports는 reviews.id를 FK로 참조하므로 먼저 DROP
DROP TABLE IF EXISTS review_reports CASCADE;

-- reviews 테이블 DROP (기존 데이터 전체 삭제)
DROP TABLE IF EXISTS reviews CASCADE;

-- ─── 섹션 1: reviews 테이블 재생성 (visit_id 포함) ───────────

CREATE TABLE reviews (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  museum_id    UUID NOT NULL REFERENCES museums(id)  ON DELETE CASCADE,
  visit_id     UUID NOT NULL REFERENCES visits(id)   ON DELETE CASCADE,
  rating       SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  content      TEXT NOT NULL CHECK (char_length(content) BETWEEN 10 AND 500),
  image_urls   TEXT[] DEFAULT '{}',
  status       TEXT NOT NULL DEFAULT 'published'
                 CHECK (status IN ('published', 'pending_review', 'hidden', 'removed')),
  report_count INTEGER NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE reviews IS '커뮤니티 공개 리뷰. 1방문 1리뷰 정책 적용 (visit_id 기반 부분 인덱스).';
COMMENT ON COLUMN reviews.visit_id IS '리뷰가 연결된 방문 기록 ID. NOT NULL — 방문 기록 없이 리뷰 작성 불가.';

-- ─── 섹션 2: 인덱스 ──────────────────────────────────────────

-- 박물관별 리뷰 조회 (published 우선)
CREATE INDEX reviews_museum_id_idx
  ON reviews (museum_id, status, created_at DESC);

-- 사용자별 리뷰 조회
CREATE INDEX reviews_user_id_idx
  ON reviews (user_id, created_at DESC);

-- visit_id 조회 (방문 기록으로 리뷰 존재 여부 확인)
CREATE INDEX reviews_visit_id_idx
  ON reviews (visit_id);

-- ─── 섹션 3: 1방문 1리뷰 부분 인덱스 ────────────────────────
-- 같은 방문 기록(visit_id)에 활성 리뷰(removed 제외)를 1개만 허용
-- removed 상태 리뷰는 제외 → 삭제 후 새 리뷰 작성 가능

CREATE UNIQUE INDEX reviews_unique_active_visit
  ON reviews (visit_id)
  WHERE status != 'removed';

-- ─── 섹션 4: updated_at 자동 갱신 트리거 ─────────────────────

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

-- ─── 섹션 5: RLS (Row Level Security) ────────────────────────

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

-- ─── 섹션 6: review_reports 테이블 재생성 ────────────────────

CREATE TABLE review_reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id   UUID NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reason      TEXT NOT NULL CHECK (char_length(reason) BETWEEN 1 AND 200),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (review_id, reporter_id)
);

CREATE INDEX review_reports_review_id_idx
  ON review_reports (review_id);

ALTER TABLE review_reports ENABLE ROW LEVEL SECURITY;

-- 신고: 로그인 사용자만 가능, 본인 리뷰 신고 금지
DROP POLICY IF EXISTS "Authenticated users can report reviews" ON review_reports;
CREATE POLICY "Authenticated users can report reviews"
  ON review_reports FOR INSERT
  WITH CHECK (
    auth.uid() = reporter_id
    AND auth.uid() != (SELECT user_id FROM reviews WHERE id = review_id)
  );

-- 본인 신고 내역 조회
DROP POLICY IF EXISTS "Users can view own reports" ON review_reports;
CREATE POLICY "Users can view own reports"
  ON review_reports FOR SELECT
  USING (auth.uid() = reporter_id);

-- ─── 섹션 7: 신고 누적 자동 hidden 트리거 ────────────────────

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
-- 1. reviews 테이블 컬럼 확인 (visit_id 포함 여부)
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'reviews'
ORDER BY ordinal_position;

-- 2. 1방문 1리뷰 부분 인덱스 확인
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'reviews'
  AND indexname = 'reviews_unique_active_visit';

-- 3. RLS 정책 확인
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'reviews';

-- 4. 트리거 확인
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_table IN ('reviews', 'review_reports');
*/
