-- ══════════════════════════════════════════════════════════════════
-- Fix: session_payment ledger uses dynamic commission from system_settings
-- Previously hardcoded at 15% — now reads session_commission_pct setting
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- Ensure the setting key exists with default 15%
INSERT INTO public.system_settings (key, value)
VALUES ('session_commission_pct', '15')
ON CONFLICT (key) DO NOTHING;

-- Recreate the session state trigger with dynamic commission
CREATE OR REPLACE FUNCTION public.on_session_state_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_timeout     INT;
  v_comm_rate   NUMERIC;
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
      NEW.payment_deadline := now() + make_interval(mins => COALESCE(v_timeout, 30));

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
              'وافق الأستاذ على طلبك 🎉',
              'لديك ' || COALESCE(v_timeout, 30) || ' دقيقة لإرسال إثبات الدفع',
              'session_approved', v_session_id);

    -- Payment submitted → notify admin
    WHEN 'PAYMENT_SUBMITTED' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      SELECT p.id, 'دفعة جديدة بانتظار تأكيدك', 'مراجعة إثبات الدفع وتأكيده', 'payment_submitted', v_session_id
      FROM profiles p WHERE p.role = 'admin';

    -- Admin confirmed payment → auto-move to CONFIRMED_BOOKING
    WHEN 'PAYMENT_CONFIRMED' THEN
      NEW.state := 'CONFIRMED_BOOKING';

      -- Read dynamic commission rate (stored as percentage e.g. 15 = 15%)
      SELECT COALESCE((value::TEXT)::NUMERIC, 15) / 100.0 INTO v_comm_rate
      FROM system_settings WHERE key = 'session_commission_pct';
      v_comm_rate := COALESCE(v_comm_rate, 0.15);

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id, 'تم تأكيد حجزك ✅', 'جلستك مؤكّدة. احضر في الموعد.', 'payment_confirmed', v_session_id),
        (v_teacher_id, 'حجز مؤكّد جديد',   'طالب أكّد حجزه معك.',              'payment_confirmed', v_session_id);

      INSERT INTO ledger_entries (session_id, student_id, teacher_id, type, amount, commission, net_amount, description)
      VALUES (v_session_id, v_student_id, v_teacher_id,
              'session_payment',
              NEW.amount,
              ROUND(NEW.amount * v_comm_rate, 2),
              ROUND(NEW.amount * (1 - v_comm_rate), 2),
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
      VALUES (v_student_id, 'اعتذر الأستاذ عن طلبك',
              COALESCE(NEW.rejection_reason, 'يمكنك تجربة أستاذ آخر'),
              'session_rejected', v_session_id);

    ELSE NULL;
  END CASE;

  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
