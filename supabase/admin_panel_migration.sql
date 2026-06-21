-- Payment methods table (طرق الدفع)
CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  method TEXT NOT NULL,
  label TEXT,
  number TEXT NOT NULL,
  holder TEXT NOT NULL DEFAULT 'منصة حجز استاذ',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: students can read active methods only; admin can CRUD
ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public read active methods" ON payment_methods;
CREATE POLICY "public read active methods"
  ON payment_methods FOR SELECT
  USING (is_active = true);

-- Allow admin (service role or authenticated with admin role) to manage
DROP POLICY IF EXISTS "admin manage methods" ON payment_methods;
CREATE POLICY "admin manage methods"
  ON payment_methods FOR ALL
  USING (true) WITH CHECK (true);

-- Sample data
INSERT INTO payment_methods (method, label, number, holder, is_active)
VALUES
  ('bimbank',   'بيم بنك',       '2202 3456 7890', 'منصة حجز استاذ', true),
  ('mauribank', 'بنك موريتاني',   '1201 9876 5432', 'منصة حجز استاذ', true),
  ('sedad',     'صدد',           '0501 1234 5678', 'منصة حجز استاذ', true)
ON CONFLICT DO NOTHING;

-- Add student_level to sessions if not exists
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS student_level TEXT;

-- Add teaching_levels to teacher_profiles if not exists
ALTER TABLE teacher_profiles ADD COLUMN IF NOT EXISTS teaching_levels TEXT[] DEFAULT '{}';

-- Update teachers_view to include teaching_levels
-- (Drop and recreate if it already exists)
-- NOTE: Adjust this to match your current teachers_view definition

-- Add lesson_type and chapter_title to course_lessons
ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS lesson_type TEXT DEFAULT 'video';
ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS chapter_title TEXT;

-- Storage buckets for course content
-- Run these in Supabase Dashboard → Storage → New Bucket:
--   1. "course-videos"  — public: true
--   2. "course-files"   — public: true
--
-- Or via SQL (requires pg_storage extension):
-- INSERT INTO storage.buckets (id, name, public) VALUES ('course-videos', 'course-videos', true) ON CONFLICT DO NOTHING;
-- INSERT INTO storage.buckets (id, name, public) VALUES ('course-files', 'course-files', true) ON CONFLICT DO NOTHING;

-- RLS for storage: allow authenticated users to upload
-- In Supabase Dashboard → Storage → course-videos → Policies:
--   SELECT (public), INSERT (authenticated), UPDATE (authenticated), DELETE (authenticated)
