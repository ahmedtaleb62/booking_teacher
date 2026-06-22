import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'
import ConfirmModal from '../components/ConfirmModal'

export default function Users() {
  const toast = useToast()
  const [rows, setRows]                 = useState([])
  const [loading, setLoading]           = useState(true)
  const [actionId, setActionId]         = useState(null)
  const [suspendTarget, setSuspendTarget] = useState(null) // { id, name, is_active }

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const [{ data: profiles }, { data: sessions }] = await Promise.all([
      supabase.from('profiles').select('*').order('created_at', { ascending: false }).limit(200),
      supabase.from('sessions').select('student_id, teacher_id, state, updated_at').limit(2000),
    ])

    const activityMap = {}
    ;(sessions || []).forEach(s => {
      for (const id of [s.student_id, s.teacher_id]) {
        if (!id) continue
        if (!activityMap[id] || new Date(s.updated_at) > new Date(activityMap[id].date))
          activityMap[id] = { date: s.updated_at }
      }
    })

    const sessCountMap = {}
    ;(sessions || []).forEach(s => {
      for (const id of [s.student_id, s.teacher_id]) {
        if (id) sessCountMap[id] = (sessCountMap[id] || 0) + 1
      }
    })

    const colors = [['#E0E7FF', '#4338CA'], ['#D1FAE5', '#065F46'], ['#EDE9FE', '#5B21B6'], ['#FEF3C7', '#92400E'], ['#DBEAFE', '#1D4ED8']]
    setRows((profiles || []).map((p, i) => {
      const [bg, fg] = colors[i % colors.length]
      const last = activityMap[p.id]
      return {
        ...p, bg, fg,
        init:       (p.full_name || '?')[0],
        lastActive: last ? new Date(last.date).toLocaleDateString('ar-EG') : '—',
        sessCount:  sessCountMap[p.id] || 0,
      }
    }))
    setLoading(false)
  }

  async function toggleActive(id, currentActive) {
    setActionId(id)
    const { error } = await supabase
      .from('profiles').update({ is_active: !currentActive }).eq('id', id)
    setActionId(null)
    setSuspendTarget(null)
    if (error) {
      toast('خطأ في تحديث الحالة: ' + error.message, 'error')
    } else {
      toast(currentActive ? 'تم تعليق الحساب' : 'تم تفعيل الحساب', 'success')
      await loadData()
    }
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const fmtDate = dt => dt
    ? new Date(dt).toLocaleDateString('ar-EG', { year: 'numeric', month: 'short', day: 'numeric' })
    : '—'

  return (
    <div>
      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: '1.6fr 0.7fr 1fr 1.3fr 0.8fr 1fr' }}>
          <span>المستخدم</span><span>الدور</span><span>انضم</span><span>النشاط</span><span>الحالة</span><span style={{ textAlign: 'left' }}>إجراء</span>
        </div>
        {rows.length === 0 && (
          <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا يوجد مستخدمون</div>
        )}
        {rows.map(u => (
          <div key={u.id} className="table-row" style={{ gridTemplateColumns: '1.6fr 0.7fr 1fr 1.3fr 0.8fr 1fr' }}>
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
            <span>
              <span
                className="badge"
                style={{
                  background: u.is_active === false ? '#FEE2E2' : '#D1FAE5',
                  color:      u.is_active === false ? '#991B1B' : '#065F46',
                }}
              >
                {u.is_active === false ? 'موقوف' : 'نشط'}
              </span>
            </span>
            <span style={{ textAlign: 'left' }}>
              <button
                className="btn btn-sm"
                style={{
                  padding: '5px 12px', fontSize: 12,
                  background: u.is_active === false ? '#D1FAE5' : '#FEF2F2',
                  color:      u.is_active === false ? '#065F46' : '#DC2626',
                  border:     u.is_active === false ? '1px solid #6EE7B7' : '1px solid #FCA5A5',
                }}
                disabled={actionId === u.id}
                onClick={() => setSuspendTarget({ id: u.id, name: u.full_name || '—', is_active: u.is_active !== false })}
              >
                {u.is_active === false ? '✓ تفعيل' : '⊘ تعليق'}
              </button>
            </span>
          </div>
        ))}
      </div>

      <ConfirmModal
        open={!!suspendTarget}
        danger={suspendTarget?.is_active}
        title={suspendTarget?.is_active ? `تعليق حساب ${suspendTarget?.name}` : `تفعيل حساب ${suspendTarget?.name}`}
        message={
          suspendTarget?.is_active
            ? 'لن يتمكن المستخدم من تسجيل الدخول أو استخدام التطبيق حتى تُعيد تفعيل الحساب.'
            : 'سيتمكن المستخدم من تسجيل الدخول واستخدام التطبيق مجدداً.'
        }
        confirm={suspendTarget?.is_active ? 'تعليق الحساب' : 'تفعيل الحساب'}
        cancel="إلغاء"
        loading={actionId === suspendTarget?.id}
        onConfirm={() => toggleActive(suspendTarget.id, suspendTarget.is_active)}
        onCancel={() => !actionId && setSuspendTarget(null)}
      />
    </div>
  )
}
