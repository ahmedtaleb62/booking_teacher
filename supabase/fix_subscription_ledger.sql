-- Fix: handle_subscription_earnings was inserting into ledger_entries
-- without the required NOT NULL columns: amount and commission.

CREATE OR REPLACE FUNCTION public.handle_subscription_earnings()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _rate         NUMERIC;
  _teacher_id   UUID;
  _course_title TEXT;
  _teacher_amt  NUMERIC;
  _plat_amt     NUMERIC;
BEGIN
  -- Only run when status first becomes 'active'
  IF NEW.status = 'active' AND (OLD.status IS DISTINCT FROM 'active') THEN

    SELECT COALESCE(value::NUMERIC, 0.15)
      INTO _rate
      FROM public.platform_settings
      WHERE key = 'course_commission_rate';

    _teacher_amt := ROUND(NEW.amount * (1 - _rate), 2);
    _plat_amt    := ROUND(NEW.amount * _rate,        2);

    -- Persist computed amounts on the subscription row
    UPDATE public.subscriptions
      SET teacher_earning     = _teacher_amt,
          platform_commission = _plat_amt
      WHERE id = NEW.id;

    -- Resolve teacher from course or package
    IF NEW.course_id IS NOT NULL THEN
      SELECT c.teacher_id, c.title
        INTO _teacher_id, _course_title
        FROM public.courses c
        WHERE c.id = NEW.course_id;
    ELSIF NEW.package_id IS NOT NULL THEN
      SELECT p.teacher_id, p.title
        INTO _teacher_id, _course_title
        FROM public.packages p
        WHERE p.id = NEW.package_id;
    END IF;

    -- Insert ledger entry with all required columns
    IF _teacher_id IS NOT NULL THEN
      INSERT INTO public.ledger_entries
        (teacher_id, amount, commission, net_amount, type, description, created_at)
      VALUES
        (_teacher_id,
         NEW.amount,
         _plat_amt,
         _teacher_amt,
         'course_subscription',
         'اشتراك في: ' || COALESCE(_course_title, 'دورة'),
         NOW());
    END IF;

  END IF;
  RETURN NEW;
END;
$$;
