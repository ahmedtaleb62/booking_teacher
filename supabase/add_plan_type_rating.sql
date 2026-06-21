-- Add plan_type to subscriptions (monthly / yearly)
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS plan_type TEXT DEFAULT 'monthly';

-- Add rating to courses (admin-set, e.g. 4.8)
ALTER TABLE courses ADD COLUMN IF NOT EXISTS rating DECIMAL(2,1);

-- Add file_pages to course_lessons (used when lesson_type = 'file')
ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS file_pages INT DEFAULT 0;
