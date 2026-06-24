import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

export default function Subscriptions({ adminId }) {
  const toast = useToast()
  const [rows, setRows]           = useState([])
  const [stats, setStats]         = useState({})
  const [loading, setLoading]     = useState(true)
  const [modal, setModal]         = useState(null)
  const [actionId, setActionId]   = useState(null)
  const [showRejectInput, setShowRejectInput] = useState(false)
  const [rejectReason, setRejectReason]       = useState('')
  const [proofUrl, setProofUrl]               = useState(null)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const { data } = await supabase
      .from('subscriptions')
      .select('*, course:course_id(title), package:package_id(title), student:student_id(full_name)')
      .order('created_at', { ascending: false })

    const subs = data || []
    const now = new Date()
    const weekEnd = new Date(now); weekEnd.setDate(weekEnd.getDate() + 7)

    setStats({
      active:   subs.filter(s => s.status === 'active').length,
      pending:  subs.filter(s => s.status === 'pending').length,
      expiring: subs.filter(s => s.status === 'active' && s.expires_at && new Date(s.expires_at) <= weekEnd).length,
      income:   subs.filter(s => s.status === 'active').reduce((t, s) => t + (s.amount || 0), 0),
    })
    setRows(subs)
    setLoading(false)
  }

  async function openModal(row) {
    setModal({ row })
    setProofUrl(null)
    setShowRejectInput(false)
    setRejectReason('')
    if (row.proof_image_url) {
      if (row.proof_image_url.startsWith('http')) {
        setProofUrl(row.proof_image_url)
      } else {
        const { data } = await supabase.storage.from('subscription-proofs').createSignedUrl(row.proof_image_url, 3600)
        setProofUrl(data?.signedUrl || null)
      }
    }
  }

  function closeModal() {
    setModal(null)
    setProofUrl(null)
    setShowRejectInput(false)
    setRejectReason('')
  }

  async function confirmSub(id) {
    setActionId(id)
    try {
      const months = modal?.row?.plan_type === 'yearly' ? 12 : 1
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
    setActionId(id)
    try {
      // admin_reject_subscription(p_subscription_id, p_admin_id, p_reason)
      const { error } = await supabase.rpc('admin_reject_subscription', {
        p_subscription_id: id,
        p_admin_id:        adminId,
        p_reason:          reason?.trim() || '',
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

  const fmtDate = dt => dt ? new Date(dt).toLocaleDateString('ar-EG', { month: 'short', day: 'numeric' }) : '—'
  const daysLeft = dt => {
    if (!dt) return '—'
    const d = Math.ceil((new Date(dt) - new Date()) / 86400000)
    return d > 0 ? `${d} يوم` : 'منتهي'
  }

  const statusMap = {
    pending:  ['قيد المراجعة', '#EDE9FE', '#5B21B6'],
    active:   ['نشط',          '#D1FAE5', '#065F46'],
    expired:  ['منتهي',        '#F1F5F9', '#475569'],
    rejected: ['مرفوض',        '#FEE2E2', '#991B1B'],
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div>
      {/* Stats */}
      <div className="grid-4 mb-18">
        <div className="card-sm"><div className="text-muted" style={{ fontSize: 12 }}>اشتراكات نشطة</div><div style={{ fontSize: 21, fontWeight: 700, color: '#059669', marginTop: 3 }}>{stats.active}</div></div>
        <div className="card-sm"><div className="text-muted" style={{ fontSize: 12 }}>قيد المراجعة</div><div style={{ fontSize: 21, fontWeight: 700, color: '#7C3AED', marginTop: 3 }}>{stats.pending}</div></div>
        <div className="card-sm"><div className="text-muted" style={{ fontSize: 12 }}>تنتهي هذا الأسبوع</div><div style={{ fontSize: 21, fontWeight: 700, color: '#D97706', marginTop: 3 }}>{stats.expiring}</div></div>
        <div className="card-sm"><div className="text-muted" style={{ fontSize: 12 }}>دخل الاشتراكات</div><div style={{ fontSize: 21, fontWeight: 700, marginTop: 3 }}>{(stats.income || 0).toLocaleString('ar')}</div></div>
      </div>

      {/* Table */}
      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: '0.8fr 1fr 1.3fr 0.6fr 0.9fr 0.9fr 0.8fr 0.8fr 1fr' }}>
          <span>المرجع</span><span>الطالب</span><span>المحتوى</span><span>الخطة</span>
          <span>يبدأ</span><span>ينتهي</span><span>المتبقي</span><span>الحالة</span>
          <span style={{ textAlign: 'left' }}>إجراء</span>
        </div>
        {rows.length === 0 && <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا توجد اشتراكات</div>}
        {rows.map(s => {
          const [label, bg, fg] = statusMap[s.status] || ['—', '#F1F3F5', '#516170']
          const content = s.course?.title || s.package?.title || '—'
          return (
            <div key={s.id} className="table-row" style={{ gridTemplateColumns: '0.8fr 1fr 1.3fr 0.6fr 0.9fr 0.9fr 0.8fr 0.8fr 1fr' }}>
              <span className="fw-700 dir-ltr">{s.id.slice(0, 8)}</span>
              <span>{s.student?.full_name || '—'}</span>
              <span className="text-2">{content}</span>
              <span className="text-2">{s.plan_type === 'yearly' ? 'سنوي' : 'شهري'}</span>
              <span className="text-2 dir-ltr">{fmtDate(s.started_at)}</span>
              <span className="text-2 dir-ltr">{fmtDate(s.expires_at)}</span>
              <span className="fw-700 text-teal">{daysLeft(s.expires_at)}</span>
              <span><span className="badge" style={{ background: bg, color: fg }}>{label}</span></span>
              <span style={{ textAlign: 'left' }}>
                {s.status === 'pending' ? (
                  <button className="btn btn-sm btn-review" onClick={() => openModal(s)} disabled={actionId === s.id}>
                    🔍 مراجعة
                  </button>
                ) : <span className="text-muted" style={{ fontSize: 12 }}>—</span>}
              </span>
            </div>
          )
        })}
      </div>

      {/* Review modal */}
      {modal && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.45)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}
          onClick={closeModal}
        >
          <div style={{ background: '#fff', borderRadius: 20, padding: 28, width: 440, maxWidth: '95vw' }} onClick={e => e.stopPropagation()}>
            <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 16, color: 'var(--text)' }}>مراجعة الاشتراك</div>

            {/* Proof image */}
            {modal.row.proof_image_url && (
              <div style={{ marginBottom: 16 }}>
                <div style={{ fontSize: 12, color: 'var(--text3)', marginBottom: 8 }}>إثبات الدفع</div>
                {proofUrl
                  ? <img src={proofUrl} alt="proof" style={{ width: '100%', borderRadius: 12, border: '1px solid var(--border)', maxHeight: 280, objectFit: 'contain' }} />
                  : <div style={{ textAlign: 'center', padding: '18px 0', color: 'var(--text3)', fontSize: 13, background: '#F5F7FF', borderRadius: 12 }}>جارٍ تحميل إثبات الدفع…</div>
                }
              </div>
            )}

            {/* Details */}
            <div style={{ background: '#F5F7FF', borderRadius: 12, padding: 14, marginBottom: 20, fontSize: 13, display: 'flex', flexDirection: 'column', gap: 7 }}>
              <div><b>الطالب:</b> {modal.row.student?.full_name || '—'}</div>
              <div><b>المحتوى:</b> {modal.row.course?.title || modal.row.package?.title || '—'}</div>
              <div><b>نوع الاشتراك:</b> {modal.row.plan_type === 'yearly' ? 'سنوي (سنة كاملة)' : 'شهري (شهر واحد)'}</div>
              <div><b>المبلغ:</b> {modal.row.amount?.toLocaleString('ar')} أوقية</div>
              <div><b>التاريخ:</b> {modal.row.created_at?.slice(0, 10)}</div>
            </div>

            {/* Actions */}
            <div style={{ display: 'flex', gap: 10, flexDirection: 'column' }}>
              {!showRejectInput ? (
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
                    onClick={() => setShowRejectInput(true)}
                  >
                    ✕ رفض
                  </button>
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                  <div style={{ fontSize: 13, color: 'var(--text2)', marginBottom: 2 }}>سبب الرفض (سيُرسَل للطالب)</div>
                  <textarea
                    value={rejectReason}
                    onChange={e => setRejectReason(e.target.value)}
                    placeholder="مثال: الإثبات غير واضح أو لا يطابق المبلغ…"
                    rows={2}
                    autoFocus
                    style={{ width: '100%', borderRadius: 8, border: '1px solid #E1E9EF', padding: '8px 10px', fontSize: 13, resize: 'none', fontFamily: 'inherit', outline: 'none', boxSizing: 'border-box' }}
                  />
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button
                      className="btn btn-secondary"
                      style={{ flex: 1 }}
                      onClick={() => { setShowRejectInput(false); setRejectReason('') }}
                    >
                      إلغاء
                    </button>
                    <button
                      className="btn btn-danger"
                      style={{ flex: 1 }}
                      disabled={!!actionId || !rejectReason.trim()}
                      onClick={() => rejectSub(modal.row.id, rejectReason)}
                    >
                      {actionId ? '…' : 'تأكيد الرفض'}
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
