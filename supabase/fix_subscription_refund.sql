-- ══════════════════════════════════════════════════════════════════
-- Fix: subscription rejection with refund amount
-- Problems fixed:
--   1. subscriptions table had no actual_refund_amount column, so the
--      admin-entered refund amount was silently dropped (Payments.jsx
--      wrapped the update in try/catch "if column exists").
--   2. admin_reject_subscription() only set status/reject_reason —
--      the refund amount was set in a second, separate JS call, racing
--      with the trg_subscription_status trigger.
--   3. trg_subscription_status always fired the generic "rejected —
--      contact support" notification on status → 'rejected', even when
--      the admin panel also sent a second, contradictory "refund coming
--      soon" notification manually from JS. Now the trigger itself sends
--      the correct bilingual refund message and the JS-side manual
--      insert is no longer needed.
-- Run in Supabase Dashboard → SQL Editor (after add_language_preference.sql)
-- ══════════════════════════════════════════════════════════════════

-- 1. New column on subscriptions
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS actual_refund_amount NUMERIC;

-- 2. admin_reject_subscription — now accepts the refund amount atomically
CREATE OR REPLACE FUNCTION public.admin_reject_subscription(
  p_subscription_id UUID,
  p_admin_id        UUID,
  p_reason          TEXT    DEFAULT '',
  p_refund_amount   NUMERIC DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.subscriptions
  SET
    status               = 'rejected',
    reject_reason        = p_reason,
    actual_refund_amount = p_refund_amount,
    updated_at           = NOW()
  WHERE id = p_subscription_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reject_subscription(UUID, UUID, TEXT, NUMERIC) TO authenticated;

-- 3. notify_subscription_status_change — refund-aware bilingual rejection notice
CREATE OR REPLACE FUNCTION public.notify_subscription_status_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_title        TEXT;
  v_body         TEXT;
  v_type         TEXT;
  v_content_name TEXT;
  v_lang         TEXT;
BEGIN
  IF NEW.course_id IS NOT NULL THEN
    SELECT title INTO v_content_name FROM public.courses WHERE id = NEW.course_id;
  ELSIF NEW.package_id IS NOT NULL THEN
    SELECT title INTO v_content_name FROM public.packages WHERE id = NEW.package_id;
  END IF;
  v_content_name := COALESCE(v_content_name, '');
  v_lang := user_lang(NEW.student_id);

  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    v_title := CASE v_lang WHEN 'fr' THEN 'Abonnement en cours de vérification ⏳'
      ELSE 'طلب الاشتراك قيد المراجعة ⏳' END;
    v_body := CASE v_lang WHEN 'fr'
      THEN 'Votre paiement sera vérifié et confirmé sous 24h · ' || v_content_name
      ELSE 'سيتم مراجعة دفعتك والتأكيد خلال 24 ساعة · ' || v_content_name END;
    v_type := 'SUB_PENDING';

  ELSIF TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status THEN
    CASE NEW.status
      WHEN 'active' THEN
        v_title := CASE v_lang WHEN 'fr' THEN 'Abonnement accepté ✅'
          ELSE 'تم قبول اشتراكك ✅' END;
        v_body := CASE v_lang WHEN 'fr'
          THEN 'Vous avez maintenant accès à tous les cours de ' || v_content_name
          ELSE 'يمكنك الآن الوصول إلى جميع دروس ' || v_content_name END;
        v_type := 'SUB_ACTIVE';
      WHEN 'rejected' THEN
        IF NEW.actual_refund_amount IS NOT NULL THEN
          v_title := CASE v_lang WHEN 'fr' THEN 'Abonnement refusé — remboursement en cours 💰'
            ELSE 'تم إلغاء اشتراكك وسيُسترد مبلغك 💰' END;
          v_body := CASE v_lang WHEN 'fr'
            THEN 'Le montant payé pour ' || v_content_name || ' est insuffisant. ' ||
                 NEW.actual_refund_amount::TEXT || ' MRU vous seront remboursés prochainement.'
            ELSE 'المبلغ المدفوع في ' || v_content_name || ' غير كافٍ. سيُسترد لك ' ||
                 NEW.actual_refund_amount::TEXT || ' أوقية قريباً.' END;
          v_type := 'SUB_REJECTED_REFUND';
        ELSE
          v_title := CASE v_lang WHEN 'fr' THEN 'Abonnement refusé ❌'
            ELSE 'تم رفض اشتراكك ❌' END;
          v_body := CASE v_lang WHEN 'fr'
            THEN 'Nous n''avons pas pu confirmer votre paiement pour ' || v_content_name || '. Contactez le support.'
            ELSE 'تعذّر تأكيد الدفعة في ' || v_content_name || '. تواصل مع الدعم للحصول على المساعدة.' END;
          v_type := 'SUB_REJECTED';
        END IF;
      ELSE
        RETURN NEW;
    END CASE;
  ELSE
    RETURN NEW;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (NEW.student_id, v_title, v_body, v_type,
          jsonb_build_object('subscription_id', NEW.id::text));
  RETURN NEW;
END;
$$;

NOTIFY pgrst, 'reload schema';
