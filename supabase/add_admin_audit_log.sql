-- Unified admin audit trail. Every sensitive admin action (delete, suspend,
-- cancel+refund, dispute resolution, etc.) writes one row here, regardless
-- of which RPC or admin-panel page triggered it.

CREATE TABLE IF NOT EXISTS public.admin_audit_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  action      text NOT NULL,
  target_type text NOT NULL,
  target_id   uuid,
  details     jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created_at ON public.admin_audit_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin_id   ON public.admin_audit_log (admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_target     ON public.admin_audit_log (target_type, target_id);

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY admin_audit_log_select_admin ON public.admin_audit_log
  FOR SELECT USING (public.is_admin());

-- No INSERT/UPDATE/DELETE policy for regular clients — rows are only ever
-- written by SECURITY DEFINER functions (log_admin_action) or the trigger
-- below, both of which run as the function owner and bypass RLS.

CREATE OR REPLACE FUNCTION public.log_admin_action(
  p_admin_id    uuid,
  p_action      text,
  p_target_type text,
  p_target_id   uuid,
  p_details     jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.admin_audit_log (admin_id, action, target_type, target_id, details)
  VALUES (p_admin_id, p_action, p_target_type, p_target_id, p_details);
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_admin_action(uuid, text, text, uuid, jsonb) TO authenticated;

-- ── Trigger: catch suspend/activate/device-unlink done via direct table
-- update (Users.jsx does these as plain UPDATEs, not RPCs) ────────────────
CREATE OR REPLACE FUNCTION public.log_profile_admin_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _actor uuid := auth.uid();
BEGIN
  -- Only log when an admin acts on SOMEONE ELSE's profile (not self-edits)
  IF _actor IS NULL OR _actor = NEW.id THEN
    RETURN NEW;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = _actor AND role = 'admin') THEN
    RETURN NEW;
  END IF;

  IF OLD.is_active IS DISTINCT FROM NEW.is_active THEN
    PERFORM public.log_admin_action(_actor,
      CASE WHEN NEW.is_active THEN 'activate_account' ELSE 'suspend_account' END,
      'user', NEW.id, jsonb_build_object('full_name', NEW.full_name));
  END IF;

  IF OLD.device_id IS NOT NULL AND NEW.device_id IS NULL THEN
    PERFORM public.log_admin_action(_actor, 'unlink_device', 'user', NEW.id,
      jsonb_build_object('full_name', NEW.full_name));
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_profile_admin_changes ON public.profiles;
CREATE TRIGGER trg_log_profile_admin_changes
  AFTER UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.log_profile_admin_changes();
