-- RPC: get_course_lesson_outline
-- Returns lesson titles + metadata for ANY authenticated user (no video_url).
-- SECURITY DEFINER bypasses row-level security so non-subscribers can
-- browse the full lesson structure. video_url is intentionally excluded.

CREATE OR REPLACE FUNCTION public.get_course_lesson_outline(p_course_id UUID)
RETURNS TABLE (
  id               UUID,
  title            TEXT,
  chapter_title    TEXT,
  order_index      INTEGER,
  duration_minutes INTEGER,
  is_preview       BOOLEAN,
  lesson_type      TEXT,
  file_pages       INTEGER
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    id,
    title,
    chapter_title,
    order_index,
    duration_minutes,
    is_preview,
    lesson_type,
    file_pages
  FROM public.course_lessons
  WHERE course_id = p_course_id
  ORDER BY order_index;
$$;

GRANT EXECUTE ON FUNCTION public.get_course_lesson_outline(UUID) TO authenticated;
