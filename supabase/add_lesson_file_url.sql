-- Add file_url to course_lessons for PDF/doc attachments per lesson
ALTER TABLE public.course_lessons ADD COLUMN IF NOT EXISTS file_url TEXT;
