import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

export default function Disputes() {
  const toast = useToast()
  const [tab, setTab]           = useState('disputes')
  const [rows, setRows]         = useState([])
  const [refundRows, setRefundRows] = useState([])
  const [loading, setLoading]   = useState(true)
  const [modal, setModal]       = useState(null)
  const [resolving, setResolving] = useState(null)
  const [commission, setCommission] = useState(0.15)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    try {
    const { data: settingsData } = await supabase.rpc('get_system_settings')
    if (settingsData) {
      const s = Object.fromEntries(settingsData.map(r => [r.key, parseFloat(r.value)]))
      if (!isNaN(s.session_commission_pct)) setCommission(s.session_commission_pct / 100)
    }

    const [sessRes, refundRes] = await Promise.all([
      // Active disputes / no-shows
      supabase
        .from('sessions')
        .select('*')
        .in('state', ['DISPUTE', 'TEACHER_NO_SHOW', 'STUDENT_NO_SHOW'])
        .order('updated_at', { ascending: false }),

      // Refund requests pending admin action
      supabase
        .from('sessions')
        .select('*')
        .eq('refund_status', 'student_requested')
        .order('updated_at', { ascending: false }),
    ])

    const sessData   = sessRes.data   || []
    const refundData = refundRes.data || []

    const allIds = [...new Set([
      ...sessData.map(s => s.student_id),
      ...sessData.map(s => s.teacher_id),
      ...refundData.map(s => s.student_id),
      ...refundData.map(s => s.teacher_id),
    ].filter(Boolean))]

    const { data: profiles } = allIds.length
      ? await supabase.from('profiles').select('id, full_name').in('id', allIds)
      : { data: [] }
    const nameMap = Object.fromEntries((profiles || []).map(p => [p.id, p.full_name]))

    setRows(sessData.map(s => ({
      id: `DSP-${s.id.slice(0, 6).toUpperCase()}`,
      sessionId: s.id,
      parties:  `${nameMap[s.student_id] || '—'} ← ${nameMap[s.teacher_id] || '—'}`,
      reason:   s.state === 'TEACHER_NO_SHOW' ? 'غياب الأستاذ'
              : s.state === 'STUDENT_NO_SHOW' ? 'غياب الطالب'
              : 'نزاع مفتوح',
      amount:   s.amount,
      age:      timeAgo(s.updated_at),
      status:   s.state === 'DISPUTE'       ? 'نزاع مفتوح'
              : s.state === 'TEACHER_NO_SHOW' ? 'غياب أستاذ'
              : 'غياب طالب',
      statusBg: s.state === 'DISPUTE' ? '#FEE2E2' : '#FEF3C7',
      statusFg: s.state === 'DISPUTE' ? '#991B1B' : '#92400E',
      raw: s,
    })))

    setRefundRows(refundData.map(s => ({
      sessionId: s.id,
      student:   nameMap[s.student_id] || '—',
      teacher:   nameMap[s.teacher_id] || '—',
      subject:   s.subject || '—',
      amount:    s.amount,
      age:       timeAgo(s.updated_at),
      raw:       s,
    })))

    setLoading(false)
    } catch (e) {
      console.error('Disputes loadData error:', e)
      setLoading(false)
    }
  }

  function timeAgo(dt) {
    if (!dt) return '—'
    const h = Math.round((Date.now() - new Date(dt)) / 3600000)
    if (h < 24) return `${h} ساعة`
    return `${Math.round(h / 24)} يوم`
  }

  // ── Resolve dispute (COMPLETED or CANCELLED) ──────────────────────────────
  async function resolve(sessionId, newState) {
    if (resolving) return
    setResolving(sessionId)
    try {
      const { error } = await supabase
        .from('sessions').update({ state: newState }).eq('id', sessionId)
      if (error) throw error

      const { error: evErr } = await supabase.from('session_events').insert({
        session_id: sessionId,
        event_type: 'DISPUTE_RESOLVED',
        actor: 'admin',
        metadata: { resolution: newState },
      })
      if (evErr) throw evErr

      if (newState === 'CANCELLED') {
        const sess = modal.raw
        await supabase.from('ledger_entries').insert({
          session_id: sessionId,
          student_id: sess.student_id,
          teacher_id: sess.teacher_id,
          type:        'refund',
          amount:      sess.amount || 0,
          commission:  0,
          net_amount:  sess.amount || 0,
          description: 'استرداد — نزاع محلول لصالح الطالب',
        })
        await supabase.from('payments')
          .update({ status: 'refunded' }).eq('session_id', sessionId)
        await supabase.from('notifications').insert({
          user_id:    sess.student_id,
          title:      'تم استرداد مبلغك ✅',
          body:       'تم حل النزاع لصالحك وسيتم تحويل المبلغ قريباً.',
          type:       'dispute_resolved',
          session_id: sessionId,
        })
      }

      if (newState === 'COMPLETED') {
        const sess = modal.raw
        const commAmt = Math.round((sess.amount || 0) * commission)
        const netAmt  = (sess.amount || 0) - commAmt
        await supabase.from('ledger_entries').insert({
          session_id: sessionId,
          student_id: sess.student_id,
          teacher_id: sess.teacher_id,
          type:        'session_payment',
          amount:      sess.amount || 0,
          commission:  commAmt,
          net_amount:  netAmt,
          description: 'جلسة مكتملة — نزاع محلول لصالح الأستاذ',
        })
        await supabase.from('notifications').insert({
          user_id:    sess.teacher_id,
          title:      'تم إيداع مستحقاتك ✅',
          body:       'تم حل النزاع لصالحك وسيُحوَّل مستحقك قريباً.',
          type:       'dispute_resolved',
          session_id: sessionId,
        })
      }

      setModal(null)
      await loadData()
      toast(
        newState === 'COMPLETED'
          ? 'تم حل النزاع — الجلسة مكتملة'
          : 'تم إلغاء الجلسة وتسجيل الاسترداد',
        'success',
      )
    } catch (err) {
      toast('خطأ في حل النزاع: ' + (err.message || 'حدث خطأ غير متوقع'), 'error')
    } finally {
      setResolving(null)
    }
  }

  // ── Process refund request from student ───────────────────────────────────
  async function processRefund(sess) {
    if (resolving) return
    setResolving(sess.id)
    try {
      const { error } = await supabase.from('sessions').update({
        state:               'CANCELLED',
        refund_status:       'admin_processed',
        cancellation_reason: 'teacher_no_show_refund',
        updated_at:          new Date().toISOString(),
      }).eq('id', sess.id)
      if (error) throw error

      await supabase.from('session_events').insert({
        session_id: sess.id,
        event_type: 'REFUND_PROCESSED',
        actor:      'admin',
      })

      await supabase.from('ledger_entries').insert({
        session_id: sess.id,
        student_id: sess.student_id,
        teacher_id: sess.teacher_id,
        type:        'refund',
        amount:      sess.amount || 0,
        commission:  0,
        net_amount:  sess.amount || 0,
        description: 'استرداد — غياب الأستاذ (طلب طالب)',
      })

      await supabase.from('payments')
        .update({ status: 'refunded' }).eq('session_id', sess.id)

      await supabase.from('notifications').insert({
        user_id:    sess.student_id,
        title:      'تم استرداد مبلغك ✅',
        body:       'تمت معالجة طلب الاسترداد. سيُحوَّل المبلغ إليك قريباً.',
        type:       'refund_processed',
        session_id: sess.id,
      })

      await loadData()
      toast('تم تأكيد الاسترداد وإشعار الطالب', 'success')
    } catch (err) {
      toast('خطأ في معالجة الاسترداد: ' + (err.message || ''), 'error')
    } finally {
      setResolving(null)
    }
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const pendingRefunds = refundRows.length

  return (
    <div>
      {/* ── Tabs ──────────────────────────────────────────────── */}
      <div className="tabs mb-18">
        <div className={`tab${tab === 'disputes' ? ' active' : ''}`} onClick={() => setTab('disputes')}>
          النزاعات والغيابات
          {rows.length > 0 && (
            <span className="badge" style={{ background: '#FEE2E2', color: '#991B1B', marginRight: 6, fontSize: 10 }}>
              {rows.length}
            </span>
          )}
        </div>
        <div className={`tab${tab === 'refunds' ? ' active' : ''}`} onClick={() => setTab('refunds')}>
          طلبات الاسترداد
          {pendingRefunds > 0 && (
            <span className="badge" style={{ background: '#EDE9FE', color: '#5B21B6', marginRight: 6, fontSize: 10 }}>
              {pendingRefunds}
            </span>
          )}
        </div>
      </div>

      {/* ── Disputes tab ─────────────────────────────────────── */}
      {tab === 'disputes' && (
        rows.length === 0
          ? <EmptyState icon="🛡️" title="لا توجد نزاعات مفتوحة" sub="جميع النزاعات محلولة" />
          : (
            <div className="table-wrap">
              <div className="table-head" style={{ gridTemplateColumns: '0.9fr 1.8fr 1.2fr 0.9fr 1fr 1fr' }}>
                <span>الرقم</span><span>الأطراف</span><span>السبب</span>
                <span>المجمّد</span><span>العمر</span><span style={{ textAlign: 'left' }}>الحالة</span>
              </div>
              {rows.map(d => (
                <div key={d.id} className="table-row"
                  style={{ gridTemplateColumns: '0.9fr 1.8fr 1.2fr 0.9fr 1fr 1fr', cursor: 'pointer' }}
                  onClick={() => setModal(d)}>
                  <span className="fw-700 dir-ltr">{d.id}</span>
                  <span>{d.parties}</span>
                  <span className="text-2">{d.reason}</span>
                  <span className="fw-700 text-red">{d.amount?.toLocaleString('ar')} أوقية</span>
                  <span className="text-muted">{d.age}</span>
                  <span style={{ textAlign: 'left' }}>
                    <span className="badge" style={{ background: d.statusBg, color: d.statusFg }}>{d.status}</span>
                  </span>
                </div>
              ))}
            </div>
          )
      )}

      {/* ── Refund requests tab ───────────────────────────────── */}
      {tab === 'refunds' && (
        refundRows.length === 0
          ? <EmptyState icon="💰" title="لا توجد طلبات استرداد معلقة" sub="جميع الطلبات معالجة" />
          : (
            <div className="table-wrap">
              <div className="table-head" style={{ gridTemplateColumns: '1.5fr 1.5fr 1fr 0.9fr 1fr 1.2fr' }}>
                <span>الطالب</span><span>الأستاذ</span><span>المادة</span>
                <span>المبلغ</span><span>منذ</span><span style={{ textAlign: 'left' }}>إجراء</span>
              </div>
              {refundRows.map(r => (
                <div key={r.sessionId} className="table-row"
                  style={{ gridTemplateColumns: '1.5fr 1.5fr 1fr 0.9fr 1fr 1.2fr' }}>
                  <span className="fw-700">{r.student}</span>
                  <span>{r.teacher}</span>
                  <span className="text-2">{r.subject}</span>
                  <span className="fw-700 text-red">{r.amount?.toLocaleString('ar')} أوقية</span>
                  <span className="text-muted">{r.age}</span>
                  <span style={{ textAlign: 'left' }}>
                    <button
                      className="btn btn-sm btn-primary"
                      disabled={resolving === r.sessionId}
                      onClick={() => processRefund(r.raw)}
                    >
                      {resolving === r.sessionId
                        ? <span className="spinner" style={{ width: 14, height: 14, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
                        : '✓ تأكيد الاسترداد'}
                    </button>
                  </span>
                </div>
              ))}
            </div>
          )
      )}

      {/* ── Dispute resolution modal ──────────────────────────── */}
      {modal && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.45)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}
          onClick={() => !resolving && setModal(null)}
        >
          <div style={{ background: '#fff', borderRadius: 20, padding: 28, width: 460, maxWidth: '95vw' }} onClick={e => e.stopPropagation()}>
            <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 16, color: 'var(--text)' }}>
              حل النزاع · {modal.id}
            </div>
            <div style={{ background: '#F5F7FF', borderRadius: 12, padding: 16, marginBottom: 20, fontSize: 13, display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div><b>الطرفان:</b> {modal.parties}</div>
              <div><b>السبب:</b> {modal.reason}</div>
              <div><b>المبلغ المجمّد:</b> {modal.amount?.toLocaleString('ar')} أوقية</div>
              <div><b>العمر:</b> {modal.age}</div>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {modal.raw.state !== 'TEACHER_NO_SHOW' && (
                <button
                  className="btn btn-primary"
                  style={{ justifyContent: 'center' }}
                  disabled={!!resolving}
                  onClick={() => resolve(modal.sessionId, 'COMPLETED')}
                >
                  {resolving === modal.sessionId
                    ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
                    : '✓ حلّ النزاع — الجلسة مكتملة (يُدفع الأستاذ)'}
                </button>
              )}
              <button
                className="btn"
                style={{ background: '#FDECEC', color: '#C0392B', justifyContent: 'center' }}
                disabled={!!resolving}
                onClick={() => resolve(modal.sessionId, 'CANCELLED')}
              >
                {resolving === modal.sessionId
                  ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2, borderColor: 'rgba(192,57,43,.3)', borderTopColor: '#C0392B' }} />
                  : '✕ إلغاء الجلسة وإعادة المبلغ'}
              </button>
              <button
                className="btn btn-secondary"
                style={{ justifyContent: 'center' }}
                disabled={!!resolving}
                onClick={() => setModal(null)}
              >
                إغلاق
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function EmptyState({ icon, title, sub }) {
  return (
    <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text3)' }}>
      <div style={{ fontSize: 48, marginBottom: 12 }}>{icon}</div>
      <div style={{ fontSize: 16, fontWeight: 700, color: 'var(--text2)' }}>{title}</div>
      <div style={{ fontSize: 13, marginTop: 6 }}>{sub}</div>
    </div>
  )
}
