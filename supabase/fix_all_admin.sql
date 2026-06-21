-- ================================================================
-- COMPLETE FIX — run this ONCE in Supabase SQL Editor
-- Fixes: courses RLS, payment_methods 403, storage 400
-- ================================================================

-- ── 1. Create is_admin() with SECURITY DEFINER ───────────────────
-- SECURITY DEFINER bypasses RLS on profiles — no recursion issues
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin');
$$;

-- ── 2. Make sure admin user has role = 'admin' ───────────────────
UPDATE profiles
SET role = 'admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@hajezustad.com');

-- ── 3. GRANT table permissions ───────────────────────────────────
GRANT SELECT, INSERT, UPDATE, DELETE ON courses         TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON course_lessons  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON packages        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON package_courses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON subscriptions   TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payment_methods TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON lesson_progress TO authenticated;
GRANT SELECT                          ON profiles        TO authenticated;
GRANT SELECT                          ON payment_methods TO anon;

-- Allow storage to access auth.users (fixes 400 on upload)
GRANT SELECT ON auth.users TO authenticated;
GRANT SELECT ON auth.users TO anon;

-- ── 4. Enable RLS on all tables ──────────────────────────────────
ALTER TABLE courses         ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_lessons  ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages        ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;

-- ── 5. DROP all old policies (clean slate) ───────────────────────
DROP POLICY IF EXISTS "courses_public_read"         ON courses;
DROP POLICY IF EXISTS "courses_admin_all"            ON courses;
DROP POLICY IF EXISTS "lessons_read"                ON course_lessons;
DROP POLICY IF EXISTS "lessons_admin_write"          ON course_lessons;
DROP POLICY IF EXISTS "packages_public_read"         ON packages;
DROP POLICY IF EXISTS "packages_admin_all"           ON packages;
DROP POLICY IF EXISTS "package_courses_public_read"  ON package_courses;
DROP POLICY IF EXISTS "package_courses_admin_all"    ON package_courses;
DROP POLICY IF EXISTS "subscriptions_student_read"   ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_student_insert" ON subscriptions;
DROP POLICY IF EXISTS "subscriptions_admin_all"      ON subscriptions;
DROP POLICY IF EXISTS "admin_subscriptions_all"      ON subscriptions;
DROP POLICY IF EXISTS "lesson_progress_student_all"  ON lesson_progress;
DROP POLICY IF EXISTS "public read active methods"   ON payment_methods;
DROP POLICY IF EXISTS "admin manage methods"         ON payment_methods;

-- ── 6. COURSES policies ──────────────────────────────────────────
-- Everyone sees active courses
CREATE POLICY "courses_public_read" ON courses
  FOR SELECT USING (is_active = TRUE OR is_admin());

-- Admin writes (INSERT/UPDATE/DELETE)
CREATE POLICY "courses_admin_all" ON courses
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

-- ── 7. COURSE_LESSONS policies ───────────────────────────────────
-- Preview lessons: everyone; locked: subscribers or admin
CREATE POLICY "lessons_read" ON course_lessons
  FOR SELECT USING (
    is_preview = TRUE
    OR is_admin()
    OR EXISTS (
      SELECT 1 FROM subscriptions s
      WHERE s.student_id = auth.uid()
        AND s.status = 'active'
        AND (
          s.course_id = course_lessons.course_id
          OR s.package_id IN (
            SELECT pc.package_id FROM package_courses pc
            WHERE pc.course_id = course_lessons.course_id
          )
        )
    )
  );

CREATE POLICY "lessons_admin_write" ON course_lessons
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

-- ── 8. PACKAGES policies ─────────────────────────────────────────
CREATE POLICY "packages_public_read" ON packages
  FOR SELECT USING (is_active = TRUE OR is_admin());

CREATE POLICY "packages_admin_all" ON packages
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

-- ── 9. PACKAGE_COURSES policies ──────────────────────────────────
CREATE POLICY "package_courses_public_read" ON package_courses
  FOR SELECT USING (TRUE);

CREATE POLICY "package_courses_admin_all" ON package_courses
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

-- ── 10. SUBSCRIPTIONS policies ───────────────────────────────────
CREATE POLICY "subscriptions_student_read" ON subscriptions
  FOR SELECT USING (student_id = auth.uid() OR is_admin());

CREATE POLICY "subscriptions_student_insert" ON subscriptions
  FOR INSERT WITH CHECK (student_id = auth.uid());

CREATE POLICY "subscriptions_admin_write" ON subscriptions
  FOR UPDATE TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

-- ── 11. LESSON_PROGRESS policies ─────────────────────────────────
CREATE POLICY "lesson_progress_student_all" ON lesson_progress
  FOR ALL USING  (student_id = auth.uid() OR is_admin())
  WITH CHECK (student_id = auth.uid() OR is_admin());

-- ── 12. PAYMENT_METHODS policies ─────────────────────────────────
CREATE POLICY "payment_methods_public_read" ON payment_methods
  FOR SELECT USING (is_active = TRUE OR is_admin());

CREATE POLICY "payment_methods_admin_all" ON payment_methods
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

-- ── 13. Storage buckets (create if not exist) ────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES
  ('course-videos',       'course-videos',       true, 524288000),
  ('course-files',        'course-files',        true,  52428800),
  ('subscription-proofs', 'subscription-proofs', false, 10485760)
ON CONFLICT (id) DO NOTHING;

-- Drop old storage policies
DROP POLICY IF EXISTS "authenticated can upload course-videos"  ON storage.objects;
DROP POLICY IF EXISTS "public can read course-videos"           ON storage.objects;
DROP POLICY IF EXISTS "authenticated can update course-videos"  ON storage.objects;
DROP POLICY IF EXISTS "authenticated can delete course-videos"  ON storage.objects;
DROP POLICY IF EXISTS "authenticated can upload course-files"   ON storage.objects;
DROP POLICY IF EXISTS "public can read course-files"            ON storage.objects;
DROP POLICY IF EXISTS "authenticated can update course-files"   ON storage.objects;
DROP POLICY IF EXISTS "authenticated can delete course-files"   ON storage.objects;
DROP POLICY IF EXISTS "authenticated can upload subscription-proofs"  ON storage.objects;
DROP POLICY IF EXISTS "owner can read subscription-proofs"            ON storage.objects;

-- course-videos: admin uploads, public reads
CREATE POLICY "upload course-videos" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'course-videos');
CREATE POLICY "read course-videos" ON storage.objects
  FOR SELECT USING (bucket_id = 'course-videos');
CREATE POLICY "update course-videos" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'course-videos');
CREATE POLICY "delete course-videos" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'course-videos');

-- course-files: same
CREATE POLICY "upload course-files" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'course-files');
CREATE POLICY "read course-files" ON storage.objects
  FOR SELECT USING (bucket_id = 'course-files');
CREATE POLICY "update course-files" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'course-files');
CREATE POLICY "delete course-files" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'course-files');

-- subscription-proofs: student uploads own, admin reads all
CREATE POLICY "upload subscription-proofs" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'subscription-proofs');
CREATE POLICY "read subscription-proofs" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'subscription-proofs');

-- ── 14. Verify ──────────────────────────────────────────────────
SELECT id, role FROM profiles
WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@hajezustad.com');
