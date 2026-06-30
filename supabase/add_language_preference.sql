-- ══════════════════════════════════════════════════════════════════
-- Bilingual Notifications — Arabic + French
-- Run in Supabase Dashboard → SQL Editor
-- Depends on: fix_notifications_final.sql already applied
-- ══════════════════════════════════════════════════════════════════

-- ── 1. Add language_preference column to profiles ───────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS language_preference TEXT NOT NULL DEFAULT 'ar'
  CHECK (language_preference IN ('ar', 'fr'));

-- Allow users to update their own language preference
DROP POLICY IF EXISTS "profiles_update_lang" ON public.profiles;
CREATE POLICY "profiles_update_lang"
  ON public.profiles FOR UPDATE
  USING  (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ── 2. Helper: read user language (STABLE = cached per query) ───
CREATE OR REPLACE FUNCTION public.user_lang(p_user_id UUID)
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT COALESCE(language_preference, 'ar')
  FROM public.profiles WHERE id = p_user_id
$$;

-- ── 3. on_session_state_change — full bilingual version ─────────
CREATE OR REPLACE FUNCTION on_session_state_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_commission_pct NUMERIC := 0.15;
  v_student_id     UUID := NEW.student_id;
  v_teacher_id     UUID := NEW.teacher_id;
  v_session_id     UUID := NEW.id;
  v_sl             TEXT; -- student language
  v_tl             TEXT; -- teacher language
BEGIN
  IF OLD.state = NEW.state THEN RETURN NEW; END IF;

  INSERT INTO session_events (session_id, event_type, actor, metadata)
  VALUES (v_session_id, NEW.state::TEXT, 'system',
          jsonb_build_object('from', OLD.state, 'to', NEW.state));

  v_sl := user_lang(v_student_id);
  v_tl := user_lang(v_teacher_id);

  CASE NEW.state

    -- ── Teacher approved → AWAITING_PAYMENT ──────────────────────
    WHEN 'TEACHER_APPROVED' THEN
      NEW.state            := 'AWAITING_PAYMENT';
      NEW.payment_deadline := now() + interval '1 hour';
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
        CASE v_sl WHEN 'fr' THEN 'Demande acceptée 🎉'
          ELSE 'وافق الأستاذ على طلبك 🎉' END,
        CASE v_sl WHEN 'fr' THEN 'Vous avez une heure pour envoyer la preuve de paiement'
          ELSE 'لديك ساعة واحدة لإرسال إثبات الدفع' END,
        'session_approved', v_session_id);

    -- ── Admin confirmed → CONFIRMED_BOOKING + ledger ─────────────
    WHEN 'PAYMENT_CONFIRMED' THEN
      SELECT (value::TEXT::NUMERIC) / 100.0 INTO v_commission_pct
      FROM system_settings WHERE key = 'session_commission_pct';
      v_commission_pct := COALESCE(v_commission_pct, 0.15);
      NEW.state := 'CONFIRMED_BOOKING';
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id,
          CASE v_sl WHEN 'fr' THEN 'Réservation confirmée ✅'
            ELSE 'تم تأكيد حجزك ✅' END,
          CASE v_sl WHEN 'fr' THEN 'Votre cours est confirmé. Soyez à l''heure.'
            ELSE 'جلستك مؤكّدة. احضر في الموعد.' END,
          'payment_confirmed', v_session_id),
        (v_teacher_id,
          CASE v_tl WHEN 'fr' THEN 'Nouvelle réservation confirmée'
            ELSE 'حجز مؤكّد جديد' END,
          CASE v_tl WHEN 'fr' THEN 'Un élève a confirmé sa réservation — préparez-vous.'
            ELSE 'طالب أكّد حجزه معك — استعد للجلسة.' END,
          'payment_confirmed', v_session_id);
      INSERT INTO ledger_entries
        (session_id, student_id, teacher_id, type, amount, commission, net_amount, description)
      VALUES
        (v_session_id, v_student_id, v_teacher_id,
         'session_payment', NEW.amount,
         NEW.amount * v_commission_pct,
         NEW.amount * (1.0 - v_commission_pct),
         'دفعة جلسة مؤكّدة');

    -- ── Teacher opened room → student only ───────────────────────
    WHEN 'ACTIVE_SESSION' THEN
      NEW.started_at := now();
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
        CASE v_sl WHEN 'fr' THEN 'Votre cours a commencé 📚'
          ELSE 'جلستك بدأت الآن 📚' END,
        CASE v_sl WHEN 'fr' THEN 'Le professeur vous attend — rejoignez la salle maintenant.'
          ELSE 'الأستاذ في انتظارك — ادخل الغرفة الآن.' END,
        'session_started', v_session_id);

    -- ── Session completed ─────────────────────────────────────────
    WHEN 'COMPLETED' THEN
      NEW.ended_at := now();
      UPDATE teacher_profiles SET total_sessions = total_sessions + 1 WHERE id = v_teacher_id;
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES
        (v_student_id,
          CASE v_sl WHEN 'fr' THEN 'Cours terminé ⭐'
            ELSE 'اكتملت جلستك ⭐' END,
          CASE v_sl WHEN 'fr' THEN 'Comment s''est passé votre cours ? Évaluez votre professeur.'
            ELSE 'كيف كانت تجربتك؟ قيّم أستاذك الآن.' END,
          'session_completed', v_session_id),
        (v_teacher_id,
          CASE v_tl WHEN 'fr' THEN 'Cours terminé ✅'
            ELSE 'اكتملت الجلسة ✅' END,
          CASE v_tl WHEN 'fr' THEN 'Ce cours a été ajouté à votre historique et vos gains.'
            ELSE 'أُضيفت الجلسة إلى سجلك وأرباحك.' END,
          'session_completed', v_session_id);

    -- ── Teacher rejected ──────────────────────────────────────────
    WHEN 'TEACHER_REJECTED' THEN
      INSERT INTO notifications (user_id, title, body, type, session_id)
      VALUES (v_student_id,
        CASE v_sl WHEN 'fr' THEN 'Demande refusée'
          ELSE 'اعتذر الأستاذ عن طلبك' END,
        COALESCE(NEW.rejection_reason,
          CASE v_sl WHEN 'fr' THEN 'Vous pouvez essayer un autre professeur'
            ELSE 'يمكنك تجربة أستاذ آخر' END),
        'session_rejected', v_session_id);

    -- ── Cancelled — reason-specific ───────────────────────────────
    WHEN 'CANCELLED' THEN
      NEW.ended_at := now();
      CASE

        WHEN NEW.cancellation_reason = 'student_cancelled' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id) VALUES
            (v_teacher_id,
              CASE v_tl WHEN 'fr' THEN 'Cours annulé par l''élève'
                ELSE 'ألغى الطالب الجلسة' END,
              CASE v_tl WHEN 'fr' THEN 'L''élève a annulé cette réservation.'
                ELSE 'قام الطالب بإلغاء هذا الحجز.' END,
              'session_cancelled', v_session_id),
            (v_student_id,
              CASE v_sl WHEN 'fr' THEN 'Cours annulé'
                ELSE 'تم إلغاء جلستك' END,
              CASE v_sl WHEN 'fr' THEN 'Vous avez annulé ce cours avec succès.'
                ELSE 'لقد ألغيت هذه الجلسة بنجاح.' END,
              'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason = 'teacher_timeout' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id) VALUES
            (v_student_id,
              CASE v_sl WHEN 'fr' THEN 'Délai de réponse dépassé'
                ELSE 'انتهت مهلة رد الأستاذ' END,
              CASE v_sl WHEN 'fr' THEN 'Le professeur n''a pas répondu à temps. Essayez un autre professeur.'
                ELSE 'لم يرد الأستاذ في الوقت المحدد. يمكنك تجربة أستاذ آخر.' END,
              'session_cancelled', v_session_id),
            (v_teacher_id,
              CASE v_tl WHEN 'fr' THEN 'Délai de réponse dépassé'
                ELSE 'طلب جلسة انتهت مهلته' END,
              CASE v_tl WHEN 'fr' THEN 'Vous n''avez pas répondu à une demande à temps — annulée automatiquement.'
                ELSE 'لم تردّ على طلب جلسة في الوقت المحدد وأُلغي تلقائياً.' END,
              'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason = 'payment_timeout' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id) VALUES
            (v_student_id,
              CASE v_sl WHEN 'fr' THEN 'Délai de paiement dépassé'
                ELSE 'انتهت مهلة الدفع — إلغاء تلقائي' END,
              CASE v_sl WHEN 'fr' THEN 'La preuve de paiement n''a pas été envoyée à temps — cours annulé.'
                ELSE 'لم يُرسل إثبات الدفع في الوقت المحدد فأُلغيت الجلسة.' END,
              'session_cancelled', v_session_id),
            (v_teacher_id,
              CASE v_tl WHEN 'fr' THEN 'Annulation — paiement incomplet'
                ELSE 'إلغاء — لم يكتمل الدفع' END,
              CASE v_tl WHEN 'fr' THEN 'L''élève n''a pas complété le paiement à temps.'
                ELSE 'لم يُكمل الطالب الدفع في الوقت المحدد.' END,
              'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason = 'fake_proof' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES (v_student_id,
            CASE v_sl WHEN 'fr' THEN 'Réservation annulée définitivement 🚫'
              ELSE 'رُفض حجزك نهائياً 🚫' END,
            CASE v_sl WHEN 'fr' THEN 'La preuve de paiement est invalide. Cours annulé sans remboursement.'
              ELSE 'الوصل المُرفَق غير حقيقي. تم إلغاء الجلسة ولن يُرد المبلغ.' END,
            'session_cancelled', v_session_id);

        WHEN NEW.cancellation_reason = 'insufficient_refund' THEN
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES (v_student_id,
            CASE v_sl WHEN 'fr' THEN 'Cours annulé — remboursement en cours 💰'
              ELSE 'تم إلغاء الجلسة وسيُسترد مبلغك 💰' END,
            CASE v_sl WHEN 'fr' THEN 'Le montant payé est insuffisant. Votre remboursement sera traité prochainement.'
              ELSE 'المبلغ المُرسَل أقل من المطلوب، سيُسترد مبلغك قريباً.' END,
            'session_cancelled', v_session_id);

        ELSE
          INSERT INTO notifications (user_id, title, body, type, session_id)
          VALUES (v_student_id,
            CASE v_sl WHEN 'fr' THEN 'Cours annulé' ELSE 'الجلسة ملغاة' END,
            CASE v_sl WHEN 'fr' THEN 'Ce cours a été annulé.' ELSE 'تم إلغاء هذه الجلسة.' END,
            'session_cancelled', v_session_id);
      END CASE;

    ELSE NULL;
  END CASE;

  RETURN NEW;
END;
$$;

-- ── 4. DB trigger: notify teacher on session request ────────────
--    Replaces the Flutter-side insert in session_service.dart
CREATE OR REPLACE FUNCTION public.notify_teacher_on_session_request()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_lang    TEXT;
  v_subject TEXT := COALESCE(NEW.subject, '');
BEGIN
  v_lang := user_lang(NEW.teacher_id);
  INSERT INTO public.notifications (user_id, title, body, type, session_id)
  VALUES (
    NEW.teacher_id,
    CASE v_lang WHEN 'fr' THEN 'Nouvelle demande de cours 📚'
      ELSE 'طلب جلسة جديد 📚' END,
    CASE v_lang
      WHEN 'fr' THEN 'Vous avez une nouvelle demande de cours en ' || v_subject
      ELSE            'لديك طلب جلسة جديد في مادة ' || v_subject
    END,
    'SESSION_REQUESTED',
    NEW.id
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_session_requested ON public.sessions;
CREATE TRIGGER trg_session_requested
  AFTER INSERT ON public.sessions
  FOR EACH ROW
  WHEN (NEW.state = 'REQUESTED')
  EXECUTE FUNCTION public.notify_teacher_on_session_request();

-- ── 5. notify_subscription_status_change — bilingual ───────────
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
        v_title := CASE v_lang WHEN 'fr' THEN 'Abonnement refusé ❌'
          ELSE 'تم رفض اشتراكك ❌' END;
        v_body := CASE v_lang WHEN 'fr'
          THEN 'Nous n''avons pas pu confirmer votre paiement pour ' || v_content_name || '. Contactez le support.'
          ELSE 'تعذّر تأكيد الدفعة في ' || v_content_name || '. تواصل مع الدعم للحصول على المساعدة.' END;
        v_type := 'SUB_REJECTED';
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

-- ── 6. admin_settle_teacher — bilingual ─────────────────────────
CREATE OR REPLACE FUNCTION public.admin_settle_teacher(
  p_teacher_id uuid, p_amount numeric, p_description text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE v_lang TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  THEN RAISE EXCEPTION 'not authorized'; END IF;

  v_lang := user_lang(p_teacher_id);

  INSERT INTO public.ledger_entries
    (teacher_id, type, amount, commission, net_amount, description)
  VALUES (p_teacher_id, 'payout_sent', p_amount, 0, -p_amount, p_description);

  INSERT INTO public.notifications (user_id, title, body, type)
  VALUES (p_teacher_id,
    CASE v_lang WHEN 'fr' THEN 'Paiement effectué 💰'
      ELSE 'تمت تسوية مستحقاتك 💰' END,
    CASE v_lang WHEN 'fr'
      THEN 'Vos gains de ' || p_amount::INT || ' ouguiyas ont été transférés — ' || p_description
      ELSE 'تم تحويل مستحقاتك البالغة ' || p_amount || ' أوقية — ' || p_description END,
    'payout_sent');
END;
$$;

-- ── 7. admin_reject_payment — bilingual (trigger handles notif) ─
CREATE OR REPLACE FUNCTION admin_reject_payment(
  p_payment_id UUID, p_admin_id UUID, p_reason TEXT
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_session_id    UUID;
  v_cancel_reason TEXT;
BEGIN
  UPDATE payments
  SET status = 'rejected', confirmed_by = p_admin_id,
      confirmed_at = now(), reject_reason = p_reason
  WHERE id = p_payment_id
  RETURNING session_id INTO v_session_id;

  IF v_session_id IS NULL THEN
    RAISE EXCEPTION 'Payment % not found', p_payment_id;
  END IF;

  v_cancel_reason := CASE UPPER(TRIM(COALESCE(p_reason, '')))
    WHEN 'FAKE_PROOF'        THEN 'fake_proof'
    WHEN 'INCOMPLETE_AMOUNT' THEN 'insufficient_refund'
    ELSE                          'payment_rejected'
  END;

  -- Cancel immediately — on_session_state_change trigger sends the bilingual notification
  UPDATE sessions
  SET state = 'CANCELLED', cancellation_reason = v_cancel_reason, ended_at = now()
  WHERE id = v_session_id;

  INSERT INTO session_events (session_id, event_type, actor, note)
  VALUES (v_session_id, 'PAYMENT_REJECTED', 'admin', p_reason);
END;
$$;

-- ── 8. Dispute functions — bilingual ────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_freeze_payment(
  p_payment_id UUID, p_admin_id UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_amount NUMERIC; v_student_id UUID; v_teacher_id UUID; v_session_id UUID;
  v_sl TEXT; v_tl TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin')
  THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT p.amount, s.student_id, s.teacher_id, p.session_id
  INTO   v_amount, v_student_id, v_teacher_id, v_session_id
  FROM   public.payments p JOIN public.sessions s ON s.id = p.session_id
  WHERE  p.id = p_payment_id AND p.status = 'confirmed';
  IF NOT FOUND THEN RAISE EXCEPTION 'Payment not found or not confirmed'; END IF;

  UPDATE public.payments SET dispute_status = 'frozen', dispute_updated_at = NOW()
  WHERE id = p_payment_id;

  v_sl := user_lang(v_student_id); v_tl := user_lang(v_teacher_id);

  INSERT INTO public.notifications (user_id, title, body, type, session_id) VALUES
    (v_teacher_id,
      CASE v_tl WHEN 'fr' THEN 'Montant de la session gelé ⚠' ELSE 'تم تجميد مبلغ الجلسة ⚠' END,
      CASE v_tl WHEN 'fr'
        THEN 'Le montant de ' || v_amount::INT || ' ouguiyas a été gelé suite à une réclamation.'
        ELSE 'تم تجميد مبلغ ' || v_amount::INT || ' أوقية بسبب شكوى من الطالب، جارٍ التحقيق.' END,
      'PAYMENT_FROZEN', v_session_id),
    (v_student_id,
      CASE v_sl WHEN 'fr' THEN 'Réclamation reçue ✅' ELSE 'تم استلام شكواك ✅' END,
      CASE v_sl WHEN 'fr'
        THEN 'Le montant de ' || v_amount::INT || ' ouguiyas a été gelé pour enquête.'
        ELSE 'تم تجميد مبلغك (' || v_amount::INT || ' أوقية) للتحقيق، وسيُسترد إن كنت صاحب الحق.' END,
      'PAYMENT_FROZEN_STUDENT', v_session_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_dispute_refund(
  p_payment_id UUID, p_admin_id UUID, p_refund_amount NUMERIC
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_amount NUMERIC; v_student_id UUID; v_teacher_id UUID; v_session_id UUID;
  v_sl TEXT; v_tl TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin')
  THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT p.amount, s.student_id, s.teacher_id, p.session_id
  INTO   v_amount, v_student_id, v_teacher_id, v_session_id
  FROM   public.payments p JOIN public.sessions s ON s.id = p.session_id
  WHERE  p.id = p_payment_id AND p.status = 'confirmed';
  IF NOT FOUND THEN RAISE EXCEPTION 'Payment not found or not confirmed'; END IF;

  UPDATE public.payments
  SET dispute_status = 'refunded', dispute_refund_amount = p_refund_amount, dispute_updated_at = NOW()
  WHERE id = p_payment_id;

  v_sl := user_lang(v_student_id); v_tl := user_lang(v_teacher_id);

  INSERT INTO public.notifications (user_id, title, body, type, session_id) VALUES
    (v_teacher_id,
      CASE v_tl WHEN 'fr' THEN 'Montant remboursé à l''élève' ELSE 'تم استرداد مبلغ الجلسة للطالب' END,
      CASE v_tl WHEN 'fr'
        THEN 'Après enquête, ' || p_refund_amount::INT || ' ouguiyas ont été remboursés à l''élève.'
        ELSE 'بعد التحقيق، تقرر استرداد ' || p_refund_amount::INT || ' أوقية للطالب.' END,
      'DISPUTE_REFUNDED_TEACHER', v_session_id),
    (v_student_id,
      CASE v_sl WHEN 'fr' THEN 'Remboursement effectué ✅' ELSE 'تم استرداد مبلغك ✅' END,
      CASE v_sl WHEN 'fr'
        THEN 'Après enquête, ' || p_refund_amount::INT || ' ouguiyas vous seront remboursés prochainement.'
        ELSE 'بعد التحقيق، تقرر إعادة ' || p_refund_amount::INT || ' أوقية إليك. سيصلك المبلغ قريباً.' END,
      'DISPUTE_REFUNDED_STUDENT', v_session_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_confirm_after_dispute(
  p_payment_id UUID, p_admin_id UUID
) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_amount NUMERIC; v_student_id UUID; v_teacher_id UUID; v_session_id UUID;
  v_sl TEXT; v_tl TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_admin_id AND role = 'admin')
  THEN RAISE EXCEPTION 'Unauthorized'; END IF;

  SELECT p.amount, s.student_id, s.teacher_id, p.session_id
  INTO   v_amount, v_student_id, v_teacher_id, v_session_id
  FROM   public.payments p JOIN public.sessions s ON s.id = p.session_id
  WHERE  p.id = p_payment_id AND p.status = 'confirmed';
  IF NOT FOUND THEN RAISE EXCEPTION 'Payment not found or not confirmed'; END IF;

  UPDATE public.payments SET dispute_status = 'confirmed', dispute_updated_at = NOW()
  WHERE id = p_payment_id;

  v_sl := user_lang(v_student_id); v_tl := user_lang(v_teacher_id);

  INSERT INTO public.notifications (user_id, title, body, type, session_id) VALUES
    (v_teacher_id,
      CASE v_tl WHEN 'fr' THEN 'Paiement confirmé en votre faveur ✅' ELSE 'تم تأكيد استحقاقك للمبلغ ✅' END,
      CASE v_tl WHEN 'fr'
        THEN 'Après enquête, les ' || v_amount::INT || ' ouguiyas vous reviennent de droit.'
        ELSE 'بعد التحقيق، تقررت الإدارة أن مبلغ ' || v_amount::INT || ' أوقية من حقك.' END,
      'DISPUTE_CONFIRMED_TEACHER', v_session_id),
    (v_student_id,
      CASE v_sl WHEN 'fr' THEN 'Résultat de votre réclamation' ELSE 'نتيجة التحقيق في شكواك' END,
      CASE v_sl WHEN 'fr'
        THEN 'Après enquête, le remboursement a été refusé. Contactez-nous via WhatsApp.'
        ELSE 'بعد التحقيق، قررت الإدارة عدم استرداد مبلغ الجلسة. للاستفسار تواصل معنا عبر واتساب.' END,
      'DISPUTE_CONFIRMED_STUDENT', v_session_id);
END;
$$;

-- ── 9. RPC: admin approves teacher → bilingual notification ─────
CREATE OR REPLACE FUNCTION public.admin_notify_teacher_approved(p_teacher_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_lang TEXT;
BEGIN
  v_lang := user_lang(p_teacher_id);
  INSERT INTO public.notifications (user_id, title, body, type)
  VALUES (p_teacher_id,
    CASE v_lang WHEN 'fr' THEN 'Félicitations ! Compte approuvé 🎉'
      ELSE 'تهانينا! تم اعتماد حسابك 🎉' END,
    CASE v_lang WHEN 'fr' THEN 'Vous pouvez maintenant recevoir des demandes de cours d''élèves.'
      ELSE 'يمكنك الآن استقبال طلبات الجلسات من الطلاب.' END,
    'teacher_approved');
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_notify_teacher_approved TO authenticated;
