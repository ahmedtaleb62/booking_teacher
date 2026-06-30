import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'
import ConfirmModal from '../components/ConfirmModal'

const COVERS = ['#1B6B7A', '#7B61FF', '#1B9E77', '#C77A1A', '#2D6CDF']

function CourseSelector({ selected, onChange, courses }) {
  const toggle = id => onChange(
    selected.includes(id) ? selected.filter(x => x !== id) : [...selected, id]
  )
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 7, maxHeight: 260, overflowY: 'auto', padding: '2px 2px 2px 0' }}>
      {courses.length === 0 && (
        <div style={{ color: 'var(--text3)', fontSize: 13, textAlign: 'center', padding: '16px 0' }}>لا توجد دروس منشورة بعد</div>
      )}
      {courses.map(c => {
        const sel = selected.includes(c.id)
        return (
          <div
            key={c.id}
            onClick={() => toggle(c.id)}
            style={{
              display: 'flex', alignItems: 'center', gap: 11, padding: '10px 13px',
              border: '1.5px solid ' + (sel ? 'var(--primary)' : '#E8EDF1'),
              borderRadius: 11, cursor: 'pointer',
              background: sel ? 'var(--primary-light)' : '#FAFBFC',
              transition: 'all .12s',
            }}
          >
            <div style={{
              width: 20, height: 20, borderRadius: 6, border: '2px solid ' + (sel ? 'var(--primary)' : '#CBD5E0'),
              background: sel ? 'var(--primary)' : '#fff', flexShrink: 0,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              {sel && <span style={{ color: '#fff', fontSize: 12, lineHeight: 1 }}>✓</span>}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: sel ? 'var(--primary)' : 'var(--text)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {c.title}
              </div>
              <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 1 }}>
                {c.subject} · {c.level} · {c.total_lessons || 0} درس
              </div>
            </div>
            <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--primary)', flexShrink: 0 }}>
              {c.price_monthly?.toLocaleString('en-US')} أوقية
            </div>
          </div>
        )
      })}
    </div>
  )
}

export default function Packages() {
  const toast = useToast()
  const [packages, setPackages]         = useState([])
  const [allCourses, setAllCourses]     = useState([])
  const [loading, setLoading]           = useState(true)
  const [showAdd, setShowAdd]           = useState(false)
  const [form, setForm]                 = useState({ title: '', priceYearly: '', originalPrice: '', courseIds: [], isFree: false })
  const [saving, setSaving]             = useState(false)
  const [editTarget, setEditTarget]     = useState(null)
  const [deleteTarget, setDeleteTarget] = useState(null)
  const [deleting, setDeleting]         = useState(false)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const [pkgRes, subRes, courseRes] = await Promise.all([
      supabase.from('packages').select('*, courses:package_courses(course_id, courses(title, subject))').order('created_at', { ascending: false }),
      supabase.from('subscriptions').select('package_id').eq('status', 'active'),
      supabase.from('courses').select('id, title, subject, level, price_monthly, total_lessons').eq('is_active', true).order('title'),
    ])

    const pkgs = pkgRes.data || []
    const subs = subRes.data || []
    const subCount = {}
    subs.forEach(s => { if (s.package_id) subCount[s.package_id] = (subCount[s.package_id] || 0) + 1 })

    setAllCourses(courseRes.data || [])
    setPackages(pkgs.map((p, i) => ({
      ...p,
      cover:       COVERS[i % COVERS.length],
      subsCount:   subCount[p.id] || 0,
      subjects:    [...new Set((p.courses || []).map(c => c.courses?.subject).filter(Boolean))].join(' · '),
      courseCount: (p.courses || []).length,
      courseIds:   (p.courses || []).map(c => c.course_id),
    })))
    setLoading(false)
  }

  async function addPackage() {
    if (!form.title || (!form.isFree && !form.priceYearly)) return
    setSaving(true)
    const yearly = form.isFree ? 0 : parseFloat(form.priceYearly)
    const { data: pkg, error } = await supabase.from('packages').insert({
      title:          form.title,
      price_monthly:  yearly,
      price_yearly:   form.isFree ? null : yearly,
      original_price: form.isFree ? null : (form.originalPrice ? parseFloat(form.originalPrice) : null),
      is_active:      true,
    }).select().single()
    if (error) { toast('خطأ في الإضافة: ' + error.message, 'error'); setSaving(false); return }

    if (form.courseIds.length > 0) {
      const rows = form.courseIds.map(cid => ({ package_id: pkg.id, course_id: cid }))
      const { error: pcErr } = await supabase.from('package_courses').insert(rows)
      if (pcErr) { toast('تمت إضافة الباقة لكن فشل ربط الدروس: ' + pcErr.message, 'error'); setSaving(false); return }
    }

    try {
      await supabase.rpc('send_admin_notification', {
        p_target_type: 'students',
        p_title: 'باقة جديدة متاحة 🎁',
        p_body:  form.title || 'تحقق من الباقات الجديدة',
        p_type:  'NEW_PACKAGE',
      })
    } catch (_) {}

    setSaving(false)
    setShowAdd(false)
    setForm({ title: '', priceYearly: '', originalPrice: '', courseIds: [], isFree: false })
    toast('تمت إضافة الباقة بنجاح', 'success')
    await loadData()
  }

  function openEdit(p) {
    const free = p.price_monthly === 0
    setEditTarget({
      id:           p.id,
      title:        p.title,
      isFree:       free,
      priceYearly:  !free && p.price_yearly != null ? String(p.price_yearly) : '',
      originalPrice:!free && p.original_price != null ? String(p.original_price) : '',
      courseIds:    p.courseIds || [],
    })
  }

  async function saveEdit() {
    if (!editTarget.title || (!editTarget.isFree && !editTarget.priceYearly)) return
    setSaving(true)
    const yearly = editTarget.isFree ? 0 : parseFloat(editTarget.priceYearly)
    const { error: updErr } = await supabase.from('packages').update({
      title:          editTarget.title,
      price_monthly:  yearly,
      price_yearly:   editTarget.isFree ? null : yearly,
      original_price: editTarget.isFree ? null : (editTarget.originalPrice ? parseFloat(editTarget.originalPrice) : null),
    }).eq('id', editTarget.id)
    if (updErr) { toast('خطأ في التعديل: ' + updErr.message, 'error'); setSaving(false); return }

    // Replace course assignments
    await supabase.from('package_courses').delete().eq('package_id', editTarget.id)
    if (editTarget.courseIds.length > 0) {
      const rows = editTarget.courseIds.map(cid => ({ package_id: editTarget.id, course_id: cid }))
      const { error: pcErr } = await supabase.from('package_courses').insert(rows)
      if (pcErr) { toast('تم حفظ الباقة لكن فشل تحديث الدروس: ' + pcErr.message, 'error') }
    }

    setSaving(false)
    setEditTarget(null)
    toast('تم تعديل الباقة بنجاح', 'success')
    await loadData()
  }

  async function deletePackage() {
    setDeleting(true)
    const { data: active } = await supabase
      .from('subscriptions').select('id')
      .eq('package_id', deleteTarget.id).eq('status', 'active').limit(1)
    if (active?.length) {
      toast('لا يمكن الحذف — يوجد مشتركون نشطون في هذه الباقة', 'error')
      setDeleting(false); setDeleteTarget(null); return
    }
    const { error } = await supabase.from('packages').delete().eq('id', deleteTarget.id)
    setDeleting(false); setDeleteTarget(null)
    if (error) { toast('خطأ في الحذف: ' + error.message, 'error'); return }
    toast('تم حذف الباقة', 'success')
    await loadData()
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div>
      <div className="flex justify-between items-center mb-16">
        <div style={{ fontSize: 13, color: 'var(--text3)' }}>{packages.length} باقة</div>
        <button className="btn btn-primary" onClick={() => setShowAdd(true)}>+ إضافة باقة</button>
      </div>

      {packages.length === 0 && !showAdd && (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text3)' }}>
          <div style={{ fontSize: 48, marginBottom: 12 }}>📦</div>
          <div style={{ fontSize: 16, fontWeight: 700 }}>لا توجد باقات بعد</div>
          <div style={{ fontSize: 13, marginTop: 6 }}>
            <span style={{ color: 'var(--primary)', cursor: 'pointer', fontWeight: 700 }} onClick={() => setShowAdd(true)}>أضف أول باقة</span>
          </div>
        </div>
      )}

      <div className="grid-2">
        {packages.map(p => (
          <div key={p.id} style={{ background: '#fff', border: '1px solid var(--border)', borderRadius: 16, overflow: 'hidden' }}>
            <div style={{ background: p.cover, padding: 18, color: '#fff' }}>
              <div className="flex justify-between items-center" style={{ alignItems: 'flex-start' }}>
                <div style={{ fontSize: 17, fontWeight: 700 }}>{p.title}</div>
                <span style={{ background: 'rgba(255,255,255,.2)', fontSize: 10.5, fontWeight: 700, padding: '4px 9px', borderRadius: 999 }}>
                  {p.courseCount} دروس
                </span>
              </div>
              <div style={{ fontSize: 12, color: 'rgba(255,255,255,.82)', marginTop: 8 }}>{p.subjects || 'مواد متعددة'}</div>
            </div>
            <div style={{ padding: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
                <div>
                  {p.price_monthly === 0 ? (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                      <span style={{ fontSize: 19, fontWeight: 700, color: '#15805F' }}>مجاني</span>
                      <span style={{ fontSize: 15 }}>🎁</span>
                    </div>
                  ) : (<>
                    {p.original_price && (
                      <div style={{ fontSize: 11, color: '#B0BEC5', textDecoration: 'line-through', marginBottom: 1 }}>
                        {p.original_price?.toLocaleString('en-US')} أوقية
                      </div>
                    )}
                    <div>
                      <span style={{ fontSize: 19, fontWeight: 700 }}>{(p.price_yearly ?? p.price_monthly)?.toLocaleString('en-US')}</span>
                      <span style={{ fontSize: 11, color: 'var(--text3)' }}> أوقية/سنة</span>
                    </div>
                  </>)}
                </div>
                <div style={{ textAlign: 'left' }}>
                  <div style={{ fontSize: 18, fontWeight: 700, color: 'var(--primary)' }}>{p.subsCount}</div>
                  <div style={{ fontSize: 11, color: 'var(--text3)' }}>مشترك</div>
                </div>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button
                  className="btn btn-sm btn-secondary"
                  style={{ flex: 1, justifyContent: 'center', fontSize: 12.5 }}
                  onClick={() => openEdit(p)}
                >
                  ✏️ تعديل
                </button>
                <button
                  className="btn btn-sm"
                  style={{ padding: '6px 12px', fontSize: 12, background: '#FBE0DB', color: '#A12B1D', border: '1px solid #F3C5BD' }}
                  onClick={() => setDeleteTarget({ id: p.id, title: p.title })}
                >
                  🗑
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* ── Add modal ───────────────────────────────── */}
      {showAdd && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: 20, overflowY: 'auto' }}
          onClick={() => setShowAdd(false)}
        >
          <div style={{ background: '#fff', borderRadius: 20, padding: 28, width: 560, maxWidth: '95vw', margin: 'auto' }} onClick={e => e.stopPropagation()}>
            <div style={{ fontSize: 17, fontWeight: 700, marginBottom: 20 }}>إضافة باقة جديدة</div>

            <div style={{ marginBottom: 6 }}>
              <div className="field-label" style={{ marginBottom: 6 }}>اسم الباقة *</div>
              <input className="field-input" placeholder="باقة العلوم الشاملة" value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} />
            </div>

            {/* Free toggle */}
            <div
              onClick={() => setForm(f => ({ ...f, isFree: !f.isFree, priceYearly: '', originalPrice: '' }))}
              style={{ display:'flex', alignItems:'center', gap:12, padding:'13px 15px', borderRadius:11, border:'2px solid '+(form.isFree?'#1B9E77':'#E1E5E9'), background:form.isFree?'#F0FBF7':'#FAFBFC', cursor:'pointer', marginBottom:14, marginTop:10, transition:'all .15s' }}
            >
              <div style={{ width:42, height:24, borderRadius:12, background:form.isFree?'#1B9E77':'#C9D3DC', position:'relative', transition:'background .2s', flexShrink:0 }}>
                <div style={{ position:'absolute', top:3, right:form.isFree?3:undefined, left:form.isFree?undefined:3, width:18, height:18, borderRadius:'50%', background:'#fff', transition:'all .2s', boxShadow:'0 1px 3px rgba(0,0,0,.2)' }} />
              </div>
              <div>
                <div style={{ fontSize:13, fontWeight:700, color:form.isFree?'#15805F':'var(--text)' }}>مجاني بالكامل 🎁</div>
                <div style={{ fontSize:11, color:'var(--text3)', marginTop:2 }}>الطلاب يشاهدون الدروس دون اشتراك</div>
              </div>
            </div>

            {!form.isFree && (
              <>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 20 }}>
                  <div>
                    <div className="field-label" style={{ marginBottom: 6 }}>السعر السنوي * (أوقية)</div>
                    <input className="field-input" type="number" placeholder="110000" value={form.priceYearly} onChange={e => setForm(f => ({ ...f, priceYearly: e.target.value }))} />
                  </div>
                  <div>
                    <div className="field-label" style={{ marginBottom: 6 }}>سعر الخصم المشطوب</div>
                    <input className="field-input" type="number" placeholder="15000" value={form.originalPrice} onChange={e => setForm(f => ({ ...f, originalPrice: e.target.value }))} />
                  </div>
                </div>
                {(form.priceYearly || form.originalPrice) && (
                  <div style={{ background: '#F7F9FA', borderRadius: 10, padding: '9px 13px', marginBottom: 16, fontSize: 12.5 }}>
                    <span style={{ fontSize: 10.5, color: 'var(--text3)', fontWeight: 700, marginBottom: 4, display: 'block' }}>معاينة السعر</span>
                    <div style={{ display: 'flex', gap: 10, alignItems: 'baseline', flexWrap: 'wrap' }}>
                      {form.originalPrice && <span style={{ color: '#B0BEC5', textDecoration: 'line-through' }}>{Number(form.originalPrice).toLocaleString('en-US')} أوقية</span>}
                      {form.priceYearly && <span style={{ fontWeight: 700, color: 'var(--primary)', fontSize: 16 }}>{Number(form.priceYearly).toLocaleString('en-US')} أوقية<span style={{ fontSize: 10.5, fontWeight: 400 }}>/سنة</span></span>}
                    </div>
                    {form.originalPrice && form.priceYearly && (
                      <div style={{ fontSize: 11, fontWeight: 700, color: '#1B9E77', marginTop: 4 }}>
                        🏷 خصم {Math.round((1 - parseFloat(form.priceYearly) / parseFloat(form.originalPrice)) * 100)}%
                      </div>
                    )}
                  </div>
                )}
              </>
            )}

            <div className="field-label" style={{ marginBottom: 10 }}>
              الدروس المضمّنة في الباقة
              {form.courseIds.length > 0 && (
                <span style={{ marginRight: 8, padding: '2px 9px', borderRadius: 999, background: 'var(--primary)', color: '#fff', fontSize: 11, fontWeight: 700 }}>
                  {form.courseIds.length} محدد
                </span>
              )}
            </div>
            <CourseSelector
              selected={form.courseIds}
              onChange={ids => setForm(f => ({ ...f, courseIds: ids }))}
              courses={allCourses}
            />

            <div style={{ display: 'flex', gap: 10, marginTop: 20 }}>
              <button className="btn btn-primary" style={{ flex: 1, justifyContent: 'center' }} disabled={saving || !form.title || !form.priceYearly} onClick={addPackage}>
                {saving ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : '+ إضافة الباقة'}
              </button>
              <button className="btn btn-secondary" onClick={() => setShowAdd(false)}>إلغاء</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Edit modal ──────────────────────────────── */}
      {editTarget && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: 20, overflowY: 'auto' }}
          onClick={() => setEditTarget(null)}
        >
          <div style={{ background: '#fff', borderRadius: 20, padding: 28, width: 560, maxWidth: '95vw', margin: 'auto' }} onClick={e => e.stopPropagation()}>
            <div style={{ fontSize: 17, fontWeight: 700, marginBottom: 20 }}>تعديل الباقة</div>

            <div style={{ marginBottom: 6 }}>
              <div className="field-label" style={{ marginBottom: 6 }}>اسم الباقة *</div>
              <input className="field-input" value={editTarget.title} onChange={e => setEditTarget(t => ({ ...t, title: e.target.value }))} />
            </div>

            {/* Free toggle */}
            <div
              onClick={() => setEditTarget(t => ({ ...t, isFree: !t.isFree, priceYearly: '', originalPrice: '' }))}
              style={{ display:'flex', alignItems:'center', gap:12, padding:'13px 15px', borderRadius:11, border:'2px solid '+(editTarget.isFree?'#1B9E77':'#E1E5E9'), background:editTarget.isFree?'#F0FBF7':'#FAFBFC', cursor:'pointer', marginBottom:14, marginTop:10, transition:'all .15s' }}
            >
              <div style={{ width:42, height:24, borderRadius:12, background:editTarget.isFree?'#1B9E77':'#C9D3DC', position:'relative', transition:'background .2s', flexShrink:0 }}>
                <div style={{ position:'absolute', top:3, right:editTarget.isFree?3:undefined, left:editTarget.isFree?undefined:3, width:18, height:18, borderRadius:'50%', background:'#fff', transition:'all .2s', boxShadow:'0 1px 3px rgba(0,0,0,.2)' }} />
              </div>
              <div>
                <div style={{ fontSize:13, fontWeight:700, color:editTarget.isFree?'#15805F':'var(--text)' }}>مجاني بالكامل 🎁</div>
                <div style={{ fontSize:11, color:'var(--text3)', marginTop:2 }}>الطلاب يشاهدون الدروس دون اشتراك</div>
              </div>
            </div>

            {!editTarget.isFree && (
              <>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
                  <div>
                    <div className="field-label" style={{ marginBottom: 6 }}>السعر السنوي * (أوقية)</div>
                    <input className="field-input" type="number" placeholder="110000" value={editTarget.priceYearly} onChange={e => setEditTarget(t => ({ ...t, priceYearly: e.target.value }))} />
                  </div>
                  <div>
                    <div className="field-label" style={{ marginBottom: 6 }}>سعر الخصم المشطوب</div>
                    <input className="field-input" type="number" placeholder="15000" value={editTarget.originalPrice} onChange={e => setEditTarget(t => ({ ...t, originalPrice: e.target.value }))} />
                  </div>
                </div>
                {(editTarget.priceYearly || editTarget.originalPrice) && (
                  <div style={{ background: '#F7F9FA', borderRadius: 10, padding: '9px 13px', marginBottom: 16, fontSize: 12.5 }}>
                    <span style={{ fontSize: 10.5, color: 'var(--text3)', fontWeight: 700, marginBottom: 4, display: 'block' }}>معاينة السعر</span>
                    <div style={{ display: 'flex', gap: 10, alignItems: 'baseline', flexWrap: 'wrap' }}>
                      {editTarget.originalPrice && <span style={{ color: '#B0BEC5', textDecoration: 'line-through' }}>{Number(editTarget.originalPrice).toLocaleString('en-US')} أوقية</span>}
                      {editTarget.priceYearly && <span style={{ fontWeight: 700, color: 'var(--primary)', fontSize: 16 }}>{Number(editTarget.priceYearly).toLocaleString('en-US')} أوقية<span style={{ fontSize: 10.5, fontWeight: 400 }}>/سنة</span></span>}
                    </div>
                    {editTarget.originalPrice && editTarget.priceYearly && (
                      <div style={{ fontSize: 11, fontWeight: 700, color: '#1B9E77', marginTop: 4 }}>
                        🏷 خصم {Math.round((1 - parseFloat(editTarget.priceYearly) / parseFloat(editTarget.originalPrice)) * 100)}%
                      </div>
                    )}
                  </div>
                )}
              </>
            )}

            <div className="field-label" style={{ marginBottom: 10 }}>
              الدروس المضمّنة في الباقة
              {editTarget.courseIds.length > 0 && (
                <span style={{ marginRight: 8, padding: '2px 9px', borderRadius: 999, background: 'var(--primary)', color: '#fff', fontSize: 11, fontWeight: 700 }}>
                  {editTarget.courseIds.length} محدد
                </span>
              )}
            </div>
            <CourseSelector
              selected={editTarget.courseIds}
              onChange={ids => setEditTarget(t => ({ ...t, courseIds: ids }))}
              courses={allCourses}
            />

            <div style={{ display: 'flex', gap: 10, marginTop: 20 }}>
              <button className="btn btn-primary" style={{ flex: 1, justifyContent: 'center' }} disabled={saving || !editTarget.title || (!editTarget.isFree && !editTarget.priceYearly)} onClick={saveEdit}>
                {saving ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : '💾 حفظ التعديلات'}
              </button>
              <button className="btn btn-secondary" onClick={() => setEditTarget(null)}>إلغاء</button>
            </div>
          </div>
        </div>
      )}

      {/* Delete confirm */}
      <ConfirmModal
        open={!!deleteTarget}
        danger
        title={`حذف باقة "${deleteTarget?.title}"`}
        message="سيتم حذف الباقة نهائياً. لا يمكن حذف باقة يوجد فيها مشتركون نشطون."
        confirm="حذف الباقة"
        cancel="إلغاء"
        loading={deleting}
        onConfirm={deletePackage}
        onCancel={() => !deleting && setDeleteTarget(null)}
      />
    </div>
  )
}
