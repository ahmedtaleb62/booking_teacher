import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'

const ACTION_LABELS = {
  delete_user:                   ['حذف مستخدم',            '#FBE0DB', '#A12B1D'],
  suspend_account:               ['تعليق حساب',             '#FBE0DB', '#A12B1D'],
  activate_account:              ['تفعيل حساب',             '#D7F2E6', '#0A6E4E'],
  unlink_device:                 ['فك ربط جهاز',            '#DEEAF7', '#1F5C99'],
  cancel_session:                ['إلغاء جلسة',             '#FBE0DB', '#A12B1D'],
  reschedule_session:            ['إعادة جدولة جلسة',       '#DEEAF7', '#1F5C99'],
  suspend_subscription:          ['تعطيل اشتراك',           '#FBE0DB', '#A12B1D'],
  create_manual_subscription:    ['تفعيل اشتراك يدوي',      '#D7F2E6', '#0A6E4E'],
  freeze_payment:                ['تجميد دفعة',             '#FEF3C7', '#92400E'],
  dispute_refund:                ['استرداد نزاع',           '#ECE5F7', '#5A3B95'],
  confirm_teacher_after_dispute: ['تأكيد حق الأستاذ',       '#D7F2E6', '#0A6E4E'],
  settle_teacher:                ['تسوية مستحقات أستاذ',    '#D7F2E6', '#0A6E4E'],
}

const TARGET_LABELS = {
  user: 'مستخدم', session: 'جلسة', subscription: 'اشتراك', payment: 'دفعة',
}

const ACTION_FILTERS = [['all', 'كل الإجراءات'], ...Object.entries(ACTION_LABELS).map(([k, v]) => [k, v[0]])]

function detailsSummary(row) {
  const d = row.details || {}
  const parts = []
  if (d.full_name) parts.push(d.full_name)
  if (d.amount != null) parts.push(`${Number(d.amount).toLocaleString('en-US')} أوقية`)
  if (d.refund === true) parts.push('مع استرداد')
  if (d.refund === false) parts.push('بدون استرداد')
  if (d.refund_amount != null) parts.push(`استرداد ${Number(d.refund_amount).toLocaleString('en-US')} أوقية`)
  if (d.plan_type) parts.push(d.plan_type)
  if (d.description) parts.push(d.description)
  if (d.new_scheduled_at) parts.push('موعد جديد: ' + new Date(d.new_scheduled_at).toLocaleString('ar-EG-u-nu-latn', { dateStyle: 'short', timeStyle: 'short' }))
  return parts.join(' · ') || '—'
}

export default function AuditLog() {
  const [rows, setRows]           = useState([])
  const [loading, setLoading]     = useState(true)
  const [search, setSearch]       = useState('')
  const [actionFilter, setActionFilter] = useState('all')

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const { data } = await supabase
      .from('admin_audit_log')
      .select('*, admin:admin_id(full_name)')
      .order('created_at', { ascending: false })
      .limit(500)
    setRows(data || [])
    setLoading(false)
  }

  const filteredRows = rows.filter(r => {
    if (actionFilter !== 'all' && r.action !== actionFilter) return false
    if (search.trim()) {
      const q = search.trim().toLowerCase()
      const hay = [r.admin?.full_name, r.action, JSON.stringify(r.details)].join(' ').toLowerCase()
      if (!hay.includes(q)) return false
    }
    return true
  })

  const fmtTs = dt => new Date(dt).toLocaleString('ar-EG-u-nu-latn', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const COLS = '1fr 1.3fr 0.8fr 2fr 1.1fr'

  return (
    <div>
      <div style={{
        display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center',
        marginBottom: 16, padding: 12, background: 'var(--surface)',
        border: '1px solid var(--border)', borderRadius: 12,
      }}>
        <input
          className="field-input"
          placeholder="بحث باسم الأدمن أو نوع الإجراء..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={{ flex: '1 1 240px', minWidth: 200 }}
        />
        <select className="field-input" value={actionFilter} onChange={e => setActionFilter(e.target.value)} style={{ width: 180 }}>
          {ACTION_FILTERS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
        </select>
        <span style={{ fontSize: 12, color: 'var(--text3)', marginInlineStart: 'auto' }}>
          {filteredRows.length} من {rows.length} (آخر 500)
        </span>
      </div>

      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: COLS }}>
          <span>الأدمن</span><span>الإجراء</span><span>النوع</span><span>التفاصيل</span><span>الوقت</span>
        </div>

        {filteredRows.length === 0 && (
          <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا توجد سجلات</div>
        )}

        {filteredRows.map(r => {
          const [label, bg, fg] = ACTION_LABELS[r.action] || [r.action, '#F1F5F9', '#475569']
          return (
            <div key={r.id} className="table-row" style={{ gridTemplateColumns: COLS, alignItems: 'center' }}>
              <span className="fw-700" style={{ fontSize: 13 }}>{r.admin?.full_name || '—'}</span>
              <span><span className="badge" style={{ background: bg, color: fg }}>{label}</span></span>
              <span className="text-2" style={{ fontSize: 12 }}>{TARGET_LABELS[r.target_type] || r.target_type}</span>
              <span className="text-2" style={{ fontSize: 12 }}>{detailsSummary(r)}</span>
              <span className="text-2 dir-ltr" style={{ fontSize: 11 }}>{fmtTs(r.created_at)}</span>
            </div>
          )
        })}
      </div>
    </div>
  )
}
