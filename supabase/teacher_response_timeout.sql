-- ============================================================
-- Teacher Response Timeout + Commission Fix Migration
-- Run in Supabase SQL Editor AFTER schema.sql and cron.sql
-- ============================================================

-- ============================================================
-- 1. expire_unanswered_requests()
--    Auto-cancels REQUESTED sessions whose teacher_response_hours
--    deadline (from system_settings) has passed.
--    Scheduled: every 5 minutes
-- ============================================================
CREATE OR REPLACE FUNCTION expire_unanswered_requests()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INT := 0;
  v_hours NUMERIC;
  rec     RECORD;
BEGIN
  SELECT (value::TEXT::NUMERIC) INTO v_hours
  FROM system_settings WHERE key = 'teacher_response_hours';
  v_hours := COALESCE(v_hours, 24);   -- default 24h if not set

  FOR rec IN
    SELECT id, student_id, teacher_id FROM sessions
    WHERE state = 'REQUESTED'
      AND created_at + make_interval(hours => v_hours::INT) < now()
  LOOP
    UPDATE sessions SET state = 'CANCELLED' WHERE id = rec.id;

    INSERT INTO notifications (user_id, title, body, type, session_id)
    VALUES (
      rec.student_id,
      'انتهت مهلة رد الأستاذ',
      'لم يرد الأستاذ في الوقت المحدد. يمكنك تجربة أستاذ آخر.',
      'session_cancelled',
      rec.id
    );

    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

-- Schedule (idempotent: remove old job if exists first)
DO $$ BEGIN PERFORM cron.unschedule('expire-unanswered-requests'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
SELECT cron.schedule(
  'expire-unanswered-requests',
  '*/5 * * * *',
  $$SELECT expire_unanswered_requests()$$
);

-- ============================================================
-- 2. detect_no_shows() — safe COALESCE default
--    Unchanged logic; just adds COALESCE(v_timeout, 15) so the
--    cron job keeps working if no_show_timeout_minutes is ever
--    removed from system_settings.
-- ============================================================
CREATE OR REPLACE FUNCTION detect_no_shows()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count   INT := 0;
  v_timeout INT;
  rec       RECORD;
BEGIN
  SELECT (value::TEXT::NUMERIC)::INT INTO v_timeout
  FROM system_settings WHERE key = 'no_show_timeout_minutes';
  v_timeout := COALESCE(v_timeout, 15);   -- default 15 min

  -- Teacher no-show: CONFIRMED_BOOKING + timeout past scheduled_at + never started
  FOR rec IN
    SELECT id FROM sessions
    WHERE state = 'CONFIRMED_BOOKING'
      AND scheduled_at + make_interval(mins => v_timeout) < now()
      AND started_at IS NULL
  LOOP
    UPDATE sessions SET state = 'TEACHER_NO_SHOW' WHERE id = rec.id;
    v_count := v_count + 1;
  END LOOP;

  -- Student no-show: ACTIVE_SESSION + timeout past started_at + student never joined
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
-- 3. on_session_state_change() — commission from system_settings
--    Replaces the hardcoded 0.15 with a live read of
--    session_commission_pct from system_settings.
--    All other cases are identical to student_no_show_migration.sql
-- ============================================================
CREATE OR REPLACE FUNCTION on_session_state_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_timeout        INT;
  v_commission_pct NUMERIC := 0.15;   -- fallback if key missing
  v_student_id     UUID := NEW.student_id;
  v_teacher_id     UUID := NEW.teacher_id;
  v_session_id     UUID := NEW.id;
BEGIN
  IF OLD.state = NEW.state THEN RETURN NEW; END IF;

  -- Audit log
  INSERT INTO session_events (session_id, event_type, actor, metadata)
  VALUES (v_session_id, NEW.state::TEXT, 'system',
          jsonb_build_object('from', OLD.state, 'to', NEW.state));

  CASE NEW.state

    -- Teacher approved → AWAITING_PAYMENT + set deadline from system_settings
    WHEN 'TEACHER_APPROVED' THEN
      SELECT (value::TEXT::NUMERIC)::INT INTO v_timeout
      FROM system_settings WHERE key = 'payment_timeout_minutes';
      v_timeout := COALESCE(v_timeout, 60);

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

    -- Admin confirmed → CONFIRMED_BOOKING + ledger with live commission
    WHEN 'PAYMENT_CONFIRMED' THEN
      -- Read commission rate from system_settings (default 15%)
      SELECT (value::TEXT::NUMERIC) / 100.0 INTO v_commission_pct
      FROM system_settings WHERE key = 'session_commission_pct';
      v_commission_pct := COALESCE(v_commission_pct, 0.15);

      NEW.state := 'CONFIRMED_BOOKING';

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id, 'تم تأكيد حجزك ✅', 'جلستك مؤكّدة. احضر في الموعد.',  'payment_confirmed', v_session_id),
        (v_teacher_id, 'حجز مؤكّد جديد',   'طالب أكّد حجزه معك.',             'payment_confirmed', v_session_id);

      INSERT INTO ledger_entries
        (session_id, student_id, teacher_id, type, amount, commission, net_amount, description)
      VALUES
        (v_session_id, v_student_id, v_teacher_id,
         'session_payment',
         NEW.amount,
         NEW.amount * v_commission_pct,
         NEW.amount * (1.0 - v_commission_pct),
         'دفعة جلسة مؤكّدة');

    -- Teacher opened room → session is live
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

    -- Teacher didn't show
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

    -- Student didn't join within timeout
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
-- 4. Ensure teacher_response_hours exists in system_settings
--    (safe: ON CONFLICT DO NOTHING keeps existing value)
-- ============================================================
INSERT INTO system_settings (key, value)
VALUES ('teacher_response_hours', '24')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- Verification queries (run separately to check)
-- ============================================================
-- SELECT * FROM cron.job ORDER BY jobname;
-- SELECT key, value FROM system_settings ORDER BY key;
-- SELECT expire_unanswered_requests();   -- test run (safe, returns count)
-- ============================================================
