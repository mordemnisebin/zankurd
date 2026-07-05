-- Faz C: Contest & Events System
-- Tables: contests, contest_entries, contest_badges, user_contest_badges
-- RPC: get_today_contest, submit_contest_entry, claim_contest_reward, get_contest_leaderboard

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS contests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  day_key DATE NOT NULL UNIQUE,
  theme_name_ku TEXT NOT NULL,
  theme_description_ku TEXT,
  category TEXT NOT NULL,
  difficulty_min INT DEFAULT 1,
  difficulty_max INT DEFAULT 5,
  participation_reward INT DEFAULT 10,
  rank1_reward INT DEFAULT 500,
  rank2_reward INT DEFAULT 300,
  rank3_reward INT DEFAULT 100,
  question_count INT DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS contest_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contest_id UUID NOT NULL REFERENCES contests(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  score INT DEFAULT 0,
  correct_count INT DEFAULT 0,
  finished_at TIMESTAMPTZ,
  rank INT,
  reward_claimed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(contest_id, user_id)
);

CREATE TABLE IF NOT EXISTS contest_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  name_ku TEXT NOT NULL,
  description_ku TEXT,
  icon_name TEXT,
  color_hex TEXT,
  tier INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_contest_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_id UUID NOT NULL REFERENCES contest_badges(id) ON DELETE CASCADE,
  contest_id UUID NOT NULL REFERENCES contests(id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, badge_id, contest_id)
);

-- ============================================================================
-- RPC: get_today_contest
-- ============================================================================

CREATE OR REPLACE FUNCTION get_today_contest()
RETURNS TABLE (
  id UUID,
  day_key DATE,
  theme_name_ku TEXT,
  theme_description_ku TEXT,
  category TEXT,
  difficulty_min INT,
  difficulty_max INT,
  participation_reward INT,
  rank1_reward INT,
  rank2_reward INT,
  rank3_reward INT,
  question_count INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id, c.day_key, c.theme_name_ku, c.theme_description_ku, c.category,
    c.difficulty_min, c.difficulty_max, c.participation_reward,
    c.rank1_reward, c.rank2_reward, c.rank3_reward, c.question_count
  FROM contests c
  WHERE c.day_key = CURRENT_DATE
  LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- RPC: get_contest_leaderboard
-- ============================================================================

CREATE OR REPLACE FUNCTION get_contest_leaderboard(p_contest_id UUID, p_limit INT DEFAULT 10)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  score INT,
  correct_count INT,
  rank INT,
  finished_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ce.user_id, p.display_name, ce.score, ce.correct_count, ce.rank, ce.finished_at
  FROM contest_entries ce
  LEFT JOIN profiles p ON p.id = ce.user_id
  WHERE ce.contest_id = p_contest_id AND ce.finished_at IS NOT NULL
  ORDER BY ce.rank NULLS LAST, ce.score DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- RPC: submit_contest_entry (Quiz bitişinde skor kaydı + katılım reward)
-- ============================================================================

CREATE OR REPLACE FUNCTION submit_contest_entry(
  p_contest_id UUID,
  p_correct_count INT
)
RETURNS TABLE (
  entry_id UUID,
  score INT,
  rank INT,
  participation_reward INT
) AS $$
DECLARE
  v_user_id UUID;
  v_correct_count INT;
  v_score INT;
  v_rank INT;
  v_contest_category TEXT;
  v_participation_reward INT;
  v_total_participants INT;
BEGIN
  -- Current user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get contest info
  SELECT c.category, c.participation_reward INTO v_contest_category, v_participation_reward
  FROM contests c WHERE c.id = p_contest_id;

  IF v_contest_category IS NULL THEN
    RAISE EXCEPTION 'Contest not found';
  END IF;

  -- Score = correct_count * 100
  v_score := p_correct_count * 100;

  -- Insert or update entry
  INSERT INTO contest_entries (contest_id, user_id, correct_count, score, finished_at)
  VALUES (p_contest_id, v_user_id, p_correct_count, v_score, now())
  ON CONFLICT (contest_id, user_id)
  DO UPDATE SET correct_count = EXCLUDED.correct_count, score = EXCLUDED.score, finished_at = now()
  RETURNING id INTO v_entry_id;

  -- Calculate rank (1-indexed)
  v_rank := (SELECT COUNT(*) FROM contest_entries
    WHERE contest_id = p_contest_id AND score > v_score) + 1;

  UPDATE contest_entries SET rank = v_rank WHERE id = v_entry_id;

  -- Give participation reward
  INSERT INTO coin_transactions (user_id, amount, reason, metadata)
  VALUES (v_user_id, v_participation_reward, 'contest_participation',
    jsonb_build_object('contest_id', p_contest_id, 'day', CURRENT_DATE));

  RETURN QUERY
  SELECT v_entry_id, v_score, v_rank, v_participation_reward;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RPC: claim_contest_reward (Rank reward + badge verilmesi)
-- ============================================================================

CREATE OR REPLACE FUNCTION claim_contest_reward(p_contest_id UUID)
RETURNS TABLE (
  claimed BOOLEAN,
  rank_reward INT,
  badge_awarded TEXT
) AS $$
DECLARE
  v_user_id UUID;
  v_entry_id UUID;
  v_rank INT;
  v_reward INT;
  v_badge_id UUID;
  v_badge_slug TEXT;
  v_day_key DATE;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get entry
  SELECT id, rank, ce.contest_id INTO v_entry_id, v_rank
  FROM contest_entries ce
  WHERE ce.contest_id = p_contest_id AND ce.user_id = v_user_id
  LIMIT 1;

  IF v_entry_id IS NULL THEN
    RAISE EXCEPTION 'No entry for this contest';
  END IF;

  -- Already claimed?
  IF (SELECT reward_claimed FROM contest_entries WHERE id = v_entry_id) THEN
    RETURN QUERY SELECT FALSE, 0::INT, NULL::TEXT;
    RETURN;
  END IF;

  -- Get day_key for badge slug
  SELECT c.day_key INTO v_day_key FROM contests c WHERE c.id = p_contest_id;

  -- Give rank reward if top 3
  v_reward := 0;
  v_badge_slug := NULL;

  IF v_rank = 1 THEN
    v_reward := (SELECT rank1_reward FROM contests WHERE id = p_contest_id);
    v_badge_slug := 'contest_' || to_char(v_day_key, 'YYYYMMDD') || '_champion';
  ELSIF v_rank = 2 THEN
    v_reward := (SELECT rank2_reward FROM contests WHERE id = p_contest_id);
    v_badge_slug := 'contest_' || to_char(v_day_key, 'YYYYMMDD') || '_finalist';
  ELSIF v_rank = 3 THEN
    v_reward := (SELECT rank3_reward FROM contests WHERE id = p_contest_id);
    v_badge_slug := 'contest_' || to_char(v_day_key, 'YYYYMMDD') || '_participant';
  END IF;

  IF v_reward > 0 THEN
    INSERT INTO coin_transactions (user_id, amount, reason, metadata)
    VALUES (v_user_id, v_reward, 'contest_rank_reward',
      jsonb_build_object('contest_id', p_contest_id, 'rank', v_rank));
  END IF;

  -- Award badge if applicable
  IF v_badge_slug IS NOT NULL THEN
    SELECT id INTO v_badge_id FROM contest_badges WHERE slug = v_badge_slug LIMIT 1;
    IF v_badge_id IS NOT NULL THEN
      INSERT INTO user_contest_badges (user_id, badge_id, contest_id)
      VALUES (v_user_id, v_badge_id, p_contest_id)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  UPDATE contest_entries SET reward_claimed = TRUE WHERE id = v_entry_id;

  RETURN QUERY SELECT TRUE, v_reward, v_badge_slug;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

ALTER TABLE contests ENABLE ROW LEVEL SECURITY;
ALTER TABLE contest_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE contest_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_contest_badges ENABLE ROW LEVEL SECURITY;

-- contests: anyone can read
CREATE POLICY "contests_read" ON contests FOR SELECT USING (true);

-- contest_entries: users see own + all leaderboard
CREATE POLICY "contest_entries_read" ON contest_entries FOR SELECT USING (true);
CREATE POLICY "contest_entries_insert_own" ON contest_entries FOR INSERT
  WITH CHECK (user_id = auth.uid());
CREATE POLICY "contest_entries_update_own" ON contest_entries FOR UPDATE
  USING (user_id = auth.uid());

-- contest_badges: anyone can read
CREATE POLICY "contest_badges_read" ON contest_badges FOR SELECT USING (true);

-- user_contest_badges: users see own + others' (for showcase)
CREATE POLICY "user_contest_badges_read" ON user_contest_badges FOR SELECT USING (true);
CREATE POLICY "user_contest_badges_insert_own" ON user_contest_badges FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_contests_day_key ON contests(day_key);
CREATE INDEX IF NOT EXISTS idx_contest_entries_contest_id ON contest_entries(contest_id);
CREATE INDEX IF NOT EXISTS idx_contest_entries_user_id ON contest_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_contest_entries_finished ON contest_entries(finished_at)
  WHERE finished_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_contest_badges_user_id ON user_contest_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_user_contest_badges_badge_id ON user_contest_badges(badge_id);
