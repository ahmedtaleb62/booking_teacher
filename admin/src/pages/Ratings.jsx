import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'

export default function Ratings() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadData()
  }, [])

  async function loadData() {
    setLoading(true)
    const { data } = await supabase
      .from('reviews')
      .select('*, teacher:teacher_id(profiles(full_name)), student:student_id(full_name)')
      .order('created_at', { ascending: false })

    const byTeacher = {}
    ;(data || []).forEach(r => {
      const id = r.teacher_id
      const name = r.teacher?.profiles?.full_name || '—'
      if (!byTeacher[id]) byTeacher[id] = { id, name, ratings: [], comments: [] }
      byTeacher[id].ratings.push(r.rating || 0)
      if (r.comment) byTeacher[id].comments.push({ text: r.comment, student: r.student?.full_name || 'طالب' })
    })

    const colors = [['#D7F2E6', '#0A6E4E'], ['#ECE5F7', '#5A3B95'], ['#E3F4EF', '#0E7C66'], ['#FBEFD6', '#92620F']]
    const teacherRows = Object.values(byTeacher).map((t, i) => {
      const [bg, fg] = colors[i % colors.length]
      const avg = t.ratings.length ? (t.ratings.reduce((s, r) => s + r, 0) / t.ratings.length).toFixed(1) : '0.0'
      const bars = [5, 4, 3, 2, 1].map(star => {
        const count = t.ratings.filter(r => r === star).length
        const pct = t.ratings.length ? Math.round((count / t.ratings.length) * 100) : 0
        return { star, pct }
      })
      return { ...t, bg, fg, init: t.name[0] || '?', avg, bars, recent: t.comments[0]?.text || 'لا توجد تعليقات بعد' }
    })

    setRows(teacherRows)
    setLoading(false)
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  if (rows.length === 0) return (
    <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text3)' }}>
      <div style={{ fontSize: 48, marginBottom: 12 }}>⭐</div>
      <div style={{ fontSize: 16, fontWeight: 700 }}>لا توجد تقييمات بعد</div>
    </div>
  )

  return (
    <div className="grid-2">
      {rows.map(r => (
        <div key={r.id} className="card">
          <div className="flex gap-8 items-center mb-14" style={{ gap: 13 }}>
            <span style={{ width: 48, height: 48, borderRadius: 13, background: r.bg, color: r.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 19, flexShrink: 0 }}>{r.init}</span>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 15, fontWeight: 700 }}>{r.name}</div>
              <div style={{ fontSize: 12, color: 'var(--text3)' }}>{r.ratings.length} تقييم</div>
            </div>
            <div style={{ textAlign: 'center' }}>
              <div className="flex items-center gap-8" style={{ fontSize: 22, fontWeight: 700 }}>⭐ {r.avg}</div>
            </div>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 5, marginBottom: 14 }}>
            {r.bars.map(b => (
              <div key={b.star} className="flex items-center gap-8">
                <span style={{ fontSize: 10, color: 'var(--text3)', width: 10 }}>{b.star}</span>
                <div style={{ flex: 1, height: 6, borderRadius: 3, background: '#EDF0F2', overflow: 'hidden' }}>
                  <span style={{ display: 'block', height: '100%', width: `${b.pct}%`, background: '#F2A93B' }} />
                </div>
              </div>
            ))}
          </div>

          <div style={{ background: '#F7F9FA', borderRadius: 11, padding: 12, fontSize: 12, color: 'var(--text2)', lineHeight: 1.6 }}>
            "{r.recent}"
          </div>
        </div>
      ))}
    </div>
  )
}
