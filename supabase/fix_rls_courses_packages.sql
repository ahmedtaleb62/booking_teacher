-- ================================================================
-- FIX: permission denied 42501 for courses & packages
-- Run in Supabase SQL Editor
-- ================================================================

-- 1. Make sure tables exist
CREATE TABLE IF NOT EXISTS courses (
  id              UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  title           TEXT          NOT NULL,
  description     TEXT,
  subject         TEXT          NOT NULL,
  level           TEXT          NOT NULL DEFAULT 'مبتدئ',
  teacher_id      UUID          REFERENCES profiles(id) ON DELETE SET NULL,
  total_lessons   INT           NOT NULL DEFAULT 0,
  total_hours     DECIMAL(4,1)  NOT NULL DEFAULT 0,
  price_monthly   DECIMAL(10,2) NOT NULL DEFAULT 0,
  cover_color     TEXT          NOT NULL DEFAULT '#1B6B7A',
  badge           TEXT,
  badge_bg        TEXT          DEFAULT '#1B9E77',
  badge_fg        TEXT          DEFAULT '#FFFFFF',
  is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS packages (
  id            UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  title         TEXT          NOT NULL,
  description   TEXT,
  price_monthly DECIMAL(10,2) NOT NULL DEFAULT 0,
  cover_color   TEXT          NOT NULL DEFAULT '#7B61FF',
  subjects      TEXT,
  save_label    TEXT,
  is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS course_lessons (
  id               UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  course_id        UUID        NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title            TEXT        NOT NULL,
  description      TEXT,
  video_url        TEXT,
  thumbnail_url    TEXT,
  order_index      INT         NOT NULL DEFAULT 0,
  duration_minutes INT         NOT NULL DEFAULT 0,
  is_preview       BOOLEAN     NOT NULL DEFAULT FALSE,
  lesson_type      TEXT        NOT NULL DEFAULT 'video',
  chapter_title    TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS package_courses (
  package_id UUID NOT NULL REFERENCES packages(id) ON DELETE CASCADE,
  course_id  UUID NOT NULL REFERENCES courses(id)  ON DELETE CASCADE,
  PRIMARY KEY (package_id, course_id)
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id              UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id      UUID          NOT NULL REFERENCES profiles(id),
  course_id       UUID          REFERENCES courses(id),
  package_id      UUID          REFERENCES packages(id),
  type            TEXT          NOT NULL CHECK (type IN ('course','package')),
  status          TEXT          NOT NULL DEFAULT 'pending'
                                CHECK (status IN ('pending','active','expired','rejected')),
  proof_image_url TEXT,
  amount          DECIMAL(10,2) NOT NULL DEFAULT 0,
  reject_reason   TEXT,
  started_at      TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS lesson_progress (
  student_id      UUID    NOT NULL REFERENCES profiles(id),
  lesson_id       UUID    NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  subscription_id UUID    REFERENCES subscriptions(id),
  watched_seconds INT     NOT NULL DEFAULT 0,
  completed       BOOLEAN NOT NULL DEFAULT FALSE,
  last_watched    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (student_id, lesson_id)
);

-- 1b. Add missing price columns (safe to re-run)
ALTER TABLE courses ADD COLUMN IF NOT EXISTS price_yearly   DECIMAL(10,2);
ALTER TABLE courses ADD COLUMN IF NOT EXISTS original_price DECIMAL(10,2);
ALTER TABLE packages ADD COLUMN IF NOT EXISTS price_yearly   DECIMAL(10,2);
ALTER TABLE packages ADD COLUMN IF NOT EXISTS original_price DECIMAL(10,2);

-- 2. GRANT table access to Supabase roles
--    (this is what was missing — RLS alone is not enough)
GRANT SELECT ON courses         TO anon, authenticated;
GRANT SELECT ON packages        TO anon, authenticated;
GRANT SELECT ON course_lessons  TO anon, authenticated;
GRANT SELECT ON package_courses TO anon, authenticated;

GRANT SELECT, INSERT, UPDATE ON subscriptions   TO authenticated;
GRANT SELECT, INSERT, UPDATE ON lesson_progress TO authenticated;

-- 3. Enable RLS
ALTER TABLE courses         ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_lessons  ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages        ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_progress ENABLE ROW LEVEL SECURITY;

-- 4. Drop then recreate policies
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
DROP POLICY IF EXISTS "lesson_progress_student_all"  ON lesson_progress;

-- courses: everyone can read active
CREATE POLICY "courses_public_read" ON courses
  FOR SELECT USING (is_active = TRUE);

-- courses: admin writes
CREATE POLICY "courses_admin_all" ON courses
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- course_lessons: preview = anyone; locked = subscriber or admin
CREATE POLICY "lessons_read" ON course_lessons
  FOR SELECT USING (
    is_preview = TRUE
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
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "lessons_admin_write" ON course_lessons
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- packages: everyone can read active
CREATE POLICY "packages_public_read" ON packages
  FOR SELECT USING (is_active = TRUE);

CREATE POLICY "packages_admin_all" ON packages
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- package_courses: public read
CREATE POLICY "package_courses_public_read" ON package_courses
  FOR SELECT USING (TRUE);

CREATE POLICY "package_courses_admin_all" ON package_courses
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- subscriptions: student reads/inserts own
CREATE POLICY "subscriptions_student_read" ON subscriptions
  FOR SELECT USING (student_id = auth.uid());

CREATE POLICY "subscriptions_student_insert" ON subscriptions
  FOR INSERT WITH CHECK (student_id = auth.uid());

-- subscriptions: admin full
CREATE POLICY "subscriptions_admin_all" ON subscriptions
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- lesson_progress: student manages own
CREATE POLICY "lesson_progress_student_all" ON lesson_progress
  FOR ALL USING  (student_id = auth.uid())
  WITH CHECK (student_id = auth.uid());
