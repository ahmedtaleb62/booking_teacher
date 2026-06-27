-- Simplified rejection logic — 2 outcomes only:
--   FAKE_PROOF       → session CANCELLED, no refund  (proof was fake, no real payment)
--   INCOMPLETE_AMOUNT → session CANCELLED + payment REFUNDED immediately (no deadline)

CREATE OR REPLACE FUNCTION public.admin_reject_payment(
  p_payment_id  UUID,
  p_admin_id    UUID,
  p_reason      TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_session_id UUID;
  v_student_id UUID;
  v_teacher_id UUID;
  v_is_fake    BOOLEAN;
BEGIN
  v_is_fake := upper(p_reason) = 'FAKE_PROOF';

  UPDATE public.payments
  SET status        = CASE WHEN v_is_fake THEN 'rejected' ELSE 'refunded' END,
      confirmed_by  = p_admin_id,
      confirmed_at  = now(),
      reject_reason = p_reason
  WHERE id = p_payment_id
  RETURNING session_id INTO v_session_id;

  IF v_session_id IS NULL THEN
    RAISE EXCEPTION 'payment % not found', p_payment_id;
  END IF;

  SELECT student_id, teacher_id INTO v_student_id, v_teacher_id
  FROM public.sessions WHERE id = v_session_id;

  -- Both cases cancel the session immediately
  UPDATE public.sessions
  SET state               = 'CANCELLED',
      cancellation_reason = CASE WHEN v_is_fake THEN 'fake_proof' ELSE 'insufficient_refund' END,
      rejection_reason    = p_reason,
      payment_deadline    = NULL,
      updated_at          = now()
  WHERE id = v_session_id;

  INSERT INTO public.session_events (session_id, event_type, actor, note)
  VALUES (v_session_id, 'PAYMENT_REJECTED', 'admin', p_reason);

  IF v_is_fake THEN
    -- Fake proof: no refund, student loses nothing (they never paid)
    INSERT INTO public.notifications (user_id, title, body, type, session_id)
    VALUES (
      v_student_id,
      'جلسة مرفوضة — الوصل مزيف',
      'رُفض إثبات دفعك لأنه غير حقيقي. تم إلغاء الحجز.',
      'payment_rejected',
      v_session_id
    );
  ELSE
    -- Incomplete amount: refund automatically
    INSERT INTO public.notifications (user_id, title, body, type, session_id)
    VALUES (
      v_student_id,
      'المبلغ المدفوع غير مكتمل — سيُسترد مبلغك',
      'المبلغ المدفوع أقل من المطلوب. تم إلغاء الحجز وسيُسترد مبلغك قريباً.',
      'payment_rejected',
      v_session_id
    );
  END IF;

  -- Teacher always gets "غياب الدفع"
  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES (
    v_teacher_id,
    'غياب الدفع',
    'لم يكتمل دفع الطالب. تم إلغاء هذا الحجز.',
    'payment_rejected',
    v_session_id
  );
END;
$$;
