-- Turnuva ilerleme bütünlüğü: istemcinin stage atlamasını ve erken şampiyonluğu engeller.
-- Bu migration canlıya uygulanmadan önce staging Supabase projesinde doğrulanmalıdır.

CREATE OR REPLACE FUNCTION public.save_tournament_progress(
  p_stage TEXT,
  p_user_score INT,
  p_opponent_score INT,
  p_bot_winners TEXT[]
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_today DATE := CURRENT_DATE;
  v_current_stage TEXT;
  v_current_rank INT := 0;
  v_requested_rank INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  IF p_stage NOT IN ('lobby', 'quarter', 'semi', 'final', 'won', 'lost') THEN
    RETURN QUERY SELECT FALSE, 'Invalid tournament stage'::TEXT;
    RETURN;
  END IF;

  SELECT stage
    INTO v_current_stage
    FROM public.tournament_progress
   WHERE user_id = v_user_id
     AND tournament_date = v_today
   FOR UPDATE;

  v_current_rank := CASE v_current_stage
    WHEN 'lobby' THEN 0
    WHEN 'quarter' THEN 1
    WHEN 'semi' THEN 2
    WHEN 'final' THEN 3
    WHEN 'won' THEN 4
    WHEN 'lost' THEN 4
    ELSE 0
  END;

  v_requested_rank := CASE p_stage
    WHEN 'lobby' THEN 0
    WHEN 'quarter' THEN 1
    WHEN 'semi' THEN 2
    WHEN 'final' THEN 3
    WHEN 'won' THEN 4
    WHEN 'lost' THEN 4
    ELSE -1
  END;

  IF p_stage <> 'lost'
     AND v_current_stage IS NOT NULL
     AND v_requested_rank > v_current_rank + 1 THEN
    RETURN QUERY SELECT FALSE, 'Tournament stage jump rejected'::TEXT;
    RETURN;
  END IF;

  IF p_stage = 'won'
     AND (v_current_stage IS NULL OR v_current_stage <> 'final') THEN
    RETURN QUERY SELECT FALSE, 'Tournament champion must complete final'::TEXT;
    RETURN;
  END IF;

  INSERT INTO public.tournament_progress (
    user_id, tournament_date, stage, user_score, opponent_score, bot_winners
  )
  VALUES (v_user_id, v_today, p_stage, p_user_score, p_opponent_score, p_bot_winners)
  ON CONFLICT (user_id, tournament_date) DO UPDATE SET
    stage = EXCLUDED.stage,
    user_score = EXCLUDED.user_score,
    opponent_score = EXCLUDED.opponent_score,
    bot_winners = EXCLUDED.bot_winners,
    updated_at = now();

  RETURN QUERY SELECT TRUE, 'Tournament progress saved'::TEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.save_tournament_progress(TEXT, INT, INT, TEXT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.save_tournament_progress(TEXT, INT, INT, TEXT[])
  TO authenticated;
