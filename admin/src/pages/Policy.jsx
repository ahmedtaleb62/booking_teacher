import React, { useState } from 'react'

export default function Policy() {
  const [saved, setSaved] = useState(false)
  const [policies] = useState([
    { title: 'نافذة الإلغاء', value: '24 ساعة', desc: 'يحق للطالب الإلغاء قبل الموعد بـ 24 ساعة بدون غرامة' },
    { title: 'مهلة الدفع', value: '48 ساعة', desc: 'بعد قبول الطلب ينتهي بها وقت الدفع وإلا يُلغى' },
    { title: 'وقت رد الأستاذ', value: '24 ساعة', desc: 'أقصى مهلة لقبول أو رفض الطلب الجديد' },
    { title: 'الحد الأدنى للسعر', value: '200 أوقية', desc: 'أقل سعر مسموح به للجلسة الواحدة' },
  ])

  function handleSave() {
    setSaved(true)
    setTimeout(() => setSaved(false), 2500)
  }

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18, maxWidth: 1000 }}>
      {/* Session commission */}
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

      {/* Subscription commission */}
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

      {/* Operational policies */}
      <div className="card" style={{ gridColumn: '1/3' }}>
        <div className="card-title" style={{ marginBottom: 16 }}>سياسات التشغيل</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 14 }}>
          {policies.map((p, i) => (
            <div key={i} style={{ border: '1px solid var(--border-table)', borderRadius: 12, padding: 15 }}>
              <div style={{ fontSize: 12.5, fontWeight: 700, marginBottom: 6 }}>{p.title}</div>
              <div style={{ fontSize: 19, fontWeight: 700, color: 'var(--primary)' }}>{p.value}</div>
              <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 4, lineHeight: 1.5 }}>{p.desc}</div>
            </div>
          ))}
        </div>
        <div style={{ marginTop: 18 }}>
          <button className="btn btn-primary" style={{ padding: '12px 28px', fontSize: 13.5 }} onClick={handleSave}>
            {saved ? '✓ تم الحفظ' : 'حفظ السياسات'}
          </button>
        </div>
      </div>
    </div>
  )
}
