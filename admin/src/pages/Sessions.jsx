import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'

function StateBadge({ state }) {
  const map = {
    REQUESTED:         ['بانتظار', '#FEF3C7', '#92400E'],
    TEACHER_APPROVED:  ['معتمد', '#DBEAFE', '#1D4ED8'],
    AWAITING_PAYMENT:  ['انتظار الدفع', '#FEF3C7', '#92400E'],
    PAYMENT_SUBMITTED: ['دفع مُرسَل', '#EDE9FE', '#5B21B6'],
    CONFIRMED_BOOKING: ['محجوز', '#D1FAE5', '#065F46'],
    ACTIVE_SESSION:    ['نشط 🔴', '#DCFCE7', '#15803D'],
    COMPLETED:         ['مكتمل', '#F1F5F9', '#475569'],
    CANCELLED:         ['ملغى', '#FEE2E2', '#991B1B'],
    TEACHER_REJECTED:  ['مرفوض', '#FEE2E2', '#991B1B'],
    TEACHER_NO_SHOW:   ['أستاذ غائب', '#FEE2E2', '#991B1B'],
    STUDENT_NO_SHOW:   ['طالب غائب',  '#FEF3C7', '#92400E'],
    DISPUTE:           ['نزاع',       '#FEE2E2', '#991B1B'],
  }
  const [label, bg, fg] = map[state] || [state, '#F1F3F5', '#516170']
  return <span className="badge" style={{ background: bg, color: fg }}>{label}</span>
}

export default function Sessions() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [stats, setStats] = useState({})

  useEffect(() => {
    loadData()
    const channel = supabase.channel('admin-sessions')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'sessions' }, () => loadData(true))
      .subscribe()
    return () => supabase.removeChannel(channel)
  }, [])

  async function loadData(silent = false) {
    if (!silent) setLoading(true)
    const { data } = await supabase
      .from('sessions')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(100)

    const sessData = data || []
    const userIds = [...new Set([
      ...sessData.map(s => s.student_id),
      ...sessData.map(s => s.teacher_id),
    ].filter(Boolean))]
    const { data: profiles } = userIds.length
      ? await supabase.from('profiles').select('id, full_name').in('id', userIds)
      : { data: [] }
    const nameMap = Object.fromEntries((profiles || []).map(p => [p.id, p.full_name]))

    const sessions = sessData.map(s => ({
      ...s,
      teacherName: nameMap[s.teacher_id] || '—',
      studentName: nameMap[s.student_id] || '—',
    }))

    const today = new Date().toISOString().slice(0, 10)
    setStats({
      active: sessions.filter(s => s.state === 'ACTIVE_SESSION').length,
      scheduled: sessions.filter(s => s.scheduled_at?.startsWith(today) && ['CONFIRMED_BOOKING'].includes(s.state)).length,
      completed: sessions.filter(s => s.state === 'COMPLETED' && s.updated_at?.startsWith(today)).length,
      disputes: sessions.filter(s => ['DISPUTE', 'TEACHER_NO_SHOW', 'STUDENT_NO_SHOW'].includes(s.state)).length,
    })
    setRows(sessions)
    setLoading(false)
  }

  const fmtDate = dt => dt ? new Date(dt).toLocaleString('ar-EG', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—'

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div>
      <div className="grid-4 mb-18">
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>نشطة الآن</div>
          <div className="flex items-center gap-8 mt-3">
            <span className="live-dot" />
            <span style={{ fontSize: 21, fontWeight: 700, color: '#16A34A' }}>{stats.active}</span>
          </div>
        </div>
        <div className="card-sm"><div className="text-muted" style={{ fontSize: 12 }}>مجدولة اليوم</div><div style={{ fontSize: 21, fontWeight: 700, color: '#4F46E5', marginTop: 3 }}>{stats.scheduled}</div></div>
        <div className="card-sm"><div className="text-muted" style={{ fontSize: 12 }}>مكتملة اليوم</div><div style={{ fontSize: 21, fontWeight: 700, marginTop: 3 }}>{stats.completed}</div></div>
        <div className="card-sm"><div className="text-muted" style={{ fontSize: 12 }}>في نزاع</div><div style={{ fontSize: 21, fontWeight: 700, color: '#DC2626', marginTop: 3 }}>{stats.disputes}</div></div>
      </div>

      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: '0.9fr 0.9fr 1.6fr 1fr 0.9fr 0.9fr 1fr' }}>
          <span>المرجع</span><span>المادة</span><span>الطرفان</span><span>المجدول</span><span>المدة</span><span>المبلغ</span><span style={{ textAlign: 'left' }}>الحالة</span>
        </div>
        {rows.length === 0 && <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا توجد جلسات</div>}
        {rows.map(s => (
          <div key={s.id} className="table-row" style={{ gridTemplateColumns: '0.9fr 0.9fr 1.6fr 1fr 0.9fr 0.9fr 1fr' }}>
            <span className="fw-700 dir-ltr">{s.id.slice(0, 8)}</span>
            <span className="text-2">{s.subject}</span>
            <span>{s.studentName} ← {s.teacherName}</span>
            <span className="text-2 dir-ltr">{fmtDate(s.scheduled_at)}</span>
            <span className="text-2">{s.duration_minutes} د</span>
            <span className="fw-700">{s.amount?.toLocaleString('ar')}</span>
            <span style={{ textAlign: 'left' }}><StateBadge state={s.state} /></span>
          </div>
        ))}
      </div>
    </div>
  )
}
