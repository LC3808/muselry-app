-- ============================================================
-- Muselry: 어린이 친화 필드 추가 마이그레이션
-- 작성일: 2026-05-12
-- 대상: museums 테이블
-- ============================================================

-- 1. 컬럼 추가 (nullable/default false → 기존 기능 영향 없음)
ALTER TABLE museums
  ADD COLUMN IF NOT EXISTS is_kids_friendly BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS kids_note TEXT;

-- ============================================================
-- 2. 키워드 기반 자동 분류 백필
--
-- 분류 룰 (실제 데이터 점검 결과 기반, 2026-05-12):
--
-- [1차 룰] name에 핵심 키워드 포함 → 단독 true
--   키워드: 어린이, 아동, 키즈, 놀이, 유아
--
-- [2차 룰] description에 가족/체험/아이/어린이/유아 중 2개 이상 동시 포함 → true
--   (단독 사용 시 오탐 방지를 위해 AND 조건 적용)
--
-- [제외 결정]
--   - '과학' 키워드: name 히트 5건 중 전문 연구형 포함 → 오탐 위험으로 제외
--   - '생태' 키워드: 자연생태관 성격 혼재 → 제외
--   - '체험' name 단독: 6.25전쟁체험기념관 등 어린이 부적합 포함 → 제외
--
-- [누락 후보 6건]
--   한지체험박물관, 백제문화체험박물관, 영천전통문화체험관,
--   고강선사유적체험관, 증평민속체험박물관, 6.25전쟁체험기념관
--   → 체험 프로그램은 있으나 어린이 특화 아님 → 수동 보정 대상
--
-- [description null 비율: 33% (181/546건)]
--   → 2차 룰 적용 범위가 제한적이므로 수동 보정 필수
-- ============================================================

UPDATE museums
SET is_kids_friendly = true
WHERE
  -- 1차 룰: name 핵심 키워드
  name ILIKE '%어린이%'
  OR name ILIKE '%아동%'
  OR name ILIKE '%키즈%'
  OR name ILIKE '%놀이%'
  OR name ILIKE '%유아%'
  OR (
    -- 2차 룰: description 복합 키워드 (2개 이상 AND)
    description IS NOT NULL
    AND (
      (description ILIKE '%가족%' AND description ILIKE '%체험%')
      OR (description ILIKE '%어린이%' AND description ILIKE '%체험%')
      OR (description ILIKE '%아이%' AND description ILIKE '%체험%')
      OR (description ILIKE '%유아%' AND description ILIKE '%체험%')
      OR (description ILIKE '%어린이%' AND description ILIKE '%아이%')
    )
  );

-- ============================================================
-- 3. 예상 결과 확인 쿼리 (실행 후 검증용)
-- ============================================================
-- SELECT COUNT(*) FROM museums WHERE is_kids_friendly = true;
-- → 예상: 약 13~19건 (수동 보정 전)

-- SELECT id, name, type, ownership
-- FROM museums
-- WHERE is_kids_friendly = true
-- ORDER BY type, name;

-- ============================================================
-- 4. 수동 보정 가이드
-- ============================================================
-- 아래 박물관은 자동 분류에서 누락되었으나 검토 후 추가 가능:
--   - 한지체험박물관 (체험 프로그램 있음)
--   - 백제문화체험박물관 (체험 프로그램 있음)
--   - 고강선사유적체험관 (체험형 전시)
--   - 증평민속체험박물관 (민속 체험)
--
-- 추가 시:
-- UPDATE museums SET is_kids_friendly = true, kids_note = '체험 프로그램 운영'
-- WHERE name IN ('한지체험박물관', '백제문화체험박물관', '고강선사유적체험관', '증평민속체험박물관');
--
-- kids_note 예시:
-- UPDATE museums SET kids_note = '어린이 전용 체험 공간 운영, 유아 동반 가족 추천'
-- WHERE name = '경기도어린이박물관';
