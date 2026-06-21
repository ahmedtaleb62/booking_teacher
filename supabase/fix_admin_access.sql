-- ================================================================
-- FIX: Admin Panel Full Access
-- Run ALL of this in Supabase SQL Editor
-- ================================================================

-- ── STEP 1: GRANT all tables the admin panel needs ───────────────

-- Sessions & payments (booking system)
GRANT SELECT, UPDATE ON sessions        TO authenticated;
GRANT SELECT, UPDATE ON session_events  TO authenticated;
GRANT SELECT, UPDATE ON payments        TO authenticated;

-- Courses & packages
GRANT SELECT, INSERT, UPDATE, DELETE ON courses         TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON packages        TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON course_lessons  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON package_courses TO authenticated;

-- Subscriptions
GRANT SELECT, UPDATE ON subscriptions TO authenticated;

-- Payment methods
GRANT SELECT, INSERT, UPDATE, DELETE ON payment_methods TO authenticated;

-- Teacher profiles & profiles
GRANT SELECT, UPDATE, DELETE ON teacher_profiles TO authenticated;
GRANT SELECT                  ON profiles         TO authenticated;

-- ── STEP 2: RLS policies — admin full access ─────────────────────

-- Helper: is current user admin?
-- (checks profiles.role = 'admin')

-- sessions
DROP POLICY IF EXISTS "admin_sessions_all" ON sessions;
CREATE POLICY "admin_sessions_all" ON sessions
  FOR ALL TO authenticated
  USING   (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- payments
DROP POLICY IF EXISTS "admin_payments_all" ON payments;
CREATE POLICY "admin_payments_all" ON payments
  FOR ALL TO authenticated
  USING   (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- subscriptions: keep student policies, add admin
DROP POLICY IF EXISTS "admin_subscriptions_all" ON subscriptions;
CREATE POLICY "admin_subscriptions_all" ON subscriptions
  FOR ALL TO authenticated
  USING   (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- payment_methods: admin full access
DROP POLICY IF EXISTS "admin manage methods" ON payment_methods;
DROP POLICY IF EXISTS "public read active methods" ON payment_methods;
CREATE POLICY "public read active methods" ON payment_methods
  FOR SELECT USING (is_active = true);
CREATE POLICY "admin manage methods" ON payment_methods
  FOR ALL TO authenticated
  USING   (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- teacher_profiles: admin full access
DROP POLICY IF EXISTS "admin_teacher_profiles_all" ON teacher_profiles;
CREATE POLICY "admin_teacher_profiles_all" ON teacher_profiles
  FOR ALL TO authenticated
  USING   (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- profiles: admin can read all
DROP POLICY IF EXISTS "admin_profiles_read" ON profiles;
CREATE POLICY "admin_profiles_read" ON profiles
  FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
      OR id = auth.uid());

-- ── STEP 3: Price columns (if not already added) ─────────────────
ALTER TABLE courses  ADD COLUMN IF NOT EXISTS price_yearly   DECIMAL(10,2);
ALTER TABLE courses  ADD COLUMN IF NOT EXISTS original_price DECIMAL(10,2);
ALTER TABLE packages ADD COLUMN IF NOT EXISTS price_yearly   DECIMAL(10,2);
ALTER TABLE packages ADD COLUMN IF NOT EXISTS original_price DECIMAL(10,2);

-- ── STEP 4: Storage buckets + policies ──────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES
  ('course-videos', 'course-videos', true, 524288000),
  ('course-files',  'course-files',  true, 52428800)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "authenticated can upload course-videos"  ON storage.objects;
DROP POLICY IF EXISTS "public can read course-videos"           ON storage.objects;
DROP POLICY IF EXISTS "authenticated can update course-videos"  ON storage.objects;
DROP POLICY IF EXISTS "authenticated can delete course-videos"  ON storage.objects;
DROP POLICY IF EXISTS "authenticated can upload course-files"   ON storage.objects;
DROP POLICY IF EXISTS "public can read course-files"            ON storage.objects;
DROP POLICY IF EXISTS "authenticated can update course-files"   ON storage.objects;
DROP POLICY IF EXISTS "authenticated can delete course-files"   ON storage.objects;

CREATE POLICY "authenticated can upload course-videos"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'course-videos');
CREATE POLICY "public can read course-videos"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'course-videos');
CREATE POLICY "authenticated can update course-videos"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'course-videos');
CREATE POLICY "authenticated can delete course-videos"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'course-videos');

CREATE POLICY "authenticated can upload course-files"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'course-files');
CREATE POLICY "public can read course-files"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'course-files');
CREATE POLICY "authenticated can update course-files"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'course-files');
CREATE POLICY "authenticated can delete course-files"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'course-files');

-- ── STEP 5: Set a user as admin ──────────────────────────────────
-- Replace 'admin@yoursite.com' with the actual admin email
-- Run this AFTER creating the user in Supabase Dashboard → Auth → Users

-- UPDATE profiles SET role = 'admin' WHERE email = 'admin@yoursite.com';

-- ── DONE ────────────────────────────────────────────────────────
-- After running this SQL:
-- 1. Go to Supabase Dashboard → Authentication → Users → Add user
--    Email: your-admin@email.com  Password: choose a strong password
-- 2. Uncomment and run the UPDATE above with that email
-- 3. Log in to the admin panel with those credentials
