-- Payment method logo (shown to students to visually distinguish methods)
ALTER TABLE public.payment_methods ADD COLUMN IF NOT EXISTS logo_url text;

-- Admin-settable quarterly (3-month) course price — previously only
-- auto-computed client-side as price_monthly * 3, with no override.
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS price_quarterly numeric;
