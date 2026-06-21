import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'

export default function Packages() {
  const [packages, setPackages] = useState([])
  const [loading, setLoading] = useState(true)
  const [showAdd, setShowAdd] = useState(false)
  const [form, setForm] = useState({ title: '', priceMonthly: '' })
  const [saving, setSaving] = useState(false)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const [pkgRes, subRes] = await Promise.all([
      supabase.from('packages').select('*, courses:package_courses(course_id, courses(title, subject))').order('created_at', { ascending: false }),
      supabase.from('subscriptions').select('package_id').eq('status', 'active'),
    ])

    const pkgs = pkgRes.data || []
    const subs = subRes.data || []
    const subCount = {}
    subs.forEach(s => { if (s.package_id) subCount[s.package_id] = (subCount[s.package_id] || 0) + 1 })

    const covers = ['#1B6B7A', '#7B61FF', '#1B9E77', '#C77A1A', '#2D6CDF']
    setPackages(pkgs.map((p, i) => ({
      ...p,
      cover: covers[i % covers.length],
      subsCount: subCount[p.id] || 0,
      subjects: [...new Set((p.courses || []).map(c => c.courses?.subject).filter(Boolean))].join(' · '),
      courseCount: (p.courses || []).length,
    })))
    setLoading(false)
  }

  async function addPackage() {
    if (!form.title || !form.priceMonthly) return
    setSaving(true)
    await supabase.from('packages').insert({ title: form.title, price_monthly: parseFloat(form.priceMonthly), is_active: true })
    setSaving(false)
    setShowAdd(false)
    setForm({ title: '', priceMonthly: '' })
    await loadData()
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div>
      <div className="flex justify-between items-center mb-16">
        <div />
        <button className="btn btn-primary" onClick={() => setShowAdd(true)}>+ إضافة باقة</button>
      </div>

      {packages.length === 0 && !showAdd && (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text3)' }}>
          <div style={{ fontSize: 48, marginBottom: 12 }}>📦</div>
          <div style={{ fontSize: 16, fontWeight: 700 }}>لا توجد باقات بعد</div>
          <div style={{ fontSize: 13, marginTop: 6 }}><span style={{ color: 'var(--primary)', cursor: 'pointer', fontWeight: 700 }} onClick={() => setShowAdd(true)}>أضف أول باقة</span></div>
        </div>
      )}

      <div className="grid-2">
        {packages.map(p => (
          <div key={p.id} style={{ background: '#fff', border: '1px solid var(--border)', borderRadius: 16, overflow: 'hidden' }}>
            <div style={{ background: p.cover, padding: 18, color: '#fff' }}>
              <div className="flex justify-between items-center" style={{ alignItems: 'flex-start' }}>
                <div style={{ fontSize: 17, fontWeight: 700 }}>{p.title}</div>
                <span style={{ background: 'rgba(255,255,255,.2)', fontSize: 10.5, fontWeight: 700, padding: '4px 9px', borderRadius: 999 }}>{p.courseCount} دروس</span>
              </div>
              <div style={{ fontSize: 12, color: 'rgba(255,255,255,.82)', marginTop: 8 }}>{p.subjects || 'مواد متعددة'}</div>
            </div>
            <div style={{ padding: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div><span style={{ fontSize: 19, fontWeight: 700 }}>{p.price_monthly?.toLocaleString('ar')}</span><span style={{ fontSize: 11, color: 'var(--text3)' }}> أوقية/شهر</span></div>
              <div style={{ textAlign: 'left' }}>
                <div style={{ fontSize: 18, fontWeight: 700, color: 'var(--primary)' }}>{p.subsCount}</div>
                <div style={{ fontSize: 11, color: 'var(--text3)' }}>مشترك</div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {showAdd && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.45)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }} onClick={() => setShowAdd(false)}>
          <div style={{ background: '#fff', borderRadius: 20, padding: 28, width: 420 }} onClick={e => e.stopPropagation()}>
            <div style={{ fontSize: 17, fontWeight: 700, marginBottom: 18 }}>إضافة باقة جديدة</div>
            <div style={{ marginBottom: 14 }}>
              <div className="field-label">اسم الباقة</div>
              <input className="field-input" placeholder="باقة العلوم الشاملة" value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} />
            </div>
            <div style={{ marginBottom: 22 }}>
              <div className="field-label">سعر/شهر (أوقية)</div>
              <input className="field-input" type="number" placeholder="12000" value={form.priceMonthly} onChange={e => setForm(f => ({ ...f, priceMonthly: e.target.value }))} />
            </div>
            <div className="flex gap-10">
              <button className="btn btn-primary" style={{ flex: 1, justifyContent: 'center' }} disabled={saving} onClick={addPackage}>{saving ? '…' : 'إضافة'}</button>
              <button className="btn btn-secondary" style={{ flex: 1, justifyContent: 'center' }} onClick={() => setShowAdd(false)}>إلغاء</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
