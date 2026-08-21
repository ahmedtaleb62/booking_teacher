import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'
import ConfirmModal from '../components/ConfirmModal'

const PLAN_MONTHS = { monthly: 1, quarterly: 3, yearly: 12 }
const PLAN_LABELS = { monthly: 'شهري', quarterly: 'فصلي (3 أشهر)', yearly: 'سنوي (12 شهراً)' }

/* ── Manual subscription modal (WhatsApp payments) ────────────── */
function ManualSubModal({ student, onClose, onDone }) {
  const toast = useToast()
  const [items, setItems]       = useState({ courses: [], packages: [] })
  const [loadingItems, setLoadingItems] = useState(true)
  const [itemType, setItemType] = useState('course') // 'course' | 'package'
  const [itemId, setItemId]     = useState('')
  const [amount, setAmount]     = useState('')
  const [planType, setPlanType] = useState('monthly')
  const [saving, setSaving]     = useState(false)

  useEffect(() => {
    (async () => {
      const [{ data: courses }, { data: packages }] = await Promise.all([
        supabase.from('courses').select('id, title, price_monthly, teacher:teacher_id(full_name)').eq('is_active', true).order('title'),
        supabase.from('packages').select('id, title, price_monthly').eq('is_active', true).order('title'),
      ])
      setItems({ courses: courses || [], packages: packages || [] })
      setLoadingItems(false)
    })()
  }, [])

  const list = itemType === 'course' ? items.courses : items.packages
  const selected = list.find(i => i.id === itemId)

  useEffect(() => {
    if (selected) setAmount(String((selected.price_monthly || 0) * PLAN_MONTHS[planType]))
  }, [itemId, planType]) // eslint-disable-line react-hooks/exhaustive-deps

  async function submit() {
    if (!itemId || !amount) { toast('اختر الدرس/الباقة وأدخل المبلغ', 'error'); return }
    setSaving(true)
    const { data: { user } } = await supabase.auth.getUser()
    const { error } = await supabase.rpc('admin_create_manual_subscription', {
      p_student_id: student.id,
      p_course_id:  itemType === 'course'  ? itemId : null,
      p_package_id: itemType === 'package' ? itemId : null,
      p_amount:     parseFloat(amount),
      p_plan_type:  planType,
      p_months:     PLAN_MONTHS[planType],
      p_admin_id:   user.id,
    })
    setSaving(false)
    if (error) {
      toast('خطأ: ' + error.message, 'error')
    } else {
      toast('تم تفعيل الاشتراك بنجاح — أرباح الأستاذ أُضيفت تلقائياً', 'success')
      onDone()
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 440 }}>
        <div className="modal-title">تفعيل اشتراك يدوياً — {student.full_name}</div>
        <div style={{ fontSize: 12, color: 'var(--text3)', marginBottom: 16 }}>
          للطلاب الذين دفعوا عبر واتساب خارج التطبيق. سيُضاف نصيب الأستاذ تلقائياً لأرباحه.
        </div>

        {loadingItems ? (
          <div style={{ padding: 20, textAlign: 'center' }}>...جاري التحميل</div>
        ) : (
          <>
            <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
              <button className={`btn btn-sm ${itemType === 'course' ? 'btn-primary' : ''}`}
                onClick={() => { setItemType('course'); setItemId('') }}>درس</button>
              <button className={`btn btn-sm ${itemType === 'package' ? 'btn-primary' : ''}`}
                onClick={() => { setItemType('package'); setItemId('') }}>باقة</button>
            </div>

            <div className="field-label" style={{ marginBottom: 6 }}>
              {itemType === 'course' ? 'الدرس' : 'الباقة'}
            </div>
            <select className="field-input" value={itemId} onChange={e => setItemId(e.target.value)} style={{ marginBottom: 12 }}>
              <option value="">اختر...</option>
              {list.map(i => (
                <option key={i.id} value={i.id}>
                  {i.title}{i.teacher?.full_name ? ` — ${i.teacher.full_name}` : ''}
                </option>
              ))}
            </select>

            <div className="field-label" style={{ marginBottom: 6 }}>مدة الاشتراك</div>
            <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
              {Object.keys(PLAN_MONTHS).map(p => (
                <button key={p} className={`btn btn-sm ${planType === p ? 'btn-primary' : ''}`}
                  onClick={() => setPlanType(p)} style={{ flex: 1, fontSize: 11 }}>
                  {PLAN_LABELS[p]}
                </button>
              ))}
            </div>

            <div className="field-label" style={{ marginBottom: 6 }}>المبلغ المدفوع (أوقية)</div>
            <input className="field-input" type="number" value={amount} onChange={e => setAmount(e.target.value)} style={{ marginBottom: 16 }} />

            <div style={{ display: 'flex', gap: 8 }}>
              <button className="btn" style={{ flex: 1 }} onClick={onClose} disabled={saving}>إلغاء</button>
              <button className="btn btn-primary" style={{ flex: 2 }} onClick={submit} disabled={saving || !itemId}>
                {saving ? '...جارٍ التفعيل' : 'تفعيل الاشتراك'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

const AVATAR_COLORS = [
  ['#D7F2E6', '#0A6E4E'], ['#E3F4EF', '#0E7C66'],
  ['#ECE5F7', '#5A3B95'], ['#FBEFD6', '#92620F'],
  ['#DEEAF7', '#1F5C99'], ['#FBE0DB', '#A12B1D'],
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

const ROLE_FILTERS   = [ ['all', 'الكل'], ['student', 'طالب'], ['teacher', 'أستاذ'] ]
const STATUS_FILTERS = [ ['all', 'الكل'], ['active', 'نشط'], ['suspended', 'معلَّق'] ]
const SUB_FILTERS    = [ ['all', 'الكل'], ['subscribed', 'مشترك'], ['unsubscribed', 'غير مشترك'] ]
const DEVICE_FILTERS = [ ['all', 'الكل'], ['linked', 'مرتبط'], ['unlinked', 'غير مرتبط'] ]

export default function Users() {
  const toast = useToast()
  const [rows, setRows]                   = useState([])
  const [loading, setLoading]             = useState(true)
  const [actionId, setActionId]           = useState(null)
  const [suspendTarget, setSuspendTarget] = useState(null) // { id, name, is_active }
  const [deleteTarget, setDeleteTarget]   = useState(null) // { id, name }
  const [subTarget, setSubTarget]         = useState(null) // { id, full_name }

  const [search, setSearch]           = useState('')
  const [roleFilter, setRoleFilter]     = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')
  const [subFilter, setSubFilter]       = useState('all')
  const [deviceFilter, setDeviceFilter] = useState('all')

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const [{ data: profiles }, { data: sessions }, { data: subs }] = await Promise.all([
      supabase.from('profiles').select('*').order('created_at', { ascending: false }).limit(200),
      supabase.from('sessions').select('student_id, teacher_id, state, updated_at').limit(2000),
      supabase.from('subscriptions').select('student_id, status').eq('status', 'active'),
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

    const subscribedIds = new Set((subs || []).map(s => s.student_id))

    setRows((profiles || []).map((p, i) => {
      const [bg, fg] = AVATAR_COLORS[i % AVATAR_COLORS.length]
      const last = activityMap[p.id]
      return {
        ...p, bg, fg,
        lastActive: last ? new Date(last.date).toLocaleDateString('ar-EG-u-nu-latn') : '—',
        sessCount:  sessCountMap[p.id] || 0,
        isSubscribed: subscribedIds.has(p.id),
      }
    }))
    setLoading(false)
  }

  const filteredRows = rows.filter(u => {
    if (roleFilter !== 'all' && u.role !== roleFilter) return false
    if (statusFilter === 'active' && u.is_active === false) return false
    if (statusFilter === 'suspended' && u.is_active !== false) return false
    if (subFilter === 'subscribed' && !u.isSubscribed) return false
    if (subFilter === 'unsubscribed' && u.isSubscribed) return false
    if (deviceFilter === 'linked' && !u.device_id) return false
    if (deviceFilter === 'unlinked' && u.device_id) return false
    if (search.trim()) {
      const q = search.trim().toLowerCase()
      const nameMatch  = (u.full_name || '').toLowerCase().includes(q)
      const phoneMatch = (u.phone || '').replace(/\D/g, '').includes(q.replace(/\D/g, ''))
      if (!nameMatch && !(q.replace(/\D/g, '') && phoneMatch)) return false
    }
    return true
  })

  const hasActiveFilters = search.trim() || roleFilter !== 'all' || statusFilter !== 'all' || subFilter !== 'all' || deviceFilter !== 'all'
  function clearFilters() {
    setSearch(''); setRoleFilter('all'); setStatusFilter('all'); setSubFilter('all'); setDeviceFilter('all')
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

  async function resetDevice(id) {
    setActionId(id)
    const { error } = await supabase.from('profiles').update({ device_id: null, device_name: null }).eq('id', id)
    setActionId(null)
    if (error) {
      toast('خطأ في إعادة تعيين الجهاز: ' + error.message, 'error')
    } else {
      toast('تم فك ربط الجهاز — يمكن للطالب الدخول من جهاز جديد الآن', 'success')
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
    ? new Date(dt).toLocaleDateString('ar-EG-u-nu-latn', { year: 'numeric', month: 'short', day: 'numeric' })
    : '—'

  const COLS = '52px 1.5fr 0.6fr 0.9fr 1.1fr 0.7fr 1.1fr'

  return (
    <div>
      {/* Advanced search / filter bar */}
      <div style={{
        display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center',
        marginBottom: 12, padding: 12, background: 'var(--surface)',
        border: '1px solid var(--border)', borderRadius: 12,
      }}>
        <input
          className="field-input"
          placeholder="بحث بالاسم أو رقم الهاتف..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={{ flex: '1 1 220px', minWidth: 180 }}
        />
        <select className="field-input" value={roleFilter} onChange={e => setRoleFilter(e.target.value)} style={{ width: 110 }}>
          {ROLE_FILTERS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
        </select>
        <select className="field-input" value={statusFilter} onChange={e => setStatusFilter(e.target.value)} style={{ width: 110 }}>
          {STATUS_FILTERS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
        </select>
        <select className="field-input" value={subFilter} onChange={e => setSubFilter(e.target.value)} style={{ width: 130 }}>
          {SUB_FILTERS.map(([v, l]) => <option key={v} value={v}>{l === 'الكل' ? 'الاشتراك: الكل' : l}</option>)}
        </select>
        <select className="field-input" value={deviceFilter} onChange={e => setDeviceFilter(e.target.value)} style={{ width: 130 }}>
          {DEVICE_FILTERS.map(([v, l]) => <option key={v} value={v}>{l === 'الكل' ? 'الجهاز: الكل' : l}</option>)}
        </select>
        {hasActiveFilters && (
          <button className="btn btn-sm" onClick={clearFilters}>إلغاء الفلاتر</button>
        )}
        <span style={{ fontSize: 12, color: 'var(--text3)', marginInlineStart: 'auto' }}>
          {filteredRows.length} من {rows.length}
        </span>
      </div>

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

        {filteredRows.length === 0 && (
          <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>
            {hasActiveFilters ? 'لا توجد نتائج مطابقة للفلاتر' : 'لا يوجد مستخدمون'}
          </div>
        )}

        {filteredRows.map(u => (
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
                background: u.role === 'teacher' ? '#ECE5F7' : '#DEEAF7',
                color:      u.role === 'teacher' ? '#5A3B95' : '#1F5C99',
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
                background: u.is_active === false ? '#FBE0DB' : '#D7F2E6',
                color:      u.is_active === false ? '#A12B1D' : '#0A6E4E',
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
                  background: u.is_active === false ? '#D7F2E6' : '#FBE0DB',
                  color:      u.is_active === false ? '#0A6E4E' : '#A12B1D',
                  border:     u.is_active === false ? '1px solid #13A88A' : '1px solid #F3C5BD',
                }}
                disabled={!!actionId}
                onClick={() => setSuspendTarget({ id: u.id, name: u.full_name || '—', is_active: u.is_active !== false })}
              >
                {u.is_active === false ? '✓ تفعيل' : '⊘ تعليق'}
              </button>
              {u.role !== 'teacher' && (
                <button
                  className="btn btn-sm"
                  title="تفعيل اشتراك يدوياً (دفع عبر واتساب)"
                  style={{ padding: '4px 10px', fontSize: 11, background: '#D7F2E6', color: '#0A6E4E', border: '1px solid #A9E0CB' }}
                  disabled={!!actionId}
                  onClick={() => setSubTarget({ id: u.id, full_name: u.full_name || '—' })}
                >
                  💳 تفعيل اشتراك
                </button>
              )}
              {u.role !== 'teacher' && u.device_id && (
                <span
                  className="badge"
                  title={u.device_id}
                  style={{ background: '#F1F5F9', color: '#334155', fontSize: 10.5, maxWidth: 130, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                >
                  📱 {u.device_name || 'جهاز غير مسمّى'}
                </span>
              )}
              {u.role !== 'teacher' && u.device_id && (
                <button
                  className="btn btn-sm"
                  title="فك ربط الجهاز — يسمح للطالب بالدخول من جهاز جديد"
                  style={{ padding: '4px 10px', fontSize: 11, background: '#DEEAF7', color: '#1F5C99', border: '1px solid #B9D2F0' }}
                  disabled={!!actionId}
                  onClick={() => resetDevice(u.id)}
                >
                  فك الربط
                </button>
              )}
              <button
                className="btn btn-sm"
                style={{ padding: '4px 10px', fontSize: 11, background: '#FBE0DB', color: '#A12B1D', border: '1px solid #F3C5BD' }}
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

      {/* Manual subscription modal */}
      {subTarget && (
        <ManualSubModal
          student={subTarget}
          onClose={() => setSubTarget(null)}
          onDone={() => { setSubTarget(null); loadData() }}
        />
      )}
    </div>
  )
}
