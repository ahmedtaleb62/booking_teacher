-- Human-readable device name/model alongside device_id, so admin can see
-- which physical device an account is actually locked to.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS device_name text;
