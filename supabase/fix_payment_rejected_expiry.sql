-- Fix: expire_overdue_payments() was only cancelling AWAITING_PAYMENT.
-- Sessions in PAYMENT_REJECTED with an expired deadline were never auto-cancelled,
-- even though the UI told the student "will auto-cancel".
-- This migration extends the function to cover PAYMENT_REJECTED as well.

CREATE OR REPLACE FUNCTION expire_overdue_payments()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count INT;
BEGIN
  UPDATE sessions
  SET state = 'CANCELLED'
  WHERE state IN ('AWAITING_PAYMENT', 'PAYMENT_REJECTED')
    AND payment_deadline < now();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
