-- Faz E2: Friends System
-- Tables: friends, friend_requests
-- RPC: add_friend, accept_friend_request, reject_friend_request, list_friends, list_friend_requests

-- ============================================================================
-- TABLES
-- ============================================================================

CREATE TABLE IF NOT EXISTS friends (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_name TEXT NOT NULL,
  friend_avatar_color TEXT DEFAULT '#E94560',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, friend_id),
  CHECK (user_id != friend_id)
);

CREATE TABLE IF NOT EXISTS friend_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  from_user_name TEXT NOT NULL,
  to_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(from_user_id, to_user_id),
  CHECK (from_user_id != to_user_id)
);

-- ============================================================================
-- RPC: add_friend
-- ============================================================================
-- Arkadaş ekleme isteği gönder (friend_requests'e kaydedilir)

CREATE OR REPLACE FUNCTION add_friend(p_friend_id UUID, p_friend_name TEXT)
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

  IF v_user_id = p_friend_id THEN
    RETURN QUERY SELECT FALSE, 'Cannot add yourself as friend'::TEXT;
    RETURN;
  END IF;

  -- Check if already friends
  IF EXISTS (
    SELECT 1 FROM friends
    WHERE (user_id = v_user_id AND friend_id = p_friend_id)
       OR (user_id = p_friend_id AND friend_id = v_user_id)
  ) THEN
    RETURN QUERY SELECT FALSE, 'Already friends'::TEXT;
    RETURN;
  END IF;

  -- Create friend request
  INSERT INTO friend_requests (from_user_id, from_user_name, to_user_id, status)
  VALUES (v_user_id, 'Player', p_friend_id, 'pending')
  ON CONFLICT (from_user_id, to_user_id) DO NOTHING;

  RETURN QUERY SELECT TRUE, 'Friend request sent'::TEXT;
END;
$$;

-- ============================================================================
-- RPC: accept_friend_request
-- ============================================================================
-- Arkadaş isteğini kabul et

CREATE OR REPLACE FUNCTION accept_friend_request(p_request_id UUID)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_from_user_id UUID;
  v_from_user_name TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  -- Get request and verify it's for current user
  SELECT from_user_id, from_user_name INTO v_from_user_id, v_from_user_name
  FROM friend_requests
  WHERE id = p_request_id AND to_user_id = v_user_id AND status = 'pending';

  IF v_from_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Friend request not found or already processed'::TEXT;
    RETURN;
  END IF;

  -- Create bidirectional friendship
  INSERT INTO friends (user_id, friend_id, friend_name)
  VALUES
    (v_user_id, v_from_user_id, v_from_user_name),
    (v_from_user_id, v_user_id, 'Player')
  ON CONFLICT DO NOTHING;

  -- Update request status
  UPDATE friend_requests SET status = 'accepted' WHERE id = p_request_id;

  RETURN QUERY SELECT TRUE, 'Friend request accepted'::TEXT;
END;
$$;

-- ============================================================================
-- RPC: list_friends
-- ============================================================================
-- Arkadaş listesini getir

CREATE OR REPLACE FUNCTION list_friends()
RETURNS TABLE (
  id UUID,
  friend_id UUID,
  friend_name TEXT,
  friend_avatar_color TEXT,
  created_at TIMESTAMPTZ
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    f.id, f.friend_id, f.friend_name, f.friend_avatar_color, f.created_at
  FROM friends f
  WHERE f.user_id = v_user_id
  ORDER BY f.created_at DESC;
END;
$$;

-- ============================================================================
-- RPC: list_pending_friend_requests
-- ============================================================================
-- Bekleyen arkadaş isteklerini getir

CREATE OR REPLACE FUNCTION list_pending_friend_requests()
RETURNS TABLE (
  id UUID,
  from_user_id UUID,
  from_user_name TEXT,
  created_at TIMESTAMPTZ
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    fr.id, fr.from_user_id, fr.from_user_name, fr.created_at
  FROM friend_requests fr
  WHERE fr.to_user_id = v_user_id AND fr.status = 'pending'
  ORDER BY fr.created_at DESC;
END;
$$;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own friends"
  ON friends FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view incoming friend requests"
  ON friend_requests FOR SELECT
  USING (auth.uid() = to_user_id);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_friends_user_id ON friends(user_id);
CREATE INDEX idx_friend_requests_to_user_id ON friend_requests(to_user_id, status);
