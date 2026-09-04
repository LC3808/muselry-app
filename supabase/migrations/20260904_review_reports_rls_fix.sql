BEGIN;

CREATE OR REPLACE FUNCTION public.can_report_review(p_review_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.reviews r
    WHERE r.id = p_review_id
      AND r.user_id <> auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.can_report_review(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_report_review(uuid) TO authenticated;

DROP POLICY IF EXISTS "Authenticated users can report reviews"
ON public.review_reports;

CREATE POLICY "Authenticated users can report reviews"
ON public.review_reports
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = reporter_id
  AND public.can_report_review(review_id)
);

COMMIT;
