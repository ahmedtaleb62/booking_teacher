-- RPC: admin_create_manual_subscription
-- Lets an admin activate a course/package subscription on behalf of a
-- student who paid outside the app (e.g. via WhatsApp), so the teacher
-- still gets their earnings share and the platform its commission.
--
-- Reuses admin_confirm_subscription (which already sets started_at/
-- expires_at, fires the "subscription active" notification, and the
-- trg_subscription_earnings trigger that splits/credits ledger_entries)
-- by inserting a pending row first, then confirming it in the same call.

CREATE OR REPLACE FUNCTION public.admin_create_manual_subscription(
  p_student_id  uuid,
  p_course_id   uuid,
  p_package_id  uuid,
  p_amount      numeric,
  p_plan_type   text,
  p_months      integer,
  p_admin_id    uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _sub_id uuid;
  _type   text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF (p_course_id IS NULL) = (p_package_id IS NULL) THEN
    RAISE EXCEPTION 'exactly one of course_id or package_id must be provided';
  END IF;

  _type := CASE WHEN p_course_id IS NOT NULL THEN 'course' ELSE 'package' END;

  IF EXISTS (
    SELECT 1 FROM public.subscriptions
    WHERE student_id = p_student_id
      AND status IN ('active', 'pending')
      AND ((p_course_id  IS NOT NULL AND course_id  = p_course_id)
        OR (p_package_id IS NOT NULL AND package_id = p_package_id))
  ) THEN
    RAISE EXCEPTION 'student already has an active or pending subscription for this item';
  END IF;

  INSERT INTO public.subscriptions (student_id, type, course_id, package_id, amount, plan_type, status)
  VALUES (p_student_id, _type, p_course_id, p_package_id, p_amount, p_plan_type, 'pending')
  RETURNING id INTO _sub_id;

  PERFORM public.admin_confirm_subscription(_sub_id, p_admin_id, p_months);

  RETURN _sub_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_create_manual_subscription(uuid, uuid, uuid, numeric, text, integer, uuid) TO authenticated;
