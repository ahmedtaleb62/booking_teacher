-- Fix: Add DELETE and UPDATE RLS policies for session_messages
-- Run in Supabase Dashboard → SQL Editor

-- Allow users to delete their own messages
CREATE POLICY "Users can delete own messages"
  ON public.session_messages FOR DELETE
  USING (sender_id = auth.uid());

-- Allow users to edit their own text messages
CREATE POLICY "Users can update own messages"
  ON public.session_messages FOR UPDATE
  USING (sender_id = auth.uid())
  WITH CHECK (sender_id = auth.uid());
