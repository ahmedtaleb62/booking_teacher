-- ══════════════════════════════════════════════════════════════════
-- FIX: teacher_earnings table + handle_subscription_earnings trigger
--      + admin_confirm_subscription / admin_reject_subscription
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- ── 1. Drop the VIEW we previously created (wrong type) ──────────
DROP VIEW IF EXISTS public.teacher_earnings;

-- ── 2. Create teacher_earnings as a proper TABLE ──────────────────
--    (legacy compatibility — the old trigger was inserting here;
--     the new trigger uses ledger_entries instead, but the TABLE
--     must exist so any remaining DB references don't crash)
CREATE TABLE IF NOT EXISTS public.teacher_earnings (
  id              UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
  subscription_id UUID         REFERENCES public.subscriptions(id),
  teacher_id      UUID         REFERENCES public.profiles(id),
  amount          NUMERIC(10,2),
  commission      NUMERIC(10,2),
  net_amount      NUMERIC(10,2),
  description     TEXT,
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ── 3. Replace handle_subscription_earnings ───────────────────────
--    Old version inserted into teacher_earnings — new version uses
--    ledger_entries (the single source of truth for the Flutter app)
CREATE OR REPLACE FUNCTION public.handle_subscription_earnings()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _rate          NUMERIC;
  _teacher_id    UUID;
  _course_title  TEXT;
  _teacher_amt   NUMERIC;
  _plat_amt      NUMERIC;
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

    -- Resolve teacher + title
    IF NEW.course_id IS NOT NULL THEN
      SELECT c.teacher_id, c.title INTO _teacher_id, _course_title
        FROM public.courses c WHERE c.id = NEW.course_id;
    ELSIF NEW.package_id IS NOT NULL THEN
      SELECT p.teacher_id, p.title INTO _teacher_id, _course_title
        FROM public.packages p WHERE p.id = NEW.package_id;
    END IF;

    -- Write to ledger_entries (Flutter app reads from here)
    IF _teacher_id IS NOT NULL THEN
      INSERT INTO public.ledger_entries
        (teacher_id, amount, commission, net_amount, type, description, created_at)
      VALUES
        (_teacher_id, NEW.amount, _plat_amt, _teacher_amt,
         'course_subscription',
         'اشتراك في: ' || COALESCE(_course_title, 'دورة'),
         NOW());
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

-- ── 4. Recreate admin_confirm_subscription ────────────────────────
CREATE OR REPLACE FUNCTION public.admin_confirm_subscription(
  p_subscription_id UUID,
  p_admin_id        UUID,
  p_months          INT DEFAULT 1
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.subscriptions
  SET
    status     = 'active',
    started_at = NOW(),
    expires_at = NOW() + (p_months || ' months')::INTERVAL,
    updated_at = NOW()
  WHERE id = p_subscription_id
    AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'subscription % is not in pending state', p_subscription_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_confirm_subscription(UUID, UUID, INT) TO authenticated;

-- ── 5. Recreate admin_reject_subscription ─────────────────────────
CREATE OR REPLACE FUNCTION public.admin_reject_subscription(
  p_subscription_id UUID,
  p_admin_id        UUID,
  p_reason          TEXT DEFAULT ''
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.subscriptions
  SET
    status        = 'rejected',
    reject_reason = p_reason,
    updated_at    = NOW()
  WHERE id = p_subscription_id
    AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'subscription % is not in pending state', p_subscription_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reject_subscription(UUID, UUID, TEXT) TO authenticated;

-- ── 6. Reload PostgREST schema cache ─────────────────────────────
NOTIFY pgrst, 'reload schema';
