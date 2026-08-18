-- RPC: admin_delete_user
-- Deletes any user's data + auth account. Caller must have role = 'admin'.
--
-- Clears every table found via a live information_schema FK audit that
-- references profiles/auth.users, so the delete never aborts partway
-- through with a foreign-key violation.

CREATE OR REPLACE FUNCTION public.admin_delete_user(target_uid uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _sess_ids uuid[];
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT array_agg(id) INTO _sess_ids
  FROM public.sessions WHERE student_id = target_uid OR teacher_id = target_uid;

  -- Ratings / reviews
  DELETE FROM public.reviews        WHERE student_id = target_uid OR teacher_id = target_uid;
  DELETE FROM public.course_ratings WHERE student_id = target_uid;

  -- Financial history
  DELETE FROM public.ledger_entries   WHERE student_id = target_uid OR teacher_id = target_uid;
  DELETE FROM public.teacher_earnings WHERE teacher_id = target_uid;
  UPDATE public.payments SET confirmed_by = NULL WHERE confirmed_by = target_uid;
  DELETE FROM public.payments WHERE student_id = target_uid;

  -- Disputes (opened_by is required on the row; resolved_by is just an audit field)
  DELETE FROM public.disputes WHERE opened_by = target_uid;
  UPDATE public.disputes SET resolved_by = NULL WHERE resolved_by = target_uid;

  -- Notifications / sessions referencing each other need clearing before
  -- the sessions themselves are dropped (notifications.session_id and
  -- sessions.parent_session_id both use ON DELETE NO ACTION).
  IF _sess_ids IS NOT NULL THEN
    DELETE FROM public.notifications WHERE session_id = ANY(_sess_ids);
    UPDATE public.sessions SET parent_session_id = NULL WHERE parent_session_id = ANY(_sess_ids);
  END IF;
  DELETE FROM public.notifications WHERE user_id = target_uid;

  -- actor_id on someone else's session (e.g. an admin acting on a session
  -- that isn't theirs) isn't covered by the sessions delete below.
  UPDATE public.session_events SET actor_id = NULL WHERE actor_id = target_uid;

  DELETE FROM public.device_tokens   WHERE user_id = target_uid;
  DELETE FROM public.lesson_progress WHERE student_id = target_uid;
  UPDATE public.system_settings SET updated_by = NULL WHERE updated_by = target_uid;

  -- Sessions (cascades: session_events, session_messages, remaining payments/disputes/reviews)
  DELETE FROM public.sessions WHERE student_id = target_uid OR teacher_id = target_uid;

  -- teacher_earnings.subscription_id can reference a subscription owned by
  -- a student while teacher_id belongs to someone else entirely.
  DELETE FROM public.teacher_earnings
  WHERE subscription_id IN (SELECT id FROM public.subscriptions WHERE student_id = target_uid);

  -- Subscriptions
  DELETE FROM public.subscriptions WHERE student_id = target_uid;

  -- Teacher-only data (cascades: teacher_availability)
  DELETE FROM public.teacher_profiles WHERE id = target_uid;

  -- Profile + auth account (courses.teacher_id auto SET NULL on this)
  DELETE FROM public.profiles WHERE id = target_uid;
  DELETE FROM auth.users      WHERE id = target_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_delete_user(uuid) TO authenticated;
