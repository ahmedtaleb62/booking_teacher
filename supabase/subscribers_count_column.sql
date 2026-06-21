-- ─────────────────────────────────────────────────────────────────
-- Denormalize subscribers_count on courses to avoid RLS issues
-- (students can't read other students' subscriptions)
-- ─────────────────────────────────────────────────────────────────

ALTER TABLE public.courses
  ADD COLUMN IF NOT EXISTS subscribers_count INTEGER NOT NULL DEFAULT 0;

-- Back-fill existing counts
UPDATE public.courses c
SET subscribers_count = (
  SELECT COUNT(*)::INTEGER
  FROM public.subscriptions s
  WHERE s.course_id = c.id AND s.status = 'active'
);

-- Trigger function: keep subscribers_count in sync
CREATE OR REPLACE FUNCTION public.sync_course_subscribers_count()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- On INSERT: only if already active
  IF TG_OP = 'INSERT' AND NEW.status = 'active' AND NEW.course_id IS NOT NULL THEN
    UPDATE public.courses
      SET subscribers_count = GREATEST(subscribers_count + 1, 0)
      WHERE id = NEW.course_id;

  -- On UPDATE: status changed to active
  ELSIF TG_OP = 'UPDATE' AND NEW.course_id IS NOT NULL THEN
    IF NEW.status = 'active' AND (OLD.status IS DISTINCT FROM 'active') THEN
      UPDATE public.courses
        SET subscribers_count = GREATEST(subscribers_count + 1, 0)
        WHERE id = NEW.course_id;
    ELSIF OLD.status = 'active' AND (NEW.status IS DISTINCT FROM 'active') THEN
      UPDATE public.courses
        SET subscribers_count = GREATEST(subscribers_count - 1, 0)
        WHERE id = NEW.course_id;
    END IF;

  -- On DELETE: if it was active
  ELSIF TG_OP = 'DELETE' AND OLD.status = 'active' AND OLD.course_id IS NOT NULL THEN
    UPDATE public.courses
      SET subscribers_count = GREATEST(subscribers_count - 1, 0)
      WHERE id = OLD.course_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_subscribers_count ON public.subscriptions;
CREATE TRIGGER trg_sync_subscribers_count
  AFTER INSERT OR UPDATE OF status OR DELETE ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.sync_course_subscribers_count();
