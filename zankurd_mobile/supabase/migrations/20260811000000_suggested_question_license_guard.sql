-- Soru önerileri için açık lisans, gönüllü katkıcı adı ve yayımlamama kapısı.
--
-- ÖNEMLİ: Eski satırlar otomatik olarak lisanslanmaz. `license_version` ve
-- `accepted_at` önce nullable eklenir; sunucu varsayılanı ancak bundan sonra
-- kurulur. Böylece mevcut satırlar NULL/NULL kalır ve yeniden açık onay
-- alınmadan `approved` yapılamaz.

ALTER TABLE public.suggested_questions
  ADD COLUMN IF NOT EXISTS license_version TEXT,
  ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS attribution_requested BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS attribution_name TEXT,
  ADD COLUMN IF NOT EXISTS do_not_publish BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.suggested_questions
  ALTER COLUMN accepted_at SET DEFAULT statement_timestamp();
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'suggested_questions_license_audit_check'
      AND conrelid = 'public.suggested_questions'::regclass
  ) THEN
    ALTER TABLE public.suggested_questions
      ADD CONSTRAINT suggested_questions_license_audit_check
      CHECK (
        (license_version IS NULL AND accepted_at IS NULL)
        OR (
          license_version IS NOT NULL
          AND license_version = '2026-08-11'
          AND accepted_at IS NOT NULL
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'suggested_questions_attribution_check'
      AND conrelid = 'public.suggested_questions'::regclass
  ) THEN
    ALTER TABLE public.suggested_questions
      ADD CONSTRAINT suggested_questions_attribution_check
      CHECK (
        (
          attribution_requested = FALSE
          AND attribution_name IS NULL
        )
        OR (
          attribution_requested = TRUE
          AND attribution_name IS NOT NULL
          AND NULLIF(btrim(attribution_name), '') IS NOT NULL
          AND char_length(btrim(attribution_name)) <= 80
        )
      );
  END IF;
END
$$;
CREATE OR REPLACE FUNCTION public.stamp_suggested_question_acceptance()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.license_version = '2026-08-11' THEN
    -- İstemcinin gönderdiği zaman damgasına güvenme; kabul anı sunucudur.
    NEW.accepted_at := statement_timestamp();
  ELSE
    NEW.accepted_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS suggested_questions_stamp_acceptance
  ON public.suggested_questions;
CREATE TRIGGER suggested_questions_stamp_acceptance
BEFORE INSERT ON public.suggested_questions
FOR EACH ROW
EXECUTE FUNCTION public.stamp_suggested_question_acceptance();
REVOKE ALL ON FUNCTION public.stamp_suggested_question_acceptance()
  FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS "suggested_questions_insert_own"
  ON public.suggested_questions;
CREATE POLICY "suggested_questions_insert_own"
ON public.suggested_questions
FOR INSERT
TO authenticated
WITH CHECK (
  user_id = auth.uid()
  AND status = 'pending'
  AND license_version = '2026-08-11'
  AND accepted_at IS NOT NULL
  AND attribution_requested IS NOT NULL
  AND do_not_publish IS NOT NULL
  AND (
    (
      attribution_requested = FALSE
      AND attribution_name IS NULL
    )
    OR (
      attribution_requested = TRUE
      AND attribution_name IS NOT NULL
      AND NULLIF(btrim(attribution_name), '') IS NOT NULL
      AND char_length(btrim(attribution_name)) <= 80
    )
  )
);
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

  SELECT *
  INTO result_row
  FROM public.suggested_questions
  WHERE id = p_question_id
  FOR UPDATE;

  IF result_row.id IS NULL THEN
    RAISE EXCEPTION 'suggested question not found';
  END IF;

  IF p_status = 'approved' AND (
    result_row.license_version IS DISTINCT FROM '2026-08-11'
    OR result_row.accepted_at IS NULL
    OR result_row.do_not_publish
  ) THEN
    RAISE EXCEPTION
      'approved requires current license acceptance and publishable content';
  END IF;

  UPDATE public.suggested_questions
  SET status = p_status,
      reviewed_by = auth.uid(),
      reviewed_at = statement_timestamp(),
      review_note = NULLIF(trim(p_review_note), '')
  WHERE id = p_question_id
  RETURNING * INTO result_row;

  RETURN result_row;
END;
$$;
REVOKE ALL ON FUNCTION public.moderate_suggested_question(UUID, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_suggested_question(UUID, TEXT, TEXT)
  TO service_role;
