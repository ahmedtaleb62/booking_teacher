import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

const SETTING_META = {
  payment_timeout_minutes: {
    label: 'مهلة الدفع',
    unit: 'دقيقة',
    desc: 'بعد قبول الطلب، ينتهي فيها وقت إرسال إثبات الدفع وإلا يُلغى',
    displayFn: v => `${Math.round(v / 60)} ساعة`,
  },
  no_show_timeout_minutes: {
    label: 'مهلة الغياب',
    unit: 'دقيقة',
    desc: 'بعد وقت الجلسة، يُسجَّل غياب الأستاذ أو الطالب تلقائياً',
    displayFn: v => `${v} دقيقة`,
  },
  cancellation_window_hours: {
    label: 'نافذة الإلغاء',
    unit: 'ساعة',
    desc: 'يحق للطالب الإلغاء قبل الموعد بهذه المدة بدون غرامة',
    displayFn: v => `${v} ساعة`,
  },
  teacher_response_hours: {
    label: 'وقت رد الأستاذ',
    unit: 'ساعة',
    desc: 'أقصى مهلة لقبول أو رفض الطلب الجديد',
    displayFn: v => `${v} ساعة`,
  },
  min_session_price: {
    label: 'الحد الأدنى للسعر',
    unit: 'أوقية',
    desc: 'أقل سعر مسموح به للجلسة الواحدة',
    displayFn: v => `${v} أوقية`,
  },
}

const DEFAULTS = {
  payment_timeout_minutes:   2880,
  no_show_timeout_minutes:   15,
  cancellation_window_hours: 24,
  teacher_response_hours:    24,
  min_session_price:         200,
}

export default function Policy() {
  const toast = useToast()
  const [values, setValues]   = useState(DEFAULTS)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving]   = useState(false)

  useEffect(() => { loadSettings() }, [])

  async function loadSettings() {
    setLoading(true)
    const { data } = await supabase.from('system_settings').select('key, value')
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
    const entries = Object.entries(values).map(([key, value]) => ({
      key, value: String(value),
    }))
    for (const entry of entries) {
      const { error } = await supabase
        .from('system_settings')
        .upsert(entry, { onConflict: 'key' })
      if (error) {
        toast('خطأ في الحفظ: ' + error.message, 'error')
        setSaving(false)
        return
      }
    }
    setSaving(false)
    toast('تم حفظ السياسات بنجاح ✓', 'success')
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18, maxWidth: 1000 }}>
      {/* Session commission — display only */}
      <div className="card">
        <div className="flex items-center gap-10 mb-14" style={{ marginBottom: 6 }}>
          <span style={{ width: 36, height: 36, borderRadius: 10, background: '#E0E7FF', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>💼</span>
          <span className="card-title">عمولة الجلسات</span>
        </div>
        <div style={{ fontSize: 12.5, color: 'var(--text3)', marginBottom: 18 }}>تُخصم من كل جلسة مباشرة مؤكّدة</div>
        <div className="flex items-center gap-8" style={{ alignItems: 'flex-end', gap: 5 }}>
          <span style={{ fontSize: 46, fontWeight: 700, color: 'var(--primary)' }}>15</span>
          <span style={{ fontSize: 20, fontWeight: 700, color: 'var(--primary)', paddingBottom: 9 }}>%</span>
        </div>
        <div style={{ height: 6, background: '#E6E9ED', borderRadius: 3, position: 'relative', margin: '16px 4px 18px' }}>
          <div style={{ position: 'absolute', right: 0, width: '30%', top: 0, bottom: 0, background: 'var(--primary)', borderRadius: 3 }} />
          <span style={{ position: 'absolute', right: '30%', top: '50%', transform: 'translate(50%,-50%)', width: 20, height: 20, borderRadius: '50%', background: '#fff', border: '3px solid var(--primary)', boxShadow: '0 2px 6px rgba(0,0,0,.15)', display: 'block' }} />
        </div>
        <div style={{ background: '#F5F7FF', borderRadius: 11, padding: 13, fontSize: 12.5, color: 'var(--text2)', lineHeight: 1.7 }}>
          جلسة بـ <b style={{ color: 'var(--text)' }}>500 أوقية</b> ← عمولة <b style={{ color: 'var(--text)' }}>75</b> · صافي الأستاذ <b style={{ color: '#059669' }}>425</b>.
        </div>
      </div>

      {/* Subscription commission — display only */}
      <div className="card">
        <div className="flex items-center gap-10 mb-14" style={{ marginBottom: 6 }}>
          <span style={{ width: 36, height: 36, borderRadius: 10, background: '#EDE9FE', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>📚</span>
          <span className="card-title">عمولة الاشتراكات في الدروس</span>
        </div>
        <div style={{ fontSize: 12.5, color: 'var(--text3)', marginBottom: 18 }}>تُخصم من كل اشتراك في درس أو باقة</div>
        <div className="flex items-center gap-8" style={{ alignItems: 'flex-end', gap: 5 }}>
          <span style={{ fontSize: 46, fontWeight: 700, color: '#7C3AED' }}>20</span>
          <span style={{ fontSize: 20, fontWeight: 700, color: '#7C3AED', paddingBottom: 9 }}>%</span>
        </div>
        <div style={{ height: 6, background: '#E6E9ED', borderRadius: 3, position: 'relative', margin: '16px 4px 18px' }}>
          <div style={{ position: 'absolute', right: 0, width: '40%', top: 0, bottom: 0, background: '#7C3AED', borderRadius: 3 }} />
          <span style={{ position: 'absolute', right: '40%', top: '50%', transform: 'translate(50%,-50%)', width: 20, height: 20, borderRadius: '50%', background: '#fff', border: '3px solid #7C3AED', boxShadow: '0 2px 6px rgba(0,0,0,.15)', display: 'block' }} />
        </div>
        <div style={{ background: '#F5F7FF', borderRadius: 11, padding: 13, fontSize: 12.5, color: 'var(--text2)', lineHeight: 1.7 }}>
          اشتراك بـ <b style={{ color: 'var(--text)' }}>12,000 أوقية</b> ← عمولة <b style={{ color: 'var(--text)' }}>2,400</b> · صافي الأستاذ <b style={{ color: '#059669' }}>9,600</b>.
        </div>
      </div>

      {/* Editable operational settings */}
      <div className="card" style={{ gridColumn: '1/3' }}>
        <div className="card-title" style={{ marginBottom: 20 }}>سياسات التشغيل</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(210px, 1fr))', gap: 16, marginBottom: 24 }}>
          {Object.entries(SETTING_META).map(([key, meta]) => (
            <div key={key} style={{ border: '1px solid var(--border-table)', borderRadius: 12, padding: 16 }}>
              <div style={{ fontSize: 12.5, fontWeight: 700, marginBottom: 4, color: 'var(--text)' }}>{meta.label}</div>
              <div style={{ fontSize: 11, color: 'var(--text3)', marginBottom: 12, lineHeight: 1.5 }}>{meta.desc}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <input
                  type="number"
                  min="0"
                  value={values[key]}
                  onChange={e => setValues(v => ({ ...v, [key]: parseFloat(e.target.value) || 0 }))}
                  style={{
                    flex: 1, minWidth: 0,
                    padding: '8px 10px',
                    border: '1.5px solid var(--border)',
                    borderRadius: 8,
                    fontSize: 15,
                    fontWeight: 700,
                    fontFamily: 'inherit',
                    color: 'var(--primary)',
                  }}
                />
                <span style={{ fontSize: 12, color: 'var(--text3)', whiteSpace: 'nowrap' }}>{meta.unit}</span>
              </div>
              <div style={{ marginTop: 8, fontSize: 11.5, color: '#059669', fontWeight: 700 }}>
                ← {meta.displayFn(values[key])}
              </div>
            </div>
          ))}
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
