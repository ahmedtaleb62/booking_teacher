-- RPC: admin_delete_user
-- Deletes any user's data + auth account. Caller must have role = 'admin'.

CREATE OR REPLACE FUNCTION public.admin_delete_user(target_uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  DELETE FROM public.course_ratings  WHERE student_id = target_uid;
  DELETE FROM public.lesson_progress WHERE student_id = target_uid;
  DELETE FROM public.subscriptions   WHERE student_id = target_uid;
  DELETE FROM public.payments        WHERE student_id = target_uid;
  DELETE FROM public.session_events
    WHERE session_id IN (
      SELECT id FROM public.sessions
      WHERE student_id = target_uid OR teacher_id = target_uid
    );
  DELETE FROM public.sessions        WHERE student_id = target_uid OR teacher_id = target_uid;
  DELETE FROM public.teacher_profiles WHERE id = target_uid;
  DELETE FROM public.profiles        WHERE id = target_uid;
  DELETE FROM auth.users             WHERE id = target_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_delete_user(uuid) TO authenticated;
