-- ══════════════════════════════════════════════════════════════════
-- Notifications Cleanup — Final
-- Run in Supabase Dashboard → SQL Editor AFTER fix_cancellation_system.sql
-- ══════════════════════════════════════════════════════════════════
-- Changes:
--   1. ACTIVE_SESSION: remove teacher push (teacher opened the room himself)
--   2. COMPLETED: add teacher notification "اكتملت الجلسة ✅"
--   3. CANCELLED fake_proof / insufficient_refund: trigger handles notification
--      (removed from admin_reject_payment to avoid duplicates)
--   4. admin_reject_payment: immediate cancel + reason-specific notification
--      (no more "لديك ساعة لإعادة رفع الإثبات" — rejection is now final)
-- ══════════════════════════════════════════════════════════════════

-- ── 1. Updated on_session_state_change ─────────────────────────
CREATE OR REPLACE FUNCTION on_session_state_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_commission_pct NUMERIC := 0.15;
  v_student_id     UUID := NEW.student_id;
  v_teacher_id     UUID := NEW.teacher_id;
  v_session_id     UUID := NEW.id;
BEGIN
  IF OLD.state = NEW.state THEN RETURN NEW; END IF;

  INSERT INTO session_events (session_id, event_type, actor, metadata)
  VALUES (v_session_id, NEW.state::TEXT, 'system',
          jsonb_build_object('from', OLD.state, 'to', NEW.state));

  CASE NEW.state

    -- Teacher approved → AWAITING_PAYMENT (1-hour deadline)
    WHEN 'TEACHER_APPROVED' THEN
      NEW.state            := 'AWAITING_PAYMENT';
      NEW.payment_deadline := now() + interval '1 hour';
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
              'وافق الأستاذ على طلبك 🎉',
              'لديك ساعة واحدة لإرسال إثبات الدفع',
              'session_approved', v_session_id);

    -- Admin confirmed → CONFIRMED_BOOKING + ledger
    WHEN 'PAYMENT_CONFIRMED' THEN
      SELECT (value::TEXT::NUMERIC) / 100.0 INTO v_commission_pct
      FROM system_settings WHERE key = 'session_commission_pct';
      v_commission_pct := COALESCE(v_commission_pct, 0.15);
      NEW.state := 'CONFIRMED_BOOKING';
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id, 'تم تأكيد حجزك ✅',  'جلستك مؤكّدة. احضر في الموعد.',       'payment_confirmed', v_session_id),
        (v_teacher_id, 'حجز مؤكّد جديد',    'طالب أكّد حجزه معك — استعد للجلسة.', 'payment_confirmed', v_session_id);
      INSERT INTO ledger_entries
        (session_id, student_id, teacher_id, type, amount, commission, net_amount, description)
      VALUES
        (v_session_id, v_student_id, v_teacher_id,
         'session_payment', NEW.amount,
         NEW.amount * v_commission_pct,
         NEW.amount * (1.0 - v_commission_pct),
         'دفعة جلسة مؤكّدة');

    -- Teacher opened the room → only student needs a push
    -- (teacher is already in the room — no point notifying him)
    WHEN 'ACTIVE_SESSION' THEN
      NEW.started_at := now();
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
              'جلستك بدأت الآن 📚',
              'الأستاذ في انتظارك — ادخل الغرفة الآن.',
              'session_started', v_session_id);

    -- Session completed
    WHEN 'COMPLETED' THEN
      NEW.ended_at := now();
      UPDATE teacher_profiles SET total_sessions = total_sessions + 1 WHERE id = v_teacher_id;
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id, 'اكتملت جلستك ⭐',  'كيف كانت تجربتك؟ قيّم أستاذك الآن.', 'session_completed', v_session_id),
        (v_teacher_id, 'اكتملت الجلسة ✅', 'أُضيفت الجلسة إلى سجلك وأرباحك.',    'session_completed', v_session_id);

    -- Teacher rejected the student request
    WHEN 'TEACHER_REJECTED' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
              'اعتذر الأستاذ عن طلبك',
              COALESCE(NEW.rejection_reason, 'يمكنك تجربة أستاذ آخر'),
              'session_rejected', v_session_id);

    -- Session cancelled — reason-specific messages
    WHEN 'CANCELLED' THEN
      NEW.ended_at := now();
      CASE

        WHEN NEW.cancellation_reason = 'student_cancelled' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES
            (v_teacher_id, 'ألغى الطالب الجلسة',
             'قام الطالب بإلغاء هذا الحجز.',
             'session_cancelled', v_session_id),
            (v_student_id, 'تم إلغاء جلستك',
             'لقد ألغيت هذه الجلسة بنجاح.',
             'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason = 'teacher_timeout' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES
            (v_student_id, 'انتهت مهلة رد الأستاذ',
             'لم يرد الأستاذ في الوقت المحدد. يمكنك تجربة أستاذ آخر.',
             'session_cancelled', v_session_id),
            (v_teacher_id, 'طلب جلسة انتهت مهلته',
             'لم تردّ على طلب جلسة في الوقت المحدد وأُلغي تلقائياً.',
             'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason = 'payment_timeout' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES
            (v_student_id, 'انتهت مهلة الدفع — إلغاء تلقائي',
             'لم يُرسل إثبات الدفع في الوقت المحدد فأُلغيت الجلسة.',
             'session_cancelled', v_session_id),
            (v_teacher_id, 'إلغاء — لم يكتمل الدفع',
             'لم يُكمل الطالب الدفع في الوقت المحدد.',
             'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason = 'fake_proof' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES (v_student_id,
                  'رُفض حجزك نهائياً 🚫',
                  'الوصل المُرفَق غير حقيقي. تم إلغاء الجلسة ولن يُرد المبلغ.',
                  'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason = 'insufficient_refund' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES (v_student_id,
                  'تم إلغاء الجلسة وسيُسترد مبلغك 💰',
                  'المبلغ المُرسَل أقل من المطلوب، سيُسترد مبلغك قريباً.',
                  'session_cancelled', v_session_id);

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

-- ── 2. Updated admin_reject_payment ────────────────────────────
-- Rejection is final (no PAYMENT_REJECTED retry state).
-- Sets session to CANCELLED immediately and lets the trigger send
-- the right notification based on cancellation_reason.
CREATE OR REPLACE FUNCTION admin_reject_payment(
  p_payment_id  UUID,
  p_admin_id    UUID,
  p_reason      TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_session_id    UUID;
  v_reason_upper  TEXT := UPPER(TRIM(COALESCE(p_reason, '')));
  v_cancel_reason TEXT;
BEGIN
  -- Mark payment as rejected
  UPDATE payments
  SET status       = 'rejected',
      confirmed_by = p_admin_id,
      confirmed_at = now(),
      reject_reason = p_reason
  WHERE id = p_payment_id
  RETURNING session_id INTO v_session_id;

  IF v_session_id IS NULL THEN
    RAISE EXCEPTION 'Payment % not found', p_payment_id;
  END IF;

  -- Map reason string → cancellation_reason
  v_cancel_reason := CASE v_reason_upper
    WHEN 'FAKE_PROOF'         THEN 'fake_proof'
    WHEN 'INCOMPLETE_AMOUNT'  THEN 'insufficient_refund'
    ELSE                           'payment_rejected'
  END;

  -- Cancel immediately — no retry window
  -- on_session_state_change trigger fires and sends the right notification
  UPDATE sessions
  SET state               = 'CANCELLED',
      cancellation_reason = v_cancel_reason,
      ended_at            = now()
  WHERE id = v_session_id;

  -- Timeline event
  INSERT INTO session_events (session_id, event_type, actor, note)
  VALUES (v_session_id, 'PAYMENT_REJECTED', 'admin', p_reason);
END;
$$;

-- ── 3. Remove duplicate admin-payment trigger ───────────────────
-- admin_notifications.sql created trg_notify_admin_payment_submitted
-- which sends "إثبات دفع جديد" to admins.
-- payments also have trg_notify_admin_payment_submitted from admin_notifications.sql.
-- That trigger fires on INSERT to payments WHERE status='submitted'.
-- Keep that one (it's the admin panel notification).
-- on_session_state_change no longer has a PAYMENT_SUBMITTED case → no duplicate.
-- Nothing to drop here — already clean.
