-- RPC: admin_suspend_subscription
-- Suspends an active subscription. With p_refund=true, also reverses the
-- teacher's earning for it (so they aren't credited for money that's being
-- refunded) and notifies both student and teacher(s). Never mutates or
-- deletes the original earning ledger row — inserts an offsetting
-- 'subscription_refund' entry instead, preserving full history.

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

  -- Flip status — the existing notify_subscription_status_change trigger
  -- sends the base "تم تعطيل اشتراكك" notification automatically, and RLS
  -- on course_lessons already keys purely off status='active', so this
  -- alone cuts the student's access.
  UPDATE public.subscriptions
    SET status = 'suspended',
        actual_refund_amount = CASE WHEN p_refund THEN _sub.amount ELSE NULL END
  WHERE id = p_subscription_id;

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

GRANT EXECUTE ON FUNCTION public.admin_suspend_subscription(uuid, uuid, boolean) TO authenticated;
