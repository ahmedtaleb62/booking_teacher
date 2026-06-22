-- ============================================================
-- Student No-Show Auto-Detection Migration
-- Run AFTER schema.sql, rls.sql, and cron.sql
-- ============================================================

-- 1. Add student_joined_at column to sessions
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS student_joined_at TIMESTAMPTZ;

-- Index used by the cron job (only active sessions matter)
CREATE INDEX IF NOT EXISTS idx_sessions_student_joined
  ON public.sessions (started_at)
  WHERE state = 'ACTIVE_SESSION' AND student_joined_at IS NULL;

-- ============================================================
-- 2. Replace detect_no_shows() — adds student no-show branch
-- ============================================================
CREATE OR REPLACE FUNCTION detect_no_shows()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count    INT := 0;
  v_timeout  INT;
  rec        RECORD;
BEGIN
  SELECT (value::TEXT::NUMERIC)::INT INTO v_timeout
  FROM system_settings WHERE key = 'no_show_timeout_minutes';

  -- ── Teacher no-show ────────────────────────────────────────
  -- CONFIRMED_BOOKING + 15 min past scheduled_at + never started
  FOR rec IN
    SELECT id FROM sessions
    WHERE state = 'CONFIRMED_BOOKING'
      AND scheduled_at + make_interval(mins => v_timeout) < now()
      AND started_at IS NULL
  LOOP
    UPDATE sessions SET state = 'TEACHER_NO_SHOW' WHERE id = rec.id;
    v_count := v_count + 1;
  END LOOP;

  -- ── Student no-show ────────────────────────────────────────
  -- ACTIVE_SESSION + 15 min past started_at + student never joined
  FOR rec IN
    SELECT id FROM sessions
    WHERE state = 'ACTIVE_SESSION'
      AND started_at + make_interval(mins => v_timeout) < now()
      AND student_joined_at IS NULL
  LOOP
    UPDATE sessions SET state = 'STUDENT_NO_SHOW' WHERE id = rec.id;
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- ============================================================
-- 3. Replace on_session_state_change() — adds STUDENT_NO_SHOW
--    and improves ACTIVE_SESSION notification
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

  -- Immutable audit log for every transition
  INSERT INTO session_events (session_id, event_type, actor, metadata)
  VALUES (v_session_id, NEW.state::TEXT, 'system',
          jsonb_build_object('from', OLD.state, 'to', NEW.state));

  CASE NEW.state

    -- Teacher approved → auto-advance to AWAITING_PAYMENT + set deadline
    WHEN 'TEACHER_APPROVED' THEN
      SELECT (value::TEXT::NUMERIC)::INT INTO v_timeout
      FROM system_settings WHERE key = 'payment_timeout_minutes';

      NEW.state            := 'AWAITING_PAYMENT';
      NEW.payment_deadline := now() + make_interval(mins => v_timeout);

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
              'وافق الأستاذ على طلبك 🎉',
              'لديك ' || v_timeout || ' دقيقة لإرسال إثبات الدفع',
              'session_approved', v_session_id);

    -- Payment submitted → notify admins
    WHEN 'PAYMENT_SUBMITTED' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      SELECT p.id,
             'دفعة جديدة بانتظار تأكيدك',
             'مراجعة إثبات الدفع وتأكيده',
             'payment_submitted',
             v_session_id
      FROM profiles p WHERE p.role = 'admin';

    -- Admin confirmed payment → auto-advance to CONFIRMED_BOOKING
    WHEN 'PAYMENT_CONFIRMED' THEN
      NEW.state := 'CONFIRMED_BOOKING';

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id, 'تم تأكيد حجزك ✅', 'جلستك مؤكّدة. احضر في الموعد.',  'payment_confirmed', v_session_id),
        (v_teacher_id, 'حجز مؤكّد جديد',   'طالب أكّد حجزه معك.',             'payment_confirmed', v_session_id);

      INSERT INTO ledger_entries
        (session_id, student_id, teacher_id, type, amount, commission, net_amount, description)
      VALUES
        (v_session_id, v_student_id, v_teacher_id,
         'session_payment', NEW.amount, NEW.amount * 0.15, NEW.amount * 0.85,
         'دفعة جلسة مؤكّدة');

    -- Teacher opened the room → session is now live
    -- Student has no_show_timeout_minutes to join before STUDENT_NO_SHOW fires
    WHEN 'ACTIVE_SESSION' THEN
      NEW.started_at := now();

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id, 'جلستك بدأت الآن 📚',
         'الأستاذ في انتظارك — ادخل الغرفة الآن.',
         'session_started', v_session_id),
        (v_teacher_id, 'الجلسة بدأت',
         'الطالب سيدخل قريباً.',
         'session_started', v_session_id);

    -- Session completed normally
    WHEN 'COMPLETED' THEN
      NEW.ended_at := now();
      UPDATE teacher_profiles
         SET total_sessions = total_sessions + 1
       WHERE id = v_teacher_id;

    -- Teacher didn't show → reschedule with same payment (student notified)
    WHEN 'TEACHER_NO_SHOW' THEN
      NEW.ended_at := now();

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id,
         'الأستاذ لم يحضر',
         'يمكنك إعادة الجدولة مجاناً بنفس الدفعة.',
         'teacher_no_show', v_session_id),
        (v_teacher_id,
         'تم تسجيل غيابك',
         'سيتم إشعار الإدارة. يرجى التواصل مع الطالب.',
         'teacher_no_show', v_session_id);

    -- Student didn't join within 15 min → teacher keeps full earnings
    WHEN 'STUDENT_NO_SHOW' THEN
      NEW.ended_at := now();

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_teacher_id,
         'الطالب لم يحضر ✅',
         'أجرك محفوظ كاملاً وفق سياسة الغياب.',
         'student_no_show', v_session_id),
        (v_student_id,
         'غبت عن الجلسة',
         'لن يتم استرداد المبلغ وفق سياسة الغياب.',
         'student_no_show', v_session_id);

    -- Dispute opened
    WHEN 'DISPUTE' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      SELECT p.id,
             'نزاع جديد #' || LEFT(v_session_id::TEXT, 8),
             'يحتاج مراجعة فورية',
             'dispute_opened',
             v_session_id
      FROM profiles p WHERE p.role = 'admin';

    -- Teacher rejected the request
    WHEN 'TEACHER_REJECTED' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
              'اعتذر الأستاذ عن طلبك',
              COALESCE(NEW.rejection_reason, 'يمكنك تجربة أستاذ آخر'),
              'session_rejected', v_session_id);

    ELSE NULL;
  END CASE;

  RETURN NEW;
END;
$$;

-- ============================================================
-- 4. RLS policy: student can record their own join timestamp
--    (state stays ACTIVE_SESSION — only student_joined_at changes)
-- ============================================================
DROP POLICY IF EXISTS "sessions_update_student_join" ON public.sessions;

CREATE POLICY "sessions_update_student_join"
  ON public.sessions FOR UPDATE
  USING  (auth.uid() = student_id AND state = 'ACTIVE_SESSION')
  WITH CHECK (state = 'ACTIVE_SESSION');  -- state must not change via this policy

-- ============================================================
-- Verify
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'sessions' AND column_name = 'student_joined_at';
-- ============================================================
