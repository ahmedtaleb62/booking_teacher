-- Table: complaints
-- General feedback channel (complaint or suggestion) students submit from
-- the profile screen. Separate from session/payment disputes, which are
-- handled entirely outside the app via WhatsApp.

CREATE TABLE IF NOT EXISTS public.complaints (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  type        text NOT NULL CHECK (type IN ('complaint', 'suggestion')),
  message     text NOT NULL,
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed')),
  admin_note  text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz
);

ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

CREATE POLICY complaints_insert_own ON public.complaints
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY complaints_select_own ON public.complaints
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY complaints_select_admin ON public.complaints
  FOR SELECT USING (public.is_admin());

CREATE POLICY complaints_update_admin ON public.complaints
  FOR UPDATE USING (public.is_admin());

GRANT SELECT, INSERT, UPDATE ON public.complaints TO authenticated;
