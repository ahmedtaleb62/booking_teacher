-- Run this in Supabase SQL Editor
CREATE OR REPLACE FUNCTION public.admin_settle_teacher(
  p_teacher_id  uuid,
  p_amount      numeric,
  p_description text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only admins may call this
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  INSERT INTO public.ledger_entries
    (teacher_id, type, amount, commission, net_amount, description)
  VALUES
    (p_teacher_id, 'payout_sent', p_amount, 0, -p_amount, p_description);

  INSERT INTO public.notifications
    (user_id, title, body, type)
  VALUES
    (
      p_teacher_id,
      'تمت تسوية مستحقاتك 💰',
      'تم تحويل مستحقاتك البالغة ' || p_amount || ' أوقية — ' || p_description,
      'payout_sent'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_settle_teacher(uuid, numeric, text) TO authenticated;
