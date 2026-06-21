import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'

export default function Teachers() {
  const [apps, setApps] = useState([])
  const [loading, setLoading] = useState(true)
  const [actionId, setActionId] = useState(null)
  const [modal, setModal] = useState(null)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const { data: tps } = await supabase
      .from('teacher_profiles')
      .select('*')
      .eq('is_approved', false)
      .order('created_at', { ascending: false })

    const ids = (tps || []).map(t => t.id)
    const { data: profs } = ids.length
      ? await supabase.from('profiles').select('id, full_name, email, created_at').in('id', ids)
      : { data: [] }
    const profMap = Object.fromEntries((profs || []).map(p => [p.id, p]))

    const colors = [
      ['#E0E7FF', '#4338CA'], ['#D1FAE5', '#065F46'],
      ['#EDE9FE', '#5B21B6'], ['#FEF3C7', '#92400E'],
      ['#DBEAFE', '#1D4ED8'], ['#FEE2E2', '#991B1B'],
    ]

    setApps((tps || []).map((t, i) => {
      const [bg, fg] = colors[i % colors.length]
      const p = profMap[t.id] || {}
      const name = p.full_name || '—'
      return { ...t, profiles: p, name, init: name[0] || '?', bg, fg }
    }))
    setLoading(false)
  }

  async function approve(id) {
    setActionId(id)
    await supabase.from('teacher_profiles').update({ is_approved: true }).eq('id', id)
    setModal(null)
    setActionId(null)
    await loadData()
  }

  async function reject(id) {
    setActionId(id)
    await supabase.from('teacher_profiles').delete().eq('id', id)
    await supabase.from('profiles').update({ is_active: false }).eq('id', id)
    setModal(null)
    setActionId(null)
    await loadData()
  }

  const timeAgo = dt => {
    if (!dt) return '—'
    const mins = Math.round((Date.now() - new Date(dt)) / 60000)
    if (mins < 60) return `منذ ${mins} دقيقة`
    if (mins < 1440) return `منذ ${Math.round(mins / 60)} ساعة`
    return `منذ ${Math.round(mins / 1440)} يوم`
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div>
      <div className="info-banner blue">
        ℹ️ &nbsp;للاعتماد يكفي أن يرسل الأستاذ: المادة · سنوات الخبرة · صورة ورقم بطاقة التعريف. اضغط أي طلب للمراجعة.
      </div>

      {apps.length === 0 && (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text3)' }}>
          <div style={{ fontSize: 48, marginBottom: 12 }}>✅</div>
          <div style={{ fontSize: 16, fontWeight: 700 }}>لا توجد طلبات معلّقة</div>
          <div style={{ fontSize: 13, marginTop: 6 }}>جميع الأساتذة تمت معالجة طلباتهم</div>
        </div>
      )}

      <div className="grid-3">
        {apps.map(t => (
          <div key={t.id} className="card" style={{ cursor: 'pointer' }} onClick={() => setModal(t)}>
            <div className="flex justify-between items-center" style={{ alignItems: 'flex-start' }}>
              <span style={{ width: 52, height: 52, borderRadius: 14, background: t.bg, color: t.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 21 }}>{t.init}</span>
              <span className="badge" style={{ background: '#FEF3C7', color: '#92400E' }}>بانتظار</span>
            </div>
            <div style={{ fontSize: 16, fontWeight: 700, marginTop: 13 }}>{t.name}</div>
            <div style={{ fontSize: 12.5, color: 'var(--text2)', marginTop: 2 }}>
              {(t.subjects || []).join('، ')} · {t.years_of_experience || '?'} سنوات خبرة
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginTop: 12, paddingTop: 12, borderTop: '1px solid var(--border-table)', fontSize: 12, color: 'var(--text3)' }}>
              🪪 {t.profiles?.email || '—'}
            </div>
            <div style={{ fontSize: 11, color: 'var(--text4)', marginTop: 8 }}>تقدّم {timeAgo(t.created_at || t.profiles?.created_at)}</div>
          </div>
        ))}
      </div>

      {modal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.45)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }} onClick={() => setModal(null)}>
          <div style={{ background: '#fff', borderRadius: 20, padding: 28, width: 460, maxWidth: '95vw' }} onClick={e => e.stopPropagation()}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 20 }}>
              <span style={{ width: 52, height: 52, borderRadius: 14, background: modal.bg, color: modal.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 22 }}>{modal.init}</span>
              <div>
                <div style={{ fontSize: 18, fontWeight: 800 }}>{modal.name}</div>
                <div style={{ fontSize: 12.5, color: 'var(--text2)', marginTop: 2 }}>{modal.profiles?.email}</div>
              </div>
            </div>
            <div style={{ background: '#F5F7FF', borderRadius: 12, padding: 16, marginBottom: 20, display: 'flex', flexDirection: 'column', gap: 10, fontSize: 13 }}>
              <div><b>المواد:</b> {(modal.subjects || []).join('، ') || '—'}</div>
              <div><b>سنوات الخبرة:</b> {modal.years_of_experience || '—'}</div>
              <div><b>سعر الساعة:</b> {modal.price_per_hour?.toLocaleString('ar') || '—'} أوقية</div>
              <div><b>نبذة:</b> {modal.bio || '—'}</div>
              {modal.id_card_url && (
                <div>
                  <b>بطاقة التعريف:</b>
                  <img src={modal.id_card_url} alt="id" style={{ display: 'block', marginTop: 8, width: '100%', borderRadius: 8, maxHeight: 160, objectFit: 'cover' }} />
                </div>
              )}
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button className="btn btn-primary" style={{ flex: 1, justifyContent: 'center' }} disabled={!!actionId} onClick={() => approve(modal.id)}>
                {actionId === modal.id ? '…' : '✓ اعتماد الأستاذ'}
              </button>
              <button className="btn btn-danger" style={{ flex: 1, justifyContent: 'center' }} disabled={!!actionId} onClick={() => reject(modal.id)}>
                ✕ رفض الطلب
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
