import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

const SUBJECTS = ['العربية','الفرنسية','الإنجليزية','الرياضيات','التاريخ و الجغرافيا','الفلسفة','العلوم الطبيعية','التربية الإسلامية','التربية المدنية']

export default function Courses({ onNavigate }) {
  const toast = useToast()
  const [rows, setRows]           = useState([])
  const [stats, setStats]         = useState({})
  const [loading, setLoading]     = useState(true)
  const [editModal, setEditModal]   = useState(null)   // course row being edited
  const [editForm, setEditForm]     = useState({})
  const [editSaving, setEditSaving] = useState(false)
  const [deleteId, setDeleteId]     = useState(null)   // id awaiting delete confirm
  const [toggleId, setToggleId]     = useState(null)   // id awaiting toggle confirm

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const [courseRes, subRes] = await Promise.all([
      supabase.from('courses').select('*, teacher:teacher_id(full_name), lessons:course_lessons(id)').order('created_at', { ascending: false }),
      supabase.from('subscriptions').select('course_id, status').eq('status', 'active'),
    ])

    const courses   = courseRes.data || []
    const activeSubs = subRes.data || []
    const subCountByCourse = {}
    activeSubs.forEach(s => { if (s.course_id) subCountByCourse[s.course_id] = (subCountByCourse[s.course_id] || 0) + 1 })

    setStats({
      total: courses.length,
      subs:  activeSubs.length,
      drafts: courses.filter(c => !c.is_active).length,
    })
    setRows(courses.map(c => ({ ...c, teacherName: c.teacher?.full_name || '—', lessonsCount: c.lessons?.length || 0, subsCount: subCountByCourse[c.id] || 0 })))
    setLoading(false)
  }

  async function toggleActive(id, current) {
    const { error } = await supabase.from('courses').update({ is_active: !current }).eq('id', id)
    setToggleId(null)
    if (error) {
      toast('خطأ في تغيير حالة الدورة: ' + error.message, 'error')
    } else {
      toast(current ? 'تم تحويل الدورة إلى مسودة' : 'تم نشر الدورة بنجاح', 'success')
      await loadData()
    }
  }

  function openEdit(c) {
    setEditForm({
      title:          c.title || '',
      description:    c.description || '',
      subject:        c.subject || '',
      price_monthly:  c.price_monthly != null  ? String(c.price_monthly)  : '',
      price_yearly:   c.price_yearly   != null  ? String(c.price_yearly)   : '',
      original_price: c.original_price != null  ? String(c.original_price) : '',
      rating:         c.rating         != null  ? String(c.rating)         : '',
      is_active:      c.is_active,
    })
    setEditModal(c)
  }

  async function saveEdit() {
    if (!editForm.title || !editForm.price_monthly) return
    setEditSaving(true)
    const { error } = await supabase.from('courses').update({
      title:          editForm.title,
      description:    editForm.description || null,
      subject:        editForm.subject || null,
      price_monthly:  parseFloat(editForm.price_monthly) || 0,
      price_yearly:   editForm.price_yearly   ? parseFloat(editForm.price_yearly)   : null,
      original_price: editForm.original_price ? parseFloat(editForm.original_price) : null,
      rating:         editForm.rating         ? parseFloat(editForm.rating)          : null,
      is_active:      editForm.is_active,
    }).eq('id', editModal.id)
    setEditSaving(false)
    if (error) {
      toast('خطأ في حفظ التعديلات: ' + error.message, 'error')
    } else {
      toast('تم حفظ تعديلات الدورة بنجاح', 'success')
      setEditModal(null)
      await loadData()
    }
  }

  async function deleteCourse(id) {
    // Check active subscriptions first
    const { data: activeSubs } = await supabase
      .from('subscriptions')
      .select('id')
      .eq('course_id', id)
      .eq('status', 'active')
      .limit(1)

    if (activeSubs?.length > 0) {
      toast('لا يمكن الحذف — يوجد مشتركون نشطون في هذه الدورة', 'error')
      setDeleteId(null)
      return
    }

    const { error } = await supabase.from('courses').delete().eq('id', id)
    setDeleteId(null)
    if (error) {
      toast('خطأ في حذف الدورة: ' + error.message, 'error')
    } else {
      toast('تم حذف الدورة بنجاح', 'success')
      await loadData()
    }
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div>
      {/* Stats + Add button */}
      <div className="flex justify-between items-center mb-18">
        <div className="flex gap-14">
          <div className="card-sm"><div className="text-muted" style={{ fontSize: 12 }}>إجمالي الدروس</div><div style={{ fontSize: 21, fontWeight: 700, marginTop: 2 }}>{stats.total}</div></div>
          <div className="card-sm"><div className="text-muted" style={{ fontSize: 12 }}>إجمالي المشتركين</div><div style={{ fontSize: 21, fontWeight: 700, color: '#059669', marginTop: 2 }}>{stats.subs}</div></div>
          <div className="card-sm"><div className="text-muted" style={{ fontSize: 12 }}>مسودّات</div><div style={{ fontSize: 21, fontWeight: 700, color: '#D97706', marginTop: 2 }}>{stats.drafts}</div></div>
        </div>
        <button className="btn btn-primary" onClick={() => onNavigate('addCourse')}>+ إضافة درس</button>
      </div>

      {/* Table */}
      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: '2fr 1.2fr 1fr 0.6fr 0.9fr 0.8fr 0.8fr 1.1fr' }}>
          <span>العنوان</span><span>الأستاذ</span><span>المستوى</span><span>دروس</span>
          <span>سعر/شهر</span><span>مشتركون</span><span>الحالة</span>
          <span style={{ textAlign: 'left' }}>إجراءات</span>
        </div>
        {rows.length === 0 && (
          <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>
            لا توجد دروس بعد.{' '}
            <span style={{ color: 'var(--primary)', cursor: 'pointer', fontWeight: 700 }} onClick={() => onNavigate('addCourse')}>
              أضف أول درس
            </span>
          </div>
        )}
        {rows.map(c => (
          <div key={c.id} className="table-row" style={{ gridTemplateColumns: '2fr 1.2fr 1fr 0.6fr 0.9fr 0.8fr 0.8fr 1.1fr' }}>
            <span className="fw-700">{c.title}</span>
            <span className="text-2">{c.teacherName}</span>
            <span className="text-2">{c.level || '—'}</span>
            <span className="text-2">{c.lessonsCount}</span>
            <span className="fw-700">{c.price_monthly?.toLocaleString('ar')}</span>
            <span className="fw-700 text-teal">{c.subsCount}</span>
            <span>
              {toggleId === c.id ? (
                <div style={{ display: 'flex', gap: 5, alignItems: 'center', flexWrap: 'wrap' }}>
                  <span style={{ fontSize: 11, color: 'var(--text2)', whiteSpace: 'nowrap' }}>تغيير؟</span>
                  <button
                    className="btn btn-sm"
                    style={{ padding: '2px 9px', fontSize: 11, background: 'var(--primary)', color: '#fff', border: 'none' }}
                    onClick={() => toggleActive(c.id, c.is_active)}
                  >نعم</button>
                  <button
                    className="btn btn-sm btn-secondary"
                    style={{ padding: '2px 8px', fontSize: 11 }}
                    onClick={() => setToggleId(null)}
                  >لا</button>
                </div>
              ) : (
                <span
                  className="badge"
                  style={{ background: c.is_active ? '#D1FAE5' : '#FEF3C7', color: c.is_active ? '#065F46' : '#92400E', cursor: 'pointer' }}
                  onClick={() => setToggleId(c.id)}
                >
                  {c.is_active ? 'منشور' : 'مسودة'}
                </span>
              )}
            </span>
            <span style={{ textAlign: 'left', display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
              {/* Edit button */}
              <button
                className="btn btn-sm btn-secondary"
                style={{ padding: '5px 12px', fontSize: 12 }}
                onClick={() => openEdit(c)}
              >
                ✏️ تعديل
              </button>
              {/* Delete button */}
              {deleteId === c.id ? (
                <div style={{ display: 'flex', gap: 5 }}>
                  <button
                    className="btn btn-sm"
                    style={{ padding: '5px 10px', fontSize: 12, background: '#DC2626', color: '#fff', border: 'none' }}
                    onClick={() => deleteCourse(c.id)}
                  >
                    تأكيد
                  </button>
                  <button
                    className="btn btn-sm btn-secondary"
                    style={{ padding: '5px 10px', fontSize: 12 }}
                    onClick={() => setDeleteId(null)}
                  >
                    إلغاء
                  </button>
                </div>
              ) : (
                <button
                  className="btn btn-sm"
                  style={{ padding: '5px 10px', fontSize: 12, background: '#FEF2F2', color: '#DC2626', border: '1px solid #FCA5A5' }}
                  onClick={() => setDeleteId(c.id)}
                >
                  🗑
                </button>
              )}
            </span>
          </div>
        ))}
      </div>

      {/* Edit modal */}
      {editModal && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.45)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, overflowY: 'auto', padding: 20 }}
          onClick={() => setEditModal(null)}
        >
          <div style={{ background: '#fff', borderRadius: 20, padding: 28, width: 520, maxWidth: '95vw', margin: 'auto' }} onClick={e => e.stopPropagation()}>
            <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 20, color: 'var(--text)' }}>تعديل الدورة</div>

            {/* Title */}
            <div className="field-label" style={{ marginBottom: 6 }}>العنوان *</div>
            <input
              className="field-input"
              style={{ marginBottom: 14 }}
              value={editForm.title}
              onChange={e => setEditForm(f => ({ ...f, title: e.target.value }))}
              placeholder="عنوان الدورة"
            />

            {/* Description */}
            <div className="field-label" style={{ marginBottom: 6 }}>الوصف</div>
            <textarea
              className="field-input"
              style={{ marginBottom: 14, resize: 'vertical' }}
              rows={2}
              value={editForm.description}
              onChange={e => setEditForm(f => ({ ...f, description: e.target.value }))}
              placeholder="وصف مختصر"
            />

            {/* Subject chips */}
            <div className="field-label" style={{ marginBottom: 8 }}>المادة</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 7, marginBottom: 16 }}>
              {SUBJECTS.map(s => (
                <span
                  key={s}
                  className={'chip' + (editForm.subject === s ? ' active' : '')}
                  style={{ fontSize: 12, padding: '5px 11px', cursor: 'pointer' }}
                  onClick={() => setEditForm(f => ({ ...f, subject: s }))}
                >
                  {s}
                </span>
              ))}
            </div>

            {/* Prices */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10, marginBottom: 14 }}>
              <div>
                <div className="field-label" style={{ marginBottom: 5 }}>سعر/شهر *</div>
                <input className="field-input" type="number" placeholder="1200" value={editForm.price_monthly} onChange={e => setEditForm(f => ({ ...f, price_monthly: e.target.value }))} />
              </div>
              <div>
                <div className="field-label" style={{ marginBottom: 5 }}>سعر/سنة</div>
                <input className="field-input" type="number" placeholder="11000" value={editForm.price_yearly} onChange={e => setEditForm(f => ({ ...f, price_yearly: e.target.value }))} />
              </div>
              <div>
                <div className="field-label" style={{ marginBottom: 5 }}>سعر مشطوب</div>
                <input className="field-input" type="number" placeholder="1600" value={editForm.original_price} onChange={e => setEditForm(f => ({ ...f, original_price: e.target.value }))} />
              </div>
            </div>

            {/* Rating + is_active */}
            <div style={{ display: 'flex', gap: 14, alignItems: 'center', marginBottom: 22 }}>
              <div style={{ flex: 1 }}>
                <div className="field-label" style={{ marginBottom: 5 }}>التقييم (0–5)</div>
                <input className="field-input" type="number" step="0.1" min="0" max="5" placeholder="4.8" value={editForm.rating} onChange={e => setEditForm(f => ({ ...f, rating: e.target.value }))} />
              </div>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', marginTop: 18 }}>
                <input
                  type="checkbox"
                  checked={editForm.is_active}
                  onChange={e => setEditForm(f => ({ ...f, is_active: e.target.checked }))}
                  style={{ width: 16, height: 16, accentColor: 'var(--primary)' }}
                />
                <span style={{ fontSize: 13, fontWeight: 600 }}>منشور (مرئي للطلاب)</span>
              </label>
            </div>

            {/* Actions */}
            <div style={{ display: 'flex', gap: 10 }}>
              <button
                className="btn btn-primary"
                style={{ flex: 1, justifyContent: 'center' }}
                disabled={editSaving || !editForm.title || !editForm.price_monthly}
                onClick={saveEdit}
              >
                {editSaving ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2 }} /> : '💾 حفظ التعديلات'}
              </button>
              <button className="btn btn-secondary" onClick={() => setEditModal(null)}>إلغاء</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
