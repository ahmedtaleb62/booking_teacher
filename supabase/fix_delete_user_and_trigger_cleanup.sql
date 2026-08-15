-- ══════════════════════════════════════════════════════════════════
-- 1) Remove duplicate profile-creation trigger on auth.users.
--    Two triggers ("on_auth_user_created" and "trg_on_auth_user_created")
--    both called handle_new_user() — harmless (ON CONFLICT DO NOTHING)
--    but redundant. Only trg_on_auth_user_created is tracked in the
--    repo (bootstrap.sql / schema.sql), so that's the one kept.
-- ══════════════════════════════════════════════════════════════════
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- ══════════════════════════════════════════════════════════════════
-- 2) admin_delete_user — was failing with FK violations because it
--    only cleared a subset of the tables that reference profiles/
--    auth.users. Any user with rows in reviews, ledger_entries,
--    teacher_earnings, disputes (opened_by/resolved_by), or
--    payments.confirmed_by would abort the whole delete with
--    "violates foreign key constraint ... is not present".
--    This version clears every table found via a live FK audit
--    (information_schema) so deletion always fully succeeds.
-- ══════════════════════════════════════════════════════════════════
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

  DELETE FROM public.device_tokens   WHERE user_id = target_uid;
  DELETE FROM public.lesson_progress WHERE student_id = target_uid;
  UPDATE public.system_settings SET updated_by = NULL WHERE updated_by = target_uid;

  -- Sessions (cascades: session_events, session_messages, remaining payments/disputes/reviews)
  DELETE FROM public.sessions WHERE student_id = target_uid OR teacher_id = target_uid;

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

NOTIFY pgrst, 'reload schema';
