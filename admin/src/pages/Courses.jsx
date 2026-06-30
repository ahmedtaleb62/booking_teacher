import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

const COLS = '2fr 1.2fr 1fr 0.6fr 0.9fr 0.9fr 0.8fr 0.8fr 0.9fr'

export default function Courses({ onNavigate }) {
  const toast = useToast()
  const [rows, setRows]       = useState([])
  const [stats, setStats]     = useState({})
  const [loading, setLoading] = useState(true)
  const [deleteId, setDeleteId] = useState(null)
  const [toggleId, setToggleId] = useState(null)

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const [courseRes, subRes] = await Promise.all([
      supabase.from('courses')
        .select('*, teacher:teacher_id(full_name), lessons:course_lessons(id)')
        .order('created_at', { ascending: false }),
      supabase.from('subscriptions').select('course_id, status').eq('status', 'active'),
    ])

    const courses    = courseRes.data || []
    const activeSubs = subRes.data || []
    const subCountByCourse = {}
    activeSubs.forEach(s => {
      if (s.course_id) subCountByCourse[s.course_id] = (subCountByCourse[s.course_id] || 0) + 1
    })

    setStats({
      total:  courses.length,
      subs:   activeSubs.length,
      drafts: courses.filter(c => !c.is_active).length,
    })
    setRows(courses.map(c => ({
      ...c,
      teacherName:  c.teacher?.full_name || '—',
      lessonsCount: c.lessons?.length || 0,
      subsCount:    subCountByCourse[c.id] || 0,
    })))
    setLoading(false)
  }

  async function toggleActive(id, current) {
    const course = rows.find(r => r.id === id)
    const { error } = await supabase.from('courses').update({ is_active: !current }).eq('id', id)
    setToggleId(null)
    if (error) {
      toast('خطأ في تغيير حالة الدورة: ' + error.message, 'error')
    } else {
      if (!current && course) {
        await supabase.functions.invoke('notify-broadcast', {
          body: {
            role:  'student',
            title: 'درس جديد متاح 📖',
            body:  course.title || 'تحقق من الدروس الجديدة',
            data:  { type: 'NEW_COURSE', course_id: id },
          },
        }).catch(() => {})
        // Insert into notifications so students see it in their list + get Realtime banner.
        // The push trigger skips FCM for NEW_COURSE (notify-broadcast already sent it).
        await supabase.rpc('send_admin_notification', {
          p_target_type: 'students',
          p_title: 'درس جديد متاح 📖',
          p_body:  course.title || 'تحقق من الدروس الجديدة',
          p_type:  'NEW_COURSE',
        }).catch(() => {})
      }
      toast(current ? 'تم تحويل الدورة إلى مسودة' : 'تم نشر الدورة بنجاح', 'success')
      await loadData()
    }
  }

  async function deleteCourse(id) {
    const { data: activeSubs } = await supabase
      .from('subscriptions').select('id')
      .eq('course_id', id).eq('status', 'active').limit(1)

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

  const fmt = n => n != null ? n.toLocaleString('en-US') : '—'

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  return (
    <div>
      {/* Stats + Add */}
      <div className="flex justify-between items-center mb-18">
        <div className="flex gap-14">
          <div className="card-sm">
            <div className="text-muted" style={{ fontSize: 12 }}>إجمالي الدروس</div>
            <div style={{ fontSize: 21, fontWeight: 700, marginTop: 2 }}>{stats.total}</div>
          </div>
          <div className="card-sm">
            <div className="text-muted" style={{ fontSize: 12 }}>إجمالي المشتركين</div>
            <div style={{ fontSize: 21, fontWeight: 700, color: '#059669', marginTop: 2 }}>{stats.subs}</div>
          </div>
          <div className="card-sm">
            <div className="text-muted" style={{ fontSize: 12 }}>مسودّات</div>
            <div style={{ fontSize: 21, fontWeight: 700, color: '#D97706', marginTop: 2 }}>{stats.drafts}</div>
          </div>
        </div>
        <button className="btn btn-primary" onClick={() => onNavigate('addCourse')}>+ إضافة درس</button>
      </div>

      {/* Table */}
      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: COLS }}>
          <span>العنوان</span>
          <span>الأستاذ</span>
          <span>المستوى</span>
          <span>دروس</span>
          <span>سعر/شهر</span>
          <span>سعر/سنة</span>
          <span>مشتركون</span>
          <span>الحالة</span>
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
          <div key={c.id} className="table-row" style={{ gridTemplateColumns: COLS }}>
            <span className="fw-700" title={c.title}
              style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {c.title}
            </span>
            <span className="text-2">{c.teacherName}</span>
            <span className="text-2" style={{ fontSize: 11.5 }}>{c.level || '—'}</span>
            <span className="text-2">{c.lessonsCount}</span>
            <span className="fw-700">{fmt(c.price_monthly)}</span>
            <span style={{ fontWeight: 600, color: c.price_yearly ? '#1B9E77' : 'var(--text3)', fontSize: c.price_yearly ? 13 : 12 }}>
              {c.price_yearly ? fmt(c.price_yearly) : '—'}
            </span>
            <span className="fw-700 text-teal">{c.subsCount}</span>

            {/* Status toggle */}
            <span>
              {toggleId === c.id ? (
                <div style={{ display: 'flex', gap: 4, alignItems: 'center', flexWrap: 'wrap' }}>
                  <span style={{ fontSize: 10.5, color: 'var(--text2)', whiteSpace: 'nowrap' }}>تغيير؟</span>
                  <button
                    className="btn btn-sm"
                    style={{ padding: '2px 8px', fontSize: 11, background: 'var(--primary)', color: '#fff', border: 'none' }}
                    onClick={() => toggleActive(c.id, c.is_active)}
                  >نعم</button>
                  <button
                    className="btn btn-sm btn-secondary"
                    style={{ padding: '2px 7px', fontSize: 11 }}
                    onClick={() => setToggleId(null)}
                  >لا</button>
                </div>
              ) : (
                <span
                  className="badge"
                  style={{ background: c.is_active ? '#D7F2E6' : '#FEF3C7', color: c.is_active ? '#0A6E4E' : '#92400E', cursor: 'pointer' }}
                  onClick={() => setToggleId(c.id)}
                >
                  {c.is_active ? 'منشور' : 'مسودة'}
                </span>
              )}
            </span>

            {/* Actions — single edit button + delete */}
            <span style={{ textAlign: 'left', display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
              <button
                className="btn btn-sm btn-secondary"
                style={{ padding: '5px 11px', fontSize: 12, background: '#ECE5F7', color: '#5A3B95', border: '1px solid #C5B4F0' }}
                onClick={() => onNavigate('editCourse', { courseId: c.id })}
                title="تعديل الدرس كاملاً"
              >
                ✏️ تعديل
              </button>

              {deleteId === c.id ? (
                <div style={{ display: 'flex', gap: 4 }}>
                  <button
                    className="btn btn-sm"
                    style={{ padding: '5px 9px', fontSize: 11.5, background: '#A12B1D', color: '#fff', border: 'none' }}
                    onClick={() => deleteCourse(c.id)}
                  >تأكيد</button>
                  <button
                    className="btn btn-sm btn-secondary"
                    style={{ padding: '5px 9px', fontSize: 11.5 }}
                    onClick={() => setDeleteId(null)}
                  >إلغاء</button>
                </div>
              ) : (
                <button
                  className="btn btn-sm"
                  style={{ padding: '5px 10px', fontSize: 12, background: '#FBE0DB', color: '#A12B1D', border: '1px solid #F3C5BD' }}
                  onClick={() => setDeleteId(c.id)}
                >🗑</button>
              )}
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}
