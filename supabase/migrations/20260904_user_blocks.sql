BEGIN;

CREATE TABLE IF NOT EXISTS public.user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL
    REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL
    REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT user_blocks_blocker_id_blocked_id_key
    UNIQUE (blocker_id, blocked_id),
  CONSTRAINT user_blocks_no_self_block_check
    CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS user_blocks_blocker_id_created_at_idx
  ON public.user_blocks (blocker_id, created_at DESC);

CREATE INDEX IF NOT EXISTS user_blocks_blocked_id_idx
  ON public.user_blocks (blocked_id);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own user blocks"
ON public.user_blocks;

CREATE POLICY "Users can view own user blocks"
ON public.user_blocks
FOR SELECT
TO authenticated
USING (auth.uid() = blocker_id);

DROP POLICY IF EXISTS "Users can create own user blocks"
ON public.user_blocks;

CREATE POLICY "Users can create own user blocks"
ON public.user_blocks
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = blocker_id
  AND blocker_id <> blocked_id
);

DROP POLICY IF EXISTS "Users can delete own user blocks"
ON public.user_blocks;

CREATE POLICY "Users can delete own user blocks"
ON public.user_blocks
FOR DELETE
TO authenticated
USING (auth.uid() = blocker_id);

COMMIT;
