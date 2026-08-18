-- Notify the student/teacher when admin replies to their complaint/suggestion
-- (status flips to 'reviewed' with an admin_note attached).

CREATE OR REPLACE FUNCTION public.notify_complaint_reply()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.status = 'reviewed' AND NEW.admin_note IS NOT NULL
     AND (OLD.status IS DISTINCT FROM 'reviewed' OR OLD.admin_note IS DISTINCT FROM NEW.admin_note) THEN
    INSERT INTO public.notifications (user_id, title, body, type)
    VALUES (
      NEW.user_id,
      'تم الرد على رسالتك',
      NEW.admin_note,
      'COMPLAINT_REPLY'
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_complaint_reply ON public.complaints;
CREATE TRIGGER trg_notify_complaint_reply
  AFTER UPDATE ON public.complaints
  FOR EACH ROW EXECUTE FUNCTION public.notify_complaint_reply();
