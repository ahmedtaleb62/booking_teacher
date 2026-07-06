-- Fix: Add DELETE and UPDATE RLS policies for session_messages
-- Run in Supabase Dashboard → SQL Editor
-- Safe to re-run: DROP IF EXISTS prevents "policy already exists" errors

-- ── Remove old versions if present ──────────────────────────────────────────
DROP POLICY IF EXISTS "Users can delete own messages" ON public.session_messages;
DROP POLICY IF EXISTS "Users can update own messages" ON public.session_messages;

-- ── Allow users to delete their own messages ─────────────────────────────────
CREATE POLICY "Users can delete own messages"
  ON public.session_messages FOR DELETE
  USING (sender_id = auth.uid());

-- ── Allow users to edit their own messages ───────────────────────────────────
-- USING: row the user is allowed to touch must be theirs
-- WITH CHECK: they cannot change sender_id to someone else
CREATE POLICY "Users can update own messages"
  ON public.session_messages FOR UPDATE
  USING (sender_id = auth.uid())
  WITH CHECK (sender_id = auth.uid());
