import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

const SETTING_META = {
  session_commission_pct: {
    label: 'عمولة الجلسات',
    unit: '%',
    desc: 'نسبة العمولة المخصومة من كل جلسة مباشرة مؤكّدة',
    min: 0, max: 100,
    displayFn: v => `${v}% من كل جلسة`,
  },
  subscription_commission_pct: {
    label: 'عمولة الاشتراكات',
    unit: '%',
    desc: 'نسبة العمولة المخصومة من كل اشتراك في دورة أو باقة',
    min: 0, max: 100,
    displayFn: v => `${v}% من كل اشتراك`,
  },
}

const DEFAULTS = {
  session_commission_pct:      15,
  subscription_commission_pct: 15,
}

// Commission fields get a special accent color
const COMMISSION_KEYS = new Set(['session_commission_pct', 'subscription_commission_pct'])

export default function Policy() {
  const toast = useToast()
  const [values, setValues]   = useState(DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving]   = useState(false)

  useEffect(() => { loadSettings() }, [])

  async function loadSettings() {
    setLoading(true)
    const { data } = await supabase.rpc('get_system_settings')
    if (data) {
      const overrides = Object.fromEntries(
        data
          .filter(r => DEFAULTS[r.key] !== undefined)
          .map(r => [r.key, parseFloat(r.value)])
      )
      setValues(v => ({ ...v, ...overrides }))
    }
    setLoading(false)
  }

  async function handleSave() {
    setSaving(true)
    // Validate commission bounds
    if (values.session_commission_pct < 0 || values.session_commission_pct > 100 ||
        values.subscription_commission_pct < 0 || values.subscription_commission_pct > 100) {
      toast('نسبة العمولة يجب أن تكون بين 0 و 100', 'error')
      setSaving(false)
      return
    }
    const entries = Object.entries(values).map(([key, value]) => ({
      key, value: String(value),
    }))
    const { error } = await supabase.rpc('admin_upsert_settings', { p_entries: entries })
    setSaving(false)
    if (error) {
      toast('خطأ في الحفظ: ' + error.message, 'error')
    } else {
      toast('تم حفظ السياسات بنجاح ✓', 'success')
    }
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const commPct   = values.session_commission_pct ?? 15
  const subCommPct = values.subscription_commission_pct ?? 15

  return (
    <div style={{ maxWidth: 1000 }}>

      {/* ── Commission preview cards ─────────────────────────────── */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18, marginBottom: 18 }}>
        {/* Session commission preview */}
        <div className="card">
          <div className="flex items-center gap-10" style={{ marginBottom: 6 }}>
            <span style={{ width: 36, height: 36, borderRadius: 10, background: '#D7F2E6', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>💼</span>
            <span className="card-title">عمولة الجلسات الحالية</span>
          </div>
          <div style={{ fontSize: 12.5, color: 'var(--text3)', marginBottom: 14 }}>تُخصم من كل جلسة مباشرة مؤكّدة</div>
          <div className="flex items-center" style={{ alignItems: 'flex-end', gap: 4 }}>
            <span style={{ fontSize: 46, fontWeight: 700, color: 'var(--primary)' }}>{commPct}</span>
            <span style={{ fontSize: 20, fontWeight: 700, color: 'var(--primary)', paddingBottom: 9 }}>%</span>
          </div>
          <div style={{ background: '#F2F7F5', borderRadius: 11, padding: 13, fontSize: 12.5, color: 'var(--text2)', lineHeight: 1.7, marginTop: 12 }}>
            جلسة بـ <b style={{ color: 'var(--text)' }}>500 أوقية</b> ← عمولة <b style={{ color: 'var(--text)' }}>{Math.round(500 * commPct / 100)}</b> · صافي الأستاذ <b style={{ color: '#059669' }}>{Math.round(500 * (1 - commPct / 100))}</b>
          </div>
        </div>

        {/* Subscription commission preview */}
        <div className="card">
          <div className="flex items-center gap-10" style={{ marginBottom: 6 }}>
            <span style={{ width: 36, height: 36, borderRadius: 10, background: '#D7F2E6', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>📚</span>
            <span className="card-title">عمولة الاشتراكات الحالية</span>
          </div>
          <div style={{ fontSize: 12.5, color: 'var(--text3)', marginBottom: 14 }}>تُخصم من كل اشتراك في درس أو باقة</div>
          <div className="flex items-center" style={{ alignItems: 'flex-end', gap: 4 }}>
            <span style={{ fontSize: 46, fontWeight: 700, color: '#13A88A' }}>{subCommPct}</span>
            <span style={{ fontSize: 20, fontWeight: 700, color: '#13A88A', paddingBottom: 9 }}>%</span>
          </div>
          <div style={{ background: '#F2F7F5', borderRadius: 11, padding: 13, fontSize: 12.5, color: 'var(--text2)', lineHeight: 1.7, marginTop: 12 }}>
            اشتراك بـ <b style={{ color: 'var(--text)' }}>12,000 أوقية</b> ← عمولة <b style={{ color: 'var(--text)' }}>{(12000 * subCommPct / 100).toLocaleString('en-US')}</b> · صافي الأستاذ <b style={{ color: '#059669' }}>{(12000 * (1 - subCommPct / 100)).toLocaleString('en-US')}</b>
          </div>
        </div>
      </div>

      {/* ── Editable settings ────────────────────────────────────── */}
      <div className="card">
        <div className="card-title" style={{ marginBottom: 20 }}>جميع السياسات</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(210px, 1fr))', gap: 16, marginBottom: 24 }}>
          {Object.entries(SETTING_META).map(([key, meta]) => {
            const isComm  = COMMISSION_KEYS.has(key)
            const accent  = isComm ? (key === 'session_commission_pct' ? 'var(--primary)' : '#13A88A') : 'var(--primary)'
            return (
              <div key={key} style={{
                border: `1.5px solid ${isComm ? (key === 'session_commission_pct' ? '#CFE9E0' : '#B8E2D6') : 'var(--border-table)'}`,
                borderRadius: 12, padding: 16,
                background: isComm ? '#F7FAF9' : '#fff',
              }}>
                <div style={{ fontSize: 12.5, fontWeight: 700, marginBottom: 4, color: 'var(--text)', display: 'flex', alignItems: 'center', gap: 6 }}>
                  {isComm && <span style={{ fontSize: 14 }}>{key === 'session_commission_pct' ? '💼' : '📚'}</span>}
                  {meta.label}
                </div>
                <div style={{ fontSize: 11, color: 'var(--text3)', marginBottom: 12, lineHeight: 1.5 }}>{meta.desc}</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <input
                    type="number"
                    min={meta.min ?? 0}
                    max={meta.max}
                    value={values[key]}
                    onChange={e => setValues(v => ({ ...v, [key]: parseFloat(e.target.value) || 0 }))}
                    style={{
                      flex: 1, minWidth: 0,
                      padding: '8px 10px',
                      border: `1.5px solid ${isComm ? accent : 'var(--border)'}`,
                      borderRadius: 8,
                      fontSize: 15,
                      fontWeight: 700,
                      fontFamily: 'inherit',
                      color: accent,
                    }}
                  />
                  <span style={{ fontSize: 12, color: 'var(--text3)', whiteSpace: 'nowrap' }}>{meta.unit}</span>
                </div>
                <div style={{ marginTop: 8, fontSize: 11.5, color: '#059669', fontWeight: 700 }}>
                  ← {meta.displayFn(values[key])}
                </div>
              </div>
            )
          })}
        </div>

        <div style={{ background: '#FEF3C7', borderRadius: 10, padding: '10px 14px', marginBottom: 18, fontSize: 12, color: '#92400E' }}>
          ⚠ تغيير العمولة يؤثر على الحسابات الجديدة فقط — المعاملات السابقة لا تتأثر.
        </div>

        <button
          className="btn btn-primary"
          style={{ padding: '12px 32px', fontSize: 13.5 }}
          disabled={saving}
          onClick={handleSave}
        >
          {saving
            ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
            : '💾 حفظ السياسات'}
        </button>
      </div>
    </div>
  )
}
