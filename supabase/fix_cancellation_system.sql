-- ============================================================
-- Fix Cancellation Reason System
-- Run in Supabase SQL Editor AFTER all other migrations
-- ============================================================

-- 1. Remove obsolete cron jobs (no-show and dispute states no longer used)
DO $$ BEGIN PERFORM cron.unschedule('detect-no-shows');          EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('auto-open-payment-disputes'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- ============================================================
-- 2. expire_unanswered_requests
--    Sets cancellation_reason = 'teacher_timeout'
--    Notifications are now handled by on_session_state_change trigger
-- ============================================================
CREATE OR REPLACE FUNCTION expire_unanswered_requests()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INT := 0;
  rec     RECORD;
BEGIN
  FOR rec IN
    SELECT id FROM sessions
    WHERE state = 'REQUESTED'
      AND created_at + interval '1 hour' < now()
  LOOP
    UPDATE sessions
    SET state               = 'CANCELLED',
        cancellation_reason = 'teacher_timeout'
    WHERE id = rec.id;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

-- ============================================================
-- 3. expire_overdue_payments
--    Sets cancellation_reason per prior state
--    Notifications handled by trigger
-- ============================================================
CREATE OR REPLACE FUNCTION expire_overdue_payments()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count INT;
BEGIN
  UPDATE sessions
  SET state               = 'CANCELLED',
      cancellation_reason = CASE state
        WHEN 'AWAITING_PAYMENT' THEN 'payment_timeout'
        ELSE COALESCE(cancellation_reason, 'payment_timeout')
      END
  WHERE state IN ('AWAITING_PAYMENT', 'PAYMENT_REJECTED')
    AND payment_deadline IS NOT NULL
    AND payment_deadline < now();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ============================================================
-- 4. auto_cancel_rejected_payments
--    Sets cancellation_reason = 'payment_rejected'
--    Notifications handled by trigger
-- ============================================================
CREATE OR REPLACE FUNCTION auto_cancel_rejected_payments()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INT := 0;
  rec     RECORD;
BEGIN
  FOR rec IN
    SELECT id FROM sessions
    WHERE state = 'PAYMENT_REJECTED'
      AND payment_deadline IS NOT NULL
      AND payment_deadline < now()
  LOOP
    UPDATE sessions
    SET state               = 'CANCELLED',
        cancellation_reason = COALESCE(cancellation_reason, 'payment_rejected')
    WHERE id = rec.id;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

-- ============================================================
-- 5. on_session_state_change — full replacement adding CANCELLED case
-- ============================================================
CREATE OR REPLACE FUNCTION on_session_state_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_commission_pct NUMERIC := 0.15;
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

    -- Teacher approved → auto-advance to AWAITING_PAYMENT + set deadline (1 hour, fixed)
    WHEN 'TEACHER_APPROVED' THEN
      NEW.state            := 'AWAITING_PAYMENT';
      NEW.payment_deadline := now() + interval '1 hour';

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
              'وافق الأستاذ على طلبك 🎉',
              'لديك ساعة واحدة لإرسال إثبات الدفع',
              'session_approved', v_session_id);

    -- Payment submitted → notify_admin_on_payment_submitted trigger handles this (no duplicate needed)

    -- Admin confirmed → CONFIRMED_BOOKING + ledger + notify both
    WHEN 'PAYMENT_CONFIRMED' THEN
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

      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
              'اكتملت جلستك ⭐',
              'كيف كانت تجربتك؟ قيّم أستاذك الآن.',
              'session_completed', v_session_id);

    -- Teacher rejected the request
    WHEN 'TEACHER_REJECTED' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
              'اعتذر الأستاذ عن طلبك',
              COALESCE(NEW.rejection_reason, 'يمكنك تجربة أستاذ آخر'),
              'session_rejected', v_session_id);

    -- Session cancelled — send reason-specific notifications
    WHEN 'CANCELLED' THEN
      NEW.ended_at := now();

      CASE
        WHEN NEW.cancellation_reason = 'student_cancelled' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES
            (v_teacher_id,
             'ألغى الطالب الجلسة',
             'قام الطالب بإلغاء هذا الحجز.',
             'session_cancelled', v_session_id),
            (v_student_id,
             'تم إلغاء جلستك',
             'لقد ألغيت هذه الجلسة بنجاح.',
             'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason = 'teacher_timeout' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES
            (v_student_id,
             'انتهت مهلة رد الأستاذ',
             'لم يرد الأستاذ في الوقت المحدد. يمكنك تجربة أستاذ آخر.',
             'session_cancelled', v_session_id),
            (v_teacher_id,
             'طلب جلسة انتهت مهلته',
             'لم تردّ على طلب جلسة في الوقت المحدد وأُلغي تلقائياً.',
             'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason = 'payment_timeout' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES
            (v_student_id,
             'انتهت مهلة الدفع — إلغاء تلقائي',
             'لم يُرسل إثبات الدفع في الوقت المحدد فأُلغيت الجلسة.',
             'session_cancelled', v_session_id),
            (v_teacher_id,
             'إلغاء — لم يكتمل الدفع',
             'لم يُكمل الطالب الدفع في الوقت المحدد.',
             'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason IN ('fake_proof', 'insufficient_refund', 'payment_rejected') THEN
          NULL; -- admin_reject_payment() already sent notifications to both student and teacher

        ELSE
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES (v_student_id,
                  'الجلسة ملغاة',
                  'تم إلغاء هذه الجلسة.',
                  'session_cancelled', v_session_id);
      END CASE;

    ELSE NULL;
  END CASE;

  RETURN NEW;
END;
$$;
