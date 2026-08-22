-- Add public.log_admin_action(...) calls to every sensitive existing RPC.

CREATE OR REPLACE FUNCTION public.admin_delete_user(target_uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  _sess_ids uuid[];
  _target_name text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT full_name INTO _target_name FROM public.profiles WHERE id = target_uid;
  PERFORM public.log_admin_action(auth.uid(), 'delete_user', 'user', target_uid,
    jsonb_build_object('full_name', _target_name));

  SELECT array_agg(id) INTO _sess_ids
  FROM public.sessions WHERE student_id = target_uid OR teacher_id = target_uid;

  -- Ratings / reviews
  DELETE FROM public.reviews        WHERE student_id = target_uid OR teacher_id = target_uid;
  DELETE FROM public.course_ratings WHERE student_id = target_uid;

  -- Financial history
  DELETE FROM public.ledger_entries   WHERE student_id = target_uid OR teacher_id = target_uid;
  DELETE FROM public.teacher_earnings WHERE teacher_id = target_uid;
  UPDATE public.payments SET confirmed_by = NULL WHERE confirmed_by = target_uid;
  DELETE FROM public.payments WHERE student_id = target_uid;

  -- Disputes (opened_by is required on the row; resolved_by is just an audit field)
  DELETE FROM public.disputes WHERE opened_by = target_uid;
  UPDATE public.disputes SET resolved_by = NULL WHERE resolved_by = target_uid;

  -- Notifications / sessions referencing each other need clearing before
  -- the sessions themselves are dropped (notifications.session_id and
  -- sessions.parent_session_id both use ON DELETE NO ACTION).
  IF _sess_ids IS NOT NULL THEN
    DELETE FROM public.notifications WHERE session_id = ANY(_sess_ids);
    UPDATE public.sessions SET parent_session_id = NULL WHERE parent_session_id = ANY(_sess_ids);
  END IF;
  DELETE FROM public.notifications WHERE user_id = target_uid;

  -- actor_id on someone else's session (e.g. an admin acting on a session
  -- that isn't theirs) isn't covered by the sessions delete below.
  UPDATE public.session_events SET actor_id = NULL WHERE actor_id = target_uid;

  DELETE FROM public.device_tokens   WHERE user_id = target_uid;
  DELETE FROM public.lesson_progress WHERE student_id = target_uid;
  UPDATE public.system_settings SET updated_by = NULL WHERE updated_by = target_uid;

  -- Sessions (cascades: session_events, session_messages, remaining payments/disputes/reviews)
  DELETE FROM public.sessions WHERE student_id = target_uid OR teacher_id = target_uid;

  -- teacher_earnings.subscription_id can reference a subscription owned by
  -- a student while teacher_id belongs to someone else entirely.
  DELETE FROM public.teacher_earnings
  WHERE subscription_id IN (SELECT id FROM public.subscriptions WHERE student_id = target_uid);

  -- Subscriptions
  DELETE FROM public.subscriptions WHERE student_id = target_uid;

  -- Teacher-only data (cascades: teacher_availability)
  DELETE FROM public.teacher_profiles WHERE id = target_uid;

  -- Profile + auth account (courses.teacher_id auto SET NULL on this)
  DELETE FROM public.profiles WHERE id = target_uid;
  DELETE FROM auth.users      WHERE id = target_uid;
END;
$$;


CREATE OR REPLACE FUNCTION public.admin_freeze_payment(p_payment_id uuid, p_admin_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_amount NUMERIC; v_student_id UUID; v_teacher_id UUID; v_session_id UUID;
  v_sl TEXT; v_tl TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin')
  THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT p.amount, s.student_id, s.teacher_id, p.session_id
  INTO   v_amount, v_student_id, v_teacher_id, v_session_id
  FROM   public.payments p JOIN public.sessions s ON s.id = p.session_id
  WHERE  p.id = p_payment_id AND p.status = 'confirmed';
  IF NOT FOUND THEN RAISE EXCEPTION 'Payment not found or not confirmed'; END IF;

  UPDATE public.payments SET dispute_status = 'frozen', dispute_updated_at = NOW()
  WHERE id = p_payment_id;

  PERFORM public.log_admin_action(p_admin_id, 'freeze_payment', 'payment', p_payment_id,
    jsonb_build_object('amount', v_amount, 'session_id', v_session_id));

  v_sl := user_lang(v_student_id); v_tl := user_lang(v_teacher_id);

  INSERT INTO public.notifications (user_id, title, body, type, session_id) VALUES
    (v_teacher_id,
      CASE v_tl WHEN 'fr' THEN 'Montant de la session gelé ⚠' ELSE 'تم تجميد مبلغ الجلسة ⚠' END,
      CASE v_tl WHEN 'fr'
        THEN 'Le montant de ' || v_amount::INT || ' ouguiyas a été gelé suite à une réclamation.'
        ELSE 'تم تجميد مبلغ ' || v_amount::INT || ' أوقية بسبب شكوى من الطالب، جارٍ التحقيق.' END,
      'PAYMENT_FROZEN', v_session_id),
    (v_student_id,
      CASE v_sl WHEN 'fr' THEN 'Réclamation reçue ✅' ELSE 'تم استلام شكواك ✅' END,
      CASE v_sl WHEN 'fr'
        THEN 'Le montant de ' || v_amount::INT || ' ouguiyas a été gelé pour enquête.'
        ELSE 'تم تجميد مبلغك (' || v_amount::INT || ' أوقية) للتحقيق، وسيُسترد إن كنت صاحب الحق.' END,
      'PAYMENT_FROZEN_STUDENT', v_session_id);
END;
$$;


CREATE OR REPLACE FUNCTION public.admin_dispute_refund(p_payment_id uuid, p_admin_id uuid, p_refund_amount numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_amount NUMERIC; v_student_id UUID; v_teacher_id UUID; v_session_id UUID;
  v_sl TEXT; v_tl TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin')
  THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT p.amount, s.student_id, s.teacher_id, p.session_id
  INTO   v_amount, v_student_id, v_teacher_id, v_session_id
  FROM   public.payments p JOIN public.sessions s ON s.id = p.session_id
  WHERE  p.id = p_payment_id AND p.status = 'confirmed';
  IF NOT FOUND THEN RAISE EXCEPTION 'Payment not found or not confirmed'; END IF;

  UPDATE public.payments
  SET dispute_status = 'refunded', dispute_refund_amount = p_refund_amount, dispute_updated_at = NOW()
  WHERE id = p_payment_id;

  PERFORM public.log_admin_action(p_admin_id, 'dispute_refund', 'payment', p_payment_id,
    jsonb_build_object('refund_amount', p_refund_amount, 'session_id', v_session_id));

  v_sl := user_lang(v_student_id); v_tl := user_lang(v_teacher_id);

  INSERT INTO public.notifications (user_id, title, body, type, session_id) VALUES
    (v_teacher_id,
      CASE v_tl WHEN 'fr' THEN 'Montant remboursé à l''élève' ELSE 'تم استرداد مبلغ الجلسة للطالب' END,
      CASE v_tl WHEN 'fr'
        THEN 'Après enquête, ' || p_refund_amount::INT || ' ouguiyas ont été remboursés à l''élève.'
        ELSE 'بعد التحقيق، تقرر استرداد ' || p_refund_amount::INT || ' أوقية للطالب.' END,
      'DISPUTE_REFUNDED_TEACHER', v_session_id),
    (v_student_id,
      CASE v_sl WHEN 'fr' THEN 'Remboursement effectué ✅' ELSE 'تم استرداد مبلغك ✅' END,
      CASE v_sl WHEN 'fr'
        THEN 'Après enquête, ' || p_refund_amount::INT || ' ouguiyas vous seront remboursés prochainement.'
        ELSE 'بعد التحقيق، تقرر إعادة ' || p_refund_amount::INT || ' أوقية إليك. سيصلك المبلغ قريباً.' END,
      'DISPUTE_REFUNDED_STUDENT', v_session_id);
END;
$$;


CREATE OR REPLACE FUNCTION public.admin_confirm_after_dispute(p_payment_id uuid, p_admin_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_amount NUMERIC; v_student_id UUID; v_teacher_id UUID; v_session_id UUID;
  v_sl TEXT; v_tl TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin')
  THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT p.amount, s.student_id, s.teacher_id, p.session_id
  INTO   v_amount, v_student_id, v_teacher_id, v_session_id
  FROM   public.payments p JOIN public.sessions s ON s.id = p.session_id
  WHERE  p.id = p_payment_id AND p.status = 'confirmed';
  IF NOT FOUND THEN RAISE EXCEPTION 'Payment not found or not confirmed'; END IF;

  UPDATE public.payments SET dispute_status = 'confirmed', dispute_updated_at = NOW()
  WHERE id = p_payment_id;

  PERFORM public.log_admin_action(p_admin_id, 'confirm_teacher_after_dispute', 'payment', p_payment_id,
    jsonb_build_object('amount', v_amount, 'session_id', v_session_id));

  v_sl := user_lang(v_student_id); v_tl := user_lang(v_teacher_id);

  INSERT INTO public.notifications (user_id, title, body, type, session_id) VALUES
    (v_teacher_id,
      CASE v_tl WHEN 'fr' THEN 'Paiement confirmé en votre faveur ✅' ELSE 'تم تأكيد استحقاقك للمبلغ ✅' END,
      CASE v_tl WHEN 'fr'
        THEN 'Après enquête, les ' || v_amount::INT || ' ouguiyas vous reviennent de droit.'
        ELSE 'بعد التحقيق، تقررت الإدارة أن مبلغ ' || v_amount::INT || ' أوقية من حقك.' END,
      'DISPUTE_CONFIRMED_TEACHER', v_session_id),
    (v_student_id,
      CASE v_sl WHEN 'fr' THEN 'Résultat de votre réclamation' ELSE 'نتيجة التحقيق في شكواك' END,
      CASE v_sl WHEN 'fr'
        THEN 'Après enquête, le remboursement a été refusé. Contactez-nous via WhatsApp.'
        ELSE 'بعد التحقيق، قررت الإدارة عدم استرداد مبلغ الجلسة. للاستفسار تواصل معنا عبر واتساب.' END,
      'DISPUTE_CONFIRMED_STUDENT', v_session_id);
END;
$$;


CREATE OR REPLACE FUNCTION public.admin_settle_teacher(p_teacher_id uuid, p_amount numeric, p_description text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_lang TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  THEN RAISE EXCEPTION 'not authorized'; END IF;

  v_lang := user_lang(p_teacher_id);

  INSERT INTO public.ledger_entries
    (teacher_id, type, amount, commission, net_amount, description)
  VALUES (p_teacher_id, 'payout_sent', p_amount, 0, -p_amount, p_description);

  PERFORM public.log_admin_action(auth.uid(), 'settle_teacher', 'user', p_teacher_id,
    jsonb_build_object('amount', p_amount, 'description', p_description));

  INSERT INTO public.notifications (user_id, title, body, type)
  VALUES (p_teacher_id,
    CASE v_lang WHEN 'fr' THEN 'Paiement effectué 💰'
      ELSE 'تمت تسوية مستحقاتك 💰' END,
    CASE v_lang WHEN 'fr'
      THEN 'Vos gains de ' || p_amount::INT || ' ouguiyas ont été transférés — ' || p_description
      ELSE 'تم تحويل مستحقاتك البالغة ' || p_amount || ' أوقية — ' || p_description END,
    'payout_sent');
END;
$$;
