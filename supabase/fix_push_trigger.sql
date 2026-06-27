-- Fix 401 error: update trigger with current service_role key
-- Get your key from: Supabase Dashboard → Project Settings → API → service_role
-- Replace <YOUR_SERVICE_ROLE_KEY> below with the actual key

CREATE OR REPLACE FUNCTION public.send_push_for_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  service_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtcnJrcXF0cGJ6Y2thZWhucHJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1OTY4MzgsImV4cCI6MjA4MzE3MjgzOH0.6Fkl7MqT6qsMeIg-73U42NzoCaDozmnp5T1YPTejYyw';  -- ← paste here
BEGIN
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
        'session_id', COALESCE(NEW.session_id::text, '')
      )
    )
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never block the INSERT even if push fails
  RETURN NEW;
END;
$$;

-- Recreate trigger to make sure it points to the updated function
DROP TRIGGER IF EXISTS push_on_notification_insert ON public.notifications;
CREATE TRIGGER push_on_notification_insert
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.send_push_for_notification();
