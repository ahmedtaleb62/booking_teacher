-- ─────────────────────────────────────────────────────────────────
-- 1. Fix course_lessons RLS:
--    Preview lessons → visible to all authenticated users (for course listing).
--    Locked lessons → only visible to active subscribers or admins.
--    This prevents video_url of locked lessons leaking via direct API calls.
-- ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "course_lessons_select" ON public.course_lessons;
DROP POLICY IF EXISTS "lessons_preview_only"  ON public.course_lessons;
DROP POLICY IF EXISTS "select_lessons"        ON public.course_lessons;
DROP POLICY IF EXISTS "lessons_read"          ON public.course_lessons;

CREATE POLICY "course_lessons_select" ON public.course_lessons
  FOR SELECT TO authenticated USING (
    is_preview = TRUE
    OR EXISTS (
      SELECT 1 FROM public.subscriptions s
      WHERE s.student_id = auth.uid()
        AND s.status = 'active'
        AND (s.expires_at IS NULL OR s.expires_at > NOW())
        AND (
          s.course_id = course_lessons.course_id
          OR s.package_id IN (
            SELECT pc.package_id FROM public.package_courses pc
            WHERE pc.course_id = course_lessons.course_id
          )
        )
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ─────────────────────────────────────────────────────────────────
-- 2. Add ratings_count column to courses
-- ─────────────────────────────────────────────────────────────────
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS ratings_count INTEGER DEFAULT 0;

-- ─────────────────────────────────────────────────────────────────
-- 3. Course ratings table (one rating per student per course)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.course_ratings (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id   UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  student_id  UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(course_id, student_id)
);

ALTER TABLE public.course_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "students_upsert_own_rating" ON public.course_ratings
  FOR ALL TO authenticated
  USING (student_id = auth.uid())
  WITH CHECK (student_id = auth.uid());

CREATE POLICY "read_all_ratings" ON public.course_ratings
  FOR SELECT TO authenticated USING (true);

-- ─────────────────────────────────────────────────────────────────
-- 4. Trigger: keep courses.rating + courses.ratings_count in sync
-- ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_course_rating()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _course_id UUID;
BEGIN
  _course_id := COALESCE(NEW.course_id, OLD.course_id);
  UPDATE public.courses SET
    rating        = (SELECT ROUND(AVG(rating)::NUMERIC, 1) FROM public.course_ratings WHERE course_id = _course_id),
    ratings_count = (SELECT COUNT(*)                       FROM public.course_ratings WHERE course_id = _course_id)
  WHERE id = _course_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_course_rating ON public.course_ratings;
CREATE TRIGGER trg_sync_course_rating
  AFTER INSERT OR UPDATE OR DELETE ON public.course_ratings
  FOR EACH ROW EXECUTE FUNCTION public.sync_course_rating();
