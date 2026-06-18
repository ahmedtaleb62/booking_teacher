-- ============================================================
-- حجز استاذ · Supabase Schema · Production Grade
-- Run in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- ============================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gist"; -- needed for EXCLUDE constraint

-- ============================================================
-- DROP (idempotent re-run)
-- ============================================================
DROP TABLE IF EXISTS disputes           CASCADE;
DROP TABLE IF EXISTS ledger_entries     CASCADE;
DROP TABLE IF EXISTS reviews            CASCADE;
DROP TABLE IF EXISTS notifications      CASCADE;
DROP TABLE IF EXISTS payments           CASCADE;
DROP TABLE IF EXISTS session_events     CASCADE;
DROP TABLE IF EXISTS sessions           CASCADE;
DROP TABLE IF EXISTS teacher_availability CASCADE;
DROP TABLE IF EXISTS teacher_profiles   CASCADE;
DROP TABLE IF EXISTS system_settings    CASCADE;
DROP TABLE IF EXISTS profiles           CASCADE;

DROP TYPE IF EXISTS session_state   CASCADE;
DROP TYPE IF EXISTS payment_status  CASCADE;
DROP TYPE IF EXISTS user_role       CASCADE;
DROP TYPE IF EXISTS payment_method  CASCADE;

-- ============================================================
-- ENUMS
-- ============================================================
CREATE TYPE user_role AS ENUM ('student', 'teacher', 'admin');

CREATE TYPE session_state AS ENUM (
  'REQUESTED',
  'TEACHER_APPROVED',
  'TEACHER_REJECTED',
  'AWAITING_PAYMENT',
  'PAYMENT_SUBMITTED',
  'PAYMENT_CONFIRMED',
  'CONFIRMED_BOOKING',
  'ACTIVE_SESSION',
  'COMPLETED',
  'TEACHER_NO_SHOW',
  'STUDENT_NO_SHOW',
  'DISPUTE',
  'CANCELLED'
);

CREATE TYPE payment_status AS ENUM (
  'pending',
  'submitted',
  'confirmed',
  'rejected'
);

CREATE TYPE payment_method AS ENUM (
  'bankily',
  'masrivi',
  'sedad',
  'bimbank',
  'bank_transfer'
);

-- ============================================================
-- PROFILES  (one per auth.users row)
-- ============================================================
CREATE TABLE profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  full_name    TEXT         NOT NULL,
  phone        TEXT,
  avatar_url   TEXT,
  role         user_role    NOT NULL DEFAULT 'student',
  is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
  city         TEXT,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ============================================================
-- TEACHER PROFILES
-- ============================================================
CREATE TABLE teacher_profiles (
  id               UUID         PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  bio              TEXT,
  subjects         TEXT[]       NOT NULL DEFAULT '{}',
  price_per_hour   NUMERIC(10,2) NOT NULL,
  years_experience INT          NOT NULL DEFAULT 0,
  is_verified      BOOLEAN      NOT NULL DEFAULT FALSE,
  is_approved      BOOLEAN      NOT NULL DEFAULT FALSE,
  rating           NUMERIC(3,2) NOT NULL DEFAULT 0,
  review_count     INT          NOT NULL DEFAULT 0,
  total_sessions   INT          NOT NULL DEFAULT 0,
  attendance_rate  NUMERIC(5,2) NOT NULL DEFAULT 100,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ============================================================
-- TEACHER AVAILABILITY
-- ============================================================
CREATE TABLE teacher_availability (
  id           UUID  PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id   UUID  NOT NULL REFERENCES teacher_profiles(id) ON DELETE CASCADE,
  day_of_week  INT   NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time   TIME  NOT NULL,
  end_time     TIME  NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- SYSTEM SETTINGS
-- ============================================================
CREATE TABLE system_settings (
  key        TEXT PRIMARY KEY,
  value      JSONB        NOT NULL,
  updated_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_by UUID         REFERENCES profiles(id)
);

INSERT INTO system_settings (key, value) VALUES
  ('commission_rate',           '"0.15"'),
  ('payment_timeout_minutes',   '"60"'),
  ('no_show_timeout_minutes',   '"15"'),
  ('dispute_auto_open_hours',   '"1"'),
  ('payment_accounts', '[
    {"method":"bankily",     "name":"Bankily",      "number":"22 41 88 90", "active":true},
    {"method":"masrivi",     "name":"Masrivi",      "number":"31 22 55 70", "active":true},
    {"method":"sedad",       "name":"Sedad",        "number":"46 90 12 33", "active":true},
    {"method":"bimbank",     "name":"Bimbank",      "number":"27 08 64 19", "active":false}
  ]');

-- ============================================================
-- SESSIONS  (core table — state machine lives here)
-- ============================================================
CREATE TABLE sessions (
  id                UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id        UUID          NOT NULL REFERENCES profiles(id),
  teacher_id        UUID          NOT NULL REFERENCES teacher_profiles(id),
  subject           TEXT          NOT NULL,
  state             session_state NOT NULL DEFAULT 'REQUESTED',
  scheduled_at      TIMESTAMPTZ   NOT NULL,
  duration_minutes  INT           NOT NULL DEFAULT 60 CHECK (duration_minutes IN (30, 60, 90)),
  amount            NUMERIC(10,2) NOT NULL,
  teacher_net       NUMERIC(10,2) GENERATED ALWAYS AS (amount * 0.85) STORED,
  student_note      TEXT,
  teacher_note      TEXT,
  rejection_reason  TEXT,
  parent_session_id UUID          REFERENCES sessions(id),
  payment_deadline  TIMESTAMPTZ,  -- set when AWAITING_PAYMENT
  room_url          TEXT,
  started_at        TIMESTAMPTZ,
  ended_at          TIMESTAMPTZ,
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
  -- double-booking prevention is enforced via trg_check_double_booking trigger below
);

CREATE INDEX idx_sessions_student   ON sessions(student_id);
CREATE INDEX idx_sessions_teacher   ON sessions(teacher_id);
CREATE INDEX idx_sessions_state     ON sessions(state);
CREATE INDEX idx_sessions_scheduled ON sessions(scheduled_at);
CREATE INDEX idx_sessions_deadline  ON sessions(payment_deadline) WHERE payment_deadline IS NOT NULL;

-- ============================================================
-- FUNCTION — double-booking guard (replaces EXCLUDE constraint)
-- ============================================================
CREATE OR REPLACE FUNCTION check_no_double_booking()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_end TIMESTAMPTZ := NEW.scheduled_at + make_interval(mins => NEW.duration_minutes);
BEGIN
  IF EXISTS (
    SELECT 1 FROM sessions
    WHERE teacher_id = NEW.teacher_id
      AND id        != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
      AND state NOT IN ('TEACHER_REJECTED','CANCELLED','COMPLETED','STUDENT_NO_SHOW','TEACHER_NO_SHOW')
      AND scheduled_at                                            < v_end
      AND scheduled_at + make_interval(mins => duration_minutes) > NEW.scheduled_at
  ) THEN
    RAISE EXCEPTION 'هذا الموعد محجوز مسبقاً لدى الأستاذ (double-booking)';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_double_booking
  BEFORE INSERT OR UPDATE OF scheduled_at, duration_minutes, teacher_id, state
  ON sessions
  FOR EACH ROW EXECUTE FUNCTION check_no_double_booking();

-- ============================================================
-- SESSION EVENTS  (immutable audit log)
-- ============================================================
CREATE TABLE session_events (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id  UUID        NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  event_type  TEXT        NOT NULL,
  actor       TEXT,        -- 'student' | 'teacher' | 'admin' | 'system'
  actor_id    UUID        REFERENCES profiles(id),
  note        TEXT,
  metadata    JSONB       DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_events_session ON session_events(session_id);

-- ============================================================
-- PAYMENTS
-- ============================================================
CREATE TABLE payments (
  id               UUID           PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id       UUID           NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  student_id       UUID           NOT NULL REFERENCES profiles(id),
  amount           NUMERIC(10,2)  NOT NULL,
  method           payment_method NOT NULL,
  proof_image_url  TEXT,
  reference        TEXT           NOT NULL UNIQUE,
  status           payment_status NOT NULL DEFAULT 'submitted',
  confirmed_by     UUID           REFERENCES profiles(id),
  confirmed_at     TIMESTAMPTZ,
  reject_reason    TEXT,
  notes            TEXT,
  created_at       TIMESTAMPTZ    NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ    NOT NULL DEFAULT now()
);

CREATE INDEX idx_payments_session ON payments(session_id);
CREATE INDEX idx_payments_student ON payments(student_id);
CREATE INDEX idx_payments_status  ON payments(status);

-- ============================================================
-- DISPUTES
-- ============================================================
CREATE TABLE disputes (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id          UUID        NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  opened_by           UUID        NOT NULL REFERENCES profiles(id),
  reason              TEXT        NOT NULL DEFAULT 'other',
  student_statement   TEXT,
  teacher_statement   TEXT,
  student_evidence    TEXT[]      NOT NULL DEFAULT '{}',
  teacher_evidence    TEXT[]      NOT NULL DEFAULT '{}',
  status              TEXT        NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','closed')),
  resolution          TEXT        CHECK (resolution IN ('full_refund','teacher_paid','split_reschedule','reschedule_only')),
  resolved_by         UUID        REFERENCES profiles(id),
  resolved_at         TIMESTAMPTZ,
  admin_note          TEXT,
  frozen_amount       NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (session_id)
);

CREATE INDEX idx_disputes_session ON disputes(session_id);
CREATE INDEX idx_disputes_status  ON disputes(status);

-- ============================================================
-- ADMIN LEDGER
-- ============================================================
CREATE TABLE ledger_entries (
  id           UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_id   UUID          REFERENCES payments(id),
  session_id   UUID          REFERENCES sessions(id),
  student_id   UUID          REFERENCES profiles(id),
  teacher_id   UUID          REFERENCES teacher_profiles(id),
  type         TEXT          NOT NULL,
  amount       NUMERIC(10,2) NOT NULL,
  commission   NUMERIC(10,2) NOT NULL DEFAULT 0,
  net_amount   NUMERIC(10,2) NOT NULL,
  description  TEXT,
  created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE INDEX idx_ledger_session ON ledger_entries(session_id);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title       TEXT        NOT NULL,
  body        TEXT        NOT NULL,
  type        TEXT        NOT NULL,
  session_id  UUID        REFERENCES sessions(id),
  data        JSONB       DEFAULT '{}',
  is_read     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_user   ON notifications(user_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE NOT is_read;

-- ============================================================
-- REVIEWS
-- ============================================================
CREATE TABLE reviews (
  id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id  UUID        NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  student_id  UUID        NOT NULL REFERENCES profiles(id),
  teacher_id  UUID        NOT NULL REFERENCES teacher_profiles(id),
  rating      INT         NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (session_id, student_id)
);

-- ============================================================
-- VIEW: teachers_view  (for Flutter student home screen)
-- ============================================================
CREATE OR REPLACE VIEW teachers_view AS
SELECT
  p.id,
  p.full_name   AS name,
  p.avatar_url,
  p.city,
  p.is_active   AS is_online,
  tp.bio,
  tp.subjects,
  tp.subjects[1] AS subject,
  tp.price_per_hour,
  tp.years_experience,
  tp.is_approved,
  tp.is_verified,
  tp.rating,
  tp.review_count,
  tp.total_sessions,
  tp.attendance_rate
FROM profiles p
JOIN teacher_profiles tp ON tp.id = p.id
WHERE p.role = 'teacher';

-- Grant read access to the view for all authenticated/anon users
GRANT SELECT ON public.teachers_view TO anon;
GRANT SELECT ON public.teachers_view TO authenticated;

-- ============================================================
-- TRIGGERS — updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_sessions_updated_at    BEFORE UPDATE ON sessions           FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_payments_updated_at    BEFORE UPDATE ON payments           FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_profiles_updated_at    BEFORE UPDATE ON profiles           FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_teachers_updated_at    BEFORE UPDATE ON teacher_profiles   FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_disputes_updated_at    BEFORE UPDATE ON disputes           FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- TRIGGER — create profile on signup
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO profiles (id, full_name, role, phone)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'مستخدم جديد'),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student'),
    NEW.raw_user_meta_data->>'phone'
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- TRIGGER — update teacher rating after review
-- ============================================================
CREATE OR REPLACE FUNCTION update_teacher_rating()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE teacher_profiles SET
    rating       = (SELECT ROUND(AVG(rating)::NUMERIC, 2) FROM reviews WHERE teacher_id = NEW.teacher_id),
    review_count = (SELECT COUNT(*)                       FROM reviews WHERE teacher_id = NEW.teacher_id),
    total_sessions = (SELECT COUNT(*) FROM sessions WHERE teacher_id = NEW.teacher_id AND state = 'COMPLETED')
  WHERE id = NEW.teacher_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_teacher_rating
  AFTER INSERT OR UPDATE ON reviews
  FOR EACH ROW EXECUTE FUNCTION update_teacher_rating();

-- ============================================================
-- TRIGGER — state machine: auto-advance + create notifications
-- ============================================================
CREATE OR REPLACE FUNCTION on_session_state_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_timeout     INT;
  v_student_id  UUID := NEW.student_id;
  v_teacher_id  UUID := NEW.teacher_id;
  v_session_id  UUID := NEW.id;
BEGIN
  IF OLD.state = NEW.state THEN RETURN NEW; END IF;

  -- Log the transition
  INSERT INTO session_events (session_id, event_type, actor, metadata)
  VALUES (v_session_id, NEW.state::TEXT, 'system',
          jsonb_build_object('from', OLD.state, 'to', NEW.state));

  CASE NEW.state

    -- Teacher approved → auto-move to AWAITING_PAYMENT + set deadline
    WHEN 'TEACHER_APPROVED' THEN
      SELECT (value::TEXT::NUMERIC)::INT INTO v_timeout
      FROM system_settings WHERE key = 'payment_timeout_minutes';

      NEW.state            := 'AWAITING_PAYMENT';
      NEW.payment_deadline := now() + make_interval(mins => v_timeout);

      -- Notify student
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
              'وافق الأستاذ على طلبك 🎉',
              'لديك ' || v_timeout || ' دقيقة لإرسال إثبات الدفع',
              'session_approved', v_session_id);

    -- Payment submitted → notify admin
    WHEN 'PAYMENT_SUBMITTED' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      SELECT p.id, 'دفعة جديدة بانتظار تأكيدك', 'مراجعة إثبات الدفع وتأكيده', 'payment_submitted', v_session_id
      FROM profiles p WHERE p.role = 'admin';

    -- Admin confirmed payment → auto-move to CONFIRMED_BOOKING
    WHEN 'PAYMENT_CONFIRMED' THEN
      NEW.state := 'CONFIRMED_BOOKING';

      -- Notify student + teacher
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id, 'تم تأكيد حجزك ✅', 'جلستك مؤكّدة. احضر في الموعد.', 'payment_confirmed', v_session_id),
        (v_teacher_id, 'حجز مؤكّد جديد',   'طالب أكّد حجزه معك.',              'payment_confirmed', v_session_id);

      -- Record ledger entry
      INSERT INTO ledger_entries (session_id, student_id, teacher_id, type, amount, commission, net_amount, description)
      VALUES (v_session_id, v_student_id, v_teacher_id,
              'session_payment', NEW.amount, NEW.amount * 0.15, NEW.amount * 0.85,
              'دفعة جلسة مؤكّدة');

    -- Session started
    WHEN 'ACTIVE_SESSION' THEN
      NEW.started_at := now();
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id, 'جلستك بدأت الآن', 'ادخل الغرفة الآن', 'session_started', v_session_id),
        (v_teacher_id, 'الجلسة بدأت', 'طالبك في انتظارك', 'session_started', v_session_id);

    -- Session completed
    WHEN 'COMPLETED' THEN
      NEW.ended_at := now();
      UPDATE teacher_profiles SET total_sessions = total_sessions + 1 WHERE id = v_teacher_id;

    -- Teacher no-show
    WHEN 'TEACHER_NO_SHOW' THEN
      NEW.ended_at := now();
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id, 'الأستاذ لم يحضر', 'سيتم إعادة الجدولة تلقائياً', 'teacher_no_show', v_session_id);

    -- Dispute opened
    WHEN 'DISPUTE' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      SELECT p.id, 'نزاع جديد #' || v_session_id, 'يحتاج مراجعة فورية', 'dispute_opened', v_session_id
      FROM profiles p WHERE p.role = 'admin';

    -- Teacher rejected
    WHEN 'TEACHER_REJECTED' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id, 'اعتذر الأستاذ عن طلبك', COALESCE(NEW.rejection_reason, 'يمكنك تجربة أستاذ آخر'), 'session_rejected', v_session_id);

    ELSE NULL;
  END CASE;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_session_state
  BEFORE UPDATE ON sessions
  FOR EACH ROW EXECUTE FUNCTION on_session_state_change();

-- ============================================================
-- FUNCTION — expire overdue payment requests (call via cron)
-- ============================================================
CREATE OR REPLACE FUNCTION expire_overdue_payments()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count INT;
BEGIN
  UPDATE sessions
  SET state = 'CANCELLED'
  WHERE state = 'AWAITING_PAYMENT'
    AND payment_deadline < now();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ============================================================
-- FUNCTION — detect teacher no-show (call via cron)
-- ============================================================
CREATE OR REPLACE FUNCTION detect_no_shows()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count    INT := 0;
  v_timeout  INT;
BEGIN
  SELECT (value::TEXT::NUMERIC)::INT INTO v_timeout
  FROM system_settings WHERE key = 'no_show_timeout_minutes';

  -- Teacher no-show
  UPDATE sessions
  SET state = 'TEACHER_NO_SHOW'
  WHERE state = 'CONFIRMED_BOOKING'
    AND scheduled_at + make_interval(mins => v_timeout) < now()
    AND started_at IS NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  -- Student no-show (teacher already started = ACTIVE_SESSION but student never joined)
  -- In current design, this is handled at the app level via TeacherNoShowScreen.

  RETURN v_count;
END;
$$;

-- ============================================================
-- FUNCTION — confirm payment (called by admin)
-- ============================================================
CREATE OR REPLACE FUNCTION admin_confirm_payment(
  p_payment_id UUID,
  p_admin_id   UUID,
  p_note       TEXT DEFAULT NULL
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_session_id UUID;
BEGIN
  -- Update payment
  UPDATE payments
  SET status       = 'confirmed',
      confirmed_by = p_admin_id,
      confirmed_at = now(),
      notes        = p_note
  WHERE id = p_payment_id
  RETURNING session_id INTO v_session_id;

  -- Advance session state (triggers the on_session_state_change)
  UPDATE sessions SET state = 'PAYMENT_CONFIRMED' WHERE id = v_session_id;
END;
$$;

-- ============================================================
-- FUNCTION — reject payment (called by admin)
-- ============================================================
CREATE OR REPLACE FUNCTION admin_reject_payment(
  p_payment_id  UUID,
  p_admin_id    UUID,
  p_reason      TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_session_id UUID;
BEGIN
  UPDATE payments
  SET status       = 'rejected',
      confirmed_by = p_admin_id,
      confirmed_at = now(),
      reject_reason = p_reason
  WHERE id = p_payment_id
  RETURNING session_id INTO v_session_id;

  -- Return session to AWAITING_PAYMENT so student can resubmit
  UPDATE sessions
  SET state = 'AWAITING_PAYMENT'
  WHERE id = v_session_id;

  -- Notify student
  INSERT INTO notifications (user_id, title, body, type, session_id)
  SELECT student_id, 'تم رفض إثبات الدفع', p_reason, 'payment_rejected', v_session_id
  FROM sessions WHERE id = v_session_id;
END;
$$;

-- ============================================================
-- FUNCTION — teacher approves session request
-- ============================================================
CREATE OR REPLACE FUNCTION teacher_approve_session(
  p_session_id UUID,
  p_teacher_id UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE sessions
  SET state = 'TEACHER_APPROVED'
  WHERE id = p_session_id
    AND teacher_id = p_teacher_id
    AND state = 'REQUESTED';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الجلسة غير موجودة أو لم تعد في حالة REQUESTED';
  END IF;
END;
$$;

-- ============================================================
-- FUNCTION — teacher rejects session request
-- ============================================================
CREATE OR REPLACE FUNCTION teacher_reject_session(
  p_session_id     UUID,
  p_teacher_id     UUID,
  p_reject_reason  TEXT DEFAULT NULL
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE sessions
  SET state            = 'TEACHER_REJECTED',
      rejection_reason = p_reject_reason
  WHERE id = p_session_id
    AND teacher_id = p_teacher_id
    AND state = 'REQUESTED';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الجلسة غير موجودة أو لا يمكن رفضها الآن';
  END IF;
END;
$$;

-- ============================================================
-- FUNCTION — open dispute
-- ============================================================
CREATE OR REPLACE FUNCTION open_dispute(
  p_session_id  UUID,
  p_opened_by   UUID,
  p_reason      TEXT,
  p_statement   TEXT
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_dispute_id  UUID;
  v_amount      NUMERIC;
  v_is_student  BOOLEAN;
BEGIN
  SELECT amount, (student_id = p_opened_by) INTO v_amount, v_is_student
  FROM sessions WHERE id = p_session_id;

  INSERT INTO disputes (session_id, opened_by, reason, frozen_amount)
  VALUES (p_session_id, p_opened_by, p_reason, v_amount)
  RETURNING id INTO v_dispute_id;

  IF v_is_student THEN
    UPDATE disputes SET student_statement = p_statement WHERE id = v_dispute_id;
  ELSE
    UPDATE disputes SET teacher_statement = p_statement WHERE id = v_dispute_id;
  END IF;

  UPDATE sessions SET state = 'DISPUTE' WHERE id = p_session_id;

  RETURN v_dispute_id;
END;
$$;
