-- ══════════════════════════════════════════════════════════════
-- Create / replace subscription admin RPC functions
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════

-- 1. Confirm a subscription (admin action)
--    Sets status = 'active', computes expiry date
--    Trigger handle_subscription_earnings fires after → ledger entry
CREATE OR REPLACE FUNCTION public.admin_confirm_subscription(
  p_subscription_id UUID,
  p_admin_id        UUID,
  p_months          INT DEFAULT 1
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.subscriptions
  SET
    status     = 'active',
    started_at = NOW(),
    expires_at = NOW() + (p_months || ' months')::INTERVAL,
    updated_at = NOW()
  WHERE id = p_subscription_id;
END;
$$;

-- 2. Reject a subscription (admin action)
--    Sets status = 'rejected' and stores the reason
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

-- 3. Grant execute to authenticated users (admin check is inside calling code via RLS)
GRANT EXECUTE ON FUNCTION public.admin_confirm_subscription(UUID, UUID, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reject_subscription(UUID, UUID, TEXT) TO authenticated;

-- 4. Reload PostgREST schema cache so functions appear immediately
NOTIFY pgrst, 'reload schema';
