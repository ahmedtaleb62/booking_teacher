-- ================================================================
-- COURSES & PACKAGES — Migration
-- Run in Supabase SQL Editor in ONE transaction
-- ================================================================

-- ── Tables ──────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS courses (
  id              UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  title           TEXT        NOT NULL,
  description     TEXT,
  subject         TEXT        NOT NULL,
  level           TEXT        NOT NULL DEFAULT 'مبتدئ',
  teacher_id      UUID        REFERENCES profiles(id) ON DELETE SET NULL,
  total_lessons   INT         NOT NULL DEFAULT 0,
  total_hours     DECIMAL(4,1) NOT NULL DEFAULT 0,
  price_monthly   DECIMAL(10,2) NOT NULL,
  cover_color     TEXT        NOT NULL DEFAULT '#1B6B7A',
  badge           TEXT,
  badge_bg        TEXT        DEFAULT '#1B9E77',
  badge_fg        TEXT        DEFAULT '#FFFFFF',
  is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS course_lessons (
  id              UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  course_id       UUID        NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  title           TEXT        NOT NULL,
  description     TEXT,
  video_url       TEXT,
  thumbnail_url   TEXT,
  order_index     INT         NOT NULL DEFAULT 0,
  duration_minutes INT        NOT NULL DEFAULT 0,
  is_preview      BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS packages (
  id              UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  title           TEXT        NOT NULL,
  description     TEXT,
  price_monthly   DECIMAL(10,2) NOT NULL,
  cover_color     TEXT        NOT NULL DEFAULT '#7B61FF',
  subjects        TEXT,
  save_label      TEXT,
  is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS package_courses (
  package_id  UUID NOT NULL REFERENCES packages(id)  ON DELETE CASCADE,
  course_id   UUID NOT NULL REFERENCES courses(id)   ON DELETE CASCADE,
  PRIMARY KEY (package_id, course_id)
);

CREATE TABLE IF NOT EXISTS subscriptions (
  id              UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id      UUID        NOT NULL REFERENCES profiles(id),
  course_id       UUID        REFERENCES courses(id),
  package_id      UUID        REFERENCES packages(id),
  type            TEXT        NOT NULL CHECK (type IN ('course', 'package')),
  status          TEXT        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending', 'active', 'expired', 'rejected')),
  proof_image_url TEXT,
  amount          DECIMAL(10,2) NOT NULL,
  reject_reason   TEXT,
  started_at      TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (
    (type = 'course'   AND course_id  IS NOT NULL AND package_id IS NULL) OR
    (type = 'package'  AND package_id IS NOT NULL AND course_id  IS NULL)
  )
);

CREATE TABLE IF NOT EXISTS lesson_progress (
  student_id       UUID NOT NULL REFERENCES profiles(id),
  lesson_id        UUID NOT NULL REFERENCES course_lessons(id) ON DELETE CASCADE,
  subscription_id  UUID REFERENCES subscriptions(id),
  watched_seconds  INT  NOT NULL DEFAULT 0,
  completed        BOOLEAN NOT NULL DEFAULT FALSE,
  last_watched     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (student_id, lesson_id)
);

-- ── RLS ─────────────────────────────────────────────────────────

ALTER TABLE courses         ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_lessons  ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages        ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE lesson_progress ENABLE ROW LEVEL SECURITY;

-- courses: anyone can read active courses
CREATE POLICY "courses_public_read" ON courses
  FOR SELECT USING (is_active = TRUE);

-- courses: admin can do everything
CREATE POLICY "courses_admin_all" ON courses
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- course_lessons: preview lessons are public; non-preview requires active subscription
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
  );

-- packages
CREATE POLICY "packages_public_read" ON packages
  FOR SELECT USING (is_active = TRUE);

CREATE POLICY "packages_admin_all" ON packages
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- package_courses: public read
CREATE POLICY "package_courses_public_read" ON package_courses
  FOR SELECT USING (TRUE);

CREATE POLICY "package_courses_admin_all" ON package_courses
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- subscriptions: student reads/creates own
CREATE POLICY "subscriptions_student_read" ON subscriptions
  FOR SELECT USING (student_id = auth.uid());

CREATE POLICY "subscriptions_student_insert" ON subscriptions
  FOR INSERT WITH CHECK (student_id = auth.uid());

-- subscriptions: admin reads/updates all
CREATE POLICY "subscriptions_admin_all" ON subscriptions
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- lesson_progress: student manages own
CREATE POLICY "lesson_progress_student_all" ON lesson_progress
  FOR ALL USING (student_id = auth.uid());

-- ── Helper functions ─────────────────────────────────────────────

-- Admin: confirm a subscription
CREATE OR REPLACE FUNCTION admin_confirm_subscription(
  p_subscription_id UUID,
  p_admin_id        UUID,
  p_months          INT DEFAULT 1
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE subscriptions SET
    status     = 'active',
    started_at = NOW(),
    expires_at = NOW() + (p_months || ' months')::INTERVAL,
    updated_at = NOW()
  WHERE id = p_subscription_id;
END;
$$;

-- Admin: reject a subscription
CREATE OR REPLACE FUNCTION admin_reject_subscription(
  p_subscription_id UUID,
  p_admin_id        UUID,
  p_reason          TEXT
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE subscriptions SET
    status        = 'rejected',
    reject_reason = p_reason,
    updated_at    = NOW()
  WHERE id = p_subscription_id;
END;
$$;

-- ── Storage bucket (run via Supabase Dashboard if not exists) ────
-- Create bucket 'subscription-proofs' with public=false in the Storage section
-- Or run:
-- INSERT INTO storage.buckets (id, name, public) VALUES ('subscription-proofs', 'subscription-proofs', false)
-- ON CONFLICT DO NOTHING;

-- ── Sample data ──────────────────────────────────────────────────

INSERT INTO courses (title, description, subject, level, total_lessons, total_hours, price_monthly, cover_color, badge, badge_bg, badge_fg) VALUES
  ('أساسيات الرياضيات', 'دورة شاملة في الجبر والهندسة والإحصاء للمرحلة الثانوية', 'رياضيات', 'مبتدئ', 12, 6.0, 450, '#1B6B7A', 'الأكثر اشتراكاً', '#1B9E77', '#FFFFFF'),
  ('الفيزياء المتقدمة', 'ميكانيكا ديناميكية وكهرومغناطيسية للمستوى الجامعي', 'فيزياء', 'متقدم', 20, 10.0, 600, '#11313A', 'جديد', '#7B61FF', '#FFFFFF'),
  ('اللغة الإنجليزية', 'قواعد اللغة الإنجليزية والمحادثة والكتابة الأكاديمية', 'إنجليزية', 'متوسط', 15, 7.5, 350, '#1B9E77', NULL, NULL, NULL)
ON CONFLICT DO NOTHING;

INSERT INTO packages (title, description, price_monthly, cover_color, subjects, save_label) VALUES
  ('باقة العلوم', 'رياضيات + فيزياء + كيمياء في باقة شاملة', 1200, '#7B61FF', '3 دروس · رياضيات · فيزياء · كيمياء', 'وفّر 30%'),
  ('الباقة الشاملة', 'جميع الدروس المتاحة في باقة واحدة بسعر استثنائي', 1800, '#11313A', '5 دروس · جميع المواد', 'وفّر 40%')
ON CONFLICT DO NOTHING;

-- Lessons for course 1 (get actual id via: SELECT id FROM courses WHERE title = 'أساسيات الرياضيات')
-- Admin can add lessons from dashboard later
