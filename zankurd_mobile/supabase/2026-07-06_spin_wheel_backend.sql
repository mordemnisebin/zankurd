-- Faz E1: Spin Wheel Backend Logic
-- RPC: award_spin_coins — günlük çark ödülünü kaydeder ve coin ekler

-- ============================================================================
-- TABLE UPDATES
-- ============================================================================

-- spin_wheel_history tablosu varsa kontrol et, yoksa oluştur
DROP TABLE IF EXISTS spin_wheel_history CASCADE;
CREATE TABLE spin_wheel_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  spin_date DATE NOT NULL,
  reward_amount INT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, spin_date)
);

-- ============================================================================
-- RPC: award_spin_coins
-- ============================================================================
-- Günde maksimum 1 kez çevrilebilir. Sunucu ödül miktarını belirler.
-- Client tahmin edemez, ödülü sunucu karar verir.

CREATE OR REPLACE FUNCTION award_spin_coins()
RETURNS TABLE (
  success BOOLEAN,
  reward_amount INT,
  message TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_today DATE;
  v_last_spin DATE;
  v_reward INT;
  v_rewards INT[] := ARRAY[10, 25, 50, 15, 75, 20, 100, 30];
BEGIN
  -- Get current user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 0, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  v_today := CURRENT_DATE;

  -- Check if user already spun today
  SELECT spin_date INTO v_last_spin
  FROM spin_wheel_history
  WHERE user_id = v_user_id
  ORDER BY spin_date DESC
  LIMIT 1;

  IF v_last_spin = v_today THEN
    RETURN QUERY SELECT FALSE, 0, 'Already spun today'::TEXT;
    RETURN;
  END IF;

  -- Deterministic reward based on date (same reward for all users on same day)
  -- Use date as seed so all players get same reward pool
  v_reward := v_rewards[
    (
      (EXTRACT(DAY FROM v_today)::INT + EXTRACT(MONTH FROM v_today)::INT * 31)
      % array_length(v_rewards, 1)
    ) + 1
  ];

  -- Record spin
  INSERT INTO spin_wheel_history (user_id, spin_date, reward_amount)
  VALUES (v_user_id, v_today, v_reward)
  ON CONFLICT (user_id, spin_date) DO NOTHING;

  -- Award coins via coin_transactions (audit trail)
  INSERT INTO coin_transactions (user_id, delta, reason, metadata)
  VALUES (
    v_user_id,
    v_reward,
    'spin_wheel',
    jsonb_build_object('spin_date', v_today, 'segment_reward', v_reward)
  );

  RETURN QUERY SELECT TRUE, v_reward, 'Spin awarded successfully'::TEXT;
END;
$$;

-- ============================================================================
-- RPC: can_spin_today
-- ============================================================================
-- Günün herhangi bir noktasında çevrildi mi kontrol et

CREATE OR REPLACE FUNCTION can_spin_today()
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_user_id UUID;
  v_today DATE;
  v_last_spin DATE;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  v_today := CURRENT_DATE;

  SELECT spin_date INTO v_last_spin
  FROM spin_wheel_history
  WHERE user_id = v_user_id
  ORDER BY spin_date DESC
  LIMIT 1;

  RETURN v_last_spin IS NULL OR v_last_spin < v_today;
END;
$$;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

ALTER TABLE spin_wheel_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own spin history" ON spin_wheel_history;
CREATE POLICY "Users can view own spin history"
  ON spin_wheel_history FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own spin records" ON spin_wheel_history;
CREATE POLICY "Users can insert own spin records"
  ON spin_wheel_history FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- INDEXES
-- ============================================================================

DROP INDEX IF EXISTS idx_spin_wheel_user_date;
CREATE INDEX idx_spin_wheel_user_date ON spin_wheel_history(user_id, spin_date DESC);
