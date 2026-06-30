-- ══════════════════════════════════════════════════════════════════
-- Fix: admin panel manual notification inserts → bilingual RPCs
-- Covers: teacher reject/revoke, dispute resolve, no-show refund
-- Requires: user_lang() helper from add_language_preference.sql
-- Run after add_language_preference.sql in Supabase SQL Editor
-- ══════════════════════════════════════════════════════════════════

-- 1. Teacher application rejected
CREATE OR REPLACE FUNCTION public.admin_notify_teacher_rejected(p_teacher_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_lang TEXT;
BEGIN
  v_lang := user_lang(p_teacher_id);
  INSERT INTO notifications (user_id, title, body, type)
  VALUES (p_teacher_id,
    CASE v_lang WHEN 'fr' THEN 'Demande non acceptée'
      ELSE 'اعتذرنا عن طلبك' END,
    CASE v_lang WHEN 'fr'
      THEN 'Nous ne pouvons pas accepter votre demande pour le moment. Contactez-nous pour plus d''informations.'
      ELSE 'لا يمكن قبول طلبك في الوقت الحالي. يرجى التواصل معنا للمزيد.' END,
    'teacher_rejected');
END;
$$;

-- 2. Teacher approval revoked
CREATE OR REPLACE FUNCTION public.admin_notify_teacher_revoked(p_teacher_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_lang TEXT;
BEGIN
  v_lang := user_lang(p_teacher_id);
  INSERT INTO notifications (user_id, title, body, type)
  VALUES (p_teacher_id,
    CASE v_lang WHEN 'fr' THEN 'Compte suspendu temporairement'
      ELSE 'تم إيقاف حسابك مؤقتاً' END,
    CASE v_lang WHEN 'fr'
      THEN 'Votre compte a été suspendu par l''administration. Contactez-nous pour plus d''informations.'
      ELSE 'تم إلغاء اعتماد حسابك من قِبَل الإدارة. للاستفسار تواصل معنا.' END,
    'teacher_revoked');
END;
$$;

-- 3. Dispute resolved in student's favor (refund)
CREATE OR REPLACE FUNCTION public.admin_notify_dispute_refund(
  p_student_id UUID, p_session_id UUID
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_lang TEXT;
BEGIN
  v_lang := user_lang(p_student_id);
  INSERT INTO notifications (user_id, title, body, type, session_id)
  VALUES (p_student_id,
    CASE v_lang WHEN 'fr' THEN 'Remboursement en cours ✅'
      ELSE 'تم استرداد مبلغك ✅' END,
    CASE v_lang WHEN 'fr'
      THEN 'Le litige a été résolu en votre faveur. Votre remboursement sera traité prochainement.'
      ELSE 'تم حل النزاع لصالحك وسيتم تحويل المبلغ قريباً.' END,
    'dispute_resolved', p_session_id);
END;
$$;

-- 4. Dispute resolved in teacher's favor (payment credited)
CREATE OR REPLACE FUNCTION public.admin_notify_dispute_complete(
  p_teacher_id UUID, p_session_id UUID
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_lang TEXT;
BEGIN
  v_lang := user_lang(p_teacher_id);
  INSERT INTO notifications (user_id, title, body, type, session_id)
  VALUES (p_teacher_id,
    CASE v_lang WHEN 'fr' THEN 'Paiement en cours de virement ✅'
      ELSE 'تم إيداع مستحقاتك ✅' END,
    CASE v_lang WHEN 'fr'
      THEN 'Le litige a été résolu en votre faveur. Votre paiement sera viré prochainement.'
      ELSE 'تم حل النزاع لصالحك وسيُحوَّل مستحقك قريباً.' END,
    'dispute_resolved', p_session_id);
END;
$$;

-- 5. Teacher no-show refund processed for student
CREATE OR REPLACE FUNCTION public.admin_notify_noshow_refund(
  p_student_id UUID, p_session_id UUID
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_lang TEXT;
BEGIN
  v_lang := user_lang(p_student_id);
  INSERT INTO notifications (user_id, title, body, type, session_id)
  VALUES (p_student_id,
    CASE v_lang WHEN 'fr' THEN 'Remboursement traité ✅'
      ELSE 'تم استرداد مبلغك ✅' END,
    CASE v_lang WHEN 'fr'
      THEN 'Votre demande de remboursement a été traitée. Le montant vous sera transféré prochainement.'
      ELSE 'تمت معالجة طلب الاسترداد. سيُحوَّل المبلغ إليك قريباً.' END,
    'refund_processed', p_session_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_notify_teacher_rejected(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_notify_teacher_revoked(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_notify_dispute_refund(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_notify_dispute_complete(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_notify_noshow_refund(UUID, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';
