-- Fix: Allow students to read, insert, and update reviews they submitted
-- Run in Supabase Dashboard → SQL Editor

DROP POLICY IF EXISTS "Students can read their own reviews" ON public.reviews;
DROP POLICY IF EXISTS "Students can insert reviews" ON public.reviews;
DROP POLICY IF EXISTS "Students can update own reviews" ON public.reviews;

CREATE POLICY "Students can read their own reviews"
  ON public.reviews FOR SELECT
  USING (student_id = auth.uid());

CREATE POLICY "Students can insert reviews"
  ON public.reviews FOR INSERT
  WITH CHECK (student_id = auth.uid());

CREATE POLICY "Students can update own reviews"
  ON public.reviews FOR UPDATE
  USING (student_id = auth.uid())
  WITH CHECK (student_id = auth.uid());
