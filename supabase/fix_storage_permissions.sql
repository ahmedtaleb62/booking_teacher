-- ================================================================
-- FIX: Storage upload permission denied
-- Run in Supabase SQL Editor
-- ================================================================

-- 1. Create buckets (safe to re-run)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES
  ('course-videos', 'course-videos', true, 524288000),  -- 500 MB
  ('course-files',  'course-files',  true, 52428800)    -- 50 MB
ON CONFLICT (id) DO NOTHING;

-- 2. Drop old policies if any
DROP POLICY IF EXISTS "authenticated can upload course-videos" ON storage.objects;
DROP POLICY IF EXISTS "public can read course-videos"         ON storage.objects;
DROP POLICY IF EXISTS "authenticated can delete course-videos" ON storage.objects;
DROP POLICY IF EXISTS "authenticated can upload course-files"  ON storage.objects;
DROP POLICY IF EXISTS "public can read course-files"           ON storage.objects;
DROP POLICY IF EXISTS "authenticated can delete course-files"  ON storage.objects;

-- 3. Policies for course-videos
CREATE POLICY "authenticated can upload course-videos"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'course-videos');

CREATE POLICY "public can read course-videos"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'course-videos');

CREATE POLICY "authenticated can update course-videos"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'course-videos');

CREATE POLICY "authenticated can delete course-videos"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'course-videos');

-- 4. Policies for course-files
CREATE POLICY "authenticated can upload course-files"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'course-files');

CREATE POLICY "public can read course-files"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'course-files');

CREATE POLICY "authenticated can update course-files"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'course-files');

CREATE POLICY "authenticated can delete course-files"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'course-files');
