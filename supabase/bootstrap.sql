-- ============================================================
-- Bootstrap — تشغيل هذا أولاً لتفعيل التسجيل
-- Supabase Dashboard → SQL Editor → New query → Run
-- ============================================================

-- 1. Enum (يتجاهل إذا موجود)
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('student', 'teacher', 'admin');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. جدول profiles
CREATE TABLE IF NOT EXISTS profiles (
  id         UUID        PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  full_name  TEXT        NOT NULL,
  phone      TEXT,
  avatar_url TEXT,
  role       user_role   NOT NULL DEFAULT 'student',
  is_active  BOOLEAN     NOT NULL DEFAULT TRUE,
  city       TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. دالة إنشاء Profile عند التسجيل
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
    COALESCE(
      CASE WHEN NEW.raw_user_meta_data->>'role' IN ('student','teacher','admin')
           THEN (NEW.raw_user_meta_data->>'role')::user_role
           ELSE 'student'::user_role
      END,
      'student'
    ),
    NEW.raw_user_meta_data->>'phone'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- 4. Trigger على auth.users
DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();
