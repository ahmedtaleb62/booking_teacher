-- ─────────────────────────────────────────────────────────────────
-- 1. Add earnings columns to subscriptions
-- ─────────────────────────────────────────────────────────────────
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS teacher_earning    NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS platform_commission NUMERIC(10,2);

-- ─────────────────────────────────────────────────────────────────
-- 2. Platform settings (commission rates)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.platform_settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT INTO public.platform_settings (key, value)
  VALUES ('course_commission_rate', '0.15')
  ON CONFLICT (key) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────
-- 3. Trigger: compute & store earnings when subscription → active
--    and insert a ledger entry for the teacher
-- ─────────────────────────────────────────────────────────────────
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
    _plat_amt    := ROUND(NEW.amount * _rate, 2);

    -- Persist computed amounts on the subscription row
    -- (use a separate UPDATE so we don't need a BEFORE trigger)
    UPDATE public.subscriptions
      SET teacher_earning     = _teacher_amt,
          platform_commission = _plat_amt
      WHERE id = NEW.id;

    -- Resolve teacher from course
    IF NEW.course_id IS NOT NULL THEN
      SELECT c.teacher_id, c.title
        INTO _teacher_id, _course_title
        FROM public.courses c
        WHERE c.id = NEW.course_id;
    END IF;

    -- Insert ledger entry so the teacher sees it in their earnings screen
    IF _teacher_id IS NOT NULL THEN
      INSERT INTO public.ledger_entries
        (teacher_id, net_amount, type, description, created_at)
      VALUES
        (_teacher_id, _teacher_amt, 'course_subscription',
         'اشتراك في: ' || COALESCE(_course_title, 'دورة'),
         NOW());
    END IF;

  END IF;
  RETURN NEW;
END;
$$;

-- Fire on INSERT (in case admin inserts already-active row)
-- and on UPDATE when status column changes
DROP TRIGGER IF EXISTS trg_subscription_earnings ON public.subscriptions;
CREATE TRIGGER trg_subscription_earnings
  AFTER INSERT OR UPDATE OF status ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.handle_subscription_earnings();
