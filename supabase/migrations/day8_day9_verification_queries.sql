-- ============================================================
-- Day 8 + Day 9 SQL 실행 후 검증 쿼리 (9개 항목 + kids_friendly)
-- 실행 순서: day8_reviews_v2_case_a.sql → day9_museum_ranking_rpc.sql → 이 파일
-- ============================================================

-- ① reviews 테이블에 visit_id 컬럼이 존재하는지
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'reviews'
  AND column_name  = 'visit_id';
-- 기대값: column_name=visit_id, data_type=uuid, is_nullable=NO

-- ② visit_id가 NOT NULL인지 (위 쿼리 is_nullable=NO 이면 통과)
-- (① 쿼리에서 is_nullable 컬럼으로 확인)

-- ③ visit_id가 visits.id FK로 연결되어 있는지
SELECT tc.constraint_name, kcu.column_name,
       ccu.table_name AS foreign_table, ccu.column_name AS foreign_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'reviews'
  AND kcu.column_name = 'visit_id';
-- 기대값: foreign_table=visits, foreign_column=id

-- ④ reviews_unique_active_visit 인덱스가 존재하는지
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'reviews'
  AND indexname = 'reviews_unique_active_visit';
-- 기대값: 1행 반환

-- ⑤ 기존 reviews_unique_active_user_museum 인덱스가 없는지 (DROP 완료)
SELECT COUNT(*) AS old_index_exists
FROM pg_indexes
WHERE tablename = 'reviews'
  AND indexname = 'reviews_unique_active_user_museum';
-- 기대값: old_index_exists = 0

-- ⑥ review_reports 테이블과 UNIQUE(review_id, reporter_id) 제약이 정상인지
SELECT tc.constraint_name, tc.constraint_type, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'review_reports'
  AND tc.constraint_type = 'UNIQUE'
ORDER BY kcu.ordinal_position;
-- 기대값: review_id, reporter_id 두 컬럼이 UNIQUE 제약에 포함

-- ⑦ trg_update_museum_rating 트리거가 reviews 테이블에 연결되어 있는지
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_table = 'reviews'
  AND trigger_name = 'trg_update_museum_rating';
-- 기대값: 3행 (INSERT, UPDATE, DELETE 각각)

-- ⑧ museum_ranking row 수가 museums row 수와 일치하는지
SELECT
  (SELECT COUNT(*) FROM museums)       AS museums_count,
  (SELECT COUNT(*) FROM museum_ranking) AS ranking_count,
  (SELECT COUNT(*) FROM museums) = (SELECT COUNT(*) FROM museum_ranking) AS counts_match;
-- 기대값: counts_match = true (museums_count = ranking_count = 546)

-- ⑨ 인기 박물관 상위 10개가 정상 조회되는지
SELECT mr.museum_id, m.name, m.type, m.region_1,
       mr.bayesian_score, m.review_count, m.average_rating,
       m.is_kids_friendly
FROM museum_ranking mr
JOIN museums m ON mr.museum_id = m.id
ORDER BY mr.bayesian_score DESC
LIMIT 10;
-- 기대값: 10행, bayesian_score 내림차순

-- ⑩ 어린이 친화 박물관 총 건수 확인 (total_kids_friendly = 37 검증)
SELECT COUNT(*) AS total_kids_friendly
FROM museums
WHERE is_kids_friendly = true;
-- 기대값: 37 (v1.6 명세서 기준)
