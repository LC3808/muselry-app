-- =============================================================
-- Muselry Day 11 DB 마이그레이션
-- 파일: supabase/migrations/day11_static_popularity_and_free.sql
-- 작성: Manus AI  |  날짜: 2026-05-14
-- 실행 위치: Supabase Dashboard → SQL Editor
--
-- ⚠️  실행 전 반드시 검토 후 적용하세요.
-- ⚠️  각 섹션을 순서대로 실행하세요 (1 → 2).
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- 섹션 1: museums 테이블 — 정적 인기 랭킹 컬럼 추가 (이슈 3)
-- ─────────────────────────────────────────────────────────────
-- 배경:
--   Day 9에서 베이지안 평점 기반 museum_ranking 테이블을 도입했으나,
--   리뷰 데이터가 부족한 초기에는 무작위처럼 보이는 문제가 있음.
--   통계청/문화체육관광부 박물관 방문객 통계 기반 정적 랭킹을 도입하여
--   리뷰 데이터 축적 전까지 안정적인 인기 순위를 제공함.
--
-- 운영 방침:
--   - static_popularity_rank: 운영자가 통계 수집 후 직접 입력 (1부터 시작, 낮을수록 인기)
--   - static_visitor_count: 참고용 방문객 수 (통계청 기준, 단위: 명/년)
--   - NULL인 박물관은 average_rating 기준 후순위로 정렬됨

-- 1-1. static_visitor_count 컬럼 추가 (연간 방문객 수, 참고용)
ALTER TABLE museums
  ADD COLUMN IF NOT EXISTS static_visitor_count INTEGER;

-- 1-2. static_popularity_rank 컬럼 추가 (정적 인기 순위, 1=가장 인기)
ALTER TABLE museums
  ADD COLUMN IF NOT EXISTS static_popularity_rank INTEGER;

-- 1-3. 인덱스 추가 (인기 박물관 정렬 쿼리 성능)
--   NULL이 아닌 행만 인덱싱하여 공간 효율 최적화
CREATE INDEX IF NOT EXISTS idx_museums_static_popularity_rank
  ON museums (static_popularity_rank)
  WHERE static_popularity_rank IS NOT NULL;

-- 1-4. 컬럼 코멘트
COMMENT ON COLUMN museums.static_visitor_count IS
  '연간 방문객 수 (통계청/문화체육관광부 기준, 단위: 명). 운영자가 직접 입력.';
COMMENT ON COLUMN museums.static_popularity_rank IS
  '정적 인기 순위 (1=가장 인기). 통계 기반 순위로, NULL이면 average_rating 기준 후순위 정렬.';


-- ─────────────────────────────────────────────────────────────
-- 섹션 2: museums 테이블 — 무료 관람 컬럼 추가 (이슈 7 B안)
-- ─────────────────────────────────────────────────────────────
-- 배경:
--   클라이언트 사이드에서 admission_fee 문자열 파싱으로 isFree를 판단하지만,
--   DB 레벨의 is_free 컬럼을 추가하여 서버사이드 필터링을 가능하게 함.
--   초기값은 admission_fee 기반 자동 백필로 설정.
--
-- 백필 규칙:
--   - admission_fee IS NULL → true (정보 없음 = 무료로 간주)
--   - admission_fee = '' (빈 문자열) → true
--   - admission_fee = '무료' → true
--   - admission_fee = '0' 또는 '0원' → true
--   - 그 외 (유료, 혼합 요금 등) → false
--
-- ⚠️  주의: '무료입장(...)' 처럼 부분 무료인 경우는 false로 처리됨.
--   운영자가 직접 수정 필요.

-- 2-1. is_free 컬럼 추가 (기본값 false)
ALTER TABLE museums
  ADD COLUMN IF NOT EXISTS is_free BOOLEAN NOT NULL DEFAULT false;

-- 2-2. 기존 데이터 백필 (admission_fee 기반 자동 설정)
UPDATE museums
SET is_free = true
WHERE
  admission_fee IS NULL
  OR TRIM(admission_fee) = ''
  OR TRIM(admission_fee) = '무료'
  OR TRIM(admission_fee) = '0'
  OR TRIM(admission_fee) = '0원';

-- 2-3. 인덱스 추가 (무료 관람 필터 쿼리 성능)
CREATE INDEX IF NOT EXISTS idx_museums_is_free
  ON museums (is_free)
  WHERE is_free = true;

-- 2-4. 컬럼 코멘트
COMMENT ON COLUMN museums.is_free IS
  '무료 관람 여부. admission_fee 기반 자동 설정 + 운영자 수동 보정으로 관리.';


-- ─────────────────────────────────────────────────────────────
-- 검증 쿼리 (실행 후 확인용)
-- ─────────────────────────────────────────────────────────────

-- 컬럼 추가 확인
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'museums'
  AND column_name IN ('static_visitor_count', 'static_popularity_rank', 'is_free')
ORDER BY column_name;
-- 예상 결과: 3개 행 반환

-- 인덱스 생성 확인
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'museums'
  AND indexname IN (
    'idx_museums_static_popularity_rank',
    'idx_museums_is_free'
  );
-- 예상 결과: 2개 행 반환

-- is_free 백필 결과 확인
SELECT
  is_free,
  COUNT(*) AS count
FROM museums
GROUP BY is_free
ORDER BY is_free DESC;
-- 예상 결과: true/false 두 행 반환, 무료 박물관이 상당수 포함되어야 함

-- static_popularity_rank 현황 (초기에는 모두 NULL)
SELECT COUNT(*) AS total,
       COUNT(static_popularity_rank) AS with_rank,
       COUNT(*) - COUNT(static_popularity_rank) AS without_rank
FROM museums
WHERE is_active = true;
-- 예상 결과: with_rank = 0 (운영자가 데이터 입력 전)
