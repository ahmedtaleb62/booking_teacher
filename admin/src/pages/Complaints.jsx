import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

const TYPE_LABELS   = { complaint: 'شكوى', suggestion: 'اقتراح' }
const TYPE_COLORS   = { complaint: ['#FBE0DB', '#A12B1D'], suggestion: ['#DEEAF7', '#1F5C99'] }
const STATUS_LABELS = { pending: 'قيد المراجعة', reviewed: 'تمت المراجعة' }

const TYPE_FILTERS   = [ ['all', 'الكل'], ['complaint', 'شكوى'], ['suggestion', 'اقتراح'] ]
const STATUS_FILTERS = [ ['all', 'الكل'], ['pending', 'قيد المراجعة'], ['reviewed', 'تمت المراجعة'] ]

export default function Complaints() {
  const toast = useToast()
  const [rows, setRows]       = useState([])
  const [loading, setLoading] = useState(true)
  const [actionId, setActionId] = useState(null)
  const [search, setSearch]         = useState('')
  const [typeFilter, setTypeFilter]     = useState('all')
  const [statusFilter, setStatusFilter] = useState('all')

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const { data } = await supabase
      .from('complaints')
      .select('id, type, message, status, admin_note, created_at, reviewed_at, user:user_id(full_name, phone, role)')
      .order('created_at', { ascending: false })
    setRows(data || [])
    setLoading(false)
  }

  async function markReviewed(id) {
    setActionId(id)
    const { error } = await supabase
      .from('complaints')
      .update({ status: 'reviewed', reviewed_at: new Date().toISOString() })
      .eq('id', id)
    setActionId(null)
    if (error) {
      toast('خطأ: ' + error.message, 'error')
    } else {
      toast('تم وضع علامة "تمت المراجعة"', 'success')
      await loadData()
    }
  }

  const filteredRows = rows.filter(r => {
    if (typeFilter !== 'all' && r.type !== typeFilter) return false
    if (statusFilter !== 'all' && r.status !== statusFilter) return false
    if (search.trim()) {
      const q = search.trim().toLowerCase()
      const nameMatch    = (r.user?.full_name || '').toLowerCase().includes(q)
      const phoneMatch    = q.replace(/\D/g, '') && (r.user?.phone || '').replace(/\D/g, '').includes(q.replace(/\D/g, ''))
      const messageMatch = (r.message || '').toLowerCase().includes(q)
      if (!nameMatch && !phoneMatch && !messageMatch) return false
    }
    return true
  })

  const pendingCount = rows.filter(r => r.status === 'pending').length

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const fmtDate = dt => new Date(dt).toLocaleString('ar-EG-u-nu-latn', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })

  return (
    <div>
      <div className="flex gap-14 mb-18" style={{ flexWrap: 'wrap' }}>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>إجمالي الرسائل</div>
          <div style={{ fontSize: 23, fontWeight: 700, marginTop: 3 }}>{rows.length}</div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>قيد المراجعة</div>
          <div style={{ fontSize: 23, fontWeight: 700, color: '#92400E', marginTop: 3 }}>{pendingCount}</div>
        </div>
      </div>

      {/* Filter bar */}
      <div style={{
        display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center',
        marginBottom: 16, padding: 12, background: 'var(--surface)',
        border: '1px solid var(--border)', borderRadius: 12,
      }}>
        <input
          className="field-input"
          placeholder="بحث بالاسم، الهاتف، أو نص الرسالة..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={{ flex: '1 1 240px', minWidth: 200 }}
        />
        <select className="field-input" value={typeFilter} onChange={e => setTypeFilter(e.target.value)} style={{ width: 110 }}>
          {TYPE_FILTERS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
        </select>
        <select className="field-input" value={statusFilter} onChange={e => setStatusFilter(e.target.value)} style={{ width: 130 }}>
          {STATUS_FILTERS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
        </select>
        <span style={{ fontSize: 12, color: 'var(--text3)', marginInlineStart: 'auto' }}>
          {filteredRows.length} من {rows.length}
        </span>
      </div>

      {filteredRows.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text3)' }}>
          <div style={{ fontSize: 48, marginBottom: 12 }}>💬</div>
          <div style={{ fontSize: 16, fontWeight: 700 }}>
            {rows.length === 0 ? 'لا توجد شكاوى أو اقتراحات بعد' : 'لا توجد نتائج مطابقة'}
          </div>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {filteredRows.map(r => {
            const [bg, fg] = TYPE_COLORS[r.type] || TYPE_COLORS.complaint
            return (
              <div key={r.id} className="card" style={{ padding: 16 }}>
                <div className="flex justify-between items-start" style={{ gap: 12 }}>
                  <div style={{ flex: 1 }}>
                    <div className="flex items-center gap-8" style={{ marginBottom: 6 }}>
                      <span className="badge" style={{ background: bg, color: fg }}>{TYPE_LABELS[r.type] || r.type}</span>
                      <span className="badge" style={{
                        background: r.status === 'pending' ? '#FEF3C7' : '#D7F2E6',
                        color:      r.status === 'pending' ? '#92400E' : '#0A6E4E',
                      }}>
                        {STATUS_LABELS[r.status] || r.status}
                      </span>
                      <span style={{ fontSize: 11, color: 'var(--text3)' }}>
                        {r.user?.role === 'teacher' ? 'أستاذ' : 'طالب'} · {r.user?.full_name || '—'}
                        {r.user?.phone ? ` · ${r.user.phone}` : ''}
                      </span>
                    </div>
                    <div style={{ fontSize: 14, color: 'var(--text1)', lineHeight: 1.6, whiteSpace: 'pre-wrap' }}>
                      {r.message}
                    </div>
                    <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 8, direction: 'ltr', textAlign: 'right' }}>
                      {fmtDate(r.created_at)}
                    </div>
                  </div>
                  {r.status === 'pending' && (
                    <button
                      className="btn btn-sm btn-primary"
                      disabled={!!actionId}
                      onClick={() => markReviewed(r.id)}
                      style={{ flexShrink: 0 }}
                    >
                      {actionId === r.id ? <span className="spinner" style={{ width: 13, height: 13, borderWidth: 2 }} /> : '✓ تمت المراجعة'}
                    </button>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
