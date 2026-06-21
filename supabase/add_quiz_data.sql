-- Add quiz_data column to store quiz questions for exercise lessons
ALTER TABLE public.course_lessons ADD COLUMN IF NOT EXISTS quiz_data JSONB DEFAULT NULL;
