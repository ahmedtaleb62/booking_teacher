-- ============================================================
-- Row Level Security — حجز استاذ
-- Run AFTER schema.sql
-- ============================================================

-- Helper: is current user an admin?
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin');
$$;

-- Helper: is current user a teacher?
CREATE OR REPLACE FUNCTION is_teacher()
RETURNS BOOLEAN LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'teacher');
$$;

-- ============================================================
-- PROFILES
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_select_admin"
  ON profiles FOR SELECT USING (is_admin());

-- Students need to read teacher profiles to display names
CREATE POLICY "profiles_select_teacher"
  ON profiles FOR SELECT USING (role = 'teacher' AND is_active = true);

CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_admin"
  ON profiles FOR UPDATE USING (is_admin());

-- ============================================================
-- TEACHER PROFILES
-- ============================================================
ALTER TABLE teacher_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "teacher_profiles_select_approved"
  ON teacher_profiles FOR SELECT USING (is_approved = true);

CREATE POLICY "teacher_profiles_select_own"
  ON teacher_profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "teacher_profiles_select_admin"
  ON teacher_profiles FOR SELECT USING (is_admin());

CREATE POLICY "teacher_profiles_update_own"
  ON teacher_profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "teacher_profiles_all_admin"
  ON teacher_profiles FOR ALL USING (is_admin());

-- ============================================================
-- TEACHER AVAILABILITY
-- ============================================================
ALTER TABLE teacher_availability ENABLE ROW LEVEL SECURITY;

CREATE POLICY "availability_select_all"
  ON teacher_availability FOR SELECT USING (true);

CREATE POLICY "availability_modify_own"
  ON teacher_availability FOR ALL USING (auth.uid() = teacher_id);

CREATE POLICY "availability_modify_admin"
  ON teacher_availability FOR ALL USING (is_admin());

-- ============================================================
-- SESSIONS
-- ============================================================
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sessions_select_student"
  ON sessions FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY "sessions_select_teacher"
  ON sessions FOR SELECT USING (auth.uid() = teacher_id);

CREATE POLICY "sessions_select_admin"
  ON sessions FOR SELECT USING (is_admin());

CREATE POLICY "sessions_insert_student"
  ON sessions FOR INSERT WITH CHECK (
    auth.uid() = student_id
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'student')
  );

-- Student can cancel before payment is confirmed
CREATE POLICY "sessions_update_student_cancel"
  ON sessions FOR UPDATE
  USING (auth.uid() = student_id AND state IN ('REQUESTED','TEACHER_APPROVED','AWAITING_PAYMENT','PAYMENT_SUBMITTED'))
  WITH CHECK (state = 'CANCELLED');

-- Student can submit payment proof (AWAITING_PAYMENT → PAYMENT_SUBMITTED handled via payments table + service)
-- Teacher can approve/reject REQUESTED sessions
CREATE POLICY "sessions_update_teacher_decision"
  ON sessions FOR UPDATE
  USING (auth.uid() = teacher_id AND state = 'REQUESTED')
  WITH CHECK (state IN ('TEACHER_APPROVED','TEACHER_REJECTED'));

-- Teacher can start/end session
CREATE POLICY "sessions_update_teacher_active"
  ON sessions FOR UPDATE
  USING (auth.uid() = teacher_id AND state IN ('CONFIRMED_BOOKING','ACTIVE_SESSION'))
  WITH CHECK (state IN ('ACTIVE_SESSION','COMPLETED','TEACHER_NO_SHOW'));

-- Admin can do anything on sessions
CREATE POLICY "sessions_all_admin"
  ON sessions FOR ALL USING (is_admin());

-- ============================================================
-- SESSION EVENTS  (read-only for participants)
-- ============================================================
ALTER TABLE session_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "events_select_participant"
  ON session_events FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM sessions s WHERE s.id = session_id
        AND (s.student_id = auth.uid() OR s.teacher_id = auth.uid())
    )
  );

CREATE POLICY "events_select_admin"
  ON session_events FOR SELECT USING (is_admin());

-- System functions use SECURITY DEFINER so they bypass RLS for inserts

-- ============================================================
-- PAYMENTS
-- ============================================================
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payments_select_student"
  ON payments FOR SELECT USING (auth.uid() = student_id);

CREATE POLICY "payments_select_teacher"
  ON payments FOR SELECT USING (
    EXISTS (SELECT 1 FROM sessions s WHERE s.id = session_id AND s.teacher_id = auth.uid())
  );

CREATE POLICY "payments_select_admin"
  ON payments FOR SELECT USING (is_admin());

CREATE POLICY "payments_insert_student"
  ON payments FOR INSERT WITH CHECK (
    auth.uid() = student_id
    AND EXISTS (
      SELECT 1 FROM sessions s
      WHERE s.id = session_id
        AND s.student_id = auth.uid()
        AND s.state = 'AWAITING_PAYMENT'
    )
  );

CREATE POLICY "payments_update_admin"
  ON payments FOR UPDATE USING (is_admin());

-- ============================================================
-- DISPUTES
-- ============================================================
ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "disputes_select_participant"
  ON disputes FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM sessions s WHERE s.id = session_id
        AND (s.student_id = auth.uid() OR s.teacher_id = auth.uid())
    )
  );

CREATE POLICY "disputes_select_admin"
  ON disputes FOR SELECT USING (is_admin());

CREATE POLICY "disputes_insert_participant"
  ON disputes FOR INSERT WITH CHECK (
    auth.uid() = opened_by
    AND EXISTS (
      SELECT 1 FROM sessions s WHERE s.id = session_id
        AND (s.student_id = auth.uid() OR s.teacher_id = auth.uid())
        AND s.state IN ('ACTIVE_SESSION','COMPLETED','CONFIRMED_BOOKING')
    )
  );

CREATE POLICY "disputes_update_admin"
  ON disputes FOR UPDATE USING (is_admin());

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select_own"
  ON notifications FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "notifications_update_own"
  ON notifications FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id AND is_read = true);

-- ============================================================
-- REVIEWS
-- ============================================================
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reviews_select_all"
  ON reviews FOR SELECT USING (true);

CREATE POLICY "reviews_insert_student"
  ON reviews FOR INSERT WITH CHECK (
    auth.uid() = student_id
    AND EXISTS (
      SELECT 1 FROM sessions s WHERE s.id = session_id
        AND s.student_id = auth.uid()
        AND s.state = 'COMPLETED'
    )
  );

-- ============================================================
-- LEDGER ENTRIES
-- ============================================================
ALTER TABLE ledger_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ledger_admin_only"
  ON ledger_entries FOR ALL USING (is_admin());

-- ============================================================
-- SYSTEM SETTINGS
-- ============================================================
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "settings_select_all"
  ON system_settings FOR SELECT USING (true);

CREATE POLICY "settings_update_admin"
  ON system_settings FOR UPDATE USING (is_admin());

-- ============================================================
-- GRANTS — views need explicit permission for PostgREST roles
-- ============================================================
GRANT SELECT ON public.teachers_view TO anon;
GRANT SELECT ON public.teachers_view TO authenticated;
