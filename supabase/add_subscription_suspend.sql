-- Admin can manually suspend/reactivate an active subscription.
-- Access to course_lessons is already gated purely on status = 'active'
-- (see course_lessons_select / lessons_read / students_can_view_subscribed_lessons
-- RLS policies), so simply moving status to 'suspended' blocks content access
-- with no RLS changes needed.

ALTER TABLE public.subscriptions DROP CONSTRAINT subscriptions_status_check;
ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_status_check
  CHECK (status = ANY (ARRAY['pending', 'active', 'expired', 'rejected', 'suspended']));

CREATE OR REPLACE FUNCTION public.notify_subscription_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
        IF OLD.status = 'suspended' THEN
          v_title := CASE v_lang WHEN 'fr' THEN 'Abonnement réactivé ✅'
            ELSE 'تم تفعيل اشتراكك ✅' END;
          v_body := CASE v_lang WHEN 'fr'
            THEN 'يمكنك الآن الوصول مجدداً إلى ' || v_content_name
            ELSE 'يمكنك الآن الوصول مجدداً إلى ' || v_content_name END;
          v_type := 'SUB_REACTIVATED';
        ELSE
          v_title := CASE v_lang WHEN 'fr' THEN 'Abonnement accepté ✅'
            ELSE 'تم قبول اشتراكك ✅' END;
          v_body := CASE v_lang WHEN 'fr'
            THEN 'Vous avez maintenant accès à tous les cours de ' || v_content_name
            ELSE 'يمكنك الآن الوصول إلى جميع دروس ' || v_content_name END;
          v_type := 'SUB_ACTIVE';
        END IF;
      WHEN 'suspended' THEN
        v_title := CASE v_lang WHEN 'fr' THEN 'Abonnement suspendu ⛔'
          ELSE 'تم تعطيل اشتراكك ⛔' END;
        v_body := CASE v_lang WHEN 'fr'
          THEN 'تم تعطيل وصولك إلى ' || v_content_name || ' من قِبل الإدارة.'
          ELSE 'تم تعطيل وصولك إلى ' || v_content_name || ' من قِبل الإدارة.' END;
        v_type := 'SUB_SUSPENDED';
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
$function$;
