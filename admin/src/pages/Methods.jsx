import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'

export default function Methods() {
  const [methods, setMethods] = useState([])
  const [loading, setLoading] = useState(true)
  const [form, setForm] = useState({ method: '', number: '', holder: '' })
  const [saving, setSaving] = useState(false)
  const [msg, setMsg] = useState('')

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const { data } = await supabase.from('payment_methods').select('*').order('created_at')
    const colors = [['#E0E7FF', '#4338CA', 'صر'], ['#EDE9FE', '#5B21B6', 'بنك'], ['#D1FAE5', '#065F46', 'حس'], ['#FEF3C7', '#92400E', 'دفع']]
    setMethods((data || []).map((m, i) => {
      const [bg, fg, tag] = colors[i % colors.length]
      return { ...m, bg, fg, tag }
    }))
    setLoading(false)
  }

  async function toggleMethod(id, current) {
    await supabase.from('payment_methods').update({ is_active: !current }).eq('id', id)
    await loadData()
  }

  async function addMethod() {
    if (!form.method || !form.number) { setMsg('يرجى إدخال اسم الطريقة ورقم الحساب'); return }
    setSaving(true)
    setMsg('')
    const { error } = await supabase.from('payment_methods').insert({
      method: form.method,
      label: form.method,
      number: form.number,
      holder: form.holder || 'منصة سولني',
      is_active: true,
    })
    setSaving(false)
    if (error) { setMsg('خطأ: ' + error.message); return }
    setForm({ method: '', number: '', holder: '' })
    await loadData()
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1.3fr 1fr', gap: 18, maxWidth: 1100 }}>
      {/* Methods list */}
      <div className="card">
        <div className="flex justify-between items-center mb-14" style={{ marginBottom: 6 }}>
          <span className="card-title">طرق الدفع المفعّلة</span>
          <span style={{ fontSize: 11.5, color: 'var(--text3)' }}>تظهر للطلاب عند الدفع</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 11, marginTop: 16 }}>
          {methods.length === 0 && <div style={{ color: 'var(--text3)', fontSize: 13, textAlign: 'center', padding: '20px 0' }}>لا توجد طرق دفع بعد</div>}
          {methods.map(m => (
            <div key={m.id} style={{ display: 'flex', alignItems: 'center', gap: 13, border: '1px solid var(--border-table)', borderRadius: 13, padding: 14 }}>
              <span style={{ width: 46, height: 46, borderRadius: 11, background: m.bg, color: m.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 12, flexShrink: 0 }}>{m.tag}</span>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 13.5, fontWeight: 700 }}>{m.label || m.method}</div>
                <div style={{ fontSize: 12.5, color: 'var(--text2)', direction: 'ltr', textAlign: 'right' }}>{m.number}</div>
                <div style={{ fontSize: 10.5, color: 'var(--text3)' }}>المستفيد: {m.holder}</div>
              </div>
              <span className="badge" style={{ background: m.is_active ? '#D1FAE5' : '#F1F5F9', color: m.is_active ? '#065F46' : '#475569' }}>
                {m.is_active ? 'مفعّل' : 'معطّل'}
              </span>
              <div
                className="switch"
                style={{ background: m.is_active ? '#4F46E5' : '#C7CEE8', cursor: 'pointer' }}
                onClick={() => toggleMethod(m.id, m.is_active)}
              >
                <div className="switch-knob" style={{ [m.is_active ? 'left' : 'right']: 3 }} />
              </div>
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
          <button className="btn btn-primary" style={{ justifyContent: 'center', padding: 13, fontSize: 13.5 }} disabled={saving} onClick={addMethod}>
            {saving ? '…' : 'إضافة الطريقة'}
          </button>
        </div>
      </div>
    </div>
  )
}

