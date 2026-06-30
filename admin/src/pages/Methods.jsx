import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'
import ConfirmModal from '../components/ConfirmModal'

export default function Methods() {
  const toast = useToast()
  const [methods, setMethods]       = useState([])
  const [loading, setLoading]       = useState(true)
  const [form, setForm]             = useState({ method: '', number: '', holder: '' })
  const [saving, setSaving]         = useState(false)
  const [msg, setMsg]               = useState('')
  const [editTarget, setEditTarget] = useState(null)  // method row being edited
  const [editSaving, setEditSaving] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState(null) // { id, label }
  const [deleting, setDeleting]     = useState(false)

  useEffect(() => { loadData() }, [])

  const COLORS = [
    ['#D7F2E6', '#0A6E4E'],
    ['#ECE5F7', '#5A3B95'],
    ['#E3F4EF', '#0E7C66'],
    ['#FBEFD6', '#92620F'],
    ['#DEEAF7', '#1F5C99'],
  ]

  async function loadData() {
    setLoading(true)
    const { data } = await supabase.from('payment_methods').select('*').order('created_at')
    setMethods((data || []).map((m, i) => {
      const [bg, fg] = COLORS[i % COLORS.length]
      return { ...m, bg, fg }
    }))
    setLoading(false)
  }

  async function toggleMethod(id, current) {
    await supabase.from('payment_methods').update({ is_active: !current }).eq('id', id)
    await loadData()
  }

  async function addMethod() {
    if (!form.method || !form.number) { setMsg('يرجى إدخال اسم الطريقة ورقم الحساب'); return }
    setSaving(true); setMsg('')
    const { error } = await supabase.from('payment_methods').insert({
      method: form.method,
      label:  form.method,
      number: form.number,
      holder: form.holder || 'منصة سولني',
      is_active: true,
    })
    setSaving(false)
    if (error) { setMsg('خطأ: ' + error.message); return }
    setForm({ method: '', number: '', holder: '' })
    toast('تمت إضافة طريقة الدفع', 'success')
    await loadData()
  }

  function startEdit(m) {
    setEditTarget({ id: m.id, method: m.label || m.method, number: m.number, holder: m.holder })
  }

  async function saveEdit() {
    if (!editTarget.method || !editTarget.number) return
    setEditSaving(true)
    const { error } = await supabase.from('payment_methods').update({
      method: editTarget.method,
      label:  editTarget.method,
      number: editTarget.number,
      holder: editTarget.holder || 'منصة سولني',
    }).eq('id', editTarget.id)
    setEditSaving(false)
    if (error) { toast('خطأ في التعديل: ' + error.message, 'error'); return }
    setEditTarget(null)
    toast('تم تعديل طريقة الدفع', 'success')
    await loadData()
  }

  async function deleteMethod() {
    setDeleting(true)
    const { error } = await supabase.from('payment_methods').delete().eq('id', deleteTarget.id)
    setDeleting(false)
    setDeleteTarget(null)
    if (error) { toast('خطأ في الحذف: ' + error.message, 'error'); return }
    toast('تم حذف طريقة الدفع', 'success')
    await loadData()
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1.3fr 1fr', gap: 18, maxWidth: 1100 }}>
      {/* Methods list */}
      <div className="card">
        <div className="flex justify-between items-center mb-14" style={{ marginBottom: 6 }}>
          <span className="card-title">طرق الدفع</span>
          <span style={{ fontSize: 11.5, color: 'var(--text3)' }}>تظهر للطلاب عند الدفع</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 11, marginTop: 16 }}>
          {methods.length === 0 && (
            <div style={{ color: 'var(--text3)', fontSize: 13, textAlign: 'center', padding: '20px 0' }}>لا توجد طرق دفع بعد</div>
          )}
          {methods.map(m => (
            <div key={m.id}>
              {/* Edit inline form */}
              {editTarget?.id === m.id ? (
                <div style={{ border: '2px solid var(--primary)', borderRadius: 13, padding: 14 }}>
                  <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text2)', marginBottom: 10 }}>تعديل طريقة الدفع</div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 12 }}>
                    <input
                      className="field-input"
                      placeholder="اسم الطريقة"
                      value={editTarget.method}
                      onChange={e => setEditTarget(t => ({ ...t, method: e.target.value }))}
                    />
                    <input
                      className="field-input"
                      placeholder="رقم الحساب"
                      dir="ltr"
                      style={{ textAlign: 'right' }}
                      value={editTarget.number}
                      onChange={e => setEditTarget(t => ({ ...t, number: e.target.value }))}
                    />
                    <input
                      className="field-input"
                      placeholder="اسم المستفيد"
                      value={editTarget.holder}
                      onChange={e => setEditTarget(t => ({ ...t, holder: e.target.value }))}
                    />
                  </div>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button
                      className="btn btn-primary"
                      style={{ flex: 1, justifyContent: 'center', padding: '9px 0', fontSize: 12.5 }}
                      disabled={editSaving}
                      onClick={saveEdit}
                    >
                      {editSaving ? '…' : '💾 حفظ'}
                    </button>
                    <button
                      className="btn btn-secondary"
                      style={{ padding: '9px 14px', fontSize: 12.5 }}
                      onClick={() => setEditTarget(null)}
                    >
                      إلغاء
                    </button>
                  </div>
                </div>
              ) : (
                <div style={{ display: 'flex', alignItems: 'center', gap: 13, border: '1px solid var(--border-table)', borderRadius: 13, padding: 14 }}>
                  <span style={{ width: 46, height: 46, borderRadius: 11, background: m.bg, color: m.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 13, flexShrink: 0 }}>
                    {(m.label || m.method || '؟').slice(0, 3)}
                  </span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13.5, fontWeight: 700 }}>{m.label || m.method}</div>
                    <div style={{ fontSize: 12.5, color: 'var(--text2)', direction: 'ltr', textAlign: 'right' }}>{m.number}</div>
                    <div style={{ fontSize: 10.5, color: 'var(--text3)' }}>المستفيد: {m.holder}</div>
                  </div>
                  <span className="badge" style={{ background: m.is_active ? '#D7F2E6' : '#F1F5F9', color: m.is_active ? '#0A6E4E' : '#475569', flexShrink: 0 }}>
                    {m.is_active ? 'مفعّل' : 'معطّل'}
                  </span>
                  {/* Toggle */}
                  <div
                    className="switch"
                    style={{ background: m.is_active ? 'var(--primary)' : '#C9D6D1', cursor: 'pointer', flexShrink: 0 }}
                    onClick={() => toggleMethod(m.id, m.is_active)}
                  >
                    <div className="switch-knob" style={{ [m.is_active ? 'left' : 'right']: 3 }} />
                  </div>
                  {/* Edit */}
                  <button
                    className="btn btn-sm btn-secondary"
                    style={{ padding: '5px 10px', fontSize: 12, flexShrink: 0 }}
                    onClick={() => startEdit(m)}
                  >
                    ✏️
                  </button>
                  {/* Delete */}
                  <button
                    className="btn btn-sm"
                    style={{ padding: '5px 10px', fontSize: 12, background: '#FBE0DB', color: '#A12B1D', border: '1px solid #F3C5BD', flexShrink: 0 }}
                    onClick={() => setDeleteTarget({ id: m.id, label: m.label || m.method })}
                  >
                    🗑
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Add method form */}
      <div className="card" style={{ alignSelf: 'flex-start' }}>
        <div className="card-title" style={{ marginBottom: 16 }}>إضافة طريقة دفع</div>
        {msg && <div className="login-error" style={{ marginBottom: 14 }}>{msg}</div>}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div>
            <div className="field-label">اسم الطريقة</div>
            <input className="field-input" placeholder="مثال: مصرفي" value={form.method} onChange={e => setForm(f => ({ ...f, method: e.target.value }))} />
          </div>
          <div>
            <div className="field-label">رقم الحساب / المحفظة</div>
            <input className="field-input" placeholder="00 00 00 00" value={form.number} onChange={e => setForm(f => ({ ...f, number: e.target.value }))} dir="ltr" style={{ textAlign: 'right' }} />
          </div>
          <div>
            <div className="field-label">اسم المستفيد</div>
            <input className="field-input" placeholder="منصة سولني" value={form.holder} onChange={e => setForm(f => ({ ...f, holder: e.target.value }))} />
          </div>
          <button
            className="btn btn-primary"
            style={{ justifyContent: 'center', padding: 13, fontSize: 13.5 }}
            disabled={saving}
            onClick={addMethod}
          >
            {saving ? '…' : '+ إضافة الطريقة'}
          </button>
        </div>
      </div>

      {/* Delete confirm */}
      <ConfirmModal
        open={!!deleteTarget}
        danger
        title={`حذف طريقة الدفع "${deleteTarget?.label}"`}
        message="لن يتمكن الطلاب من استخدام هذه الطريقة بعد الحذف. الإجراء لا يمكن التراجع عنه."
        confirm="حذف"
        cancel="إلغاء"
        loading={deleting}
        onConfirm={deleteMethod}
        onCancel={() => !deleting && setDeleteTarget(null)}
      />
    </div>
  )
}
