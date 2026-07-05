-- Faz E3: Backend Persistence
-- Tables: mission_completions, analytics_events
-- RPC: sync_mission_completion, log_analytics_event

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS mission_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mission_key TEXT NOT NULL,
  completion_date DATE NOT NULL,
  coin_reward INT NOT NULL,
  xp_reward INT NOT NULL,
  claimed BOOLEAN DEFAULT FALSE,
  completed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, mission_key, completion_date)
);

CREATE TABLE IF NOT EXISTS analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_name TEXT NOT NULL,
  event_params JSONB,
  event_timestamp TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tournament_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tournament_date DATE NOT NULL,
  stage TEXT, -- 'lobby', 'quarter', 'semi', 'final', 'won', 'lost'
  user_score INT DEFAULT 0,
  opponent_score INT DEFAULT 0,
  bot_winners TEXT[], -- array of bot names that won
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, tournament_date)
);

-- ============================================================================
-- RPC: sync_mission_completion
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_mission_completion(
  p_mission_key TEXT,
  p_coin_reward INT,
  p_xp_reward INT
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_today DATE;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  v_today := CURRENT_DATE;

  -- Insert mission completion
  INSERT INTO mission_completions (
    user_id, mission_key, completion_date, coin_reward, xp_reward
  )
  VALUES (v_user_id, p_mission_key, v_today, p_coin_reward, p_xp_reward)
  ON CONFLICT (user_id, mission_key, completion_date) DO NOTHING;

  RETURN QUERY SELECT TRUE, 'Mission completion synced'::TEXT;
END;
$$;

-- ============================================================================
-- RPC: log_analytics_event
-- ============================================================================

CREATE OR REPLACE FUNCTION log_analytics_event(
  p_event_name TEXT,
  p_event_params JSONB DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  INSERT INTO analytics_events (user_id, event_name, event_params)
  VALUES (v_user_id, p_event_name, p_event_params);

  RETURN QUERY SELECT TRUE, 'Event logged'::TEXT;
END;
$$;

-- ============================================================================
-- RPC: save_tournament_progress
-- ============================================================================

CREATE OR REPLACE FUNCTION save_tournament_progress(
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
  v_user_id UUID;
  v_today DATE;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  v_today := CURRENT_DATE;

  INSERT INTO tournament_progress (
    user_id, tournament_date, stage, user_score, opponent_score, bot_winners
  )
  VALUES (v_user_id, v_today, p_stage, p_user_score, p_opponent_score, p_bot_winners)
  ON CONFLICT (user_id, tournament_date) DO UPDATE SET
    stage = p_stage,
    user_score = p_user_score,
    opponent_score = p_opponent_score,
    bot_winners = p_bot_winners,
    updated_at = now();

  RETURN QUERY SELECT TRUE, 'Tournament progress saved'::TEXT;
END;
$$;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

ALTER TABLE mission_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE tournament_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own mission completions"
  ON mission_completions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own analytics"
  ON analytics_events FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own tournament progress"
  ON tournament_progress FOR SELECT
  USING (auth.uid() = user_id);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_mission_completions_user_date
  ON mission_completions(user_id, completion_date DESC);

CREATE INDEX idx_analytics_events_user_timestamp
  ON analytics_events(user_id, event_timestamp DESC);

CREATE INDEX idx_tournament_progress_user_date
  ON tournament_progress(user_id, tournament_date DESC);
