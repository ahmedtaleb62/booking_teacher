-- ══════════════════════════════════════════════════════════════════
-- Fix: allow all authenticated students to read lessons of free
-- courses (price_monthly = 0) without needing an active subscription.
-- Run in Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "course_lessons_select" ON public.course_lessons;

CREATE POLICY "course_lessons_select" ON public.course_lessons
  FOR SELECT TO authenticated USING (
    -- Preview lessons visible to all
    is_preview = TRUE
    -- Free course: open to every authenticated student
    OR EXISTS (
      SELECT 1 FROM public.courses
      WHERE id = course_lessons.course_id
        AND price_monthly = 0
    )
    -- Paid course: active subscriber only
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
    -- Admin: full access
    OR EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );
