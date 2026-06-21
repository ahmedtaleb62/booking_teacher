-- ================================================================
-- FIX: Students can see ALL lessons of active courses (listed but locked)
-- Previously only preview lessons were visible before subscribing
-- ================================================================

DROP POLICY IF EXISTS "lessons_read" ON course_lessons;

-- Allow any user to SELECT lessons that belong to an active course.
-- The video_url is in the same row but the storage bucket is already public,
-- so hiding the row does not add real security — it only breaks the UI.
-- Access control (play/lock) is enforced in the Flutter app.
CREATE POLICY "lessons_read" ON course_lessons
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM courses
      WHERE courses.id = course_lessons.course_id
        AND courses.is_active = TRUE
    )
    OR is_admin()
  );
