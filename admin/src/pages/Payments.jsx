import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

const COMMISSION_RATE = 0.15

function Badge({ status }) {
  const map = {
    submitted: ['قيد التأكيد', '#FEF3C7', '#92400E'],
    confirmed: ['مؤكّد',       '#D1FAE5', '#065F46'],
    rejected:  ['مرفوض',       '#FEE2E2', '#991B1B'],
    refunded:  ['مسترد',       '#EDE9FE', '#5B21B6'],
    pending:   ['قيد المراجعة','#EDE9FE', '#5B21B6'],
    active:    ['نشط',         '#D1FAE5', '#065F46'],
    cancelled: ['ملغى',        '#FEE2E2', '#991B1B'],
  }
  const [label, bg, fg] = map[status] || ['—', '#F1F5F9', '#475569']
  return <span className="badge" style={{ background: bg, color: fg }}>{label}</span>
}

const REFUND_REASON_LABELS = {
  teacher_no_show_refund: 'غياب الأستاذ (طلب طالب)',
  insufficient_refund:    'مبلغ منقوص (استرداد)',
  fake_proof:             'إثبات مزيف (انتهاء مهلة)',
  no_payment_deadline:    'انتهاء مهلة الدفع',
}

export default function Payments({ adminId }) {
  const toast = useToast()
  const [tab, setTab]           = useState('sessions')
  const [rows, setRows]         = useState([])
  const [subRows, setSubRows]   = useState([])
  const [refundedRows, setRefundedRows] = useState([])
  const [stats, setStats]       = useState({})
  const [loading, setLoading]   = useState(true)
  const [actionId, setActionId] = useState(null)
  const [modal, setModal]       = useState(null)
  const [rejectInput, setRejectInput]   = useState(false)
  const [rejectReason, setRejectReason] = useState('')
  const [proofUrl, setProofUrl]         = useState(null)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const [payRes, subPayRes, refundedRes] = await Promise.all([
      supabase.from('payments')
        .select('*, session:session_id(id,subject,student_id,teacher_id,scheduled_at,payment_deadline,state,cancellation_reason), student:student_id(full_name)')
        .order('created_at', { ascending: false }),
      supabase.from('subscriptions')
        .select('*, student:student_id(full_name), course:course_id(title, teacher_id), package:package_id(title)')
        .order('created_at', { ascending: false }),
      // Sessions cancelled with refund (any reason involving a refund)
      supabase.from('sessions')
        .select('*, student:student_id(full_name), teacher:teacher_id(full_name)')
        .in('cancellation_reason', ['teacher_no_show_refund', 'insufficient_refund'])
        .order('updated_at', { ascending: false }),
    ])

    const pays = payRes.data || []
    let subs   = subPayRes.data || []
    const refunded = refundedRes.data || []

    const teacherIds = [...new Set(subs.map(s => s.course?.teacher_id).filter(Boolean))]
    if (teacherIds.length > 0) {
      const { data: teachers } = await supabase.from('profiles').select('id, full_name').in('id', teacherIds)
      const teacherMap = Object.fromEntries((teachers || []).map(t => [t.id, t.full_name]))
      subs = subs.map(s => ({
        ...s,
        course: s.course ? { ...s.course, teacher_name: teacherMap[s.course.teacher_id] || '—' } : s.course,
      }))
    }

    const today = new Date().toISOString().slice(0, 10)
    const confirmedToday   = pays.filter(p => p.status === 'confirmed' && p.created_at?.startsWith(today))
    const sessionCommToday = confirmedToday.reduce((s, p) => s + (p.amount || 0) * COMMISSION_RATE, 0)
    const activeSubs       = subs.filter(s => s.status === 'active')
    const subCommTotal     = activeSubs.reduce((s, r) => s + (r.platform_commission ?? r.amount * COMMISSION_RATE), 0)
    const totalRefunded    = refunded.reduce((acc, s) => acc + (s.amount || 0), 0)

    setStats({
      pendingSessions:  pays.filter(p => p.status === 'submitted').length,
      pendingSubs:      subs.filter(s => s.status === 'pending').length,
      sessionCommToday: Math.round(sessionCommToday),
      subCommTotal:     Math.round(subCommTotal),
      totalRefunded:    Math.round(totalRefunded),
      refundCount:      refunded.length,
    })
    setRows(pays)
    setSubRows(subs)
    setRefundedRows(refunded)
    setLoading(false)
  }

  async function openModal(type, row) {
    setModal({ type, row })
    setProofUrl(null)
    setRejectInput(false)
    setRejectReason('')
    if (row.proof_image_url) {
      const bucket = type === 'session' ? 'payment-proofs' : 'subscription-proofs'
      // Extract storage path whether we have a full URL or just a path
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
  }

  async function confirmPayment(paymentId) {
    setActionId(paymentId)
    try {
      // admin_confirm_payment(p_payment_id, p_admin_id, p_note)
      // Sets payment.status='confirmed' + session.state='PAYMENT_CONFIRMED'
      // DB trigger then fires → ledger entry + notifications → auto-advance to CONFIRMED_BOOKING
      const { error } = await supabase.rpc('admin_confirm_payment', {
        p_payment_id: paymentId,
        p_admin_id:   adminId,
      })
      if (error) throw error
      closeModal()
      await loadData()
      toast('تم تأكيد الدفع بنجاح وإشعار الطالب والأستاذ', 'success')
    } catch (err) {
      toast('خطأ في تأكيد الدفع: ' + (err.message || 'حدث خطأ غير متوقع'), 'error')
    } finally {
      setActionId(null)
    }
  }

  async function rejectPayment(paymentId, reason) {
    if (!reason?.trim()) return
    setActionId(paymentId)
    try {
      // admin_reject_payment(p_payment_id, p_admin_id, p_reason)
      // Sets payment.status='rejected' + session.state='PAYMENT_REJECTED' + notifies student
      const { error } = await supabase.rpc('admin_reject_payment', {
        p_payment_id: paymentId,
        p_admin_id:   adminId,
        p_reason:     reason.trim(),
      })
      if (error) throw error
      closeModal()
      await loadData()
      toast('تم رفض الدفع وإشعار الطالب بسبب الرفض', 'success')
    } catch (err) {
      toast('خطأ في رفض الدفع: ' + (err.message || 'حدث خطأ غير متوقع'), 'error')
    } finally {
      setActionId(null)
    }
  }

  async function confirmSub(id) {
    setActionId(id)
    const sub = subRows.find(r => r.id === id)
    const months = sub?.plan_type === 'yearly' ? 12 : 1
    try {
      // admin_confirm_subscription(p_subscription_id, p_admin_id, p_months)
      const { error } = await supabase.rpc('admin_confirm_subscription', {
        p_subscription_id: id,
        p_admin_id:        adminId,
        p_months:          months,
      })
      if (error) throw error
      closeModal()
      await loadData()
      toast('تم تأكيد الاشتراك وتفعيله بنجاح', 'success')
    } catch (err) {
      toast('خطأ في تأكيد الاشتراك: ' + (err.message || 'حدث خطأ غير متوقع'), 'error')
    } finally {
      setActionId(null)
    }
  }

  async function rejectSub(id, reason) {
    if (!reason?.trim()) return
    setActionId(id)
    try {
      // admin_reject_subscription(p_subscription_id, p_admin_id, p_reason)
      const { error } = await supabase.rpc('admin_reject_subscription', {
        p_subscription_id: id,
        p_admin_id:        adminId,
        p_reason:          reason.trim(),
      })
      if (error) throw error
      closeModal()
      await loadData()
      toast('تم رفض الاشتراك وإشعار الطالب', 'success')
    } catch (err) {
      toast('خطأ في رفض الاشتراك: ' + (err.message || 'حدث خطأ غير متوقع'), 'error')
    } finally {
      setActionId(null)
    }
  }

  // ── Force-activate an expired rejected payment ─────────────────────────────
  async function forceActivateExpired(paymentId) {
    setActionId(paymentId)
    try {
      const { error } = await supabase.rpc('admin_confirm_payment', {
        p_payment_id: paymentId,
        p_admin_id:   adminId,
      })
      if (error) throw error
      closeModal()
      await loadData()
      toast('تم تفعيل الجلسة رغم انتهاء المهلة', 'success')
    } catch (err) {
      toast('خطأ: ' + (err.message || ''), 'error')
    } finally {
      setActionId(null)
    }
  }

  // ── Cancel expired rejected payment with refund ─────────────────────────────
  async function cancelExpiredWithRefund(payment) {
    setActionId(payment.id)
    try {
      const sessionId = payment.session_id || payment.session?.id
      const { error } = await supabase.from('sessions').update({
        state:               'CANCELLED',
        cancellation_reason: 'insufficient_refund',
        updated_at:          new Date().toISOString(),
      }).eq('id', sessionId)
      if (error) throw error

      await supabase.from('payments')
        .update({ status: 'refunded' }).eq('id', payment.id)

      await supabase.from('session_events').insert({
        session_id: sessionId,
        event_type: 'REFUND_PROCESSED',
        actor:      'admin',
      })

      await supabase.from('notifications').insert({
        user_id:    payment.student_id,
        title:      'تم استرداد مبلغك ✅',
        body:       'تم إلغاء الجلسة واسترداد المبلغ المدفوع.',
        type:       'refund_processed',
        session_id: sessionId,
      })

      closeModal()
      await loadData()
      toast('تم إلغاء الجلسة وتسجيل استرداد المبلغ', 'success')
    } catch (err) {
      toast('خطأ: ' + (err.message || ''), 'error')
    } finally {
      setActionId(null)
    }
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const fmt = n => n?.toLocaleString('ar') ?? '—'

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
          <div style={{ fontSize: 21, fontWeight: 700, color: '#7C3AED', marginTop: 3 }}>{stats.pendingSubs}</div>
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
          <div style={{ fontSize: 21, fontWeight: 700, color: '#7B61FF', marginTop: 3 }}>
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
          مدفوعات الاشتراكات {stats.pendingSubs > 0 && <span className="badge" style={{ background: '#EDE9FE', color: '#5B21B6', marginRight: 5, fontSize: 10 }}>{stats.pendingSubs}</span>}
        </div>
        <div className={`tab${tab === 'refunds' ? ' active' : ''}`} onClick={() => setTab('refunds')}>
          المبالغ المستردة {stats.refundCount > 0 && <span className="badge" style={{ background: '#EDE9FE', color: '#5B21B6', marginRight: 5, fontSize: 10 }}>{stats.refundCount}</span>}
        </div>
      </div>

      {/* ── Sessions payments table ────────────────────────────── */}
      {tab === 'sessions' && (
        <div className="table-wrap">
          <div className="table-head" style={{ gridTemplateColumns: '1fr 1.5fr 0.9fr 0.9fr 0.9fr 1fr 1.1fr' }}>
            <span>المرجع</span><span>الطالب · المادة</span>
            <span>المبلغ</span><span>عمولة المنصة</span><span>صافي الأستاذ</span>
            <span>الحالة</span><span style={{ textAlign: 'left' }}>إجراء</span>
          </div>
          {rows.length === 0 && <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا توجد مدفوعات</div>}
          {rows.map(r => {
            const comm = Math.round((r.amount || 0) * COMMISSION_RATE)
            const net  = Math.round((r.amount || 0) - comm)
            return (
              <div key={r.id} className="table-row" style={{ gridTemplateColumns: '1fr 1.5fr 0.9fr 0.9fr 0.9fr 1fr 1.1fr' }}>
                <span className="fw-700 dir-ltr">{r.reference || r.id.slice(0, 8)}</span>
                <span>{r.student?.full_name || '—'} · {r.session?.subject || '—'}</span>
                <span className="fw-700">{fmt(r.amount)}</span>
                <span style={{ color: '#D97706', fontWeight: 600 }}>{fmt(comm)}</span>
                <span className="fw-700 text-green">{fmt(net)}</span>
                <span><Badge status={r.status} /></span>
                <span style={{ textAlign: 'left' }}>
                  {r.status === 'submitted'
                    ? <button className="btn btn-sm btn-review" onClick={() => openModal('session', r)} disabled={actionId === r.id}>🔍 مراجعة</button>
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
          <div className="table-head" style={{ gridTemplateColumns: '0.8fr 1.2fr 1fr 0.7fr 0.9fr 0.9fr 0.9fr 0.8fr 1fr' }}>
            <span>المرجع</span><span>الطالب</span><span>الدورة</span><span>الخطة</span>
            <span>المبلغ</span><span>عمولة المنصة</span><span>صافي الأستاذ</span>
            <span>الحالة</span><span style={{ textAlign: 'left' }}>إجراء</span>
          </div>
          {subRows.length === 0 && <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا توجد اشتراكات</div>}
          {subRows.map(r => {
            const comm = r.platform_commission != null
              ? Math.round(r.platform_commission)
              : Math.round((r.amount || 0) * COMMISSION_RATE)
            const net = r.teacher_earning != null
              ? Math.round(r.teacher_earning)
              : Math.round((r.amount || 0) * (1 - COMMISSION_RATE))
            const teacherName = r.course?.teacher_name || '—'
            return (
              <div key={r.id} className="table-row" style={{ gridTemplateColumns: '0.8fr 1.2fr 1fr 0.7fr 0.9fr 0.9fr 0.9fr 0.8fr 1fr' }}>
                <span className="fw-700 dir-ltr">{r.id.slice(0, 8)}</span>
                <span>{r.student?.full_name || '—'}</span>
                <span className="text-2" title={`أستاذ: ${teacherName}`}>
                  {r.course?.title || r.package?.title || '—'}
                  <br /><span style={{ fontSize: 10, color: 'var(--text3)' }}>{teacherName}</span>
                </span>
                <span className="text-2">{r.plan_type === 'yearly' ? 'سنوي' : 'شهري'}</span>
                <span className="fw-700">{fmt(r.amount)}</span>
                <span style={{ color: '#D97706', fontWeight: 600 }}>{fmt(comm)}</span>
                <span className="fw-700 text-green">{fmt(net)}</span>
                <span><Badge status={r.status} /></span>
                <span style={{ textAlign: 'left' }}>
                  {r.status === 'pending'
                    ? <button className="btn btn-sm btn-review" onClick={() => openModal('sub', r)} disabled={actionId === r.id}>🔍 مراجعة</button>
                    : <span className="text-muted" style={{ fontSize: 12 }}>—</span>}
                </span>
              </div>
            )
          })}
        </div>
      )}

      {/* ── Review modal ───────────────────────────────────────── */}
      {modal && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.45)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}
          onClick={closeModal}
        >
          <div style={{ background: '#fff', borderRadius: 20, padding: 28, width: 460, maxWidth: '95vw' }} onClick={e => e.stopPropagation()}>
            <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 16, color: 'var(--text)' }}>مراجعة الدفع</div>

            {/* Proof image */}
            {modal.row.proof_image_url && (
              <div style={{ marginBottom: 16 }}>
                <div style={{ fontSize: 12, color: 'var(--text3)', marginBottom: 8 }}>إثبات الدفع</div>
                {proofUrl
                  ? <img src={proofUrl} alt="proof" style={{ width: '100%', borderRadius: 12, border: '1px solid var(--border)', maxHeight: 260, objectFit: 'contain' }} />
                  : <div style={{ textAlign: 'center', padding: '18px 0', color: 'var(--text3)', fontSize: 13, background: '#F5F7FF', borderRadius: 12 }}>جارٍ تحميل إثبات الدفع…</div>
                }
              </div>
            )}

            {/* Details */}
            <div style={{ background: '#F5F7FF', borderRadius: 12, padding: 14, marginBottom: 16, fontSize: 13, display: 'flex', flexDirection: 'column', gap: 7 }}>
              {modal.type === 'sub' && (
                <>
                  <div><b>الطالب:</b> {modal.row.student?.full_name || '—'}</div>
                  <div><b>الدورة:</b> {modal.row.course?.title || modal.row.package?.title || '—'}</div>
                  <div><b>الأستاذ:</b> {modal.row.course?.teacher_name || '—'}</div>
                  <div><b>الخطة:</b> {modal.row.plan_type === 'yearly' ? 'سنوي (12 شهراً)' : 'شهري (شهر واحد)'}</div>
                </>
              )}
              {modal.type === 'session' && (() => {
                const session = modal.row.session
                const deadline = session?.payment_deadline ? new Date(session.payment_deadline) : null
                const scheduledAt = session?.scheduled_at ? new Date(session.scheduled_at) : null
                const deadlineExpired = deadline && deadline < new Date()
                return (
                  <>
                    <div><b>الطالب:</b> {modal.row.student?.full_name || '—'}</div>
                    <div><b>المادة:</b> {session?.subject || '—'}</div>
                    <div><b>الطريقة:</b> {modal.row.method || '—'}</div>
                    {scheduledAt && (
                      <div><b>موعد الجلسة:</b> {scheduledAt.toLocaleString('ar-EG', { dateStyle: 'short', timeStyle: 'short' })}</div>
                    )}
                    {deadline && (
                      <div style={{ color: deadlineExpired ? '#DC2626' : '#D97706', fontWeight: 600 }}>
                        <b>مهلة الدفع:</b> {deadline.toLocaleString('ar-EG', { dateStyle: 'short', timeStyle: 'short' })}
                        {deadlineExpired ? ' ⚠ منتهية' : ''}
                      </div>
                    )}
                    {deadlineExpired && (
                      <div style={{ background: '#FEE2E2', borderRadius: 8, padding: '8px 10px', fontSize: 12, color: '#991B1B', marginTop: 4 }}>
                        ⚠ انتهت مهلة الدفع — تأكّد قبل الموافقة أن الجلسة لا تزال صالحة.
                      </div>
                    )}
                  </>
                )
              })()}
              <div><b>المبلغ الكلي:</b> {modal.row.amount?.toLocaleString('ar')} أوقية</div>
              <div><b>التاريخ:</b> {modal.row.created_at?.slice(0, 10)}</div>
            </div>

            {/* Earnings breakdown */}
            {(() => {
              const amt  = modal.row.amount || 0
              const comm = Math.round(amt * COMMISSION_RATE)
              const net  = amt - comm
              return (
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 20 }}>
                  <div style={{ background: '#FEF3C7', borderRadius: 12, padding: '10px 14px' }}>
                    <div style={{ fontSize: 11, color: '#92400E', marginBottom: 3 }}>عمولة المنصة (15%)</div>
                    <div style={{ fontSize: 17, fontWeight: 700, color: '#D97706' }}>{comm.toLocaleString('ar')} أوقية</div>
                  </div>
                  <div style={{ background: '#D1FAE5', borderRadius: 12, padding: '10px 14px' }}>
                    <div style={{ fontSize: 11, color: '#065F46', marginBottom: 3 }}>صافي الأستاذ</div>
                    <div style={{ fontSize: 17, fontWeight: 700, color: '#059669' }}>{net.toLocaleString('ar')} أوقية</div>
                  </div>
                </div>
              )
            })()}

            {/* Actions */}
            {(() => {
              const isExpiredRejection = modal.type === 'session'
                && modal.row.status === 'rejected'
                && modal.row.session?.payment_deadline
                && new Date(modal.row.session.payment_deadline) < new Date()

              if (isExpiredRejection) {
                return (
                  <div>
                    <div style={{ background: '#FEF3C7', borderRadius: 10, padding: '10px 13px', marginBottom: 14, fontSize: 12.5, color: '#92400E' }}>
                      ⚠ انتهت المهلة بعد الرفض — اختر القرار النهائي:
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                      <button
                        className="btn btn-primary"
                        style={{ justifyContent: 'center' }}
                        disabled={!!actionId}
                        onClick={() => forceActivateExpired(modal.row.id)}
                      >
                        {actionId ? '…' : '✓ تفعيل الجلسة رغم المهلة'}
                      </button>
                      <button
                        className="btn"
                        style={{ background: '#EDE9FE', color: '#5B21B6', justifyContent: 'center' }}
                        disabled={!!actionId}
                        onClick={() => cancelExpiredWithRefund(modal.row)}
                      >
                        {actionId ? '…' : '↩ إلغاء واسترداد المبلغ المدفوع'}
                      </button>
                      <button className="btn btn-secondary" style={{ justifyContent: 'center' }} onClick={closeModal}>إغلاق</button>
                    </div>
                  </div>
                )
              }

              return rejectInput ? (
                <div>
                  <div style={{ fontSize: 13, color: 'var(--text2)', marginBottom: 8 }}>سبب الرفض (سيُرسَل للطالب)</div>
                  <textarea
                    className="field-input"
                    rows={2}
                    style={{ marginBottom: 12, resize: 'vertical' }}
                    placeholder="مثال: الإثبات غير واضح أو لا يطابق المبلغ…"
                    value={rejectReason}
                    onChange={e => setRejectReason(e.target.value)}
                    autoFocus
                  />
                  <div style={{ display: 'flex', gap: 10 }}>
                    <button
                      className="btn btn-danger"
                      style={{ flex: 1, justifyContent: 'center' }}
                      disabled={!!actionId || !rejectReason.trim()}
                      onClick={() => modal.type === 'session'
                        ? rejectPayment(modal.row.id, rejectReason)
                        : rejectSub(modal.row.id, rejectReason)
                      }
                    >
                      {actionId ? '…' : 'تأكيد الرفض'}
                    </button>
                    <button className="btn btn-secondary" onClick={() => { setRejectInput(false); setRejectReason('') }}>رجوع</button>
                  </div>
                </div>
              ) : (
                <div style={{ display: 'flex', gap: 10 }}>
                  <button
                    className="btn btn-primary"
                    style={{ flex: 1, justifyContent: 'center' }}
                    disabled={!!actionId}
                    onClick={() => modal.type === 'session' ? confirmPayment(modal.row.id) : confirmSub(modal.row.id)}
                  >
                    {actionId
                      ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
                      : '✓ تأكيد الدفع'}
                  </button>
                  <button
                    className="btn btn-danger"
                    style={{ flex: 1, justifyContent: 'center' }}
                    disabled={!!actionId}
                    onClick={() => setRejectInput(true)}
                  >
                    ✕ رفض
                  </button>
                </div>
              )
            })()}
          </div>
        </div>
      )}

      {/* ── Refunds tab ────────────────────────────────────────── */}
      {tab === 'refunds' && (
        refundedRows.length === 0
          ? (
            <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text3)' }}>
              <div style={{ fontSize: 40, marginBottom: 12 }}>💰</div>
              <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--text2)' }}>لا توجد مبالغ مستردة</div>
            </div>
          )
          : (
            <div className="table-wrap">
              <div className="table-head" style={{ gridTemplateColumns: '1.4fr 1.4fr 1.2fr 0.9fr 1.5fr 0.9fr' }}>
                <span>الطالب</span><span>الأستاذ</span><span>المادة</span>
                <span>المبلغ</span><span>السبب</span><span>التاريخ</span>
              </div>
              {refundedRows.map(r => (
                <div key={r.id} className="table-row" style={{ gridTemplateColumns: '1.4fr 1.4fr 1.2fr 0.9fr 1.5fr 0.9fr' }}>
                  <span className="fw-700">{r.student?.full_name || r.student_id?.slice(0, 8) || '—'}</span>
                  <span>{r.teacher?.full_name || r.teacher_id?.slice(0, 8) || '—'}</span>
                  <span className="text-2">{r.subject || '—'}</span>
                  <span className="fw-700" style={{ color: '#7B61FF' }}>{fmt(r.amount)} أوقية</span>
                  <span>
                    <span className="badge" style={{ background: '#EDE9FE', color: '#5B21B6' }}>
                      {REFUND_REASON_LABELS[r.cancellation_reason] || r.cancellation_reason || '—'}
                    </span>
                  </span>
                  <span className="text-muted" style={{ fontSize: 11 }}>{r.updated_at?.slice(0, 10)}</span>
                </div>
              ))}
            </div>
          )
      )}
    </div>
  )
}
