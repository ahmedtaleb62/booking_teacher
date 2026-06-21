import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'
import ConfirmModal from '../components/ConfirmModal'

export default function Accounting() {
  const showToast = useToast()
  const [rows, setRows] = useState([])
  const [totals, setTotals] = useState({ due: 0, paid: 0, pending: 0 })
  const [loading, setLoading] = useState(true)
  const [actionId, setActionId] = useState(null)
  const [confirmModal, setConfirmModal] = useState(null) // { teacherId, amount, name }

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const { data: tps } = await supabase
      .from('teacher_profiles')
      .select('id, is_approved')
      .eq('is_approved', true)
    const tpIds = (tps || []).map(t => t.id)
    const { data: profs } = tpIds.length
      ? await supabase.from('profiles').select('id, full_name').in('id', tpIds)
      : { data: [] }
    const profMap = Object.fromEntries((profs || []).map(p => [p.id, p]))
    const teachers = (tps || []).map(t => ({ ...t, profiles: profMap[t.id] || {} }))

    const [{ data: sessions }, { data: subs }] = await Promise.all([
      supabase
        .from('sessions')
        .select('teacher_id, amount, state')
        .in('state', ['COMPLETED', 'CONFIRMED_BOOKING', 'ACTIVE_SESSION']),
      supabase
        .from('subscriptions')
        .select('course:course_id(teacher_id), amount')
        .eq('status', 'active')
        .eq('type', 'course'),
    ])

    const byTeacher = {}
    ;(sessions || []).forEach(s => {
      if (!byTeacher[s.teacher_id]) byTeacher[s.teacher_id] = { sessions: 0, subs: 0 }
      byTeacher[s.teacher_id].sessions += (s.amount || 0) * 0.85
    })
    ;(subs || []).forEach(s => {
      const tid = s.course?.teacher_id
      if (!tid) return
      if (!byTeacher[tid]) byTeacher[tid] = { sessions: 0, subs: 0 }
      byTeacher[tid].subs += (s.amount || 0) * 0.85
    })

    const teacherRows = (teachers || []).map((t, i) => {
      const stats = byTeacher[t.id] || { sessions: 0, subs: 0 }
      const total = stats.sessions + stats.subs
      const colors = [['#E0E7FF', '#4338CA'], ['#D1FAE5', '#065F46'], ['#EDE9FE', '#5B21B6'], ['#FEF3C7', '#92400E'], ['#DBEAFE', '#1D4ED8']]
      const [bg, fg] = colors[i % colors.length]
      return {
        id: t.id,
        name: t.profiles?.full_name || '—',
        init: (t.profiles?.full_name || '?')[0],
        bg, fg,
        sessions: Math.round(stats.sessions),
        subs: Math.round(stats.subs),
        total: Math.round(total),
        status: total > 0 ? 'قيد التسوية' : 'لا يوجد',
        statusBg: total > 0 ? '#FEF3C7' : '#F1F5F9',
        statusFg: total > 0 ? '#92400E' : '#475569',
      }
    })

    const fromSessions = teacherRows.reduce((s, r) => s + r.sessions, 0)
    const fromSubs     = teacherRows.reduce((s, r) => s + r.subs, 0)
    const due = Math.round(fromSessions + fromSubs)
    setTotals({ due, fromSessions: Math.round(fromSessions), fromSubs: Math.round(fromSubs) })
    setRows(teacherRows)
    setLoading(false)
  }

  function openSettle(teacherId, amount, name) {
    setConfirmModal({ teacherId, amount, name })
  }

  async function confirmSettle() {
    const { teacherId, amount, name } = confirmModal
    setActionId(teacherId)
    const { error } = await supabase.from('ledger_entries').insert({
      teacher_id: teacherId,
      type: 'payout_sent',
      gross_amount: amount,
      commission_amount: 0,
      net_amount: -amount,
      notes: 'تسوية من الإدارة — ' + new Date().toLocaleDateString('ar-EG'),
    })
    setActionId(null)
    setConfirmModal(null)
    if (error) {
      showToast('خطأ في تسجيل التسوية: ' + error.message, 'error')
    } else {
      showToast(`تمت تسوية مستحقات ${name} بنجاح`, 'success')
      await loadData()
    }
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const fmt = n => n?.toLocaleString('ar')

  return (
    <div>
      <div className="flex justify-between items-center mb-18" style={{ flexWrap: 'wrap', gap: 14 }}>
        <div className="flex gap-14" style={{ flexWrap: 'wrap' }}>
          <div className="card-sm">
            <div className="text-muted" style={{ fontSize: 12 }}>إجمالي المستحقات للأساتذة</div>
            <div style={{ fontSize: 23, fontWeight: 700, marginTop: 3 }}>{fmt(totals.due)} <span style={{ fontSize: 11, color: 'var(--text3)' }}>أوقية</span></div>
          </div>
          <div className="card-sm">
            <div className="text-muted" style={{ fontSize: 12 }}>مستحقات الجلسات</div>
            <div style={{ fontSize: 23, fontWeight: 700, color: '#1B9E77', marginTop: 3 }}>{fmt(totals.fromSessions)} <span style={{ fontSize: 11, color: 'var(--text3)' }}>أوقية</span></div>
          </div>
          <div className="card-sm" style={{ background: '#1E1B4B', border: 'none' }}>
            <div style={{ fontSize: 12, color: 'rgba(255,255,255,.5)' }}>مستحقات الاشتراكات</div>
            <div style={{ fontSize: 23, fontWeight: 700, color: '#A5B4FC', marginTop: 3 }}>{fmt(totals.fromSubs)} <span style={{ fontSize: 11, color: 'rgba(255,255,255,.4)' }}>أوقية</span></div>
          </div>
        </div>
      </div>

      <div className="info-banner warn">
        ℹ️ &nbsp;تُحسب مستحقات كل أستاذ = (دخل الجلسات − عمولة 15%) + (دخل الاشتراكات في دروسه − عمولة 15%). تتم التسوية والدفع شهرياً.
      </div>

      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: '1.6fr 1fr 1fr 1fr 1fr 1.1fr' }}>
          <span>الأستاذ</span><span>صافي الجلسات</span><span>صافي الاشتراكات</span><span>الإجمالي المستحق</span><span>الحالة</span><span style={{ textAlign: 'left' }}>إجراء</span>
        </div>
        {rows.length === 0 && <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا توجد بيانات</div>}
        {rows.map(r => (
          <div key={r.id} className="table-row" style={{ gridTemplateColumns: '1.6fr 1fr 1fr 1fr 1fr 1.1fr' }}>
            <span className="flex items-center gap-10">
              <span style={{ width: 34, height: 34, borderRadius: 10, background: r.bg, color: r.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, flexShrink: 0 }}>{r.init}</span>
              <span className="fw-700">{r.name}</span>
            </span>
            <span className="text-2">{fmt(r.sessions)}</span>
            <span className="text-2">{fmt(r.subs)}</span>
            <span className="fw-700">{fmt(r.total)}</span>
            <span><span className="badge" style={{ background: r.statusBg, color: r.statusFg }}>{r.status}</span></span>
            <span style={{ textAlign: 'left' }}>
              {r.total > 0 && (
                <button className="btn btn-sm btn-primary" disabled={!!actionId} onClick={() => openSettle(r.id, r.total, r.name)}>
                  {actionId === r.id ? <span className="spinner" style={{ width: 13, height: 13, borderWidth: 2 }} /> : 'تسوية الدفع'}
                </button>
              )}
            </span>
          </div>
        ))}
      </div>

      <ConfirmModal
        open={!!confirmModal}
        title={`تسوية مستحقات ${confirmModal?.name}`}
        message={`سيتم تسجيل دفع بقيمة ${confirmModal?.amount?.toLocaleString('ar')} أوقية للأستاذ ${confirmModal?.name}. هل تريد المتابعة؟`}
        confirm="تأكيد التسوية"
        cancel="إلغاء"
        danger={false}
        loading={!!actionId}
        onConfirm={confirmSettle}
        onCancel={() => !actionId && setConfirmModal(null)}
      />
    </div>
  )
}
