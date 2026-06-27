-- Creates the RPC called by reset_password_screen.dart after OTP verification.
-- Uses SECURITY DEFINER so it can write to auth.users.
-- pgcrypto (crypt / gen_salt) is enabled by default in Supabase projects.

CREATE OR REPLACE FUNCTION public.reset_password_by_phone(
  p_phone        TEXT,
  p_new_password TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email TEXT;
  v_user_id UUID;
BEGIN
  -- Build the synthetic email that OtpService.phoneToEmail() produces
  v_email := trim(p_phone) || '@hessati.app';

  -- Verify the user exists
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = v_email
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'رقم الهاتف غير مسجّل في التطبيق' USING ERRCODE = 'P0001';
  END IF;

  -- Update the hashed password directly in auth.users
  UPDATE auth.users
  SET
    encrypted_password = crypt(p_new_password, gen_salt('bf')),
    updated_at         = NOW()
  WHERE id = v_user_id;
END;
$$;

-- Only the service role may call this function (called server-side via Supabase RPC)
REVOKE ALL ON FUNCTION public.reset_password_by_phone(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reset_password_by_phone(TEXT, TEXT) TO authenticated;
