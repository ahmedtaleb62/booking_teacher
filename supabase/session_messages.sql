-- ══════════════════════════════════════════════════════════════════
-- Session Messages (in-session chat)
-- Run this in Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- 1. Create table
CREATE TABLE IF NOT EXISTS public.session_messages (
  id           uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  session_id   uuid        NOT NULL REFERENCES public.sessions(id) ON DELETE CASCADE,
  sender_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type         text        NOT NULL CHECK (type IN ('text', 'image', 'audio', 'file')),
  content      text,
  file_url     text,
  duration_sec integer,
  created_at   timestamptz DEFAULT now()
);

-- Index for fast ordered fetches per session
CREATE INDEX IF NOT EXISTS idx_session_messages_session_created
  ON public.session_messages (session_id, created_at);

-- 2. Enable RLS
ALTER TABLE public.session_messages ENABLE ROW LEVEL SECURITY;

-- Participants in the session (student or teacher) can read messages
CREATE POLICY "Session participants can read messages"
  ON public.session_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.sessions s
      WHERE s.id = session_id
        AND (s.student_id = auth.uid() OR s.teacher_id = auth.uid())
    )
  );

-- Participants can insert messages
CREATE POLICY "Session participants can send messages"
  ON public.session_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.sessions s
      WHERE s.id = session_id
        AND (s.student_id = auth.uid() OR s.teacher_id = auth.uid())
    )
  );

-- Enable realtime for live subscription (safe — ignores if already added)
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.session_messages;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ══════════════════════════════════════════════════════════════════
-- 3. Storage bucket for media (images, audio, files)
-- ══════════════════════════════════════════════════════════════════

INSERT INTO storage.buckets (id, name, public)
VALUES ('session-media', 'session-media', true)
ON CONFLICT (id) DO NOTHING;

-- Authenticated users can upload to their own folder
CREATE POLICY "Users upload session media"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'session-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Everyone can read (bucket is public)
CREATE POLICY "Public read session media"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'session-media');

-- Users can delete their own uploads
CREATE POLICY "Users delete own session media"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'session-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ══════════════════════════════════════════════════════════════════
-- 4. Packages table — add yearly price and discount price columns
--    (safe to run even if columns already exist)
-- ══════════════════════════════════════════════════════════════════

ALTER TABLE public.packages
  ADD COLUMN IF NOT EXISTS price_yearly   numeric,
  ADD COLUMN IF NOT EXISTS original_price numeric;

-- ══════════════════════════════════════════════════════════════════
-- 5. System settings — seed commission defaults if not present
-- ══════════════════════════════════════════════════════════════════

INSERT INTO public.system_settings (key, value)
VALUES
  ('session_commission_pct',      '15'),
  ('subscription_commission_pct', '15')
ON CONFLICT (key) DO NOTHING;
