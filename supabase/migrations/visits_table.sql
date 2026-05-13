-- ============================================================
-- visits 테이블 생성 및 RLS 정책
-- Day 6: 방문 기록(다녀왔어요) 기능
-- 실행: Supabase SQL Editor에서 실행
-- ============================================================

-- 1. 테이블 생성
CREATE TABLE IF NOT EXISTS public.visits (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  museum_id    TEXT        NOT NULL REFERENCES public.museums(id) ON DELETE CASCADE,
  visited_at   DATE        NOT NULL DEFAULT CURRENT_DATE,
  rating       NUMERIC(2,1) CHECK (rating IS NULL OR (rating >= 0.5 AND rating <= 5.0)),
  private_note TEXT        CHECK (private_note IS NULL OR length(private_note) <= 500),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. 인덱스
CREATE INDEX IF NOT EXISTS visits_user_id_idx       ON public.visits (user_id);
CREATE INDEX IF NOT EXISTS visits_museum_id_idx     ON public.visits (museum_id);
CREATE INDEX IF NOT EXISTS visits_visited_at_idx    ON public.visits (visited_at DESC);

-- 3. RLS 활성화
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;

-- 4. RLS 정책: 본인 데이터만 SELECT
CREATE POLICY "visits_select_own"
  ON public.visits
  FOR SELECT
  USING (auth.uid() = user_id);

-- 5. RLS 정책: 본인 데이터만 INSERT (user_id는 auth.uid()로 강제)
CREATE POLICY "visits_insert_own"
  ON public.visits
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 6. RLS 정책: 본인 데이터만 UPDATE
CREATE POLICY "visits_update_own"
  ON public.visits
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 7. RLS 정책: 본인 데이터만 DELETE
CREATE POLICY "visits_delete_own"
  ON public.visits
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- 검증 쿼리 (실행 후 확인)
-- ============================================================
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'visits'
-- ORDER BY ordinal_position;

-- SELECT relname, relrowsecurity
-- FROM pg_class WHERE relname = 'visits';

-- SELECT polname, polcmd
-- FROM pg_policy
-- WHERE polrelid = 'public.visits'::regclass;
