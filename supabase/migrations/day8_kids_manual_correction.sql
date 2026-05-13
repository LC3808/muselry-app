-- =============================================================
-- Muselry Day 8 어린이 친화 수동 보정 SQL (12건)
-- 파일: supabase/migrations/day8_kids_manual_correction.sql
-- 작성: Manus AI  |  날짜: 2026-05-12
-- 실행 위치: Supabase Dashboard → SQL Editor
--
-- 그룹 A (7건): 명백한 어린이 친화 — 체험 전문 시설
-- 그룹 B (5건): 보호자 동반 권장 — kids_note에 연령 안내 포함
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- 그룹 A: 명백한 어린이 친화 (7건)
-- ─────────────────────────────────────────────────────────────

-- 1. 부안청자박물관 (전북) — 도자기 만들기 체험동 운영, 야외 가마터 관찰
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '도자기 만들기 체험동과 야외 가마터 관찰 공간을 갖춘 체험형 박물관입니다. 가족 단위 방문에 적합하며, 체험 프로그램은 사전 예약이 필요할 수 있습니다.'
WHERE id = '9276475f-0657-4c9a-b737-a6f78708661d';

-- 2. 한지체험박물관 (충북) — 한지 제작 체험 전문
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '한지 제작 과정을 직접 체험할 수 있는 전문 체험 박물관입니다. 아이와 함께 전통 공예를 경험하기 좋은 공간입니다.'
WHERE id = 'a9cf8d3f-e5c0-48da-bdc0-261433a9e86d';

-- 3. 백제문화체험박물관 (충남) — 역사 전시 + 다양한 체험
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '백제 역사와 문화를 전시 관람과 체험으로 함께 즐길 수 있는 공간입니다. 초등학생 이상 어린이와 가족 단위 방문에 적합합니다.'
WHERE id = 'b794d5e2-28a7-404a-ad93-b6683ebc3b31';

-- 4. 영천전통문화체험관 (경북) — 전통문화 체험 중심
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '지역 전통문화를 체험 중심으로 경험할 수 있는 문화공간입니다. 가족 단위 방문에 적합하며, 운영 프로그램은 시기별로 달라질 수 있습니다.'
WHERE id = 'd8a3cb6d-2602-464c-94fd-0aed4b946b65';

-- 5. 김해목재문화박물관 (경남) — 참여형 전시, 목공예 체험
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '목재와 목공예를 주제로 한 참여형 전시 중심의 문화공간입니다. 아이와 함께 자연 소재를 배우고 체험하기 좋은 공간입니다.'
WHERE id = 'b671f00a-8fcd-467e-b677-aa342a886cc9';

-- 6. 문경도자기박물관 (경북) — 도자 일일체험
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '도자기 일일체험 프로그램을 운영하는 박물관입니다. 아이와 함께 도자기 만들기를 경험할 수 있으며, 체험은 사전 예약이 필요할 수 있습니다.'
WHERE id = '1f17081d-45a1-492d-91ab-6f154a88aee6';

-- 7. 청송수석꽃돌박물관 (경북) — 꽃돌 전시체험
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '청송 꽃돌을 전시하고 체험할 수 있는 공간입니다. 자연 광물에 관심 있는 어린이와 가족 단위 방문에 적합합니다.'
WHERE id = '7e27d0fc-1bfc-481f-8cc9-11be2ae5c192';


-- ─────────────────────────────────────────────────────────────
-- 그룹 B: 보호자 동반 권장 (5건)
-- ─────────────────────────────────────────────────────────────

-- 8. 김해시수도박물관 (경남) — 물의 소중함 체험, 교육적
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '상수도의 역사와 물의 소중함을 체험으로 배울 수 있는 교육형 박물관입니다. 초등학생 이상 어린이와 보호자 동반 방문에 적합합니다.'
WHERE id = 'fc4ba18c-fb24-44b2-a620-a800dd24d093';

-- 9. 나주배박물관 (전남) — 배 관련 학습·체험
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '나주 배의 역사와 재배 과정을 학습하고 체험할 수 있는 공간입니다. 가족 단위 방문에 적합하며, 운영 프로그램은 방문 전 확인을 권장합니다.'
WHERE id = '7e1996c1-1cda-4554-94cd-38933b85bb04';

-- 10. 군산근대역사박물관 (전북) — 근대문화 체험, 초등 고학년 이상 적합
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '군산의 근대문화와 해양문화를 체험할 수 있는 특화 박물관입니다. 초등 고학년 이상 어린이와 보호자 동반 방문에 적합합니다.'
WHERE id = '7d99ccdb-8db7-482b-b367-d7186905c658';

-- 11. 오산시립미술관 (경기) — 미술 체험 공간
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '미술 작품 전시와 체험 프로그램을 함께 운영하는 미술관입니다. 어린이 미술 체험 프로그램 운영 여부는 방문 전 공식 홈페이지에서 확인하세요.'
WHERE id = '9e5f5c9e-9016-4d47-a630-06c7cf9bd4b5';

-- 12. 대구약령시한의약박물관 (대구) — 한의약 체험, 보호자 동반 권장
UPDATE museums SET
  is_kids_friendly = true,
  kids_note = '전통 약령시와 한의약 문화를 체험할 수 있는 공립박물관입니다. 보호자 동반 시 어린이와 함께 방문하기 좋으며, 체험 프로그램은 시기별로 달라질 수 있습니다.'
WHERE id = '4d922f46-54b1-4480-bd5b-688196175ee8';


-- ─────────────────────────────────────────────────────────────
-- 완료 확인 쿼리
-- ─────────────────────────────────────────────────────────────

-- 수동 보정 12건 확인 (kids_note가 채워진 항목)
SELECT name, region_1, is_kids_friendly,
       LEFT(kids_note, 40) AS kids_note_preview
FROM museums
WHERE id IN (
  '9276475f-0657-4c9a-b737-a6f78708661d',
  'a9cf8d3f-e5c0-48da-bdc0-261433a9e86d',
  'b794d5e2-28a7-404a-ad93-b6683ebc3b31',
  'd8a3cb6d-2602-464c-94fd-0aed4b946b65',
  'b671f00a-8fcd-467e-b677-aa342a886cc9',
  '1f17081d-45a1-492d-91ab-6f154a88aee6',
  '7e27d0fc-1bfc-481f-8cc9-11be2ae5c192',
  'fc4ba18c-fb24-44b2-a620-a800dd24d093',
  '7e1996c1-1cda-4554-94cd-38933b85bb04',
  '7d99ccdb-8db7-482b-b367-d7186905c658',
  '9e5f5c9e-9016-4d47-a630-06c7cf9bd4b5',
  '4d922f46-54b1-4480-bd5b-688196175ee8'
)
ORDER BY name;

-- 전체 어린이 친화 최종 집계 (37건이 표시되어야 함)
SELECT COUNT(*) AS total_kids_friendly FROM museums WHERE is_kids_friendly = true;
