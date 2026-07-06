-- Faz G2: Arkadaş sistemi v2 — oyuncu arama + istek reddetme
-- RPC: search_profiles, reject_friend_request

-- ============================================================================
-- RPC: search_profiles
-- ============================================================================
-- Görünen ada göre oyuncu arar (kendisi hariç, en fazla 10 sonuç).

CREATE OR REPLACE FUNCTION search_profiles(p_query TEXT)
RETURNS TABLE (
  id UUID,
  display_name TEXT,
  avatar_color TEXT
) LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL OR length(trim(p_query)) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT p.id, p.display_name, p.avatar_color
  FROM profiles p
  WHERE p.id <> v_user_id
    AND p.display_name ILIKE '%' || trim(p_query) || '%'
  ORDER BY p.display_name
  LIMIT 10;
END;
$$;

-- ============================================================================
-- RPC: reject_friend_request
-- ============================================================================
-- Gelen arkadaşlık isteğini reddeder (yalnızca alıcı reddedebilir).

CREATE OR REPLACE FUNCTION reject_friend_request(p_request_id UUID)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID;
  v_updated INT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  UPDATE friend_requests
  SET status = 'rejected'
  WHERE id = p_request_id
    AND to_user_id = v_user_id
    AND status = 'pending';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN QUERY SELECT FALSE, 'Request not found'::TEXT;
    RETURN;
  END IF;

  RETURN QUERY SELECT TRUE, 'Request rejected'::TEXT;
END;
$$;
