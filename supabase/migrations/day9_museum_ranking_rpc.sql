-- ============================================================
-- Day 9: museum_ranking 베이지안 점수 계산 RPC 함수
-- 실행 전 확인: museum_ranking 테이블이 존재해야 합니다.
--              (day8_pre_migration.sql에서 생성됨)
-- ============================================================

-- ─── 섹션 1: 베이지안 점수 계산 함수 ─────────────────────────
-- 공식: score = (review_count * average_rating + C * global_avg) / (review_count + C)
-- C = 10 (신뢰 계수: 리뷰 수가 적은 박물관의 과대평가 방지)

CREATE OR REPLACE FUNCTION refresh_museum_ranking()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_global_avg NUMERIC;
  v_c          NUMERIC := 10;
BEGIN
  -- 1. 전체 평균 별점 계산 (published 리뷰만)
  SELECT COALESCE(AVG(rating), 3.0)
  INTO v_global_avg
  FROM reviews
  WHERE status = 'published';

  -- 2. 베이지안 점수 계산 및 museum_ranking upsert
  INSERT INTO museum_ranking (museum_id, bayesian_score, updated_at)
  SELECT
    m.id AS museum_id,
    ROUND(
      (COALESCE(m.review_count, 0) * COALESCE(m.average_rating, 0)
       + v_c * v_global_avg)
      / (COALESCE(m.review_count, 0) + v_c),
      4
    ) AS bayesian_score,
    now()
  FROM museums m
  ON CONFLICT (museum_id)
  DO UPDATE SET
    bayesian_score = EXCLUDED.bayesian_score,
    updated_at     = EXCLUDED.updated_at;

  -- 3. 전체 순위 업데이트 (bayesian_score 내림차순)
  WITH ranked AS (
    SELECT museum_id,
           ROW_NUMBER() OVER (ORDER BY bayesian_score DESC, museum_id) AS rn
    FROM museum_ranking
  )
  UPDATE museum_ranking mr
  SET rank_overall = r.rn
  FROM ranked r
  WHERE mr.museum_id = r.museum_id;

  -- 4. 지역별 순위 업데이트
  WITH ranked_region AS (
    SELECT mr.museum_id,
           ROW_NUMBER() OVER (
             PARTITION BY m.region_1
             ORDER BY mr.bayesian_score DESC, mr.museum_id
           ) AS rn
    FROM museum_ranking mr
    JOIN museums m ON m.id = mr.museum_id
  )
  UPDATE museum_ranking mr
  SET rank_by_region = r.rn
  FROM ranked_region r
  WHERE mr.museum_id = r.museum_id;

  -- 5. 유형별 순위 업데이트
  WITH ranked_type AS (
    SELECT mr.museum_id,
           ROW_NUMBER() OVER (
             PARTITION BY m.type
             ORDER BY mr.bayesian_score DESC, mr.museum_id
           ) AS rn
    FROM museum_ranking mr
    JOIN museums m ON m.id = mr.museum_id
  )
  UPDATE museum_ranking mr
  SET rank_by_type = r.rn
  FROM ranked_type r
  WHERE mr.museum_id = r.museum_id;

END;
$$;

-- ─── 섹션 2: RPC 권한 설정 ────────────────────────────────────
-- anon 사용자는 호출 불가, authenticated 사용자만 호출 가능
-- (실제 운영에서는 service_role만 호출하도록 제한 권장)
REVOKE ALL ON FUNCTION refresh_museum_ranking() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION refresh_museum_ranking() TO authenticated;

-- ─── 섹션 3: 초기 데이터 적재 ────────────────────────────────
-- 함수 생성 직후 1회 실행하여 기존 museums 데이터로 초기 랭킹 생성
-- (리뷰가 없는 경우 bayesian_score ≈ global_avg 로 균등 배분됨)
SELECT refresh_museum_ranking();

-- ─── 완료 확인 쿼리 ──────────────────────────────────────────
/*
-- 1. 함수 생성 확인
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_name = 'refresh_museum_ranking';

-- 2. 초기 랭킹 데이터 확인 (상위 10개)
SELECT mr.rank_overall, m.name, m.type, m.region_1,
       mr.bayesian_score, m.average_rating, m.review_count
FROM museum_ranking mr
JOIN museums m ON m.id = mr.museum_id
ORDER BY mr.rank_overall ASC
LIMIT 10;

-- 3. 전체 랭킹 행 수 확인
SELECT COUNT(*) AS total_ranked FROM museum_ranking;
*/
