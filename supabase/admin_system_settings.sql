-- Run this in Supabase SQL Editor (replace previous version)

-- Read all settings — returns value as plain text
CREATE OR REPLACE FUNCTION public.get_system_settings()
RETURNS TABLE(key text, value text)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT key, value::text FROM public.system_settings;
$$;

GRANT EXECUTE ON FUNCTION public.get_system_settings() TO authenticated, anon;

-- Write settings — admins only
-- Values arrive as text and are stored as jsonb numbers
CREATE OR REPLACE FUNCTION public.admin_upsert_settings(p_entries jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  rec jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  FOR rec IN SELECT * FROM jsonb_array_elements(p_entries)
  LOOP
    INSERT INTO public.system_settings (key, value)
    VALUES (rec->>'key', to_jsonb((rec->>'value')::numeric))
    ON CONFLICT (key) DO UPDATE
      SET value = to_jsonb((rec->>'value')::numeric);
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_settings(jsonb) TO authenticated;
