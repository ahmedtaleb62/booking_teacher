import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

const DEFAULT_COMMISSION = 0.15
const PLAN_LABELS = { monthly: 'شهري', quarterly: 'فصلي (3 أشهر)', yearly: 'سنوي (12 شهراً)' }

/* ── Status badge + rejection sub-reason ────────────────────── */
const BADGE_MAP = {
  submitted: ['قيد التأكيد',  '#FEF3C7', '#92400E'],
  confirmed: ['مؤكّد',        '#D7F2E6', '#0A6E4E'],
  rejected:  ['مرفوض',        '#FBE0DB', '#A12B1D'],
  refunded:  ['مسترد',        '#ECE5F7', '#5A3B95'],
  pending:   ['قيد المراجعة', '#ECE5F7', '#5A3B95'],
  active:    ['نشط',          '#D7F2E6', '#0A6E4E'],
  expired:   ['منتهي',        '#FEF3C7', '#D97706'],
  cancelled: ['ملغى',         '#FBE0DB', '#A12B1D'],
}

function Badge({ status }) {
  const [label, bg, fg] = BADGE_MAP[status] || ['—', '#F1F5F9', '#475569']
  return <span className="badge" style={{ background: bg, color: fg }}>{label}</span>
}

function StatusBadge({ row, type }) {
  const st  = row.status
  const rr  = (row.reject_reason || '').replace(/^REFUND:/i, '').toUpperCase()
  const isRefundPrefix = (row.reject_reason || '').toUpperCase().startsWith('REFUND:')
  const isFake  = rr === 'FAKE_PROOF'
  const isInsuf = rr === 'INCOMPLETE_AMOUNT'

  const [label, bg, fg] = BADGE_MAP[st] || ['—', '#F1F5F9', '#475569']

  // Sub-label — simplified: only 2 outcomes now
  let sub = null, subColor = '#6B7280'
  if (isFake && (st === 'rejected' || st === 'cancelled')) {
    sub = 'الوصل مزيف'; subColor = '#A12B1D'
  } else if ((isInsuf || isRefundPrefix) && (st === 'refunded' || isRefundPrefix)) {
    sub = 'مبلغ ناقص · مُسترد'; subColor = '#5A3B95'
  } else if (isInsuf && st === 'rejected') {
    sub = 'مبلغ ناقص'; subColor = '#92400E'
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
      <span className="badge" style={{ background: bg, color: fg }}>{label}</span>
      {sub && <span style={{ fontSize: 10, fontWeight: 600, color: subColor }}>{sub}</span>}
    </div>
  )
}

/* ── Vertical timeline component ─────────────────────────────── */
function PaymentTimeline({ steps }) {
  return (
    <div style={{ padding: '4px 0' }}>
      {steps.map((step, i) => (
        <div key={i} style={{ display: 'flex', gap: 10 }}>
          {/* Dot + connector */}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', width: 30, flexShrink: 0 }}>
            <div style={{
              width: 30, height: 30, borderRadius: '50%',
              background: step.bg, border: `2px solid ${step.color}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 13, flexShrink: 0,
            }}>
              {step.icon}
            </div>
            {i < steps.length - 1 && (
              <div style={{ width: 2, flex: 1, minHeight: 18, background: '#E5E7EB', margin: '3px 0' }} />
            )}
          </div>
          {/* Label + meta */}
          <div style={{ paddingBottom: i < steps.length - 1 ? 14 : 0, flex: 1, paddingTop: 5 }}>
            <div style={{ fontSize: 13, fontWeight: 700, color: step.color }}>{step.label}</div>
            {step.date && <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 2 }}>{step.date}</div>}
            {step.note && <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 2 }}>{step.note}</div>}
          </div>
        </div>
      ))}
    </div>
  )
}

/* Build timeline steps for a session payment — simplified 2-outcome flow */
function buildSessionTimeline(row, fmtTs) {
  const steps = []
  const rr = (row.reject_reason || '').toUpperCase()
  const cr = (row.session?.cancellation_reason || '').toLowerCase()

  steps.push({
    icon: '📤', label: 'تقديم إثبات الدفع',
    color: '#059669', bg: '#D7F2E6',
    date: row.created_at ? fmtTs(row.created_at) : undefined,
  })

  if (row.status === 'submitted') {
    steps.push({ icon: '⏳', label: 'قيد مراجعة الأدمن', color: '#92400E', bg: '#FEF3C7' })
    return steps
  }

  if (row.status === 'confirmed') {
    steps.push({ icon: '✅', label: 'تم تأكيد الدفع', color: '#059669', bg: '#D7F2E6' })
    return steps
  }

  // FAKE_PROOF → rejected, no refund
  if (rr === 'FAKE_PROOF' || cr === 'fake_proof') {
    steps.push({ icon: '🚫', label: 'الوصل مزيف — مرفوض نهائياً', color: '#A12B1D', bg: '#FBE0DB' })
    steps.push({ icon: '✕', label: 'جلسة ملغاة', color: '#A12B1D', bg: '#FBE0DB' })
    return steps
  }

  // INCOMPLETE_AMOUNT → cancelled + refunded
  if (rr === 'INCOMPLETE_AMOUNT' || cr === 'insufficient_refund') {
    steps.push({ icon: '💰', label: 'المبلغ غير مكتمل', color: '#92400E', bg: '#FEF3C7' })
    steps.push({ icon: '✕', label: 'جلسة ملغاة', color: '#A12B1D', bg: '#FBE0DB' })
    steps.push({ icon: '↩', label: 'مُسترد للطالب', color: '#5A3B95', bg: '#ECE5F7' })
    return steps
  }

  // teacher_no_show refund
  if (cr === 'teacher_no_show_refund') {
    steps.push({ icon: '👤', label: 'غياب الأستاذ', color: '#D97706', bg: '#FEF3C7' })
    steps.push({ icon: '↩', label: 'مُسترد للطالب', color: '#5A3B95', bg: '#ECE5F7' })
    return steps
  }

  // fallback for legacy states
  steps.push({ icon: '✕', label: 'مرفوض', color: '#A12B1D', bg: '#FBE0DB' })
  return steps
}

/* Build timeline steps for a subscription payment */
function buildSubTimeline(row) {
  const steps = []
  const rr             = row.reject_reason || ''
  const isRefund       = rr.startsWith('REFUND:')
  const cleanRr        = isRefund ? rr.replace(/^REFUND:/i, '').toUpperCase() : rr.toUpperCase()

  steps.push({ icon: '📤', label: 'تقديم طلب الاشتراك', color: '#059669', bg: '#D7F2E6' })

  if (row.status === 'pending') {
    steps.push({ icon: '⏳', label: 'قيد مراجعة الأدمن', color: 'var(--purple)', bg: 'var(--purple-light)' })
  } else if (row.status === 'active') {
    steps.push({ icon: '✅', label: 'تم تفعيل الاشتراك', color: '#059669', bg: '#D7F2E6' })
  } else if (row.status === 'expired') {
    steps.push({ icon: '✅', label: 'تم تفعيل الاشتراك', color: '#059669', bg: '#D7F2E6' })
    steps.push({ icon: '⏰', label: 'انتهت صلاحية الاشتراك', color: '#D97706', bg: '#FEF3C7' })
  } else if (row.status === 'rejected') {
    if (cleanRr === 'FAKE_PROOF') {
      steps.push({ icon: '🚫', label: 'الوصل مزيف — مرفوض نهائياً', color: '#A12B1D', bg: '#FBE0DB' })
      steps.push({ icon: '✕', label: 'اشتراك ملغى', color: '#A12B1D', bg: '#FBE0DB' })
    } else if (cleanRr === 'INCOMPLETE_AMOUNT') {
      steps.push({ icon: '💰', label: 'المبلغ غير مكتمل', color: '#92400E', bg: '#FEF3C7' })
      steps.push({ icon: '✕', label: 'اشتراك ملغى', color: '#A12B1D', bg: '#FBE0DB' })
      steps.push({ icon: '↩', label: 'مُسترد للطالب', color: '#5A3B95', bg: '#ECE5F7' })
    } else {
      steps.push({ icon: '✕', label: 'مرفوض من الأدمن', color: '#A12B1D', bg: '#FBE0DB' })
      if (isRefund) steps.push({ icon: '↩', label: 'مُسترد للطالب', color: '#5A3B95', bg: '#ECE5F7' })
    }
  }

  return steps
}

/* ─────────────────────────────────────────────────────────────── */

const METHOD_LABELS = { bankili: 'بنكيلي', masrivi: 'مصرفي', sedad: 'سداد', cash: 'نقداً', transfer: 'تحويل' }

const REFUND_REASON_LABELS = {
  teacher_no_show_refund: 'غياب الأستاذ (طلب طالب)',
  insufficient_refund:    'مبلغ منقوص (استرداد)',
  fake_proof:             'إثبات مزيف (انتهاء مهلة)',
  no_payment_deadline:    'انتهاء مهلة الدفع',
}

const TERMINAL_STATES = ['CANCELLED', 'CONFIRMED_BOOKING', 'ACTIVE_SESSION', 'COMPLETED', 'PAYMENT_CONFIRMED']

export default function Payments({ adminId }) {
  const toast = useToast()
  const [tab, setTab]                     = useState('sessions')
  const [rows, setRows]                   = useState([])
  const [subRows, setSubRows]             = useState([])
  const [refundedRows, setRefundedRows]   = useState([])
  const [subRefundedRows, setSubRefundedRows] = useState([])
  const [disputeRefundedRows, setDisputeRefundedRows] = useState([])
  const [stats, setStats]                 = useState({})
  const [loading, setLoading]             = useState(true)
  const [sessionComm, setSessionComm]     = useState(DEFAULT_COMMISSION)
  const [subComm, setSubComm]             = useState(DEFAULT_COMMISSION)
  const [actionId, setActionId]           = useState(null)
  const [modal, setModal]                 = useState(null)   // { type, row }
  const [rejectInput, setRejectInput]     = useState(false)
  const [rejectReason, setRejectReason]   = useState('')
  const [withRefund, setWithRefund]       = useState(false)
  const [proofUrl, setProofUrl]           = useState(null)
  const [refundAmountInput, setRefundAmountInput] = useState('')
  const actionsRef = React.useRef(null)
  // Problem 2: dispute system
  const [disputeMode, setDisputeMode]     = useState(false)
  const [disputeAction, setDisputeAction] = useState('')   // 'frozen' | 'refunded' | 'confirmed'
  const [disputeAmount, setDisputeAmount] = useState('')

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const { data: settingsData } = await supabase.rpc('get_system_settings')
    if (settingsData) {
      const s = Object.fromEntries(settingsData.map(r => [r.key, parseFloat(r.value)]))
      if (!isNaN(s.session_commission_pct))      setSessionComm(s.session_commission_pct / 100)
      if (!isNaN(s.subscription_commission_pct)) setSubComm(s.subscription_commission_pct / 100)
    }

    const [payRes, subPayRes, refundedRes, subRefundRes, disputeRefundRes] = await Promise.all([
      supabase.from('payments')
        .select('*, session:session_id(id,subject,student_id,teacher_id,scheduled_at,payment_deadline,state,cancellation_reason), student:student_id(full_name)')
        .order('created_at', { ascending: false }),
      supabase.from('subscriptions')
        .select('*, student:student_id(full_name), course:course_id(title, teacher_id), package:package_id(title)')
        .order('created_at', { ascending: false }),
      supabase.from('sessions')
        .select('id, subject, amount, teacher_id, student_id, cancellation_reason, updated_at, state')
        .in('cancellation_reason', ['teacher_no_show_refund', 'insufficient_refund'])
        .order('updated_at', { ascending: false }),
      supabase.from('subscriptions')
        .select('*, student:student_id(full_name), course:course_id(title, teacher_id), package:package_id(title)')
        .eq('status', 'rejected')
        .like('reject_reason', 'REFUND:%')
        .order('updated_at', { ascending: false }),
      supabase.from('payments')
        .select('*, session:session_id(id, subject, student_id, teacher_id), student:student_id(full_name)')
        .eq('status', 'confirmed')
        .eq('dispute_status', 'refunded')
        .order('dispute_updated_at', { ascending: false }),
    ])

    const pays      = payRes.data || []
    let subs        = subPayRes.data || []
    let refunded    = refundedRes.data || []
    let subRef      = subRefundRes.data || []
    const dispRef   = disputeRefundRes.data || []

    // Enrich subscriptions with teacher names
    const teacherIds = [...new Set(subs.map(s => s.course?.teacher_id).filter(Boolean))]
    if (teacherIds.length > 0) {
      const { data: teachers } = await supabase.from('profiles').select('id, full_name').in('id', teacherIds)
      const teacherMap = Object.fromEntries((teachers || []).map(t => [t.id, t.full_name]))
      subs = subs.map(s => ({
        ...s,
        course: s.course ? { ...s.course, teacher_name: teacherMap[s.course.teacher_id] || '—' } : s.course,
      }))
    }

    // Enrich session refunds: profiles + payments (no joins — dual FK to profiles causes 400)
    const refundUserIds = [...new Set([
      ...refunded.map(r => r.student_id),
      ...refunded.map(r => r.teacher_id),
    ].filter(Boolean))]
    if (refundUserIds.length > 0) {
      const { data: refundProfiles } = await supabase.from('profiles').select('id, full_name').in('id', refundUserIds)
      const profileMap = Object.fromEntries((refundProfiles || []).map(p => [p.id, p.full_name]))
      refunded = refunded.map(r => ({
        ...r,
        student_name: profileMap[r.student_id] || '—',
        teacher_name: profileMap[r.teacher_id] || '—',
      }))
    }
    const refundSessionIds = refunded.map(r => r.id).filter(Boolean)
    if (refundSessionIds.length > 0) {
      const { data: refundPays } = await supabase.from('payments')
        .select('session_id, amount, method, status')
        .in('session_id', refundSessionIds)
      const refundPayMap = Object.fromEntries((refundPays || []).map(p => [p.session_id, p]))
      refunded = refunded.map(r => ({ ...r, payment: refundPayMap[r.id] || null }))
    }

    // Enrich subscription refunds with teacher names
    const subRefTeacherIds = [...new Set(subRef.map(s => s.course?.teacher_id).filter(Boolean))]
    if (subRefTeacherIds.length > 0) {
      const { data: subRefTeachers } = await supabase.from('profiles').select('id, full_name').in('id', subRefTeacherIds)
      const subRefTeacherMap = Object.fromEntries((subRefTeachers || []).map(t => [t.id, t.full_name]))
      subRef = subRef.map(s => ({
        ...s,
        course: s.course ? { ...s.course, teacher_name: subRefTeacherMap[s.course.teacher_id] || '—' } : s.course,
      }))
    }

    const today             = new Date().toISOString().slice(0, 10)
    const confirmedToday    = pays.filter(p => p.status === 'confirmed' && p.created_at?.startsWith(today))
    const sessionCommToday  = confirmedToday.reduce((s, p) => s + (p.amount || 0) * sessionComm, 0)
    const activeSubs        = subs.filter(s => s.status === 'active')
    const subCommTotal      = activeSubs.reduce((s, r) => s + (r.platform_commission ?? r.amount * subComm), 0)
    const totalRefunded     = refunded.reduce((acc, s) => acc + (s.payment?.amount || s.amount || 0), 0)
    const totalSubRefunded  = subRef.reduce((acc, s) => acc + (s.amount || 0), 0)
    const totalDisputeRef   = dispRef.reduce((acc, p) => acc + (p.dispute_refund_amount || 0), 0)
    const refundCount       = refunded.length + subRef.length + dispRef.length

    setStats({
      pendingSessions:  pays.filter(p => p.status === 'submitted').length,
      pendingSubs:      subs.filter(s => s.status === 'pending').length,
      sessionCommToday: Math.round(sessionCommToday),
      subCommTotal:     Math.round(subCommTotal),
      totalRefunded:    Math.round(totalRefunded + totalSubRefunded + totalDisputeRef),
      refundCount,
    })
    setRows(pays)
    setSubRows(subs)
    setRefundedRows(refunded)
    setSubRefundedRows(subRef)
    setDisputeRefundedRows(dispRef)
    setLoading(false)
  }

  async function openModal(type, row) {
    setModal({ type, row })
    setProofUrl(null)
    setRejectInput(false)
    setRejectReason('')
    setWithRefund(false)
    setRefundAmountInput('')
    setDisputeMode(false)
    setDisputeAction('')
    setDisputeAmount('')
    if (row.proof_image_url) {
      const bucket = type === 'session' ? 'payment-proofs' : 'subscription-proofs'
      let path = row.proof_image_url
      if (path.startsWith('http')) {
        const marker = `/${bucket}/`
        const idx = path.indexOf(marker)
        path = idx !== -1 ? path.slice(idx + marker.length) : null
      }
      if (path) {
        const { data } = await supabase.storage.from(bucket).createSignedUrl(path, 3600)
        setProofUrl(data?.signedUrl || null)
      }
    }
  }

  function closeModal() {
    setModal(null)
    setProofUrl(null)
    setRejectInput(false)
    setRejectReason('')
    setRefundAmountInput('')
    setDisputeMode(false)
    setDisputeAction('')
    setDisputeAmount('')
  }

  /* ── Session payment actions ──────────────────────────────────── */
  async function confirmPayment(paymentId) {
    if (actionId) return
    setActionId(paymentId)
    try {
      const { error } = await supabase.rpc('admin_confirm_payment', { p_payment_id: paymentId, p_admin_id: adminId })
      if (error) throw error
      closeModal(); await loadData()
      toast('تم تأكيد الدفع بنجاح وإشعار الطالب والأستاذ', 'success')
    } catch (err) {
      toast('خطأ في تأكيد الدفع: ' + (err.message || 'حدث خطأ غير متوقع'), 'error')
    } finally { setActionId(null) }
  }

  async function rejectPayment(paymentId, reason) {
    if (!reason?.trim()) return
    setActionId(paymentId)
    try {
      const { error } = await supabase.rpc('admin_reject_payment', { p_payment_id: paymentId, p_admin_id: adminId, p_reason: reason.trim() })
      if (error) throw error
      closeModal(); await loadData()
      toast('تم رفض الدفع وإشعار الطالب', 'success')
    } catch (err) {
      toast('خطأ في رفض الدفع: ' + (err.message || 'حدث خطأ غير متوقع'), 'error')
    } finally { setActionId(null) }
  }

  async function forceActivateExpired(paymentId) {
    setActionId(paymentId)
    try {
      const { error } = await supabase.rpc('admin_confirm_payment', { p_payment_id: paymentId, p_admin_id: adminId })
      if (error) throw error
      closeModal(); await loadData()
      toast('تم تفعيل الجلسة رغم انتهاء المهلة', 'success')
    } catch (err) {
      toast('خطأ: ' + (err.message || ''), 'error')
    } finally { setActionId(null) }
  }

  async function cancelExpiredWithRefund(payment) {
    if (actionId) return
    setActionId(payment.id)
    try {
      const sessionId = payment.session_id || payment.session?.id
      const { error: sessErr } = await supabase.from('sessions').update({
        state: 'CANCELLED', cancellation_reason: 'insufficient_refund', updated_at: new Date().toISOString(),
      }).eq('id', sessionId)
      if (sessErr) throw sessErr
      const { error: payErr } = await supabase.from('payments').update({ status: 'refunded' }).eq('id', payment.id)
      if (payErr) throw payErr
      // on_session_state_change trigger sends bilingual notification for insufficient_refund
      await supabase.from('session_events').insert({ session_id: sessionId, event_type: 'REFUND_PROCESSED', actor: 'admin' })
      closeModal(); await loadData()
      toast('تم إلغاء الجلسة وتسجيل استرداد المبلغ وإشعار الطالب', 'success')
    } catch (err) {
      toast('خطأ: ' + (err.message || ''), 'error')
    } finally { setActionId(null) }
  }

  /* ── Subscription actions ────────────────────────────────────── */
  async function confirmSub(id) {
    setActionId(id)
    const sub    = subRows.find(r => r.id === id)
    const months = { monthly: 1, quarterly: 3, yearly: 12 }[sub?.plan_type] || 1
    try {
      const { error } = await supabase.rpc('admin_confirm_subscription', { p_subscription_id: id, p_admin_id: adminId, p_months: months })
      if (error) throw error
      closeModal(); await loadData()
      toast('تم تأكيد الاشتراك وتفعيله بنجاح', 'success')
    } catch (err) {
      toast('خطأ في تأكيد الاشتراك: ' + (err.message || 'حدث خطأ غير متوقع'), 'error')
    } finally { setActionId(null) }
  }

  async function rejectSub(id, reason) {
    if (!reason?.trim()) return
    setActionId(id)
    try {
      const { error } = await supabase.rpc('admin_reject_subscription', { p_subscription_id: id, p_admin_id: adminId, p_reason: reason.trim() })
      if (error) throw error
      closeModal(); await loadData()
      toast('تم رفض الاشتراك وإشعار الطالب', 'success')
    } catch (err) {
      toast('خطأ في رفض الاشتراك: ' + (err.message || 'حدث خطأ غير متوقع'), 'error')
    } finally { setActionId(null) }
  }

  async function rejectSubWithRefund(id, reason, refundAmount) {
    if (!reason?.trim() || !refundAmount) return
    setActionId(id)
    try {
      const { error } = await supabase.rpc('admin_reject_subscription', {
        p_subscription_id: id, p_admin_id: adminId, p_reason: reason.trim(),
        p_refund_amount: parseFloat(refundAmount),
      })
      if (error) throw error
      closeModal(); await loadData()
      toast('تم رفض الاشتراك وإشعار الطالب باسترداد مبلغه', 'success')
    } catch (err) {
      toast('خطأ: ' + (err.message || ''), 'error')
    } finally { setActionId(null) }
  }

  /* ── Dispute actions ─────────────────────────────────────────── */
  async function freezePayment(paymentId) {
    if (actionId) return
    setActionId(paymentId)
    try {
      const { error } = await supabase.rpc('admin_freeze_payment', { p_payment_id: paymentId, p_admin_id: adminId })
      if (error) throw error
      closeModal(); await loadData()
      toast('تم تجميد المبلغ وإشعار الطرفين', 'success')
    } catch (err) {
      toast('خطأ: ' + (err.message || ''), 'error')
    } finally { setActionId(null) }
  }

  async function disputeRefund(paymentId, amount) {
    if (actionId || !amount) return
    setActionId(paymentId)
    try {
      const { error } = await supabase.rpc('admin_dispute_refund', {
        p_payment_id: paymentId, p_admin_id: adminId, p_refund_amount: parseFloat(amount),
      })
      if (error) throw error
      closeModal(); await loadData()
      toast('تم تسجيل الاسترداد وإشعار الطرفين', 'success')
    } catch (err) {
      toast('خطأ: ' + (err.message || ''), 'error')
    } finally { setActionId(null) }
  }

  async function confirmAfterDispute(paymentId) {
    if (actionId) return
    setActionId(paymentId)
    try {
      const { error } = await supabase.rpc('admin_confirm_after_dispute', { p_payment_id: paymentId, p_admin_id: adminId })
      if (error) throw error
      closeModal(); await loadData()
      toast('تم تأكيد حق الأستاذ وإشعار الطرفين', 'success')
    } catch (err) {
      toast('خطأ: ' + (err.message || ''), 'error')
    } finally { setActionId(null) }
  }

  /* ── Render ──────────────────────────────────────────────────── */
  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const fmt       = n => n?.toLocaleString('en-US') ?? '—'
  const fmtDate   = s => s ? new Date(s).toLocaleDateString('ar-EG-u-nu-latn', { day: '2-digit', month: '2-digit', year: '2-digit' }) : '—'
  const fmtTs     = s => s ? new Date(s).toLocaleString('ar-EG-u-nu-latn', { dateStyle: 'short', timeStyle: 'short' }) : '—'
  const fmtMethod = m => METHOD_LABELS[m] || m || '—'

  const sessionCols = '0.7fr 1.4fr 1fr 0.7fr 0.9fr 0.9fr 0.8fr 0.6fr 0.7fr'

  return (
    <div>
      {/* ── Stats ─────────────────────────────────────────────── */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 18 }}>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>جلسات قيد التأكيد</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: '#D97706', marginTop: 3 }}>{stats.pendingSessions}</div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>اشتراكات قيد المراجعة</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: 'var(--purple)', marginTop: 3 }}>{stats.pendingSubs}</div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>عمولة الجلسات اليوم</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: '#059669', marginTop: 3 }}>
            {fmt(stats.sessionCommToday)} <span style={{ fontSize: 11, color: 'var(--text3)' }}>أوقية</span>
          </div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>عمولة المنصة (دروس)</div>
          <div style={{ fontSize: 21, fontWeight: 700, marginTop: 3 }}>
            {fmt(stats.subCommTotal)} <span style={{ fontSize: 11, color: 'var(--text3)' }}>أوقية</span>
          </div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>إجمالي المُسترد</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: 'var(--purple)', marginTop: 3 }}>
            {fmt(stats.totalRefunded)} <span style={{ fontSize: 11, color: 'var(--text3)' }}>أوقية</span>
          </div>
          <div style={{ fontSize: 10, color: 'var(--text3)', marginTop: 2 }}>{stats.refundCount} استرداد</div>
        </div>
      </div>

      {/* ── Tabs ──────────────────────────────────────────────── */}
      <div className="tabs mb-14">
        <div className={`tab${tab === 'sessions' ? ' active' : ''}`} onClick={() => setTab('sessions')}>
          مدفوعات الجلسات {stats.pendingSessions > 0 && <span className="badge" style={{ background: '#FEF3C7', color: '#92400E', marginRight: 5, fontSize: 10 }}>{stats.pendingSessions}</span>}
        </div>
        <div className={`tab${tab === 'subs' ? ' active' : ''}`} onClick={() => setTab('subs')}>
          مدفوعات الاشتراكات {stats.pendingSubs > 0 && <span className="badge" style={{ background: '#ECE5F7', color: '#5A3B95', marginRight: 5, fontSize: 10 }}>{stats.pendingSubs}</span>}
        </div>
        <div className={`tab${tab === 'refunds' ? ' active' : ''}`} onClick={() => setTab('refunds')}>
          المبالغ المستردة {stats.refundCount > 0 && <span className="badge" style={{ background: '#ECE5F7', color: '#5A3B95', marginRight: 5, fontSize: 10 }}>{stats.refundCount}</span>}
        </div>
      </div>

      {/* ── Sessions payments table ────────────────────────────── */}
      {tab === 'sessions' && (
        <div className="table-wrap">
          <div className="table-head" style={{ gridTemplateColumns: sessionCols }}>
            <span>المرجع</span><span>الطالب · المادة</span><span>الطريقة / التاريخ</span>
            <span>المبلغ</span><span>عمولة المنصة</span><span>صافي الأستاذ</span>
            <span>الحالة</span><span>الوصل</span><span style={{ textAlign: 'left' }}>إجراء</span>
          </div>
          {rows.length === 0 && <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا توجد مدفوعات</div>}
          {rows.map(r => {
            const isRejected = r.status === 'rejected' || r.status === 'refunded'
            const comm   = isRejected ? 0 : Math.round((r.amount || 0) * sessionComm)
            const net    = isRejected ? 0 : Math.round((r.amount || 0) - comm)
            const hasProof = !!r.proof_image_url
            return (
              <div key={r.id}
                className="table-row"
                style={{ gridTemplateColumns: sessionCols, alignItems: 'center', cursor: 'pointer' }}
                onClick={() => openModal('session', r)}
              >
                <span className="fw-700 dir-ltr" style={{ fontSize: 12 }}>{r.reference || r.id.slice(0, 8)}</span>
                <span>
                  <div style={{ fontWeight: 600, fontSize: 13 }}>{r.student?.full_name || '—'}</div>
                  <div style={{ fontSize: 11, color: 'var(--text3)' }}>{r.session?.subject || '—'}</div>
                </span>
                <span>
                  <div style={{ fontSize: 12, fontWeight: 600 }}>{fmtMethod(r.method)}</div>
                  <div style={{ fontSize: 10, color: 'var(--text3)', marginTop: 2 }}>{fmtDate(r.created_at)}</div>
                </span>
                <span className="fw-700">{fmt(r.amount)}</span>
                <span style={{ color: isRejected ? '#9CA3AF' : '#D97706', fontWeight: 600 }}>
                  {isRejected ? <span style={{ fontSize: 12, color: '#9CA3AF' }}>0</span> : fmt(comm)}
                </span>
                <span className={isRejected ? '' : 'fw-700 text-green'} style={isRejected ? { color: '#9CA3AF', fontSize: 12 } : {}}>
                  {isRejected ? '0' : fmt(net)}
                </span>
                {/* Status + dispute sub-badge */}
                <span>
                  <StatusBadge row={r} type="session" />
                  {r.status === 'confirmed' && r.dispute_status && r.dispute_status !== 'confirmed' && (
                    <span className="badge" style={{
                      display: 'block', marginTop: 3, fontSize: 9,
                      background: r.dispute_status === 'frozen' ? '#FEF3C7' : '#ECE5F7',
                      color: r.dispute_status === 'frozen' ? '#92400E' : '#5A3B95',
                    }}>
                      {r.dispute_status === 'frozen' ? '⚠ مجمّد' : '↩ مسترد'}
                    </span>
                  )}
                </span>
                <span>
                  {hasProof
                    ? <span title="يحتوي على وصل" style={{ fontSize: 18 }}>🧾</span>
                    : <span style={{ color: 'var(--text3)', fontSize: 12 }}>—</span>}
                </span>
                <span style={{ textAlign: 'left' }}>
                  {r.status === 'submitted'
                    ? <button className="btn btn-sm btn-review" onClick={e => { e.stopPropagation(); openModal('session', r) }} disabled={actionId === r.id}>🔍 مراجعة</button>
                    : <span className="text-muted" style={{ fontSize: 12 }}>—</span>}
                </span>
              </div>
            )
          })}
        </div>
      )}

      {/* ── Subscriptions payments table ───────────────────────── */}
      {tab === 'subs' && (
        <div className="table-wrap">
          <div className="table-head" style={{ gridTemplateColumns: '0.8fr 1.2fr 1fr 0.7fr 0.9fr 0.9fr 0.9fr 0.8fr 0.8fr' }}>
            <span>المرجع</span><span>الطالب</span><span>الدورة</span><span>الخطة</span>
            <span>المبلغ</span><span>عمولة المنصة</span><span>صافي الأستاذ</span>
            <span>الحالة</span><span style={{ textAlign: 'left' }}>إجراء</span>
          </div>
          {subRows.length === 0 && <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا توجد اشتراكات</div>}
          {subRows.map(r => {
            const isRejected = r.status === 'rejected'
            const comm = isRejected ? 0 : (r.platform_commission != null ? Math.round(r.platform_commission) : Math.round((r.amount || 0) * subComm))
            const net  = isRejected ? 0 : (r.teacher_earning != null ? Math.round(r.teacher_earning) : Math.round((r.amount || 0) * (1 - subComm)))
            return (
              <div key={r.id}
                className="table-row"
                style={{ gridTemplateColumns: '0.8fr 1.2fr 1fr 0.7fr 0.9fr 0.9fr 0.9fr 0.8fr 0.8fr', cursor: 'pointer' }}
                onClick={() => openModal('sub', r)}
              >
                <span className="fw-700 dir-ltr">{r.id.slice(0, 8)}</span>
                <span>{r.student?.full_name || '—'}</span>
                <span className="text-2" title={`أستاذ: ${r.course?.teacher_name || '—'}`}>
                  {r.course?.title || r.package?.title || '—'}
                  <br /><span style={{ fontSize: 10, color: 'var(--text3)' }}>{r.course?.teacher_name || '—'}</span>
                </span>
                <span className="text-2">{PLAN_LABELS[r.plan_type] || 'شهري'}</span>
                <span className="fw-700">{fmt(r.amount)}</span>
                <span style={{ color: isRejected ? '#9CA3AF' : '#D97706', fontWeight: 600 }}>{isRejected ? '0' : fmt(comm)}</span>
                <span className={isRejected ? '' : 'fw-700 text-green'} style={isRejected ? { color: '#9CA3AF' } : {}}>{isRejected ? '0' : fmt(net)}</span>
                {/* Status + rejection reason sub-label */}
                <span><StatusBadge row={r} type="sub" /></span>
                <span style={{ textAlign: 'left' }}>
                  {r.status === 'pending'
                    ? <button className="btn btn-sm btn-review" onClick={e => { e.stopPropagation(); openModal('sub', r) }} disabled={actionId === r.id}>🔍 مراجعة</button>
                    : <span className="text-muted" style={{ fontSize: 12 }}>—</span>}
                </span>
              </div>
            )
          })}
        </div>
      )}

      {/* ── Detail / review modal ─────────────────────────────── */}
      {modal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.45)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}
          onClick={closeModal}>
          <div style={{ background: '#fff', borderRadius: 20, padding: 28, width: 500, maxWidth: '95vw', maxHeight: '90vh', overflowY: 'auto' }}
            onClick={e => e.stopPropagation()}>

            {/* Header */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
              <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text)' }}>
                {modal.type === 'session' ? 'تفاصيل دفع الجلسة' : 'تفاصيل الاشتراك'}
              </div>
              <button onClick={closeModal} style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 20, color: 'var(--text3)', lineHeight: 1 }}>✕</button>
            </div>

            {/* ── Timeline ─────────────────────────────────────── */}
            <div style={{ background: '#F9FAFB', borderRadius: 14, padding: '14px 16px', marginBottom: 18, border: '1px solid var(--border)' }}>
              <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text3)', marginBottom: 12, textTransform: 'uppercase', letterSpacing: 0.5 }}>
                مسار الحالة
              </div>
              <PaymentTimeline
                steps={modal.type === 'session'
                  ? buildSessionTimeline(modal.row, fmtTs)
                  : buildSubTimeline(modal.row)}
              />
            </div>

            {/* ── Proof image ───────────────────────────────────── */}
            {modal.row.proof_image_url ? (
              <div style={{ marginBottom: 16 }}>
                <div style={{ fontSize: 12, color: 'var(--text3)', marginBottom: 8 }}>🧾 إثبات الدفع (الوصل)</div>
                {proofUrl
                  ? (
                    <a href={proofUrl} target="_blank" rel="noreferrer" style={{ display: 'block' }}>
                      <img src={proofUrl} alt="proof" style={{ width: '100%', borderRadius: 12, border: '1px solid var(--border)', maxHeight: 240, objectFit: 'contain', cursor: 'zoom-in' }} />
                      <div style={{ textAlign: 'center', fontSize: 11, color: 'var(--text3)', marginTop: 5 }}>انقر للعرض الكامل ↗</div>
                    </a>
                  )
                  : <div style={{ textAlign: 'center', padding: '16px 0', color: 'var(--text3)', fontSize: 13, background: '#F2F7F5', borderRadius: 12 }}>جارٍ تحميل إثبات الدفع…</div>
                }
              </div>
            ) : (
              modal.row.status === 'submitted' || modal.row.status === 'pending' ? (
                <div style={{ background: '#FEF3C7', borderRadius: 10, padding: '10px 14px', marginBottom: 14, fontSize: 12, color: '#92400E' }}>
                  ⚠ لا يوجد وصل دفع مرفق
                </div>
              ) : null
            )}

            {/* ── Details ───────────────────────────────────────── */}
            <div style={{ background: '#F2F7F5', borderRadius: 12, padding: 14, marginBottom: 16, fontSize: 13, display: 'flex', flexDirection: 'column', gap: 7 }}>
              {modal.type === 'sub' && (
                <>
                  <div><b>الطالب:</b> {modal.row.student?.full_name || '—'}</div>
                  <div><b>الدورة:</b> {modal.row.course?.title || modal.row.package?.title || '—'}</div>
                  <div><b>الأستاذ:</b> {modal.row.course?.teacher_name || '—'}</div>
                  <div><b>الخطة:</b> {PLAN_LABELS[modal.row.plan_type] || 'شهري'}</div>
                  <div><b>تاريخ الطلب:</b> {fmtDate(modal.row.created_at)}</div>
                </>
              )}
              {modal.type === 'session' && (() => {
                const session     = modal.row.session
                const deadline    = session?.payment_deadline ? new Date(session.payment_deadline) : null
                const scheduledAt = session?.scheduled_at ? new Date(session.scheduled_at) : null
                // Only warn about expired deadline when payment is not yet confirmed
                const deadlineExp = deadline && deadline < new Date() && modal.row.status !== 'confirmed'
                return (
                  <>
                    <div><b>الطالب:</b> {modal.row.student?.full_name || '—'}</div>
                    <div><b>المادة:</b> {session?.subject || '—'}</div>
                    <div><b>طريقة الدفع:</b> <span style={{ fontWeight: 700, color: '#1D4ED8' }}>{fmtMethod(modal.row.method)}</span></div>
                    <div><b>تاريخ الدفع:</b> {fmtTs(modal.row.created_at)}</div>
                    {scheduledAt && <div><b>موعد الجلسة:</b> {scheduledAt.toLocaleString('ar-EG-u-nu-latn', { dateStyle: 'short', timeStyle: 'short' })}</div>}
                    {deadline && (
                      <div style={{ color: deadlineExp ? '#A12B1D' : 'var(--text2)', fontWeight: deadlineExp ? 600 : 400 }}>
                        <b>مهلة الدفع:</b> {deadline.toLocaleString('ar-EG-u-nu-latn', { dateStyle: 'short', timeStyle: 'short' })}
                        {deadlineExp ? ' ⚠ منتهية' : ''}
                      </div>
                    )}
                  </>
                )
              })()}
              <div><b>المبلغ الكلي:</b> {modal.row.amount?.toLocaleString('en-US')} أوقية</div>
            </div>

            {/* ── Earnings ─────────────────────────────────────── */}
            {(() => {
              const isRej   = modal.row.status === 'rejected' || modal.row.status === 'refunded'
              const amt     = modal.row.amount || 0
              const commRate = modal.type === 'sub' ? subComm : sessionComm
              const comm    = isRej ? 0 : Math.round(amt * commRate)
              const net     = isRej ? 0 : amt - comm
              return (
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 20 }}>
                  <div style={{ background: isRej ? '#F3F4F6' : '#FEF3C7', borderRadius: 12, padding: '10px 14px' }}>
                    <div style={{ fontSize: 11, color: isRej ? '#9CA3AF' : '#92400E', marginBottom: 3 }}>عمولة المنصة{isRej ? ' — مرفوض' : ''}</div>
                    <div style={{ fontSize: 17, fontWeight: 700, color: isRej ? '#9CA3AF' : '#D97706' }}>{isRej ? '0' : comm.toLocaleString('en-US')} أوقية</div>
                  </div>
                  <div style={{ background: isRej ? '#F3F4F6' : '#D7F2E6', borderRadius: 12, padding: '10px 14px' }}>
                    <div style={{ fontSize: 11, color: isRej ? '#9CA3AF' : '#0A6E4E', marginBottom: 3 }}>صافي الأستاذ{isRej ? ' — مرفوض' : ''}</div>
                    <div style={{ fontSize: 17, fontWeight: 700, color: isRej ? '#9CA3AF' : '#059669' }}>{isRej ? '0' : net.toLocaleString('en-US')} أوقية</div>
                  </div>
                </div>
              )
            })()}

            {/* ── Actions ──────────────────────────────────────── */}
            {(() => {
              /* Already decided — show close + dispute options for confirmed sessions */
              if (['rejected', 'refunded', 'active', 'expired'].includes(modal.row.status)) {
                return <button className="btn btn-secondary" style={{ width: '100%', justifyContent: 'center' }} onClick={closeModal}>إغلاق</button>
              }

              if (modal.row.status === 'confirmed' && modal.type === 'session') {
                const ds = modal.row.dispute_status || 'confirmed'
                return (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                    {/* Dispute status badge */}
                    {ds !== 'confirmed' && (
                      <div style={{
                        padding: '8px 14px', borderRadius: 10, fontSize: 12, fontWeight: 600,
                        background: ds === 'frozen' ? '#FEF3C7' : '#ECE5F7',
                        color: ds === 'frozen' ? '#92400E' : '#5A3B95',
                        border: `1px solid ${ds === 'frozen' ? '#FCD34D' : '#C4B5FD'}`,
                      }}>
                        {ds === 'frozen' ? '⚠ المبلغ مجمّد للتحقيق' : '✓ تم الاسترداد بعد النزاع'}
                        {ds === 'refunded' && modal.row.dispute_refund_amount && (
                          <span style={{ marginRight: 6 }}>· {modal.row.dispute_refund_amount?.toLocaleString('en-US')} أوقية</span>
                        )}
                      </div>
                    )}

                    {!disputeMode ? (
                      <div style={{ display: 'flex', gap: 10 }}>
                        <button className="btn btn-secondary" style={{ flex: 1, justifyContent: 'center' }} onClick={closeModal}>إغلاق</button>
                        {ds !== 'refunded' && (
                          <button
                            className="btn"
                            style={{ flex: 1, justifyContent: 'center', background: '#FEF3C7', color: '#92400E', border: '1px solid #FCD34D', fontWeight: 700 }}
                            onClick={() => setDisputeMode(true)}
                          >
                            ⚠ فتح نزاع
                          </button>
                        )}
                      </div>
                    ) : (
                      <div>
                        <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text)', marginBottom: 12 }}>إجراء النزاع</div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 14 }}>
                          {/* Option 1: Freeze */}
                          <label style={{
                            display: 'flex', alignItems: 'flex-start', gap: 10,
                            padding: '12px 14px', borderRadius: 12, cursor: 'pointer',
                            border: `2px solid ${disputeAction === 'frozen' ? '#F59E0B' : 'var(--border)'}`,
                            background: disputeAction === 'frozen' ? '#FEF3C7' : '#F9FAFB',
                          }}>
                            <input type="radio" name="dispute_action" value="frozen"
                              checked={disputeAction === 'frozen'}
                              onChange={() => { setDisputeAction('frozen'); setDisputeAmount('') }}
                              style={{ marginTop: 2 }} />
                            <div>
                              <div style={{ fontSize: 13, fontWeight: 700, color: '#92400E' }}>⚠ تجميد المبلغ</div>
                              <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 2 }}>
                                يُجمَّد المبلغ مؤقتاً ويُشعَر كل من الأستاذ والطالب بالتجميد وبدء التحقيق
                              </div>
                            </div>
                          </label>

                          {/* Option 2: Refund student */}
                          <label style={{
                            display: 'flex', alignItems: 'flex-start', gap: 10,
                            padding: '12px 14px', borderRadius: 12, cursor: 'pointer',
                            border: `2px solid ${disputeAction === 'refunded' ? '#7C3AED' : 'var(--border)'}`,
                            background: disputeAction === 'refunded' ? '#F0EDFF' : '#F9FAFB',
                          }}>
                            <input type="radio" name="dispute_action" value="refunded"
                              checked={disputeAction === 'refunded'}
                              onChange={() => setDisputeAction('refunded')}
                              style={{ marginTop: 2 }} />
                            <div style={{ flex: 1 }}>
                              <div style={{ fontSize: 13, fontWeight: 700, color: '#5A3B95' }}>↩ استرداد للطالب</div>
                              <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 2 }}>
                                الطالب صاحب الحق — يُشعَر كلاهما ويُضاف للمستردات
                              </div>
                              {disputeAction === 'refunded' && (
                                <input
                                  type="number" min="0" max={modal.row.amount}
                                  placeholder={`المبلغ المسترد (من ${modal.row.amount} أوقية)`}
                                  value={disputeAmount}
                                  onChange={e => setDisputeAmount(e.target.value)}
                                  onClick={e => e.stopPropagation()}
                                  style={{
                                    marginTop: 8, width: '100%', padding: '7px 10px',
                                    borderRadius: 8, border: '1.5px solid #C4B5FD',
                                    fontSize: 13, fontWeight: 700, color: '#5A3B95', outline: 'none',
                                  }}
                                />
                              )}
                            </div>
                          </label>

                          {/* Option 3: Confirm teacher's right */}
                          <label style={{
                            display: 'flex', alignItems: 'flex-start', gap: 10,
                            padding: '12px 14px', borderRadius: 12, cursor: 'pointer',
                            border: `2px solid ${disputeAction === 'confirm' ? '#059669' : 'var(--border)'}`,
                            background: disputeAction === 'confirm' ? '#D7F2E6' : '#F9FAFB',
                          }}>
                            <input type="radio" name="dispute_action" value="confirm"
                              checked={disputeAction === 'confirm'}
                              onChange={() => { setDisputeAction('confirm'); setDisputeAmount('') }}
                              style={{ marginTop: 2 }} />
                            <div>
                              <div style={{ fontSize: 13, fontWeight: 700, color: '#059669' }}>✓ تأكيد حق الأستاذ</div>
                              <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 2 }}>
                                الأستاذ صاحب الحق — يُشعَر الأستاذ بتأكيد المبلغ والطالب برفض الشكوى
                              </div>
                            </div>
                          </label>
                        </div>

                        <div style={{ display: 'flex', gap: 10 }}>
                          <button
                            className="btn btn-primary" style={{ flex: 1, justifyContent: 'center' }}
                            disabled={!!actionId || !disputeAction || (disputeAction === 'refunded' && !disputeAmount)}
                            onClick={() => {
                              if (disputeAction === 'frozen')   return freezePayment(modal.row.id)
                              if (disputeAction === 'refunded') return disputeRefund(modal.row.id, disputeAmount)
                              if (disputeAction === 'confirm')  return confirmAfterDispute(modal.row.id)
                            }}
                          >
                            {actionId
                              ? <span className="spinner" style={{ width: 14, height: 14, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
                              : 'تنفيذ الإجراء'}
                          </button>
                          <button className="btn btn-secondary" onClick={() => { setDisputeMode(false); setDisputeAction(''); setDisputeAmount('') }}>رجوع</button>
                        </div>
                      </div>
                    )}
                  </div>
                )
              }

              if (modal.row.status === 'confirmed') {
                return <button className="btn btn-secondary" style={{ width: '100%', justifyContent: 'center' }} onClick={closeModal}>إغلاق</button>
              }

              /* Rejection form — 2 clear options */
              if (rejectInput) {
                const REJECT_REASONS = [
                  {
                    value: 'FAKE_PROOF',
                    label: 'الوصل مزيف',
                    desc:  'الإثبات غير حقيقي — مرفوض نهائياً، لا استرداد',
                    icon:  '🚫',
                    badge: { bg: '#FBE0DB', fg: '#A12B1D', text: 'ملغى' },
                  },
                  {
                    value: 'INCOMPLETE_AMOUNT',
                    label: 'المبلغ غير مكتمل',
                    desc:  'المبلغ أقل من المطلوب — يُلغى ويُسترد فوراً',
                    icon:  '💰',
                    badge: { bg: '#ECE5F7', fg: '#5A3B95', text: 'ملغى + مسترد' },
                  },
                ]
                return (
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text)', marginBottom: 12 }}>اختر سبب الرفض</div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 16 }}>
                      {REJECT_REASONS.map(opt => (
                        <label key={opt.value} style={{
                          display: 'flex', alignItems: 'center', gap: 12,
                          padding: '13px 14px', borderRadius: 12, cursor: 'pointer',
                          border: `2px solid ${rejectReason === opt.value ? '#A12B1D' : 'var(--border)'}`,
                          background: rejectReason === opt.value ? '#FBE0DB' : '#F9FAFB',
                          transition: 'all .15s',
                        }}>
                          <input type="radio" name="reject_reason" value={opt.value}
                            checked={rejectReason === opt.value}
                            onChange={() => setRejectReason(opt.value)}
                            style={{ width: 16, height: 16, cursor: 'pointer', accentColor: '#A12B1D' }} />
                          <span style={{ fontSize: 22, flexShrink: 0 }}>{opt.icon}</span>
                          <div style={{ flex: 1 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                              <span style={{ fontSize: 13.5, fontWeight: 700, color: rejectReason === opt.value ? '#A12B1D' : 'var(--text)' }}>{opt.label}</span>
                              <span className="badge" style={{ background: opt.badge.bg, color: opt.badge.fg, fontSize: 10 }}>{opt.badge.text}</span>
                            </div>
                            <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 3 }}>{opt.desc}</div>
                          </div>
                        </label>
                      ))}
                    </div>

                    {/* Problem 1: refund amount input for incomplete payment */}
                    {rejectReason === 'INCOMPLETE_AMOUNT' && (
                      <div style={{ background: '#F0EDFF', borderRadius: 10, padding: '12px 14px', marginBottom: 12 }}>
                        <div style={{ fontSize: 12, fontWeight: 700, color: '#5A3B95', marginBottom: 6 }}>
                          💰 المبلغ الفعلي الذي سيُسترد للطالب (أوقية)
                        </div>
                        <input
                          type="number"
                          min="0"
                          max={modal.row.amount}
                          placeholder={`الحد الأقصى: ${modal.row.amount} أوقية`}
                          value={refundAmountInput}
                          onChange={e => setRefundAmountInput(e.target.value)}
                          style={{
                            width: '100%', padding: '8px 12px', borderRadius: 8, border: '1.5px solid #C4B5FD',
                            fontSize: 14, fontWeight: 700, color: '#5A3B95', outline: 'none',
                          }}
                        />
                      </div>
                    )}

                    <div style={{ display: 'flex', gap: 10 }}>
                      <button
                        className="btn btn-danger" style={{ flex: 1, justifyContent: 'center' }}
                        disabled={!!actionId || !rejectReason || (rejectReason === 'INCOMPLETE_AMOUNT' && !refundAmountInput)}
                        onClick={async () => {
                          if (modal.type === 'session') {
                            await rejectPayment(modal.row.id, rejectReason)
                            // Save actual refund amount for incomplete payment
                            if (rejectReason === 'INCOMPLETE_AMOUNT' && refundAmountInput) {
                              await supabase.from('payments')
                                .update({ actual_refund_amount: parseFloat(refundAmountInput) })
                                .eq('id', modal.row.id)
                            }
                            return
                          }
                          if (rejectReason === 'INCOMPLETE_AMOUNT') return rejectSubWithRefund(modal.row.id, rejectReason, refundAmountInput)
                          return rejectSub(modal.row.id, rejectReason)
                        }}
                      >
                        {actionId
                          ? <span className="spinner" style={{ width: 14, height: 14, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
                          : rejectReason === 'INCOMPLETE_AMOUNT' ? '↩ رفض + استرداد' : '✕ رفض نهائي'}
                      </button>
                      <button className="btn btn-secondary" onClick={() => { setRejectInput(false); setRejectReason(''); setRefundAmountInput('') }}>رجوع</button>
                    </div>
                  </div>
                )
              }

              /* Main action buttons — pending / submitted */
              const noProof = modal.type === 'session' && !modal.row.proof_image_url
              return (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                  {noProof && (
                    <div style={{ background: '#FBE0DB', borderRadius: 8, padding: '8px 12px', fontSize: 12, color: '#A12B1D' }}>
                      🚫 لا يمكن تأكيد الدفع — لم يُرفق وصل دفع
                    </div>
                  )}
                  <div style={{ display: 'flex', gap: 10 }}>
                    <button className="btn btn-primary" style={{ flex: 1, justifyContent: 'center' }}
                      disabled={!!actionId || noProof}
                      title={noProof ? 'لا يوجد وصل دفع مرفق' : undefined}
                      onClick={() => modal.type === 'session' ? confirmPayment(modal.row.id) : confirmSub(modal.row.id)}>
                      {actionId
                        ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
                        : '✓ تأكيد الدفع'}
                    </button>
                    <button className="btn btn-danger" style={{ flex: 1, justifyContent: 'center' }} disabled={!!actionId} onClick={() => setRejectInput(true)}>
                      ✕ رفض
                    </button>
                  </div>
                </div>
              )
            })()}
          </div>
        </div>
      )}

      {/* ── Refunds tab ────────────────────────────────────────── */}
      {tab === 'refunds' && (
        (refundedRows.length === 0 && subRefundedRows.length === 0 && disputeRefundedRows.length === 0)
          ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text3)' }}>
              <div style={{ fontSize: 40, marginBottom: 12 }}>💰</div>
              <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--text2)' }}>لا توجد مبالغ مستردة</div>
            </div>
          )
          : (
            <>
              {refundedRows.length > 0 && (
                <>
                  <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text2)', marginBottom: 8 }}>
                    استردادات الجلسات <span style={{ fontSize: 11, fontWeight: 400, color: 'var(--text3)' }}>({refundedRows.length})</span>
                  </div>
                  <div className="table-wrap" style={{ marginBottom: 24 }}>
                    <div className="table-head" style={{ gridTemplateColumns: '1.2fr 1fr 1fr 1.1fr 0.8fr 0.8fr 0.7fr' }}>
                      <span>الطالب</span><span>المادة</span><span>الأستاذ</span>
                      <span>سبب الاسترداد</span><span>المبلغ المسترد</span><span>طريقة الدفع</span><span>التاريخ</span>
                    </div>
                    {refundedRows.map(r => {
                      const cr = r.cancellation_reason
                      const [reasonLabel, rBg, rFg] =
                        cr === 'teacher_no_show_refund' ? ['غياب الأستاذ',      '#FBE0DB', '#A12B1D']
                        : cr === 'insufficient_refund'  ? ['مبلغ ناقص',          '#ECE5F7', '#5A3B95']
                        :                                [cr || '—',             '#F1F5F9', '#475569']
                      const pay = r.payment
                      const refAmt = pay?.amount || r.amount
                      return (
                        <div key={r.id} className="table-row" style={{ gridTemplateColumns: '1.2fr 1fr 1fr 1.1fr 0.8fr 0.8fr 0.7fr', alignItems: 'center' }}>
                          <span className="fw-700">{r.student_name || '—'}</span>
                          <span className="text-2">{r.subject || '—'}</span>
                          <span className="text-2">{r.teacher_name || '—'}</span>
                          <span>
                            <span className="badge" style={{ background: rBg, color: rFg }}>{reasonLabel}</span>
                          </span>
                          <span className="fw-700" style={{ color: 'var(--purple)' }}>{fmt(refAmt)} أوقية</span>
                          <span style={{ fontSize: 12 }}>{fmtMethod(pay?.method)}</span>
                          <span className="text-muted" style={{ fontSize: 11 }}>{r.updated_at?.slice(0, 10)}</span>
                        </div>
                      )
                    })}
                  </div>
                </>
              )}

              {disputeRefundedRows.length > 0 && (
                <>
                  <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text2)', marginBottom: 8 }}>
                    استردادات النزاعات ⚖ <span style={{ fontSize: 11, fontWeight: 400, color: 'var(--text3)' }}>({disputeRefundedRows.length})</span>
                  </div>
                  <div className="table-wrap" style={{ marginBottom: 24 }}>
                    <div className="table-head" style={{ gridTemplateColumns: '1.2fr 1fr 1fr 0.9fr 0.9fr 0.7fr' }}>
                      <span>الطالب</span><span>المادة</span><span>المبلغ الكلي</span>
                      <span>المسترد فعلياً</span><span>طريقة الدفع</span><span>تاريخ الإجراء</span>
                    </div>
                    {disputeRefundedRows.map(r => (
                      <div key={r.id} className="table-row" style={{ gridTemplateColumns: '1.2fr 1fr 1fr 0.9fr 0.9fr 0.7fr', alignItems: 'center' }}>
                        <span className="fw-700">{r.student?.full_name || '—'}</span>
                        <span className="text-2">{r.session?.subject || '—'}</span>
                        <span className="fw-700">{fmt(r.amount)} أوقية</span>
                        <span className="fw-700" style={{ color: 'var(--purple)' }}>{fmt(r.dispute_refund_amount)} أوقية</span>
                        <span style={{ fontSize: 12 }}>{fmtMethod(r.method)}</span>
                        <span className="text-muted" style={{ fontSize: 11 }}>{r.dispute_updated_at?.slice(0, 10)}</span>
                      </div>
                    ))}
                  </div>
                </>
              )}

              {subRefundedRows.length > 0 && (
                <>
                  <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text2)', marginBottom: 8 }}>
                    استردادات الاشتراكات <span style={{ fontSize: 11, fontWeight: 400, color: 'var(--text3)' }}>({subRefundedRows.length})</span>
                  </div>
                  <div className="table-wrap">
                    <div className="table-head" style={{ gridTemplateColumns: '1.2fr 1.2fr 1fr 1.1fr 0.8fr 0.8fr 0.7fr' }}>
                      <span>الطالب</span><span>الدورة / الباقة</span><span>الأستاذ</span>
                      <span>سبب الاسترداد</span><span>المبلغ المسترد</span><span>الخطة</span><span>التاريخ</span>
                    </div>
                    {subRefundedRows.map(r => {
                      const rawReason = (r.reject_reason || '').replace(/^REFUND:/i, '').toUpperCase()
                      const reasonLabel =
                        rawReason === 'INCOMPLETE_AMOUNT' ? 'مبلغ ناقص'
                        : rawReason === 'FAKE_PROOF'      ? 'وصل مزيف'
                        : rawReason || '—'
                      return (
                        <div key={r.id} className="table-row" style={{ gridTemplateColumns: '1.2fr 1.2fr 1fr 1.1fr 0.8fr 0.8fr 0.7fr', alignItems: 'center' }}>
                          <span className="fw-700">{r.student?.full_name || '—'}</span>
                          <span className="text-2">{r.course?.title || r.package?.title || '—'}</span>
                          <span className="text-2">{r.course?.teacher_name || '—'}</span>
                          <span>
                            <span className="badge" style={{ background: '#ECE5F7', color: '#5A3B95' }}>{reasonLabel}</span>
                          </span>
                          <span className="fw-700" style={{ color: 'var(--purple)' }}>{fmt(r.amount)} أوقية</span>
                          <span style={{ fontSize: 12 }}>{PLAN_LABELS[r.plan_type] || 'شهري'}</span>
                          <span className="text-muted" style={{ fontSize: 11 }}>{r.updated_at?.slice(0, 10)}</span>
                        </div>
                      )
                    })}
                  </div>
                </>
              )}
            </>
          )
      )}
    </div>
  )
}
