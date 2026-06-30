-- Prevent duplicate FCM pushes for broadcast notification types.
-- When a bulk INSERT happens (NEW_COURSE, NEW_PACKAGE, NEW_TEACHER, ADMIN_BROADCAST),
-- notify-broadcast already sent FCM to all devices. The per-row trigger would call
-- notify-user once per student, causing N duplicate pushes. Skip it for those types.

CREATE OR REPLACE FUNCTION public.send_push_for_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  service_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRtcnJrcXF0cGJ6Y2thZWhucHJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1OTY4MzgsImV4cCI6MjA4MzE3MjgzOH0.6Fkl7MqT6qsMeIg-73U42NzoCaDozmnp5T1YPTejYyw';
  v_role      text;
BEGIN
  -- Broadcast types are already handled by notify-broadcast from the admin panel.
  IF NEW.type IN ('NEW_COURSE', 'NEW_PACKAGE', 'NEW_TEACHER', 'ADMIN_BROADCAST') THEN
    RETURN NEW;
  END IF;

  -- Include user role so Flutter can route to the correct screen on tap.
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

DROP TRIGGER IF EXISTS push_on_notification_insert ON public.notifications;
CREATE TRIGGER push_on_notification_insert
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.send_push_for_notification();
