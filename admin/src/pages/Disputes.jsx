import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

export default function Disputes() {
  const toast = useToast()
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [modal, setModal] = useState(null)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const { data } = await supabase
      .from('sessions')
      .select('*')
      .in('state', ['DISPUTE', 'TEACHER_NO_SHOW', 'STUDENT_NO_SHOW'])
      .order('updated_at', { ascending: false })

    const sessData = data || []
    const userIds = [...new Set([
      ...sessData.map(s => s.student_id),
      ...sessData.map(s => s.teacher_id),
    ].filter(Boolean))]
    const { data: profiles } = userIds.length
      ? await supabase.from('profiles').select('id, full_name').in('id', userIds)
      : { data: [] }
    const nameMap = Object.fromEntries((profiles || []).map(p => [p.id, p.full_name]))

    const disputes = sessData.map(s => ({
      id: `DSP-${s.id.slice(0, 6).toUpperCase()}`,
      sessionId: s.id,
      parties: `${nameMap[s.student_id] || '—'} ← ${nameMap[s.teacher_id] || '—'}`,
      reason: s.state === 'TEACHER_NO_SHOW' ? 'غياب الأستاذ' : s.state === 'STUDENT_NO_SHOW' ? 'غياب الطالب' : 'نزاع مفتوح',
      amount: s.amount,
      age: timeAgo(s.updated_at),
      status: s.state === 'DISPUTE' ? 'نزاع مفتوح' : s.state === 'TEACHER_NO_SHOW' ? 'غياب أستاذ' : 'غياب طالب',
      statusBg: s.state === 'DISPUTE' ? '#FEE2E2' : '#FEF3C7',
      statusFg: s.state === 'DISPUTE' ? '#991B1B' : '#92400E',
      raw: s,
    }))

    setRows(disputes)
    setLoading(false)
  }

  function timeAgo(dt) {
    if (!dt) return '—'
    const h = Math.round((Date.now() - new Date(dt)) / 3600000)
    if (h < 24) return `${h} ساعة`
    return `${Math.round(h / 24)} يوم`
  }

  async function resolve(sessionId, newState) {
    try {
      const { error } = await supabase.from('sessions').update({ state: newState }).eq('id', sessionId)
      if (error) throw error
      await supabase.from('session_events').insert({ session_id: sessionId, event_type: 'DISPUTE_RESOLVED', actor: 'admin' })
      setModal(null)
      await loadData()
      toast(newState === 'COMPLETED' ? 'تم حل النزاع — الجلسة مكتملة' : 'تم إلغاء الجلسة وإعادة المبلغ', 'success')
    } catch (err) {
      toast('خطأ في حل النزاع: ' + (err.message || 'حدث خطأ غير متوقع'), 'error')
    }
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  if (rows.length === 0) return (
    <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text3)' }}>
      <div style={{ fontSize: 48, marginBottom: 12 }}>🛡️</div>
      <div style={{ fontSize: 16, fontWeight: 700 }}>لا توجد نزاعات مفتوحة</div>
      <div style={{ fontSize: 13, marginTop: 6 }}>جميع النزاعات محلولة</div>
    </div>
  )

  return (
    <div>
      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: '0.9fr 1.8fr 1.2fr 0.9fr 1fr 1fr' }}>
          <span>الرقم</span><span>الأطراف</span><span>السبب</span><span>المجمّد</span><span>العمر</span><span style={{ textAlign: 'left' }}>الحالة</span>
        </div>
        {rows.map(d => (
          <div key={d.id} className="table-row" style={{ gridTemplateColumns: '0.9fr 1.8fr 1.2fr 0.9fr 1fr 1fr' }} onClick={() => setModal(d)}>
            <span className="fw-700 dir-ltr">{d.id}</span>
            <span>{d.parties}</span>
            <span className="text-2">{d.reason}</span>
            <span className="fw-700 text-red">{d.amount?.toLocaleString('ar')} أوقية</span>
            <span className="text-muted">{d.age}</span>
            <span style={{ textAlign: 'left' }}><span className="badge" style={{ background: d.statusBg, color: d.statusFg }}>{d.status}</span></span>
          </div>
        ))}
      </div>

      {modal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.45)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }} onClick={() => setModal(null)}>
          <div style={{ background: '#fff', borderRadius: 20, padding: 28, width: 460, maxWidth: '95vw' }} onClick={e => e.stopPropagation()}>
            <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 16, color: 'var(--text)' }}>حل النزاع · {modal.id}</div>
            <div style={{ background: '#F5F7FF', borderRadius: 12, padding: 16, marginBottom: 20, fontSize: 13, display: 'flex', flexDirection: 'column', gap: 8 }}>
              <div><b>الطرفان:</b> {modal.parties}</div>
              <div><b>السبب:</b> {modal.reason}</div>
              <div><b>المبلغ المجمّد:</b> {modal.amount?.toLocaleString('ar')} أوقية</div>
              <div><b>العمر:</b> {modal.age}</div>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <button className="btn btn-primary" style={{ justifyContent: 'center' }} onClick={() => resolve(modal.sessionId, 'COMPLETED')}>
                ✓ حلّ النزاع — الجلسة مكتملة
              </button>
              <button className="btn" style={{ background: '#FDECEC', color: '#C0392B', justifyContent: 'center' }} onClick={() => resolve(modal.sessionId, 'CANCELLED')}>
                ✕ إلغاء الجلسة وإعادة المبلغ
              </button>
              <button className="btn btn-secondary" style={{ justifyContent: 'center' }} onClick={() => setModal(null)}>إغلاق</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
