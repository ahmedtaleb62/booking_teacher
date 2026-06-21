-- ================================================================
-- FIX: Admin cannot insert courses — "new row violates RLS policy"
-- Run this in Supabase SQL Editor
-- ================================================================

-- STEP 1: Set role = 'admin' for the admin user
-- (this is almost always the root cause of the RLS error)
UPDATE profiles
SET role = 'admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@hajezustad.com');

-- Verify the update worked — should return 1 row with role = 'admin'
SELECT id, role FROM profiles
WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@hajezustad.com');

-- ----------------------------------------------------------------
-- STEP 2: Make sure INSERT/UPDATE/DELETE are granted
-- (SELECT-only GRANT from fix_rls_courses_packages.sql is not enough)
-- ----------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON courses        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON course_lessons TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON packages       TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON package_courses TO authenticated;
GRANT SELECT ON profiles TO authenticated;

-- ----------------------------------------------------------------
-- STEP 3: Fix the courses and course_lessons RLS policies
-- to use the SECURITY DEFINER is_admin() function (already exists
-- in rls.sql) — avoids any infinite-recursion edge cases
-- ----------------------------------------------------------------
DROP POLICY IF EXISTS "courses_admin_all"    ON courses;
DROP POLICY IF EXISTS "lessons_admin_write"  ON course_lessons;
DROP POLICY IF EXISTS "packages_admin_all"   ON packages;
DROP POLICY IF EXISTS "package_courses_admin_all" ON package_courses;

CREATE POLICY "courses_admin_all" ON courses
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "lessons_admin_write" ON course_lessons
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "packages_admin_all" ON packages
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "package_courses_admin_all" ON package_courses
  FOR ALL TO authenticated
  USING   (is_admin())
  WITH CHECK (is_admin());
