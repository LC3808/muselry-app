-- ============================================================
-- Day 8 트리거 보완: trg_update_museum_rating 재등록
-- 원인: Case A (reviews 테이블 DROP → 재생성) 시 트리거가 함께 삭제됨.
--       트리거 함수(update_museum_rating_stats)는 DB에 남아 있으므로
--       트리거 재등록만 하면 됩니다.
-- ============================================================

-- ① 트리거 함수 재생성 (함수가 남아 있어도 OR REPLACE로 안전하게 재등록)
CREATE OR REPLACE FUNCTION update_museum_rating_stats()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_museum_id UUID;
BEGIN
  -- DELETE: OLD row 기준 / INSERT·UPDATE: NEW row 기준
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

-- ② 트리거 재등록
DROP TRIGGER IF EXISTS trg_update_museum_rating ON reviews;
CREATE TRIGGER trg_update_museum_rating
  AFTER INSERT OR UPDATE OF rating, status OR DELETE
  ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_museum_rating_stats();

-- ③ 등록 확인 쿼리 (실행 후 3행 반환 기대: INSERT / UPDATE / DELETE)
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_table = 'reviews'
  AND trigger_name = 'trg_update_museum_rating'
ORDER BY event_manipulation;
-- 기대값: DELETE / INSERT / UPDATE 각 1행 (총 3행)
