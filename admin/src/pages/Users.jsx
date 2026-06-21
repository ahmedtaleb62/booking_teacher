import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'

export default function Users() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const { data: profiles } = await supabase
      .from('profiles')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(100)

    const { data: sessions } = await supabase
      .from('sessions')
      .select('student_id, teacher_id, state, updated_at')

    const activityMap = {}
    ;(sessions || []).forEach(s => {
      for (const id of [s.student_id, s.teacher_id]) {
        if (!id) continue
        if (!activityMap[id] || new Date(s.updated_at) > new Date(activityMap[id].date)) {
          activityMap[id] = { date: s.updated_at }
        }
      }
    })

    const colors = [['#E0E7FF', '#4338CA'], ['#D1FAE5', '#065F46'], ['#EDE9FE', '#5B21B6'], ['#FEF3C7', '#92400E'], ['#DBEAFE', '#1D4ED8']]

    setRows((profiles || []).map((p, i) => {
      const [bg, fg] = colors[i % colors.length]
      const last = activityMap[p.id]
      const lastActive = last ? new Date(last.date).toLocaleDateString('ar-EG') : '—'
      const sessCount = (sessions || []).filter(s => s.student_id === p.id || s.teacher_id === p.id).length
      return { ...p, bg, fg, init: (p.full_name || '?')[0], lastActive, sessCount }
    }))

    setLoading(false)
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const fmtDate = dt => dt ? new Date(dt).toLocaleDateString('ar-EG', { year: 'numeric', month: 'short', day: 'numeric' }) : '—'

  return (
    <div>
      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: '1.6fr 0.8fr 1fr 1.4fr 0.9fr' }}>
          <span>المستخدم</span><span>الدور</span><span>انضم</span><span>النشاط</span><span style={{ textAlign: 'left' }}>الحالة</span>
        </div>
        {rows.length === 0 && <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا يوجد مستخدمون</div>}
        {rows.map(u => (
          <div key={u.id} className="table-row" style={{ gridTemplateColumns: '1.6fr 0.8fr 1fr 1.4fr 0.9fr' }}>
            <span className="flex items-center gap-10">
              <span style={{ width: 34, height: 34, borderRadius: 10, background: u.bg, color: u.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, flexShrink: 0 }}>{u.init}</span>
              <div>
                <div className="fw-700" style={{ fontSize: 13 }}>{u.full_name || '—'}</div>
                <div style={{ fontSize: 11, color: 'var(--text3)' }}>{u.email || '—'}</div>
              </div>
            </span>
            <span className="text-2">{u.role === 'teacher' ? 'أستاذ' : 'طالب'}</span>
            <span className="text-2 dir-ltr">{fmtDate(u.created_at)}</span>
            <span className="text-2">{u.sessCount} جلسة · آخر نشاط {u.lastActive}</span>
            <span style={{ textAlign: 'left' }}>
              <span className="badge" style={{ background: u.is_active === false ? '#FEE2E2' : '#D1FAE5', color: u.is_active === false ? '#991B1B' : '#065F46' }}>
                {u.is_active === false ? 'موقوف' : 'نشط'}
              </span>
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}
