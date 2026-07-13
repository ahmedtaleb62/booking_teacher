-- ══════════════════════════════════════════════════════════════════
-- COMPREHENSIVE FIX — Run once in Supabase SQL Editor
-- Fixes:
--   1. Admin can't publish courses/packages back from draft
--   2. All lesson content treated as video (lesson_type data fix)
--   3. service_role permission denied
-- ══════════════════════════════════════════════════════════════════

-- ── 1. Grant service_role access (fixes REST API access) ─────────
GRANT ALL ON ALL TABLES    IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- ── 2. Ensure is_admin() function exists (SECURITY DEFINER) ──────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin');
$$;

-- ── 3. Fix COURSES policies ───────────────────────────────────────
-- Problem: courses_public_read was (is_active = TRUE) without OR is_admin()
-- Admin couldn't SEE draft courses → couldn't convert back to published

DROP POLICY IF EXISTS "courses_public_read" ON public.courses;
CREATE POLICY "courses_public_read" ON public.courses
  FOR SELECT USING (is_active = TRUE OR is_admin());

DROP POLICY IF EXISTS "courses_admin_all" ON public.courses;
CREATE POLICY "courses_admin_all" ON public.courses
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

-- ── 4. Fix PACKAGES policies ─────────────────────────────────────
-- Same issue: admin couldn't see draft packages

DROP POLICY IF EXISTS "packages_public_read" ON public.packages;
CREATE POLICY "packages_public_read" ON public.packages
  FOR SELECT USING (is_active = TRUE OR is_admin());

DROP POLICY IF EXISTS "packages_admin_all" ON public.packages;
CREATE POLICY "packages_admin_all" ON public.packages
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

-- ── 5. Ensure package_courses admin policy ────────────────────────
DROP POLICY IF EXISTS "package_courses_admin_all" ON public.package_courses;
CREATE POLICY "package_courses_admin_all" ON public.package_courses
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

-- ── 6. Ensure course_lessons columns exist ────────────────────────
ALTER TABLE public.course_lessons ADD COLUMN IF NOT EXISTS quiz_data   JSONB   DEFAULT NULL;
ALTER TABLE public.course_lessons ADD COLUMN IF NOT EXISTS file_url    TEXT;
ALTER TABLE public.course_lessons ADD COLUMN IF NOT EXISTS file_pages  INTEGER DEFAULT 0;

-- ── 7. Fix existing lesson_type data ─────────────────────────────
-- All lessons were saved with lesson_type = 'video' due to a bug in AddCourse.
-- Fix: set correct lesson_type based on actual content.

-- Lessons with quiz questions → exercise
UPDATE public.course_lessons
SET lesson_type = 'exercise'
WHERE quiz_data IS NOT NULL
  AND jsonb_array_length(quiz_data) > 0
  AND lesson_type != 'exercise';

-- Lessons with file attachment and no video → file
UPDATE public.course_lessons
SET lesson_type = 'file'
WHERE file_url IS NOT NULL AND file_url != ''
  AND (video_url IS NULL OR video_url = '')
  AND (quiz_data IS NULL OR jsonb_array_length(quiz_data) = 0)
  AND lesson_type != 'file';

-- ── 8. Fix course_lessons policies ───────────────────────────────
DROP POLICY IF EXISTS "lessons_admin_write" ON public.course_lessons;
CREATE POLICY "lessons_admin_write" ON public.course_lessons
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

-- Latest version of SELECT policy (free courses open to all, paid = subscriber or admin)
DROP POLICY IF EXISTS "course_lessons_select" ON public.course_lessons;
DROP POLICY IF EXISTS "lessons_read"          ON public.course_lessons;
CREATE POLICY "course_lessons_select" ON public.course_lessons
  FOR SELECT TO authenticated USING (
    is_preview = TRUE
    OR EXISTS (
      SELECT 1 FROM public.courses
      WHERE id = course_lessons.course_id AND price_monthly = 0
    )
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
    OR is_admin()
  );

-- ── 9. Verify ─────────────────────────────────────────────────────
SELECT
  (SELECT COUNT(*) FROM public.course_lessons WHERE lesson_type = 'exercise') AS exercise_count,
  (SELECT COUNT(*) FROM public.course_lessons WHERE lesson_type = 'file')     AS file_count,
  (SELECT COUNT(*) FROM public.course_lessons WHERE lesson_type = 'video')    AS video_count,
  (SELECT COUNT(*) FROM public.courses WHERE is_active = FALSE)               AS draft_courses,
  (SELECT COUNT(*) FROM public.packages WHERE is_active = FALSE)              AS draft_packages;
