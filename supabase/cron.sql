-- ============================================================
-- حجز استاذ · Supabase Cron Jobs
-- Run in Supabase SQL Editor AFTER schema.sql
-- Requires: pg_cron extension (enabled in Supabase Dashboard → Database → Extensions)
-- ============================================================

-- Enable pg_cron (Supabase >= free tier has this available)
CREATE EXTENSION IF NOT EXISTS pg_cron;
GRANT USAGE ON SCHEMA cron TO postgres;

-- ============================================================
-- 1. Expire overdue payment requests — every 5 minutes
--    Cancels sessions in AWAITING_PAYMENT whose deadline has passed
-- ============================================================
SELECT cron.schedule(
  'expire-overdue-payments',    -- unique job name
  '*/5 * * * *',                -- every 5 minutes
  $$SELECT expire_overdue_payments()$$
);

-- ============================================================
-- 2. Detect no-shows — every 2 minutes
--    Marks CONFIRMED_BOOKING sessions as TEACHER_NO_SHOW
--    if teacher hasn't started within no_show_timeout_minutes
-- ============================================================
SELECT cron.schedule(
  'detect-no-shows',
  '*/2 * * * *',
  $$SELECT detect_no_shows()$$
);

-- ============================================================
-- 3. Auto-open dispute for unconfirmed payments — every hour
--    Opens a DISPUTE if payment was SUBMITTED but not CONFIRMED
--    for more than dispute_auto_open_hours (default 1h)
-- ============================================================
CREATE OR REPLACE FUNCTION auto_open_stale_payment_disputes()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count  INT := 0;
  v_hours  NUMERIC;
  rec      RECORD;
BEGIN
  SELECT (value::TEXT::NUMERIC) INTO v_hours
  FROM system_settings WHERE key = 'dispute_auto_open_hours';

  FOR rec IN
    SELECT s.id AS session_id, s.student_id, p.id AS payment_id
    FROM sessions s
    JOIN payments p ON p.session_id = s.id
    WHERE s.state = 'PAYMENT_SUBMITTED'
      AND p.status = 'submitted'
      AND p.created_at < now() - make_interval(hours => v_hours::INT)
      AND NOT EXISTS (SELECT 1 FROM disputes d WHERE d.session_id = s.id)
  LOOP
    INSERT INTO disputes (session_id, opened_by, reason, frozen_amount)
    SELECT rec.session_id, rec.student_id, 'payment_not_confirmed',
           s.amount
    FROM sessions s WHERE s.id = rec.session_id;

    UPDATE sessions SET state = 'DISPUTE' WHERE id = rec.session_id;
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

SELECT cron.schedule(
  'auto-open-payment-disputes',
  '0 * * * *',   -- every hour at :00
  $$SELECT auto_open_stale_payment_disputes()$$
);

-- ============================================================
-- 4. Auto-cancel PAYMENT_REJECTED sessions past deadline — every 5 min
-- ============================================================
CREATE OR REPLACE FUNCTION auto_cancel_rejected_payments()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count INT := 0;
  rec     RECORD;
BEGIN
  FOR rec IN
    SELECT id, student_id, amount FROM sessions
    WHERE state = 'PAYMENT_REJECTED'
      AND payment_deadline IS NOT NULL
      AND payment_deadline < now()
  LOOP
    UPDATE sessions SET state = 'CANCELLED' WHERE id = rec.id;

    INSERT INTO notifications (user_id, title, body, type, session_id)
    VALUES (
      rec.student_id,
      'تم إلغاء الجلسة تلقائياً',
      'انتهت مهلة إعادة الدفع. سيتم استرداد مبلغك إن وجد.',
      'session_cancelled',
      rec.id
    );

    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

SELECT cron.schedule(
  'cancel-rejected-payments',
  '*/5 * * * *',
  $$SELECT auto_cancel_rejected_payments()$$
);

-- ============================================================
-- View scheduled jobs (for verification)
-- ============================================================
-- SELECT * FROM cron.job;

-- ============================================================
-- To remove a job:
-- SELECT cron.unschedule('expire-overdue-payments');
-- SELECT cron.unschedule('detect-no-shows');
-- SELECT cron.unschedule('auto-open-payment-disputes');
-- ============================================================
