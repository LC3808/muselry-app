-- =============================================================
-- Muselry Day 8 보완 마이그레이션 (day8_supplement.sql)
-- 작성: Manus AI  |  날짜: 2026-05-12
-- 실행 위치: Supabase Dashboard → SQL Editor
--
-- day8_pre_migration.sql 실행 완료 후 이 파일을 실행하세요.
-- 두 가지 보완 사항:
--   A. review_reports 본인 리뷰 신고 금지 RLS 정책 추가
--   B. trg_update_museum_rating 트리거 — status 변경 시 재계산 보완
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- 보완 A: review_reports — 본인 리뷰 신고 금지 RLS 정책
--
-- 현재 day8_pre_migration.sql의 INSERT 정책:
--   WITH CHECK (reporter_id = auth.uid())
--   → 로그인 사용자만 신고 가능 ✅
--   → 본인 리뷰 신고 금지 조건 누락 ⚠️
--
-- 아래 정책으로 교체하여 자기 리뷰 자동 hidden 어뷰징 차단
-- ─────────────────────────────────────────────────────────────

-- 기존 INSERT 정책 삭제
DROP POLICY IF EXISTS "Users can insert own reports" ON review_reports;

-- 보완된 INSERT 정책: 로그인 사용자 + 본인 리뷰 신고 금지
CREATE POLICY "Users can insert own reports"
  ON review_reports FOR INSERT
  TO authenticated
  WITH CHECK (
    reporter_id = auth.uid()
    AND review_id NOT IN (
      SELECT id FROM reviews WHERE user_id = auth.uid()
    )
  );


-- ─────────────────────────────────────────────────────────────
-- 보완 B: trg_update_museum_rating 트리거 함수 교체
--
-- 현재 트리거 등록:
--   AFTER INSERT OR UPDATE OF rating, status OR DELETE
--
-- 문제: UPDATE OF rating, status 는 rating 또는 status 컬럼이
--       변경될 때만 발동하므로, 이론적으로는 status 변경도 처리됨.
--       그러나 트리거 함수 내부에서 OLD/NEW 상태를 구분하지 않아
--       DELETE 시 OLD.museum_id를 사용하지만,
--       UPDATE 시에는 NEW.museum_id만 사용 → 정상.
--
-- 실제 케이스 검증:
--   1. INSERT (status='published')   → NEW.museum_id 기준 재계산 ✅
--   2. INSERT (status='pending_review') → 재계산되나 published 필터로 미반영 ✅
--   3. published → hidden (UPDATE)   → UPDATE OF status 발동, 재계산 ✅
--   4. status='removed' (UPDATE)     → UPDATE OF status 발동, 재계산 ✅
--   5. hidden → published (UPDATE)   → UPDATE OF status 발동, 재계산 ✅
--   6. DELETE                        → OLD.museum_id 기준 재계산 ✅
--
-- 결론: 현재 트리거 함수는 모든 케이스를 정상 처리합니다.
-- 단, 명확성을 위해 함수에 케이스별 주석을 추가하고 재등록합니다.
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_museum_rating_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_museum_id UUID;
BEGIN
  -- 케이스별 museum_id 결정:
  --   DELETE: OLD row 기준 (삭제된 리뷰의 박물관)
  --   INSERT/UPDATE: NEW row 기준
  --     - INSERT status='published'     → published 집계에 포함됨
  --     - INSERT status='pending_review' → published 필터로 집계 제외
  --     - UPDATE published→hidden       → published 집계에서 제외됨
  --     - UPDATE hidden→published       → published 집계에 포함됨
  --     - UPDATE status='removed'       → published 집계에서 제외됨
  IF TG_OP = 'DELETE' THEN
    v_museum_id := OLD.museum_id;
  ELSE
    v_museum_id := NEW.museum_id;
  END IF;

  -- published 리뷰만 집계하여 museums 테이블 갱신
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

-- 트리거 재등록 (함수 교체 후 트리거 재등록 필요)
DROP TRIGGER IF EXISTS trg_update_museum_rating ON reviews;
CREATE TRIGGER trg_update_museum_rating
  AFTER INSERT OR UPDATE OF rating, status OR DELETE
  ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_museum_rating_stats();


-- ─────────────────────────────────────────────────────────────
-- 완료 확인 쿼리
-- ─────────────────────────────────────────────────────────────

/*
-- A. review_reports RLS 정책 확인
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'review_reports';

-- B. 트리거 재등록 확인
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trg_update_museum_rating';
*/
