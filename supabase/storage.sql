-- ============================================================
-- Supabase Storage Buckets
-- Run in SQL Editor AFTER schema.sql
-- ============================================================

-- Payment proof images (private — only student/admin can read)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'payment-proofs',
  'payment-proofs',
  false,
  5242880, -- 5 MB
  ARRAY['image/jpeg','image/png','image/webp','image/heic']
) ON CONFLICT (id) DO NOTHING;

-- User avatars (public)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  2097152, -- 2 MB
  ARRAY['image/jpeg','image/png','image/webp']
) ON CONFLICT (id) DO NOTHING;

-- ── Storage RLS policies ─────────────────────────────────────

-- payment-proofs: student can upload their own proof
CREATE POLICY "payment_proof_upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'payment-proofs'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- payment-proofs: student can read their own proofs
CREATE POLICY "payment_proof_read_own"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment-proofs'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- payment-proofs: admin can read all
CREATE POLICY "payment_proof_read_admin"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment-proofs'
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- avatars: anyone can read (public bucket)
CREATE POLICY "avatars_read_all"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- avatars: authenticated user can upload their own
CREATE POLICY "avatars_upload_own"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- avatars: owner can update/delete
CREATE POLICY "avatars_modify_own"
  ON storage.objects FOR UPDATE USING (
    bucket_id = 'avatars'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
