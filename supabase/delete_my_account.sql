-- RPC: delete_my_account
-- Deletes all data for the currently authenticated user, then removes the auth account.
-- Must run as SECURITY DEFINER so it can delete from auth.users.

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  -- Course data
  DELETE FROM public.course_ratings    WHERE student_id = _uid;
  DELETE FROM public.lesson_progress   WHERE student_id = _uid;
  DELETE FROM public.subscriptions     WHERE student_id = _uid;

  -- Payments
  DELETE FROM public.payments          WHERE student_id = _uid;

  -- Sessions
  DELETE FROM public.session_events
    WHERE session_id IN (
      SELECT id FROM public.sessions
      WHERE student_id = _uid OR teacher_id = _uid
    );
  DELETE FROM public.sessions          WHERE student_id = _uid OR teacher_id = _uid;

  -- Teacher profile (if the user is a teacher)
  DELETE FROM public.teacher_profiles  WHERE id = _uid;

  -- Base profile
  DELETE FROM public.profiles          WHERE id = _uid;

  -- Auth account (requires SECURITY DEFINER)
  DELETE FROM auth.users               WHERE id = _uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
