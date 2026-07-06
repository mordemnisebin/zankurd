-- Faz D: Learning Zone — Kurmancî Ders Sistemi
-- Tables: lessons, lesson_slides, user_lesson_progress
-- RPC: loadLessonsByCategory, loadLesson, loadLessonSlides, markLessonCompleted

-- ============================================================================
-- TABLES
-- ============================================================================

DROP TABLE IF EXISTS user_lesson_progress CASCADE;
DROP TABLE IF EXISTS lesson_slides CASCADE;
DROP TABLE IF EXISTS lessons CASCADE;

CREATE TABLE lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT UNIQUE NOT NULL,
  title_ku TEXT NOT NULL,
  title_tr TEXT,
  description_ku TEXT,
  category TEXT NOT NULL,
  icon_name TEXT,
  order_in_category INT DEFAULT 0,
  language TEXT DEFAULT 'ku',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE lesson_slides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  order_in_lesson INT NOT NULL,
  content_ku TEXT NOT NULL,
  content_tr TEXT,
  example_ku TEXT,
  image_url TEXT,
  audio_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(lesson_id, order_in_lesson)
);

CREATE TABLE user_lesson_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  completed BOOLEAN DEFAULT FALSE,
  last_viewed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, lesson_id)
);

-- ============================================================================
-- RPC: loadLessonsByCategory
-- ============================================================================

CREATE OR REPLACE FUNCTION load_lessons_by_category(p_category TEXT)
RETURNS TABLE (
  id UUID,
  slug TEXT,
  title_ku TEXT,
  title_tr TEXT,
  description_ku TEXT,
  icon_name TEXT,
  "order" INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.id, l.slug, l.title_ku, l.title_tr, l.description_ku, l.icon_name, l.order_in_category
  FROM lessons l
  WHERE l.category = p_category
  ORDER BY l.order_in_category ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- RPC: loadLesson
-- ============================================================================

CREATE OR REPLACE FUNCTION load_lesson(p_lesson_id UUID)
RETURNS TABLE (
  id UUID,
  slug TEXT,
  title_ku TEXT,
  title_tr TEXT,
  description_ku TEXT,
  category TEXT,
  icon_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT l.id, l.slug, l.title_ku, l.title_tr, l.description_ku, l.category, l.icon_name
  FROM lessons l
  WHERE l.id = p_lesson_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- RPC: loadLessonSlides
-- ============================================================================

CREATE OR REPLACE FUNCTION load_lesson_slides(p_lesson_id UUID)
RETURNS TABLE (
  id UUID,
  lesson_id UUID,
  order_in_lesson INT,
  content_ku TEXT,
  content_tr TEXT,
  example_ku TEXT,
  image_url TEXT,
  audio_url TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT ls.id, ls.lesson_id, ls.order_in_lesson, ls.content_ku, ls.content_tr,
         ls.example_ku, ls.image_url, ls.audio_url
  FROM lesson_slides ls
  WHERE ls.lesson_id = p_lesson_id
  ORDER BY ls.order_in_lesson ASC;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- RPC: markLessonCompleted
-- ============================================================================

CREATE OR REPLACE FUNCTION mark_lesson_completed(p_lesson_id UUID)
RETURNS TABLE (
  marked BOOLEAN,
  completed_at TIMESTAMPTZ
) AS $$
DECLARE
  v_user_id UUID;
  v_now TIMESTAMPTZ;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_now := now();
  INSERT INTO user_lesson_progress (user_id, lesson_id, completed, completed_at)
  VALUES (v_user_id, p_lesson_id, TRUE, v_now)
  ON CONFLICT (user_id, lesson_id)
  DO UPDATE SET completed = TRUE, completed_at = v_now;

  RETURN QUERY SELECT TRUE, v_now;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_slides ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_lesson_progress ENABLE ROW LEVEL SECURITY;

-- lessons: anyone can read
DROP POLICY IF EXISTS "lessons_read" ON lessons;
CREATE POLICY "lessons_read" ON lessons FOR SELECT USING (true);

-- lesson_slides: anyone can read
DROP POLICY IF EXISTS "lesson_slides_read" ON lesson_slides;
CREATE POLICY "lesson_slides_read" ON lesson_slides FOR SELECT USING (true);

-- user_lesson_progress: users see own
DROP POLICY IF EXISTS "user_lesson_progress_read" ON user_lesson_progress;
CREATE POLICY "user_lesson_progress_read" ON user_lesson_progress FOR SELECT
  USING (user_id = auth.uid());
DROP POLICY IF EXISTS "user_lesson_progress_insert_own" ON user_lesson_progress;
CREATE POLICY "user_lesson_progress_insert_own" ON user_lesson_progress FOR INSERT
  WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "user_lesson_progress_update_own" ON user_lesson_progress;
CREATE POLICY "user_lesson_progress_update_own" ON user_lesson_progress FOR UPDATE
  USING (user_id = auth.uid());

-- ============================================================================
-- INDEXES
-- ============================================================================

DROP INDEX IF EXISTS idx_lessons_category;
CREATE INDEX idx_lessons_category ON lessons(category);

DROP INDEX IF EXISTS idx_lessons_slug;
CREATE INDEX idx_lessons_slug ON lessons(slug);

DROP INDEX IF EXISTS idx_lesson_slides_lesson_id;
CREATE INDEX idx_lesson_slides_lesson_id ON lesson_slides(lesson_id);

DROP INDEX IF EXISTS idx_user_lesson_progress_user_id;
CREATE INDEX idx_user_lesson_progress_user_id ON user_lesson_progress(user_id);

DROP INDEX IF EXISTS idx_user_lesson_progress_lesson_id;
CREATE INDEX idx_user_lesson_progress_lesson_id ON user_lesson_progress(lesson_id);

DROP INDEX IF EXISTS idx_user_lesson_progress_completed;
CREATE INDEX idx_user_lesson_progress_completed ON user_lesson_progress(completed)
  WHERE completed = TRUE;
