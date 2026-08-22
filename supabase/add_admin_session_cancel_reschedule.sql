-- RPCs for admin to unstick a CONFIRMED_BOOKING session that neither party
-- ever joined: cancel it outright, or reschedule it to a new time.

CREATE OR REPLACE FUNCTION public.admin_cancel_session(
  p_session_id uuid,
  p_admin_id   uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _sess record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT * INTO _sess FROM public.sessions WHERE id = p_session_id;
  IF _sess IS NULL THEN
    RAISE EXCEPTION 'session not found';
  END IF;
  IF _sess.state <> 'CONFIRMED_BOOKING' THEN
    RAISE EXCEPTION 'only a confirmed booking can be cancelled this way';
  END IF;

  UPDATE public.sessions
    SET state = 'CANCELLED', cancellation_reason = 'admin_cancelled'
  WHERE id = p_session_id;

  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES
    (_sess.student_id, 'تم إلغاء الجلسة من طرف الإدارة',
     'تم إلغاء جلستك المجدولة من قِبل الإدارة.', 'session_cancelled_admin', p_session_id),
    (_sess.teacher_id, 'تم إلغاء الجلسة من طرف الإدارة',
     'تم إلغاء الجلسة المجدولة مع طالبك من قِبل الإدارة.', 'session_cancelled_admin', p_session_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_cancel_session(uuid, uuid) TO authenticated;


CREATE OR REPLACE FUNCTION public.admin_reschedule_session(
  p_session_id       uuid,
  p_admin_id         uuid,
  p_new_scheduled_at timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _sess record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT * INTO _sess FROM public.sessions WHERE id = p_session_id;
  IF _sess IS NULL THEN
    RAISE EXCEPTION 'session not found';
  END IF;
  IF _sess.state <> 'CONFIRMED_BOOKING' THEN
    RAISE EXCEPTION 'only a confirmed booking can be rescheduled this way';
  END IF;

  -- trg_check_double_booking fires on this UPDATE and raises a clear Arabic
  -- error if the new slot conflicts with another of this teacher's sessions.
  UPDATE public.sessions SET scheduled_at = p_new_scheduled_at WHERE id = p_session_id;

  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES
    (_sess.student_id, 'تمت إعادة جدولة جلستكم',
     'تم تغيير موعد جلستك من قِبل الإدارة، تحقق من الموعد الجديد.', 'session_rescheduled', p_session_id),
    (_sess.teacher_id, 'تمت إعادة جدولة جلستكم',
     'تم تغيير موعد جلستك مع طالبك من قِبل الإدارة، تحقق من الموعد الجديد.', 'session_rescheduled', p_session_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reschedule_session(uuid, uuid, timestamptz) TO authenticated;
