-- Add audit logging to the newer session/subscription RPCs built this session.

-- Dead overload from an earlier iteration (before the p_refund parameter
-- was added) — the 3-arg version below is the only one the app calls.
DROP FUNCTION IF EXISTS public.admin_cancel_session(uuid, uuid);

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

  PERFORM public.log_admin_action(p_admin_id, 'cancel_session', 'session', p_session_id,
    jsonb_build_object('refund', p_refund, 'amount', _sess.amount));

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


CREATE OR REPLACE FUNCTION public.admin_reschedule_session(
  p_session_id       uuid,
  p_admin_id         uuid,
  p_new_scheduled_at timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _sess record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT * INTO _sess FROM public.sessions WHERE id = p_session_id;
  IF _sess IS NULL THEN
    RAISE EXCEPTION 'session not found';
  END IF;
  IF _sess.state <> 'CONFIRMED_BOOKING' THEN
    RAISE EXCEPTION 'only a confirmed booking can be rescheduled this way';
  END IF;

  UPDATE public.sessions SET scheduled_at = p_new_scheduled_at WHERE id = p_session_id;

  PERFORM public.log_admin_action(p_admin_id, 'reschedule_session', 'session', p_session_id,
    jsonb_build_object('old_scheduled_at', _sess.scheduled_at, 'new_scheduled_at', p_new_scheduled_at));

  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES
    (_sess.student_id, 'تمت إعادة جدولة جلستكم',
     'تم تغيير موعد جلستك من قِبل الإدارة، تحقق من الموعد الجديد.', 'session_rescheduled', p_session_id),
    (_sess.teacher_id, 'تمت إعادة جدولة جلستكم',
     'تم تغيير موعد جلستك مع طالبك من قِبل الإدارة، تحقق من الموعد الجديد.', 'session_rescheduled', p_session_id);
END;
$$;


CREATE OR REPLACE FUNCTION public.admin_suspend_subscription(
  p_subscription_id uuid,
  p_admin_id        uuid,
  p_refund          boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _sub            record;
  _lang           text;
  _teacher_id     uuid;
  _course_title   text;
  _package_title  text;
  _teacher_count  int;
  _split_teacher  numeric;
  _split_plat     numeric;
  _split_amount   numeric;
  r               record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT * INTO _sub FROM public.subscriptions WHERE id = p_subscription_id;
  IF _sub IS NULL THEN
    RAISE EXCEPTION 'subscription not found';
  END IF;
  IF _sub.status <> 'active' THEN
    RAISE EXCEPTION 'only an active subscription can be suspended';
  END IF;

  UPDATE public.subscriptions
    SET status = 'suspended',
        actual_refund_amount = CASE WHEN p_refund THEN _sub.amount ELSE NULL END
  WHERE id = p_subscription_id;

  PERFORM public.log_admin_action(p_admin_id, 'suspend_subscription', 'subscription', p_subscription_id,
    jsonb_build_object('refund', p_refund, 'amount', _sub.amount));

  IF NOT p_refund THEN
    RETURN;
  END IF;

  _lang := public.user_lang(_sub.student_id);

  IF _sub.course_id IS NOT NULL THEN
    SELECT teacher_id, title INTO _teacher_id, _course_title
      FROM public.courses WHERE id = _sub.course_id;

    IF _teacher_id IS NOT NULL THEN
      INSERT INTO public.ledger_entries
        (teacher_id, amount, commission, net_amount, type, description, created_at)
      VALUES
        (_teacher_id, -_sub.amount, -COALESCE(_sub.platform_commission, 0), -COALESCE(_sub.teacher_earning, 0),
         'subscription_refund', 'استرداد اشتراك: ' || COALESCE(_course_title, 'دورة'), NOW());

      INSERT INTO public.notifications (user_id, title, body, type, data)
      VALUES (
        _teacher_id,
        CASE public.user_lang(_teacher_id) WHEN 'fr' THEN 'Remboursement étudiant 💸' ELSE 'استرداد مبلغ لطالب 💸' END,
        CASE public.user_lang(_teacher_id) WHEN 'fr'
          THEN 'تم إرجاع مبلغ اشتراك أحد الطلاب في ' || COALESCE(_course_title, 'دورة') || '، وتم خصمه من أرباحك.'
          ELSE 'تم إرجاع مبلغ اشتراك أحد الطلاب في ' || COALESCE(_course_title, 'دورة') || '، وتم خصمه من أرباحك.' END,
        'SUBSCRIPTION_REFUNDED_TEACHER',
        jsonb_build_object('subscription_id', p_subscription_id::text)
      );
    END IF;

  ELSIF _sub.package_id IS NOT NULL THEN
    SELECT title INTO _package_title FROM public.packages WHERE id = _sub.package_id;

    SELECT COUNT(DISTINCT c.teacher_id) INTO _teacher_count
      FROM public.package_courses pc
      JOIN public.courses c ON c.id = pc.course_id
      WHERE pc.package_id = _sub.package_id AND c.teacher_id IS NOT NULL;

    IF _teacher_count > 0 THEN
      _split_amount  := ROUND(_sub.amount / _teacher_count, 2);
      _split_plat    := ROUND(COALESCE(_sub.platform_commission, 0) / _teacher_count, 2);
      _split_teacher := ROUND(COALESCE(_sub.teacher_earning, 0)     / _teacher_count, 2);

      FOR r IN
        SELECT DISTINCT c.teacher_id
        FROM public.package_courses pc
        JOIN public.courses c ON c.id = pc.course_id
        WHERE pc.package_id = _sub.package_id AND c.teacher_id IS NOT NULL
      LOOP
        INSERT INTO public.ledger_entries
          (teacher_id, amount, commission, net_amount, type, description, created_at)
        VALUES
          (r.teacher_id, -_split_amount, -_split_plat, -_split_teacher,
           'subscription_refund', 'استرداد اشتراك في باقة: ' || COALESCE(_package_title, 'باقة'), NOW());

        INSERT INTO public.notifications (user_id, title, body, type, data)
        VALUES (
          r.teacher_id,
          CASE public.user_lang(r.teacher_id) WHEN 'fr' THEN 'Remboursement étudiant 💸' ELSE 'استرداد مبلغ لطالب 💸' END,
          CASE public.user_lang(r.teacher_id) WHEN 'fr'
            THEN 'تم إرجاع مبلغ اشتراك أحد الطلاب في باقة ' || COALESCE(_package_title, '') || '، وتم خصم نصيبك منه.'
            ELSE 'تم إرجاع مبلغ اشتراك أحد الطلاب في باقة ' || COALESCE(_package_title, '') || '، وتم خصم نصيبك منه.' END,
          'SUBSCRIPTION_REFUNDED_TEACHER',
          jsonb_build_object('subscription_id', p_subscription_id::text)
        );
      END LOOP;
    END IF;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    _sub.student_id,
    CASE _lang WHEN 'fr' THEN 'Montant remboursé 💰' ELSE 'تم استرداد مبلغك 💰' END,
    CASE _lang WHEN 'fr' THEN _sub.amount::text || ' MRU vous seront remboursés.'
      ELSE 'سيُسترد لك ' || _sub.amount::text || ' أوقية.' END,
    'SUB_REFUNDED',
    jsonb_build_object('subscription_id', p_subscription_id::text)
  );
END;
$$;


CREATE OR REPLACE FUNCTION public.admin_create_manual_subscription(
  p_student_id  uuid,
  p_course_id   uuid,
  p_package_id  uuid,
  p_amount      numeric,
  p_plan_type   text,
  p_months      integer,
  p_admin_id    uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _sub_id uuid;
  _type   text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF (p_course_id IS NULL) = (p_package_id IS NULL) THEN
    RAISE EXCEPTION 'exactly one of course_id or package_id must be provided';
  END IF;

  _type := CASE WHEN p_course_id IS NOT NULL THEN 'course' ELSE 'package' END;

  IF EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE student_id = p_student_id
      AND status IN ('active', 'pending')
      AND ((p_course_id  IS NOT NULL AND course_id  = p_course_id)
        OR (p_package_id IS NOT NULL AND package_id = p_package_id))
  ) THEN
    RAISE EXCEPTION 'student already has an active or pending subscription for this item';
  END IF;

  INSERT INTO public.subscriptions (student_id, type, course_id, package_id, amount, plan_type, status)
  VALUES (p_student_id, _type, p_course_id, p_package_id, p_amount, p_plan_type, 'pending')
  RETURNING id INTO _sub_id;

  PERFORM public.admin_confirm_subscription(_sub_id, p_admin_id, p_months);

  PERFORM public.log_admin_action(p_admin_id, 'create_manual_subscription', 'subscription', _sub_id,
    jsonb_build_object('student_id', p_student_id, 'amount', p_amount, 'plan_type', p_plan_type));

  RETURN _sub_id;
END;
$$;
