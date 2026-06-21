-- Add student_level to sessions (the grade/class the student is in)
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS student_level TEXT;

-- Add teaching_levels to teacher_profiles (which levels the teacher teaches)
ALTER TABLE teacher_profiles ADD COLUMN IF NOT EXISTS teaching_levels TEXT[] DEFAULT '{}';
