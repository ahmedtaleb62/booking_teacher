-- ══════════════════════════════════════════════════════════════════
-- Dispute System + Actual Refund Amount
-- Run in Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- ── 1. New columns on payments ──────────────────────────────────
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS dispute_status       TEXT    DEFAULT 'confirmed'
    CHECK (dispute_status IN ('confirmed', 'frozen', 'refunded')),
  ADD COLUMN IF NOT EXISTS dispute_refund_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS dispute_updated_at   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS actual_refund_amount  NUMERIC;  -- Problem 1: real refunded amount on rejection

-- ── 2. admin_freeze_payment ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_freeze_payment(
  p_payment_id UUID,
  p_admin_id   UUID
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_amount     NUMERIC;
  v_student_id UUID;
  v_teacher_id UUID;
  v_session_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin'
  ) THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT p.amount, s.student_id, s.teacher_id, p.session_id
  INTO   v_amount, v_student_id, v_teacher_id, v_session_id
  FROM   public.payments p
  JOIN   public.sessions s ON s.id = p.session_id
  WHERE  p.id = p_payment_id AND p.status = 'confirmed';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment not found or not in confirmed status';
  END IF;

  UPDATE public.payments
  SET dispute_status = 'frozen', dispute_updated_at = NOW()
  WHERE id = p_payment_id;

  -- Notify teacher
  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES (
    v_teacher_id,
    'تم تجميد مبلغ الجلسة ⚠',
    'تم تجميد مبلغ ' || v_amount::INT || ' أوقية بسبب شكوى من الطالب، جارٍ التحقيق.',
    'PAYMENT_FROZEN',
    v_session_id
  );

  -- Notify student (reassurance)
  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES (
    v_student_id,
    'تم استلام شكواك ✅',
    'نطمئنك أنه تم تجميد مبلغك (' || v_amount::INT || ' أوقية) للتحقيق، وسيُسترد إن كنت صاحب الحق.',
    'PAYMENT_FROZEN_STUDENT',
    v_session_id
  );
END;
$$;

-- ── 3. admin_dispute_refund ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_dispute_refund(
  p_payment_id    UUID,
  p_admin_id      UUID,
  p_refund_amount NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_amount     NUMERIC;
  v_student_id UUID;
  v_teacher_id UUID;
  v_session_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin'
  ) THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT p.amount, s.student_id, s.teacher_id, p.session_id
  INTO   v_amount, v_student_id, v_teacher_id, v_session_id
  FROM   public.payments p
  JOIN   public.sessions s ON s.id = p.session_id
  WHERE  p.id = p_payment_id AND p.status = 'confirmed';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment not found or not in confirmed status';
  END IF;

  UPDATE public.payments
  SET dispute_status        = 'refunded',
      dispute_refund_amount = p_refund_amount,
      dispute_updated_at    = NOW()
  WHERE id = p_payment_id;

  -- Notify teacher
  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES (
    v_teacher_id,
    'تم استرداد مبلغ الجلسة للطالب',
    'بعد التحقيق في الشكوى، تقرر استرداد ' || p_refund_amount::INT || ' أوقية للطالب.',
    'DISPUTE_REFUNDED_TEACHER',
    v_session_id
  );

  -- Notify student
  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES (
    v_student_id,
    'تم استرداد مبلغك ✅',
    'بعد التحقيق، تقرر إعادة ' || p_refund_amount::INT || ' أوقية إليك. سيصلك المبلغ قريباً.',
    'DISPUTE_REFUNDED_STUDENT',
    v_session_id
  );
END;
$$;

-- ── 4. admin_confirm_after_dispute ──────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_confirm_after_dispute(
  p_payment_id UUID,
  p_admin_id   UUID
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_amount     NUMERIC;
  v_student_id UUID;
  v_teacher_id UUID;
  v_session_id UUID;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin'
  ) THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT p.amount, s.student_id, s.teacher_id, p.session_id
  INTO   v_amount, v_student_id, v_teacher_id, v_session_id
  FROM   public.payments p
  JOIN   public.sessions s ON s.id = p.session_id
  WHERE  p.id = p_payment_id AND p.status = 'confirmed';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment not found or not in confirmed status';
  END IF;

  UPDATE public.payments
  SET dispute_status     = 'confirmed',
      dispute_updated_at = NOW()
  WHERE id = p_payment_id;

  -- Notify teacher (good news)
  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES (
    v_teacher_id,
    'تم تأكيد استحقاقك للمبلغ ✅',
    'بعد التحقيق في الشكوى، تقررت الإدارة أن مبلغ ' || v_amount::INT || ' أوقية من حقك.',
    'DISPUTE_CONFIRMED_TEACHER',
    v_session_id
  );

  -- Notify student (rejection of complaint)
  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES (
    v_student_id,
    'نتيجة التحقيق في شكواك',
    'بعد التحقيق، قررت الإدارة عدم استرداد مبلغ الجلسة. للاستفسار تواصل معنا عبر واتساب.',
    'DISPUTE_CONFIRMED_STUDENT',
    v_session_id
  );
END;
$$;

-- ── 5. Grant execute to authenticated ───────────────────────────
GRANT EXECUTE ON FUNCTION public.admin_freeze_payment       TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_dispute_refund       TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_confirm_after_dispute TO authenticated;
