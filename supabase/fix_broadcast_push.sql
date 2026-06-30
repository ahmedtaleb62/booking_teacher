-- ══════════════════════════════════════════════════════════════════
-- Fix: broadcast notifications now send FCM via per-row trigger
-- Problem: send_push_for_notification() was skipping NEW_COURSE,
--          NEW_PACKAGE, NEW_TEACHER, ADMIN_BROADCAST — so students
--          never got a push for these types unless notify-broadcast
--          Edge Function was called successfully from the admin panel
--          (which was missing for courses and failing silently for others).
-- Fix: remove the skip → every notification row gets an FCM push via
--      notify-user regardless of type. Admin panel only needs to call
--      send_admin_notification (which inserts the rows).
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.send_push_for_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER AS $$
DECLARE
  service_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtcnJrcXF0cGJ6Y2thZWhucHJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1OTY4MzgsImV4cCI6MjA4MzE3MjgzOH0.6Fkl7MqT6qsMeIg-73U42NzoCaDozmnp5T1YPTejYyw';
  v_role      text;
BEGIN
  -- All types including broadcast types get a per-user FCM push via notify-user.
  -- Admin panel no longer calls notify-broadcast (which was unreliable / missing
  -- for courses). Each notification row triggers exactly one notify-user call.

  SELECT role INTO v_role FROM public.profiles WHERE id = NEW.user_id;

  PERFORM net.http_post(
    url     := 'https://tmrrkqqtpbzckaehnprq.supabase.co/functions/v1/notify-user',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body    := jsonb_build_object(
      'user_id', NEW.user_id,
      'title',   NEW.title,
      'body',    NEW.body,
      'data',    jsonb_build_object(
        'type',       COALESCE(NEW.type, ''),
        'session_id', COALESCE(NEW.session_id::text, ''),
        'role',       COALESCE(v_role, '')
      )
    )
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$;
