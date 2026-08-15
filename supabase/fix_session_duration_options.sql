-- Session duration options changed to 30 / 60 / 120 minutes.
--
-- The sessions_duration_minutes_check constraint only allowed
-- (5, 30, 60, 90) — meaning the app's own "ساعتان" (120 min) option
-- would have failed at booking time. Added NOT VALID so existing rows
-- (including old 5-minute test/dev sessions) aren't touched.

ALTER TABLE public.sessions DROP CONSTRAINT sessions_duration_minutes_check;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_duration_minutes_check
  CHECK (duration_minutes = ANY (ARRAY[30, 60, 120])) NOT VALID;
