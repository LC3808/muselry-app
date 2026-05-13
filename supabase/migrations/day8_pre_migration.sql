-- =============================================================
-- Muselry Day 8 사전 DB 마이그레이션
-- 파일: supabase/migrations/day8_pre_migration.sql
-- 작성: Manus AI  |  날짜: 2026-05-12
-- 실행 위치: Supabase Dashboard → SQL Editor
--
-- ⚠️  실행 전 반드시 검토 후 적용하세요.
-- ⚠️  각 섹션을 순서대로 실행하세요 (1 → 2 → 3 → 4).
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- 섹션 1: museums 테이블 — 어린이 친화 컬럼 추가
-- ─────────────────────────────────────────────────────────────

-- 1-1. is_kids_friendly 컬럼 추가 (기본값 false)
ALTER TABLE museums
  ADD COLUMN IF NOT EXISTS is_kids_friendly BOOLEAN NOT NULL DEFAULT false;

-- 1-2. kids_note 컬럼 추가 (운영자 자유 텍스트, nullable)
ALTER TABLE museums
  ADD COLUMN IF NOT EXISTS kids_note TEXT;

-- 1-3. 인덱스 추가 (어린이 친화 필터 쿼리 성능)
CREATE INDEX IF NOT EXISTS idx_museums_is_kids_friendly
  ON museums (is_kids_friendly)
  WHERE is_kids_friendly = true;

-- 1-4. 컬럼 코멘트
COMMENT ON COLUMN museums.is_kids_friendly IS
  '어린이/가족 친화 여부. 자동 분류 스크립트 + 운영자 수동 보정으로 관리.';
COMMENT ON COLUMN museums.kids_note IS
  '어린이 친화 관련 운영자 메모 (예: 체험 학습실 운영, 유모차 대여 가능)';


-- ─────────────────────────────────────────────────────────────
-- 섹션 2: museums 테이블 — average_rating 트리거 추가
--   (리뷰 작성/수정/삭제 시 산술 평균 자동 갱신)
-- ─────────────────────────────────────────────────────────────

-- 2-1. average_rating, review_count 컬럼 존재 확인 및 추가
ALTER TABLE museums
  ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3,2) DEFAULT 0.0,
  ADD COLUMN IF NOT EXISTS review_count   INTEGER      DEFAULT 0;

-- 2-2. 트리거 함수 생성
CREATE OR REPLACE FUNCTION update_museum_rating_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_museum_id UUID;
BEGIN
  -- INSERT/UPDATE: new row 기준, DELETE: old row 기준
  IF TG_OP = 'DELETE' THEN
    v_museum_id := OLD.museum_id;
  ELSE
    v_museum_id := NEW.museum_id;
  END IF;

  UPDATE museums
  SET
    review_count   = (
      SELECT COUNT(*)
      FROM reviews
      WHERE museum_id = v_museum_id
        AND status = 'published'
    ),
    average_rating = COALESCE((
      SELECT ROUND(AVG(rating)::NUMERIC, 2)
      FROM reviews
      WHERE museum_id = v_museum_id
        AND status = 'published'
    ), 0.0)
  WHERE id = v_museum_id;

  RETURN NULL;
END;
$$;

-- 2-3. 트리거 등록 (reviews 테이블에 INSERT/UPDATE/DELETE 시 발동)
DROP TRIGGER IF EXISTS trg_update_museum_rating ON reviews;
CREATE TRIGGER trg_update_museum_rating
  AFTER INSERT OR UPDATE OF rating, status OR DELETE
  ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_museum_rating_stats();


-- ─────────────────────────────────────────────────────────────
-- 섹션 3: review_reports 테이블 생성
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS review_reports (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id   UUID        NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  reporter_id UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason      TEXT        NOT NULL
    CHECK (reason IN ('spam', 'inappropriate', 'fake', 'other')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- 동일 사용자가 동일 리뷰를 중복 신고하지 못하도록 제약
  UNIQUE (review_id, reporter_id)
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_review_reports_review_id
  ON review_reports (review_id);

-- RLS 활성화
ALTER TABLE review_reports ENABLE ROW LEVEL SECURITY;

-- 정책: 로그인 사용자만 신고 가능
CREATE POLICY "Users can insert own reports"
  ON review_reports FOR INSERT
  TO authenticated
  WITH CHECK (reporter_id = auth.uid());

-- 정책: 본인 신고 내역만 조회 가능
CREATE POLICY "Users can view own reports"
  ON review_reports FOR SELECT
  TO authenticated
  USING (reporter_id = auth.uid());

-- 신고 3건 이상 누적 시 리뷰 자동 숨김 트리거
CREATE OR REPLACE FUNCTION auto_hide_reported_review()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_report_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_report_count
  FROM review_reports
  WHERE review_id = NEW.review_id;

  IF v_report_count >= 3 THEN
    UPDATE reviews
    SET status = 'hidden'
    WHERE id = NEW.review_id
      AND status = 'published';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_hide_review ON review_reports;
CREATE TRIGGER trg_auto_hide_review
  AFTER INSERT ON review_reports
  FOR EACH ROW
  EXECUTE FUNCTION auto_hide_reported_review();


-- ─────────────────────────────────────────────────────────────
-- 섹션 4: museum_ranking 테이블 생성
--   (베이지안 점수 캐싱 — Day 9 배치 로직에서 갱신)
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS museum_ranking (
  museum_id      UUID        PRIMARY KEY REFERENCES museums(id) ON DELETE CASCADE,
  bayesian_score NUMERIC(6,4) NOT NULL DEFAULT 0.0,
  rank_overall   INTEGER,
  rank_by_region INTEGER,   -- 같은 region_1 내 순위
  rank_by_type   INTEGER,   -- 같은 type 내 순위
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 인덱스 (인기 탭 정렬 성능)
CREATE INDEX IF NOT EXISTS idx_museum_ranking_bayesian
  ON museum_ranking (bayesian_score DESC);

CREATE INDEX IF NOT EXISTS idx_museum_ranking_overall
  ON museum_ranking (rank_overall ASC NULLS LAST);

-- RLS 활성화 (읽기는 전체 공개, 쓰기는 서비스 롤만)
ALTER TABLE museum_ranking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read ranking"
  ON museum_ranking FOR SELECT
  TO anon, authenticated
  USING (true);

-- 코멘트
COMMENT ON TABLE museum_ranking IS
  '베이지안 평균 기반 인기 점수 캐싱 테이블. Day 9 Edge Function 배치로 일 1회 갱신.';
COMMENT ON COLUMN museum_ranking.bayesian_score IS
  'score = (review_count * average_rating + C * global_avg) / (review_count + C), C=10';


-- ─────────────────────────────────────────────────────────────
-- 완료 확인 쿼리 (실행 후 결과 확인용)
-- ─────────────────────────────────────────────────────────────

-- 아래 쿼리를 실행하여 컬럼/테이블이 정상 생성되었는지 확인하세요.

/*
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'museums'
  AND column_name IN ('is_kids_friendly', 'kids_note', 'average_rating', 'review_count')
ORDER BY column_name;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('review_reports', 'museum_ranking');

SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name IN ('trg_update_museum_rating', 'trg_auto_hide_review');
*/
