import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'
import ConfirmModal from '../components/ConfirmModal'

const AVATAR_COLORS = [
  ['#E0E7FF', '#4338CA'], ['#D1FAE5', '#065F46'],
  ['#EDE9FE', '#5B21B6'], ['#FEF3C7', '#92400E'],
  ['#DBEAFE', '#1D4ED8'], ['#FEE2E2', '#991B1B'],
]

function Avatar({ name, size = 34, bg, fg, photoUrl }) {
  const [failed, setFailed] = React.useState(false)
  const initials = (
    <span style={{
      width: size, height: size, borderRadius: 10, background: bg, color: fg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontWeight: 700, fontSize: size * 0.42, flexShrink: 0,
    }}>
      {name?.[0] || '?'}
    </span>
  )
  if (!photoUrl || failed) return initials
  return (
    <img
      src={photoUrl} alt={name}
      style={{ width: size, height: size, borderRadius: 10, objectFit: 'cover', flexShrink: 0, border: '2px solid var(--border)' }}
      onError={() => setFailed(true)}
    />
  )
}

export default function Users() {
  const toast = useToast()
  const [rows, setRows]                   = useState([])
  const [loading, setLoading]             = useState(true)
  const [actionId, setActionId]           = useState(null)
  const [suspendTarget, setSuspendTarget] = useState(null) // { id, name, is_active }
  const [deleteTarget, setDeleteTarget]   = useState(null) // { id, name }

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

    setRows((profiles || []).map((p, i) => {
      const [bg, fg] = AVATAR_COLORS[i % AVATAR_COLORS.length]
      const last = activityMap[p.id]
      return {
        ...p, bg, fg,
        lastActive: last ? new Date(last.date).toLocaleDateString('ar-EG') : '—',
        sessCount:  sessCountMap[p.id] || 0,
      }
    }))
    setLoading(false)
  }

  async function toggleActive(id, currentActive) {
    setActionId(id)
    const { error } = await supabase.from('profiles').update({ is_active: !currentActive }).eq('id', id)
    setActionId(null)
    setSuspendTarget(null)
    if (error) {
      toast('خطأ في تحديث الحالة: ' + error.message, 'error')
    } else {
      toast(currentActive ? 'تم تعليق الحساب' : 'تم تفعيل الحساب', 'success')
      await loadData()
    }
  }

  async function deleteUser(id) {
    setActionId(id)
    const { error } = await supabase.rpc('admin_delete_user', { target_uid: id })
    setActionId(null)
    setDeleteTarget(null)
    if (error) {
      toast('خطأ في الحذف: ' + error.message, 'error')
    } else {
      toast('تم حذف الحساب نهائياً', 'success')
      await loadData()
    }
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const fmtDate = dt => dt
    ? new Date(dt).toLocaleDateString('ar-EG', { year: 'numeric', month: 'short', day: 'numeric' })
    : '—'

  const COLS = '52px 1.5fr 0.6fr 0.9fr 1.1fr 0.7fr 1.1fr'

  return (
    <div>
      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: COLS }}>
          <span></span>
          <span>المستخدم</span>
          <span>الدور</span>
          <span>انضم</span>
          <span>النشاط</span>
          <span>الحالة</span>
          <span style={{ textAlign: 'left' }}>إجراء</span>
        </div>

        {rows.length === 0 && (
          <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا يوجد مستخدمون</div>
        )}

        {rows.map(u => (
          <div key={u.id} className="table-row" style={{ gridTemplateColumns: COLS, alignItems: 'center' }}>

            {/* Avatar */}
            <span>
              <Avatar name={u.full_name} bg={u.bg} fg={u.fg} photoUrl={u.avatar_url} />
            </span>

            {/* Name + phone */}
            <span>
              <div className="fw-700" style={{ fontSize: 13 }}>{u.full_name || '—'}</div>
              <div style={{ fontSize: 11, color: 'var(--text3)', direction: 'ltr', textAlign: 'right' }}>
                {u.phone || '—'}
              </div>
            </span>

            {/* Role */}
            <span>
              <span className="badge" style={{
                background: u.role === 'teacher' ? '#EDE9FE' : '#DBEAFE',
                color:      u.role === 'teacher' ? '#5B21B6' : '#1D4ED8',
              }}>
                {u.role === 'teacher' ? 'أستاذ' : 'طالب'}
              </span>
            </span>

            {/* Join date */}
            <span className="text-2 dir-ltr">{fmtDate(u.created_at)}</span>

            {/* Activity */}
            <span className="text-2">{u.sessCount} جلسة · {u.lastActive}</span>

            {/* Status */}
            <span>
              <span className="badge" style={{
                background: u.is_active === false ? '#FEE2E2' : '#D1FAE5',
                color:      u.is_active === false ? '#991B1B' : '#065F46',
              }}>
                {u.is_active === false ? 'موقوف' : 'نشط'}
              </span>
            </span>

            {/* Actions */}
            <span style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
              <button
                className="btn btn-sm"
                style={{
                  padding: '4px 10px', fontSize: 11,
                  background: u.is_active === false ? '#D1FAE5' : '#FEF2F2',
                  color:      u.is_active === false ? '#065F46' : '#DC2626',
                  border:     u.is_active === false ? '1px solid #6EE7B7' : '1px solid #FCA5A5',
                }}
                disabled={!!actionId}
                onClick={() => setSuspendTarget({ id: u.id, name: u.full_name || '—', is_active: u.is_active !== false })}
              >
                {u.is_active === false ? '✓ تفعيل' : '⊘ تعليق'}
              </button>
              <button
                className="btn btn-sm"
                style={{ padding: '4px 10px', fontSize: 11, background: '#FEE2E2', color: '#991B1B', border: '1px solid #FCA5A5' }}
                disabled={!!actionId}
                onClick={() => setDeleteTarget({ id: u.id, name: u.full_name || '—' })}
              >
                🗑
              </button>
            </span>
          </div>
        ))}
      </div>

      {/* Suspend / activate modal */}
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

      {/* Delete modal */}
      <ConfirmModal
        open={!!deleteTarget}
        danger
        title={`حذف حساب ${deleteTarget?.name}`}
        message="سيتم حذف الحساب وجميع بياناته نهائياً (الجلسات، الاشتراكات، المدفوعات). لا يمكن التراجع عن هذا الإجراء."
        confirm="حذف نهائي"
        cancel="إلغاء"
        loading={actionId === deleteTarget?.id}
        onConfirm={() => deleteUser(deleteTarget.id)}
        onCancel={() => !actionId && setDeleteTarget(null)}
      />
    </div>
  )
}
