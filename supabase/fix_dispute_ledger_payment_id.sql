-- ══════════════════════════════════════════════════════════════════
-- FIX COMPLETE: ledger_entries + dispute filter + commission sync
-- Run ONCE in Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- ── 1. Recreate trigger with payment_id + dynamic commission ─────
CREATE OR REPLACE FUNCTION public.on_session_state_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_timeout     INT;
  v_comm_rate   NUMERIC;
  v_student_id  UUID := NEW.student_id;
  v_teacher_id  UUID := NEW.teacher_id;
  v_session_id  UUID := NEW.id;
  v_payment_id  UUID;
BEGIN
  IF OLD.state = NEW.state THEN RETURN NEW; END IF;

  INSERT INTO session_events (session_id, event_type, actor, metadata)
  VALUES (v_session_id, NEW.state::TEXT, 'system',
          jsonb_build_object('from', OLD.state, 'to', NEW.state));

  CASE NEW.state

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

    WHEN 'PAYMENT_SUBMITTED' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      SELECT p.id, 'دفعة جديدة بانتظار تأكيدك', 'مراجعة إثبات الدفع وتأكيده', 'payment_submitted', v_session_id
      FROM profiles p WHERE p.role = 'admin';

    WHEN 'PAYMENT_CONFIRMED' THEN
      NEW.state := 'CONFIRMED_BOOKING';

      -- Dynamic commission from system_settings (default 15%)
      SELECT COALESCE((value::TEXT)::NUMERIC, 15) / 100.0 INTO v_comm_rate
      FROM system_settings WHERE key = 'session_commission_pct';
      v_comm_rate := COALESCE(v_comm_rate, 0.15);

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id, 'تم تأكيد حجزك ✅', 'جلستك مؤكّدة. احضر في الموعد.', 'payment_confirmed', v_session_id),
        (v_teacher_id, 'حجز مؤكّد جديد',   'طالب أكّد حجزه معك.',              'payment_confirmed', v_session_id);

      -- Get the confirmed payment_id so dispute filters work
      SELECT id INTO v_payment_id
      FROM payments
      WHERE session_id = v_session_id AND status = 'confirmed'
      ORDER BY confirmed_at DESC NULLS LAST
      LIMIT 1;

      INSERT INTO ledger_entries (payment_id, session_id, student_id, teacher_id, type, amount, commission, net_amount, description)
      VALUES (v_payment_id, v_session_id, v_student_id, v_teacher_id,
              'session_payment',
              NEW.amount,
              ROUND(NEW.amount * v_comm_rate, 2),
              ROUND(NEW.amount * (1 - v_comm_rate), 2),
              'دفعة جلسة مؤكّدة');

    WHEN 'ACTIVE_SESSION' THEN
      NEW.started_at := now();
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id, 'جلستك بدأت الآن', 'ادخل الغرفة الآن', 'session_started', v_session_id),
        (v_teacher_id, 'الجلسة بدأت', 'طالبك في انتظارك', 'session_started', v_session_id);

    WHEN 'COMPLETED' THEN
      NEW.ended_at := now();
      UPDATE teacher_profiles SET total_sessions = total_sessions + 1 WHERE id = v_teacher_id;

    WHEN 'TEACHER_NO_SHOW' THEN
      NEW.ended_at := now();
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id, 'الأستاذ لم يحضر', 'سيتم إعادة الجدولة تلقائياً', 'teacher_no_show', v_session_id);

    WHEN 'DISPUTE' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      SELECT p.id, 'نزاع جديد #' || v_session_id, 'يحتاج مراجعة فورية', 'dispute_opened', v_session_id
      FROM profiles p WHERE p.role = 'admin';

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

-- ── 2. Backfill payment_id on existing session_payment entries ───
UPDATE public.ledger_entries le
SET payment_id = (
  SELECT p.id
  FROM public.payments p
  WHERE p.session_id = le.session_id
    AND p.status = 'confirmed'
  ORDER BY p.confirmed_at DESC NULLS LAST
  LIMIT 1
)
WHERE le.type = 'session_payment'
  AND le.payment_id IS NULL;

-- ── 3. Sync commission on existing entries to match system_settings ─
-- Fixes the discrepancy between Admin Accounting and Teacher dashboard
UPDATE public.ledger_entries le
SET commission = ROUND(le.amount * (s.value::NUMERIC / 100), 2),
    net_amount = ROUND(le.amount * (1 - s.value::NUMERIC / 100), 2)
FROM public.system_settings s
WHERE s.key = 'session_commission_pct'
  AND le.type = 'session_payment';
