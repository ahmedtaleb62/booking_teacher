-- ============================================================
-- Payment Rejection Flow Migration
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. Add PAYMENT_REJECTED to session_state enum
ALTER TYPE session_state ADD VALUE IF NOT EXISTS 'PAYMENT_REJECTED';

-- 2. Update admin_reject_payment to use new state + 1-hour deadline
CREATE OR REPLACE FUNCTION admin_reject_payment(
  p_payment_id  UUID,
  p_admin_id    UUID,
  p_reason      TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_session_id UUID;
  v_student_id UUID;
BEGIN
  -- Mark the payment as rejected
  UPDATE payments
  SET status        = 'rejected',
      confirmed_by  = p_admin_id,
      confirmed_at  = now(),
      reject_reason = p_reason
  WHERE id = p_payment_id
  RETURNING session_id INTO v_session_id;

  SELECT student_id INTO v_student_id
  FROM sessions WHERE id = v_session_id;

  -- Move session to PAYMENT_REJECTED with 1-hour deadline
  UPDATE sessions
  SET state            = 'PAYMENT_REJECTED',
      payment_deadline = now() + interval '1 hour',
      rejection_reason = p_reason
  WHERE id = v_session_id;

  -- Timeline event
  INSERT INTO session_events (session_id, event_type, actor, note)
  VALUES (v_session_id, 'PAYMENT_REJECTED', 'admin', p_reason);

  -- Notify student
  INSERT INTO notifications (user_id, title, body, type, session_id)
  VALUES (
    v_student_id,
    'رُفض إثبات الدفع',
    p_reason || ' — لديك ساعة لإعادة رفع الإثبات.',
    'payment_rejected',
    v_session_id
  );
END;
$$;

-- 3. Update RLS: allow student to resubmit when PAYMENT_REJECTED
DROP POLICY IF EXISTS "sessions_update_student_payment_submit" ON sessions;
CREATE POLICY "sessions_update_student_payment_submit"
  ON sessions FOR UPDATE
  USING (
    auth.uid() = student_id
    AND state IN ('AWAITING_PAYMENT', 'PAYMENT_REJECTED')
  )
  WITH CHECK (state = 'PAYMENT_SUBMITTED');

-- 4. Auto-cancel function (already added in cron.sql — included here for reference)
-- SELECT cron.schedule('cancel-rejected-payments', '*/5 * * * *',
--   $$SELECT auto_cancel_rejected_payments()$$);
