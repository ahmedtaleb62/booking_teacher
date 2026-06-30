import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

/* ── Rejection reason codes ─────────────────────────────────────── */
// 2 outcomes only — INCOMPLETE_AMOUNT always auto-refunds (sent as REFUND:INCOMPLETE_AMOUNT)
const REJECT_OPTIONS = [
  { value: 'FAKE_PROOF',        label: 'الوصل مزيف',       sub: 'لا استرداد — الوصل غير حقيقي',          color: '#A12B1D', bg: '#FBE0DB' },
  { value: 'INCOMPLETE_AMOUNT', label: 'المبلغ غير مكتمل', sub: 'استرداد فوري — المبلغ أقل من المطلوب', color: '#5A3B95', bg: '#ECE5F7' },
]

const REASON_LABEL = {
  FAKE_PROOF:         'الوصل مزيف',
  INCOMPLETE_AMOUNT:  'المبلغ غير مكتمل',
  STUDENT_CANCEL:     'ألغى الطالب الاشتراك',
}

/* ── Trail component ────────────────────────────────────────────── */
function SubStatusTrail({ reason, status }) {
  if (status === 'active')  return <span className="badge" style={{ background: '#D7F2E6', color: '#0A6E4E' }}>نشط</span>
  if (status === 'expired') return <span className="badge" style={{ background: '#F1F5F9', color: '#475569' }}>منتهي</span>
  if (status === 'pending') return <span className="badge" style={{ background: '#ECE5F7', color: '#5A3B95' }}>قيد المراجعة</span>

  if (!reason) return <span className="badge" style={{ background: '#FBE0DB', color: '#A12B1D' }}>مرفوض</span>

  if (reason === 'STUDENT_CANCEL') {
    return (
      <span className="badge" style={{ background: '#DBEAFE', color: '#1D4ED8' }}>
        ألغى الطالب
      </span>
    )
  }

  const isRefund   = reason.startsWith('REFUND:')
  const coreReason = isRefund ? reason.slice(7) : reason
  const isFake     = coreReason === 'FAKE_PROOF'

  if (isFake) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 4, flexWrap: 'wrap' }}>
        <span style={{ fontSize: 10, fontWeight: 600, padding: '2px 7px', borderRadius: 6, background: '#FBE0DB', color: '#A12B1D', whiteSpace: 'nowrap' }}>
          مرفوض
        </span>
        <span style={{ fontSize: 9, color: '#94A3B8' }}>·</span>
        <span style={{ fontSize: 10, fontWeight: 600, padding: '2px 7px', borderRadius: 6, background: '#FBE0DB', color: '#A12B1D', whiteSpace: 'nowrap' }}>
          الوصل مزيف
        </span>
      </div>
    )
  }

  // INCOMPLETE_AMOUNT — always refund
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 4, flexWrap: 'wrap' }}>
      <span style={{ fontSize: 10, fontWeight: 600, padding: '2px 7px', borderRadius: 6, background: '#FBE0DB', color: '#A12B1D', whiteSpace: 'nowrap' }}>
        ملغى
      </span>
      <span style={{ fontSize: 9, color: '#94A3B8' }}>·</span>
      <span style={{ fontSize: 10, fontWeight: 600, padding: '2px 7px', borderRadius: 6, background: '#ECE5F7', color: '#5A3B95', whiteSpace: 'nowrap' }}>
        مبلغ ناقص
      </span>
      <span style={{ fontSize: 9, color: '#94A3B8' }}>·</span>
      <span style={{ fontSize: 10, fontWeight: 600, padding: '2px 7px', borderRadius: 6, background: '#D7F2E6', color: '#0A6E4E', whiteSpace: 'nowrap' }}>
        مُسترد
      </span>
    </div>
  )
}

export default function Subscriptions({ adminId }) {
  const toast = useToast()
  const [rows, setRows]               = useState([])
  const [stats, setStats]             = useState({})
  const [loading, setLoading]         = useState(true)
  const [modal, setModal]             = useState(null)
  const [actionId, setActionId]       = useState(null)
  const [rejectMode, setRejectMode]   = useState(false)
  const [rejectValue, setRejectValue] = useState('')
  const [proofUrl, setProofUrl]       = useState(null)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const { data } = await supabase
      .from('subscriptions')
      .select('*, course:course_id(title), package:package_id(title), student:student_id(full_name)')
      .order('created_at', { ascending: false })

    const subs = data || []
    const now  = new Date()
    const weekEnd = new Date(now); weekEnd.setDate(weekEnd.getDate() + 7)

    setStats({
      active:   subs.filter(s => s.status === 'active').length,
      pending:  subs.filter(s => s.status === 'pending').length,
      expiring: subs.filter(s => s.status === 'active' && s.expires_at && new Date(s.expires_at) <= weekEnd).length,
      rejected: subs.filter(s => s.status === 'rejected').length,
      refunded: subs.filter(s => s.status === 'rejected' && s.reject_reason?.startsWith('REFUND:')).length,
    })
    setRows(subs)
    setLoading(false)
  }

  async function openModal(row) {
    setModal({ row })
    setProofUrl(null)
    setRejectMode(false)
    setRejectValue('')
    if (row.proof_image_url) {
      const src = row.proof_image_url
      if (src.startsWith('http')) {
        setProofUrl(src)
      } else {
        const { data } = await supabase.storage.from('subscription-proofs').createSignedUrl(src, 3600)
        setProofUrl(data?.signedUrl || null)
      }
    }
  }

  function closeModal() {
    setModal(null); setProofUrl(null); setRejectMode(false); setRejectValue('')
  }

  async function confirmSub(id) {
    setActionId(id)
    try {
      const months = modal?.row?.plan_type === 'yearly' ? 12 : 1
      const { error } = await supabase.rpc('admin_confirm_subscription', {
        p_subscription_id: id, p_admin_id: adminId, p_months: months,
      })
      if (error) throw error
      closeModal(); await loadData()
      toast('تم تأكيد الاشتراك وتفعيله بنجاح', 'success')
    } catch (err) {
      toast('خطأ: ' + (err.message || 'حدث خطأ'), 'error')
    } finally { setActionId(null) }
  }

  async function rejectSub(id) {
    if (!rejectValue) return
    setActionId(id)
    try {
      // INCOMPLETE_AMOUNT always auto-refunds — send the REFUND: prefixed value
      const reasonToSend = rejectValue === 'INCOMPLETE_AMOUNT' ? 'REFUND:INCOMPLETE_AMOUNT' : rejectValue
      const isRefund = reasonToSend.startsWith('REFUND:')
      const { error } = await supabase.rpc('admin_reject_subscription', {
        p_subscription_id: id, p_admin_id: adminId, p_reason: reasonToSend,
      })
      if (error) throw error
      // DB trigger (notify_subscription_status_change) sends the rejection
      // notification automatically — no manual insert needed here.

      closeModal(); await loadData()
      toast(isRefund ? 'تم الرفض واسترداد المبلغ للطالب' : 'تم رفض الاشتراك وإشعار الطالب', 'success')
    } catch (err) {
      toast('خطأ: ' + (err.message || 'حدث خطأ'), 'error')
    } finally { setActionId(null) }
  }

  const fmtDate = dt => dt
    ? new Date(dt).toLocaleDateString('ar-EG-u-nu-latn', { month: 'short', day: 'numeric', year: 'numeric' })
    : '—'

  const daysLeft = dt => {
    if (!dt) return null
    const d = Math.ceil((new Date(dt) - new Date()) / 86400000)
    return d > 0 ? `${d} يوم متبقي` : 'منتهي'
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const COLS = '0.5fr 1fr 1.4fr 0.6fr 0.9fr 2fr 0.9fr'

  return (
    <div>
      {/* ── Stats ─────────────────────────────────────────────────── */}
      <div className="grid-4 mb-18">
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>اشتراكات نشطة</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: '#059669', marginTop: 3 }}>{stats.active}</div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>قيد المراجعة</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: 'var(--purple)', marginTop: 3 }}>{stats.pending}</div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>ملغية / مرفوضة</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: '#A12B1D', marginTop: 3 }}>{stats.rejected}</div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>مُسترد منها</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: '#D97706', marginTop: 3 }}>{stats.refunded}</div>
        </div>
      </div>

      {/* ── Table ─────────────────────────────────────────────────── */}
      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: COLS }}>
          <span>#</span>
          <span>الطالب</span>
          <span>المحتوى</span>
          <span>الخطة</span>
          <span>المبلغ</span>
          <span>الحالة / مسار الإلغاء</span>
          <span style={{ textAlign: 'left' }}>إجراء</span>
        </div>

        {rows.length === 0 && (
          <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا توجد اشتراكات</div>
        )}

        {rows.map(s => {
          const content = s.course?.title || s.package?.title || '—'
          const days    = daysLeft(s.expires_at)
          return (
            <div key={s.id} className="table-row" style={{ gridTemplateColumns: COLS }}>
              <span className="fw-700 dir-ltr" style={{ fontSize: 11, color: 'var(--text3)' }}>{s.id.slice(0, 6)}</span>
              <span className="fw-700" style={{ fontSize: 13 }}>{s.student?.full_name || '—'}</span>
              <span className="text-2" style={{ fontSize: 12 }}>{content}</span>
              <span className="text-2" style={{ fontSize: 12 }}>{s.plan_type === 'yearly' ? 'سنوي' : 'شهري'}</span>
              <span className="fw-700" style={{ fontSize: 12 }}>{s.amount?.toLocaleString('en-US')} أوق</span>
              <span>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                  <SubStatusTrail status={s.status} reason={s.reject_reason} />
                  {s.status === 'active' && days && (
                    <span style={{ fontSize: 11, color: 'var(--text3)' }}>{days} · ينتهي {fmtDate(s.expires_at)}</span>
                  )}
                  {s.status === 'pending' && (
                    <span style={{ fontSize: 11, color: 'var(--text3)' }}>تاريخ الطلب: {fmtDate(s.created_at)}</span>
                  )}
                </div>
              </span>
              <span style={{ textAlign: 'left' }}>
                {s.status === 'pending' ? (
                  <button className="btn btn-sm btn-review" onClick={() => openModal(s)} disabled={actionId === s.id}>
                    🔍 مراجعة
                  </button>
                ) : (
                  <span className="text-muted" style={{ fontSize: 12 }}>—</span>
                )}
              </span>
            </div>
          )
        })}
      </div>

      {/* ── Review modal ──────────────────────────────────────────── */}
      {modal && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.45)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}
          onClick={closeModal}
        >
          <div
            style={{ background: '#fff', borderRadius: 20, padding: 28, width: 460, maxWidth: '95vw', maxHeight: '90vh', overflowY: 'auto' }}
            onClick={e => e.stopPropagation()}
          >
            <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 16 }}>مراجعة الاشتراك</div>

            {/* Proof image */}
            {modal.row.proof_image_url && (
              <div style={{ marginBottom: 16 }}>
                <div style={{ fontSize: 12, color: 'var(--text3)', marginBottom: 8 }}>🧾 إثبات الدفع</div>
                {proofUrl
                  ? <a href={proofUrl} target="_blank" rel="noreferrer">
                      <img src={proofUrl} alt="proof" style={{ width: '100%', borderRadius: 12, border: '1px solid var(--border)', maxHeight: 280, objectFit: 'contain', cursor: 'zoom-in' }} />
                    </a>
                  : <div style={{ textAlign: 'center', padding: 18, color: 'var(--text3)', fontSize: 13, background: '#F2F7F5', borderRadius: 12 }}>جارٍ تحميل الإثبات…</div>
                }
              </div>
            )}

            {/* Details */}
            <div style={{ background: '#F2F7F5', borderRadius: 12, padding: 14, marginBottom: 20, fontSize: 13, display: 'flex', flexDirection: 'column', gap: 7 }}>
              <div><b>الطالب:</b> {modal.row.student?.full_name || '—'}</div>
              <div><b>المحتوى:</b> {modal.row.course?.title || modal.row.package?.title || '—'}</div>
              <div><b>نوع الاشتراك:</b> {modal.row.plan_type === 'yearly' ? 'سنوي (12 شهراً)' : 'شهري'}</div>
              <div><b>المبلغ:</b> {modal.row.amount?.toLocaleString('en-US')} أوقية</div>
              <div><b>تاريخ الطلب:</b> {modal.row.created_at?.slice(0, 10)}</div>
            </div>

            {/* Actions */}
            {!rejectMode ? (
              <div style={{ display: 'flex', gap: 10 }}>
                <button
                  className="btn btn-primary"
                  style={{ flex: 1, justifyContent: 'center' }}
                  disabled={!!actionId}
                  onClick={() => confirmSub(modal.row.id)}
                >
                  {actionId
                    ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
                    : '✓ تأكيد الاشتراك'}
                </button>
                <button
                  className="btn btn-danger"
                  style={{ flex: 1, justifyContent: 'center' }}
                  disabled={!!actionId}
                  onClick={() => setRejectMode(true)}
                >
                  ✕ رفض
                </button>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text2)' }}>سبب الرفض</div>

                {REJECT_OPTIONS.map(opt => (
                  <label
                    key={opt.value}
                    style={{
                      display: 'flex', flexDirection: 'column', gap: 3, padding: '12px 14px',
                      borderRadius: 10, cursor: 'pointer',
                      border: `1.5px solid ${rejectValue === opt.value ? opt.color : 'var(--border)'}`,
                      background: rejectValue === opt.value ? opt.bg : '#FAFAFA',
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <input
                        type="radio"
                        name="rejectReason"
                        value={opt.value}
                        checked={rejectValue === opt.value}
                        onChange={() => setRejectValue(opt.value)}
                        style={{ accentColor: opt.color }}
                      />
                      <span style={{ fontSize: 13, fontWeight: 700, color: opt.color }}>{opt.label}</span>
                      {opt.value === 'INCOMPLETE_AMOUNT' && (
                        <span style={{ marginRight: 'auto', fontSize: 11, background: '#D7F2E6', color: '#0A6E4E', borderRadius: 6, padding: '2px 7px', fontWeight: 600 }}>استرداد فوري</span>
                      )}
                    </div>
                    <span style={{ fontSize: 11, color: 'var(--text3)', paddingRight: 22 }}>{opt.sub}</span>
                  </label>
                ))}

                {/* Trail preview */}
                {rejectValue && (
                  <div style={{ background: '#F2F7F5', borderRadius: 10, padding: '10px 14px' }}>
                    <div style={{ fontSize: 11, color: 'var(--text3)', marginBottom: 6 }}>ما سيظهر في السجل:</div>
                    <SubStatusTrail
                      status="rejected"
                      reason={rejectValue === 'INCOMPLETE_AMOUNT' ? 'REFUND:INCOMPLETE_AMOUNT' : rejectValue}
                    />
                  </div>
                )}

                <div style={{ display: 'flex', gap: 8, marginTop: 4 }}>
                  <button
                    className="btn btn-secondary"
                    style={{ flex: 1 }}
                    onClick={() => { setRejectMode(false); setRejectValue('') }}
                  >
                    رجوع
                  </button>
                  <button
                    className="btn btn-danger"
                    style={{ flex: 1 }}
                    disabled={!!actionId || !rejectValue}
                    onClick={() => rejectSub(modal.row.id)}
                  >
                    {actionId ? '…' : 'تأكيد الرفض'}
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
