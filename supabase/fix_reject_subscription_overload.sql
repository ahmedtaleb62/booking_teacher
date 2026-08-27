-- Two overloads of admin_reject_subscription existed simultaneously: an old
-- 3-arg version and a newer 4-arg version with an optional p_refund_amount.
-- Since the 4th param has a default, calling with exactly 3 named args
-- (as the plain-reject UI path does) matched both — Postgres/PostgREST
-- couldn't pick one and every subscription rejection failed in production.
DROP FUNCTION IF EXISTS public.admin_reject_subscription(uuid, uuid, text);

-- Recreate the surviving 4-arg version, restoring the pending-state guard
-- and search_path pin that only the old 3-arg version had (the 4-arg one
-- silently dropped both when it was added).
CREATE OR REPLACE FUNCTION public.admin_reject_subscription(
  p_subscription_id uuid,
  p_admin_id         uuid,
  p_reason           text DEFAULT ''::text,
  p_refund_amount    numeric DEFAULT NULL::numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE public.subscriptions
  SET
    status               = 'rejected',
    reject_reason        = p_reason,
    actual_refund_amount = p_refund_amount,
    updated_at            = NOW()
  WHERE id = p_subscription_id
    AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'subscription % is not in pending state', p_subscription_id;
  END IF;
END;
$function$;
