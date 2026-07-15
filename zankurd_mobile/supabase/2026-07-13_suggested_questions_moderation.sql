-- Moderation contract for suggested questions.
-- The RPC is deliberately service-role only; end users may submit and read
-- their own suggestions but cannot approve content from the client.

ALTER TABLE public.suggested_questions
  ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS review_note TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'suggested_questions_status_check'
      AND conrelid = 'public.suggested_questions'::regclass
  ) THEN
    ALTER TABLE public.suggested_questions
      ADD CONSTRAINT suggested_questions_status_check
      CHECK (status IN ('pending', 'approved', 'rejected'));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.moderate_suggested_question(
  p_question_id UUID,
  p_status TEXT,
  p_review_note TEXT DEFAULT NULL
)
RETURNS public.suggested_questions
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result_row public.suggested_questions;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'moderation requires service_role';
  END IF;

  IF p_status NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'p_status IN (''approved'', ''rejected'')';
  END IF;

  UPDATE public.suggested_questions
  SET status = p_status,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      review_note = NULLIF(trim(p_review_note), '')
  WHERE id = p_question_id
  RETURNING * INTO result_row;

  IF result_row.id IS NULL THEN
    RAISE EXCEPTION 'suggested question not found';
  END IF;

  RETURN result_row;
END;
$$;

REVOKE ALL ON FUNCTION public.moderate_suggested_question(UUID, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_suggested_question(UUID, TEXT, TEXT)
  TO service_role;
