-- Run this in Supabase SQL Editor AFTER deploying the send-push Edge Function.
-- Replace <YOUR_PROJECT_REF> with your Supabase project reference ID
-- (found in Project Settings → General, e.g. tmrrkqqtpbzckaehnprq)

CREATE OR REPLACE FUNCTION public.trigger_send_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
    ),
    body    := jsonb_build_object('record', row_to_json(NEW))
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_notification_insert ON public.notifications;
CREATE TRIGGER on_notification_insert
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_send_push();

-- Store the service role key so the trigger can read it
-- Replace <SERVICE_ROLE_KEY> with your actual key (Settings → API)
ALTER DATABASE postgres
  SET app.service_role_key = '<SERVICE_ROLE_KEY>';
