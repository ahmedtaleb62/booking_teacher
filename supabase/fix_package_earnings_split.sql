-- ══════════════════════════════════════════════════════════════════
-- FIX: handle_subscription_earnings — packages table has no teacher_id
--      column (a package can bundle courses from multiple teachers,
--      see admin/src/pages/Packages.jsx CourseSelector). The previous
--      version did `SELECT p.teacher_id FROM packages p` which fails
--      with "column p.teacher_id does not exist" and aborts the whole
--      admin_confirm_subscription transaction for package subscriptions.
--
--      This version splits the earning equally across every distinct
--      teacher who has at least one course inside the package.
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_subscription_earnings()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _rate               NUMERIC;
  _teacher_id         UUID;
  _course_title       TEXT;
  _teacher_amt        NUMERIC;
  _plat_amt           NUMERIC;
  _teacher_count      INT;
  _split_gross_amt    NUMERIC;
  _split_plat_amt     NUMERIC;
  _split_teacher_amt  NUMERIC;
  r                   RECORD;
BEGIN
  IF NEW.status = 'active' AND (OLD.status IS DISTINCT FROM 'active') THEN

    -- Read dynamic commission rate
    SELECT COALESCE((value::TEXT)::NUMERIC, 15) / 100.0 INTO _rate
    FROM public.system_settings WHERE key = 'subscription_commission_pct';
    _rate := COALESCE(_rate, 0.15);

    _teacher_amt := ROUND(NEW.amount * (1 - _rate), 2);
    _plat_amt    := ROUND(NEW.amount * _rate,        2);

    -- Persist on subscription row
    UPDATE public.subscriptions
      SET teacher_earning     = _teacher_amt,
          platform_commission = _plat_amt
      WHERE id = NEW.id;

    IF NEW.course_id IS NOT NULL THEN
      -- Single-course subscription: one teacher owns the whole amount
      SELECT c.teacher_id, c.title INTO _teacher_id, _course_title
        FROM public.courses c WHERE c.id = NEW.course_id;

      IF _teacher_id IS NOT NULL THEN
        INSERT INTO public.ledger_entries
          (teacher_id, amount, commission, net_amount, type, description, created_at)
        VALUES
          (_teacher_id, NEW.amount, _plat_amt, _teacher_amt,
           'course_subscription',
           'اشتراك في: ' || COALESCE(_course_title, 'دورة'),
           NOW());
      END IF;

    ELSIF NEW.package_id IS NOT NULL THEN
      -- Package subscription: packages have no teacher_id of their own.
      -- Split the earning equally across every distinct teacher who has
      -- a course inside this package.
      SELECT p.title INTO _course_title FROM public.packages p WHERE p.id = NEW.package_id;

      SELECT COUNT(DISTINCT c.teacher_id) INTO _teacher_count
        FROM public.package_courses pc
        JOIN public.courses c ON c.id = pc.course_id
        WHERE pc.package_id = NEW.package_id AND c.teacher_id IS NOT NULL;

      IF _teacher_count > 0 THEN
        _split_gross_amt   := ROUND(NEW.amount   / _teacher_count, 2);
        _split_plat_amt    := ROUND(_plat_amt    / _teacher_count, 2);
        _split_teacher_amt := ROUND(_teacher_amt / _teacher_count, 2);

        FOR r IN
          SELECT DISTINCT c.teacher_id
          FROM public.package_courses pc
          JOIN public.courses c ON c.id = pc.course_id
          WHERE pc.package_id = NEW.package_id AND c.teacher_id IS NOT NULL
        LOOP
          INSERT INTO public.ledger_entries
            (teacher_id, amount, commission, net_amount, type, description, created_at)
          VALUES
            (r.teacher_id, _split_gross_amt, _split_plat_amt, _split_teacher_amt,
             'package_subscription',
             'اشتراك في باقة: ' || COALESCE(_course_title, 'باقة'),
             NOW());
        END LOOP;
      END IF;
    END IF;

  END IF;
  RETURN NEW;
END;
$$;

-- Re-attach trigger (safe to re-run)
DROP TRIGGER IF EXISTS trg_subscription_earnings ON public.subscriptions;
CREATE TRIGGER trg_subscription_earnings
  AFTER INSERT OR UPDATE OF status ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.handle_subscription_earnings();

NOTIFY pgrst, 'reload schema';
