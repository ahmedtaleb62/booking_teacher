-- Admin notifications: RPC to send broadcast notifications + admin notification triggers
-- Run this migration in Supabase SQL Editor

-- ── 1. send_admin_notification RPC ──────────────────────────────────────────
-- Called from the React admin panel to send notifications to user groups.
-- SECURITY DEFINER lets it insert into notifications for any user while
-- still enforcing that the *caller* must be an admin.

CREATE OR REPLACE FUNCTION send_admin_notification(
  p_target_type  text,           -- 'all' | 'teachers' | 'students' | 'user'
  p_title        text,
  p_body         text,
  p_target_id    uuid  DEFAULT NULL,   -- required when p_target_type = 'user'
  p_type         text  DEFAULT 'ADMIN_BROADCAST',
  p_data         jsonb DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  -- Ensure caller is an admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Unauthorized: admin role required';
  END IF;

  IF p_target_type = 'user' AND p_target_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, title, body, type, is_read)
    VALUES (p_target_id, p_title, p_body, p_type, false);

  ELSIF p_target_type = 'teachers' THEN
    INSERT INTO notifications (user_id, title, body, type, is_read)
    SELECT id, p_title, p_body, p_type, false
    FROM profiles
    WHERE role = 'teacher' AND is_active = true;

  ELSIF p_target_type = 'students' THEN
    INSERT INTO notifications (user_id, title, body, type, is_read)
    SELECT id, p_title, p_body, p_type, false
    FROM profiles
    WHERE role = 'student' AND is_active = true;

  ELSIF p_target_type = 'all' THEN
    INSERT INTO notifications (user_id, title, body, type, is_read)
    SELECT id, p_title, p_body, p_type, false
    FROM profiles
    WHERE is_active = true AND role IN ('student', 'teacher');
  END IF;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Grant execute to authenticated users (the RPC itself checks admin role)
GRANT EXECUTE ON FUNCTION send_admin_notification TO authenticated;


-- ── 2. Notify admin when a payment is submitted ──────────────────────────────
-- Triggered every time a student submits a payment proof.

CREATE OR REPLACE FUNCTION notify_admin_on_payment_submitted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Insert a notification row for every admin
  INSERT INTO notifications (user_id, title, body, type, session_id, is_read)
  SELECT
    p.id,
    'إثبات دفع جديد',
    'طالب رفع إثبات دفع — يرجى المراجعة والتأكيد',
    'PAYMENT_SUBMITTED',
    NEW.session_id,
    false
  FROM profiles p
  WHERE p.role = 'admin' AND p.is_active = true;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_admin_payment_submitted ON payments;
CREATE TRIGGER trg_notify_admin_payment_submitted
  AFTER INSERT ON payments
  FOR EACH ROW
  WHEN (NEW.status = 'submitted')
  EXECUTE FUNCTION notify_admin_on_payment_submitted();


-- ── 3. Notify admin when a dispute is opened ────────────────────────────────

CREATE OR REPLACE FUNCTION notify_admin_on_dispute()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO notifications (user_id, title, body, type, session_id, is_read)
  SELECT
    p.id,
    'نزاع جديد',
    'تم فتح نزاع — يتطلب تدخل الإدارة',
    'DISPUTE_OPENED',
    NEW.session_id,
    false
  FROM profiles p
  WHERE p.role = 'admin' AND p.is_active = true;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_admin_dispute ON disputes;
CREATE TRIGGER trg_notify_admin_dispute
  AFTER INSERT ON disputes
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_on_dispute();


-- ── 4. Notify admin when a teacher completes onboarding (awaiting approval) ──

CREATE OR REPLACE FUNCTION notify_admin_on_teacher_onboarding()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Fire only when is_approved transitions from false/null to still false
  -- (meaning teacher submitted but admin hasn't approved yet)
  IF (TG_OP = 'INSERT') OR (OLD.is_approved IS DISTINCT FROM NEW.is_approved AND NEW.is_approved = false) THEN
    INSERT INTO notifications (user_id, title, body, type, is_read)
    SELECT
      p.id,
      'أستاذ جديد يطلب الانضمام',
      'قدّم أستاذ طلب انضمام جديد — يرجى المراجعة',
      'TEACHER_ONBOARDING',
      false
    FROM profiles p
    WHERE p.role = 'admin' AND p.is_active = true;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_admin_teacher_onboarding ON teacher_profiles;
CREATE TRIGGER trg_notify_admin_teacher_onboarding
  AFTER INSERT ON teacher_profiles
  FOR EACH ROW
  EXECUTE FUNCTION notify_admin_on_teacher_onboarding();


-- ── 5. RLS: allow admins to read all notifications ────────────────────────────
-- (The existing RLS likely already covers this via "admin all" policy,
--  but we make it explicit here as a safeguard.)

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'notifications'
      AND policyname = 'admin_full_notifications'
  ) THEN
    CREATE POLICY admin_full_notifications ON notifications
      FOR ALL
      USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
      );
  END IF;
END
$$;
