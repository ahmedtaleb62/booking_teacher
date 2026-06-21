-- ══════════════════════════════════════════════════════════════════
-- Subscription notifications + Realtime setup
-- Run this SQL in: Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- ── 1. Enable Realtime on notifications table ───────────────────────
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END;
$$;

-- ── 2. RLS for notifications ────────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own notifications"   ON public.notifications;
DROP POLICY IF EXISTS "System insert notifications"    ON public.notifications;
DROP POLICY IF EXISTS "Users mark notifications read"  ON public.notifications;

CREATE POLICY "Users read own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

-- SECURITY DEFINER triggers bypass RLS, but let's also allow any
-- authenticated user's trigger to insert (trigger runs as definer anyway)
CREATE POLICY "System insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (TRUE);

CREATE POLICY "Users mark notifications read"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE ON public.notifications TO authenticated;

-- ── 3. Trigger function: notify student on subscription change ──────
CREATE OR REPLACE FUNCTION public.notify_subscription_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_title        TEXT;
  v_body         TEXT;
  v_type         TEXT;
  v_content_name TEXT;
BEGIN
  -- Resolve content name (course or package)
  IF NEW.course_id IS NOT NULL THEN
    SELECT title INTO v_content_name FROM public.courses WHERE id = NEW.course_id;
  ELSIF NEW.package_id IS NOT NULL THEN
    SELECT title INTO v_content_name FROM public.packages WHERE id = NEW.package_id;
  END IF;
  v_content_name := COALESCE(v_content_name, 'الدورة');

  -- INSERT: always starts as pending
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    v_title := 'طلب الاشتراك قيد المراجعة ⏳';
    v_body  := 'سيتم مراجعة دفعتك والتأكيد خلال 24 ساعة · ' || v_content_name;
    v_type  := 'SUB_PENDING';

  -- UPDATE: status changed
  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    CASE NEW.status
      WHEN 'active' THEN
        v_title := 'تم قبول اشتراكك ✅';
        v_body  := 'يمكنك الآن الوصول إلى جميع دروس ' || v_content_name;
        v_type  := 'SUB_ACTIVE';
      WHEN 'rejected' THEN
        v_title := 'تم رفض اشتراكك ❌';
        v_body  := 'تعذّر تأكيد الدفعة في ' || v_content_name || '. تواصل مع الدعم للحصول على المساعدة.';
        v_type  := 'SUB_REJECTED';
      ELSE
        RETURN NEW; -- ignore other status changes (e.g. expired)
    END CASE;
  ELSE
    RETURN NEW; -- nothing to notify
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    NEW.student_id,
    v_title,
    v_body,
    v_type,
    jsonb_build_object('subscription_id', NEW.id::text)
  );

  RETURN NEW;
END;
$$;

-- ── 4. Attach triggers ──────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_subscription_pending ON public.subscriptions;
CREATE TRIGGER trg_subscription_pending
  AFTER INSERT ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.notify_subscription_status_change();

DROP TRIGGER IF EXISTS trg_subscription_status ON public.subscriptions;
CREATE TRIGGER trg_subscription_status
  AFTER UPDATE OF status ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.notify_subscription_status_change();
