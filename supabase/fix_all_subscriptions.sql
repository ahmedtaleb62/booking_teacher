-- ══════════════════════════════════════════════════════════════════
-- FIX ALL SUBSCRIPTION ISSUES — Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- ── 1. Add missing columns (safe if they already exist) ──────────
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS teacher_earning     NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS platform_commission NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS reject_reason       TEXT,
  ADD COLUMN IF NOT EXISTS updated_at          TIMESTAMPTZ DEFAULT NOW();

-- ── 2. Create platform_settings if missing ───────────────────────
CREATE TABLE IF NOT EXISTS public.platform_settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
INSERT INTO public.platform_settings (key, value)
  VALUES ('course_commission_rate', '0.15')
  ON CONFLICT (key) DO NOTHING;

-- ── 3. Fix the earnings trigger (amount + commission were missing) ─
CREATE OR REPLACE FUNCTION public.handle_subscription_earnings()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _rate         NUMERIC;
  _teacher_id   UUID;
  _course_title TEXT;
  _teacher_amt  NUMERIC;
  _plat_amt     NUMERIC;
BEGIN
  IF NEW.status = 'active' AND (OLD.status IS DISTINCT FROM 'active') THEN

    SELECT COALESCE(value::NUMERIC, 0.15)
      INTO _rate
      FROM public.platform_settings
      WHERE key = 'course_commission_rate';

    _teacher_amt := ROUND(NEW.amount * (1 - _rate), 2);
    _plat_amt    := ROUND(NEW.amount * _rate,        2);

    UPDATE public.subscriptions
      SET teacher_earning     = _teacher_amt,
          platform_commission = _plat_amt
      WHERE id = NEW.id;

    IF NEW.course_id IS NOT NULL THEN
      SELECT c.teacher_id, c.title INTO _teacher_id, _course_title
        FROM public.courses c WHERE c.id = NEW.course_id;
    ELSIF NEW.package_id IS NOT NULL THEN
      SELECT p.teacher_id, p.title INTO _teacher_id, _course_title
        FROM public.packages p WHERE p.id = NEW.package_id;
    END IF;

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

DROP TRIGGER IF EXISTS trg_subscription_earnings ON public.subscriptions;
CREATE TRIGGER trg_subscription_earnings
  AFTER INSERT OR UPDATE OF status ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.handle_subscription_earnings();

-- ── 4. Create admin RPC functions ────────────────────────────────

CREATE OR REPLACE FUNCTION public.admin_confirm_subscription(
  p_subscription_id UUID,
  p_admin_id        UUID,
  p_months          INT DEFAULT 1
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.subscriptions
  SET
    status      = 'active',
    started_at  = NOW(),
    expires_at  = NOW() + (p_months || ' months')::INTERVAL,
    updated_at  = NOW()
  WHERE id = p_subscription_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reject_subscription(
  p_subscription_id UUID,
  p_admin_id        UUID,
  p_reason          TEXT DEFAULT ''
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.subscriptions
  SET
    status        = 'rejected',
    reject_reason = p_reason,
    updated_at    = NOW()
  WHERE id = p_subscription_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_confirm_subscription(UUID, UUID, INT)  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reject_subscription(UUID, UUID, TEXT)  TO authenticated;

-- ── 5. Reload PostgREST schema cache ─────────────────────────────
NOTIFY pgrst, 'reload schema';
