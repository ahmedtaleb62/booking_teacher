-- Extend admin_cancel_session with an optional refund. Mirrors the existing
-- admin_dispute_refund pattern (marks the confirmed payment
-- dispute_status='refunded' so it shows correctly in the admin Payments
-- page's "مسترد" section) and additionally reverses the teacher's earning
-- via an offsetting 'session_refund' ledger entry (admin_dispute_refund
-- doesn't do this because a disputed-but-still-COMPLETED session is already
-- excluded from the live Accounting recompute by dispute_status; a
-- CANCELLED session's original ledger credit needs an explicit reversal so
-- the teacher's lifetime ledger trace stays accurate).

CREATE OR REPLACE FUNCTION public.admin_cancel_session(
  p_session_id uuid,
  p_admin_id   uuid,
  p_refund     boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _sess        record;
  _payment_id  uuid;
  _commission  numeric;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT * INTO _sess FROM public.sessions WHERE id = p_session_id;
  IF _sess IS NULL THEN
    RAISE EXCEPTION 'session not found';
  END IF;
  IF _sess.state <> 'CONFIRMED_BOOKING' THEN
    RAISE EXCEPTION 'only a confirmed booking can be cancelled this way';
  END IF;

  UPDATE public.sessions
    SET state = 'CANCELLED', cancellation_reason = 'admin_cancelled'
  WHERE id = p_session_id;

  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES
    (_sess.student_id, 'تم إلغاء الجلسة من طرف الإدارة',
     'تم إلغاء جلستك المجدولة من قِبل الإدارة.', 'session_cancelled_admin', p_session_id),
    (_sess.teacher_id, 'تم إلغاء الجلسة من طرف الإدارة',
     'تم إلغاء الجلسة المجدولة مع طالبك من قِبل الإدارة.', 'session_cancelled_admin', p_session_id);

  IF NOT p_refund THEN
    RETURN;
  END IF;

  SELECT id INTO _payment_id
  FROM public.payments
  WHERE session_id = p_session_id AND status = 'confirmed'
  ORDER BY confirmed_at DESC NULLS LAST
  LIMIT 1;

  IF _payment_id IS NOT NULL THEN
    UPDATE public.payments
      SET dispute_status = 'refunded', dispute_refund_amount = _sess.amount, dispute_updated_at = NOW()
    WHERE id = _payment_id;
  END IF;

  IF _sess.teacher_net IS NOT NULL THEN
    _commission := _sess.amount - _sess.teacher_net;

    INSERT INTO public.ledger_entries
      (session_id, student_id, teacher_id, amount, commission, net_amount, type, description, created_at)
    VALUES
      (p_session_id, _sess.student_id, _sess.teacher_id,
       -_sess.amount, -_commission, -_sess.teacher_net,
       'session_refund', 'استرداد جلسة مُلغاة: ' || COALESCE(_sess.subject, ''), NOW());
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES
    (_sess.teacher_id,
     'استرداد مبلغ لطالب 💸',
     'تم إلغاء الجلسة واسترداد مبلغها للطالب، وتم خصمه من أرباحك.',
     'SESSION_REFUNDED_TEACHER', p_session_id),
    (_sess.student_id,
     'تم استرداد مبلغك 💰',
     'سيُسترد لك ' || _sess.amount::text || ' أوقية.',
     'SESSION_REFUNDED_STUDENT', p_session_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_cancel_session(uuid, uuid, boolean) TO authenticated;
