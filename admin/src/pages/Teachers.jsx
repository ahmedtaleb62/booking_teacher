import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'
import ConfirmModal from '../components/ConfirmModal'

const AVATAR_COLORS = [
  ['#E0E7FF', '#4338CA'], ['#D1FAE5', '#065F46'],
  ['#EDE9FE', '#5B21B6'], ['#FEF3C7', '#92400E'],
  ['#DBEAFE', '#1D4ED8'], ['#FEE2E2', '#991B1B'],
]

function Avatar({ name, size = 52, bg, fg, photoUrl }) {
  const [failed, setFailed] = React.useState(false)
  const initials = (
    <span style={{
      width: size, height: size, borderRadius: 14, background: bg, color: fg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontWeight: 700, fontSize: size * 0.42, flexShrink: 0,
    }}>
      {name?.[0] || '?'}
    </span>
  )
  if (!photoUrl || failed) return initials
  return (
    <img
      src={photoUrl} alt={name}
      style={{ width: size, height: size, borderRadius: 14, objectFit: 'cover', flexShrink: 0, border: '2px solid var(--border)' }}
      onError={() => setFailed(true)}
    />
  )
}

function buildTeachers(tps, profs, approved, courseCountMap = {}) {
  const profMap = Object.fromEntries((profs || []).map(p => [p.id, p]))
  return (tps || []).map((t, i) => {
    const [bg, fg] = AVATAR_COLORS[i % AVATAR_COLORS.length]
    const p = profMap[t.id] || {}
    return { ...t, profile: p, name: p.full_name || '—', bg, fg, approved, courses_count: courseCountMap[t.id] || 0 }
  })
}

export default function Teachers() {
  const toast = useToast()
  const [tab, setTab]               = useState('pending')
  const [pending, setPending]       = useState([])
  const [approved, setApproved]     = useState([])
  const [loading, setLoading]       = useState(true)
  const [actionId, setActionId]     = useState(null)
  const [modal, setModal]           = useState(null)
  const [rejectTarget, setRejectTarget]   = useState(null)
  const [revokeTarget, setRevokeTarget]   = useState(null)
  const [search, setSearch]         = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [priceMin, setPriceMin]     = useState('')
  const [priceMax, setPriceMax]     = useState('')

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    const [pendingRes, approvedRes] = await Promise.all([
      supabase.from('teacher_profiles').select('*').eq('is_approved', false).order('created_at', { ascending: false }),
      supabase.from('teacher_profiles').select('*').eq('is_approved', true).order('created_at',  { ascending: false }),
    ])

    const pendingTeachers  = pendingRes.data  || []
    const approvedTeachers = approvedRes.data || []
    const allIds = [...pendingTeachers, ...approvedTeachers].map(t => t.id)

    const [profsRes, coursesRes] = await Promise.all([
      allIds.length
        ? supabase.from('profiles').select('id, full_name, phone, avatar_url, created_at').in('id', allIds)
        : { data: [] },
      allIds.length
        ? supabase.from('courses').select('teacher_id').in('teacher_id', allIds).eq('is_active', true)
        : { data: [] },
    ])

    const profs = profsRes.data || []
    const courseCountMap = {}
    for (const c of (coursesRes.data || [])) {
      courseCountMap[c.teacher_id] = (courseCountMap[c.teacher_id] || 0) + 1
    }

    setPending(buildTeachers(pendingTeachers, profs, false, courseCountMap))
    setApproved(buildTeachers(approvedTeachers, profs, true, courseCountMap))
    setLoading(false)
  }

  /* ── Approve pending teacher ─────────────────────────────────── */
  async function approve(id) {
    setActionId(id)
    const { error } = await supabase.from('teacher_profiles').update({ is_approved: true }).eq('id', id)
    if (error) { toast('خطأ في الاعتماد: ' + error.message, 'error'); setActionId(null); return }
    await supabase.functions.invoke('notify-user', {
      body: {
        user_id: id,
        title:   'تهانينا! تم اعتماد حسابك 🎉',
        body:    'يمكنك الآن استقبال طلبات الجلسات من الطلاب.',
        data:    { type: 'TEACHER_APPROVED' },
      },
    }).catch(() => {})
    await supabase.from('notifications').insert({
      user_id: id, title: 'تهانينا! تم اعتماد حسابك 🎉',
      body: 'يمكنك الآن استقبال طلبات الجلسات من الطلاب.', type: 'teacher_approved',
    })
    setActionId(null); setModal(null)
    toast('تم اعتماد الأستاذ بنجاح وإشعاره', 'success')
    await loadData()
  }

  /* ── Reject pending application ──────────────────────────────── */
  async function reject(id) {
    setRejectTarget(null)
    setActionId(id)
    const { error: delErr } = await supabase.from('teacher_profiles').delete().eq('id', id)
    if (delErr) { toast('خطأ في رفض الطلب: ' + delErr.message, 'error'); setActionId(null); return }
    await supabase.from('profiles').update({ is_active: false }).eq('id', id)
    await supabase.from('notifications').insert({
      user_id: id, title: 'اعتذرنا عن طلبك',
      body: 'لا يمكن قبول طلبك في الوقت الحالي. يرجى التواصل معنا للمزيد.', type: 'teacher_rejected',
    })
    setActionId(null); setModal(null)
    toast('تم رفض طلب الأستاذ', 'success')
    await loadData()
  }

  /* ── Revoke approval from approved teacher ───────────────────── */
  async function revoke(id) {
    setRevokeTarget(null)
    setActionId(id)
    const { error } = await supabase.from('teacher_profiles').update({ is_approved: false }).eq('id', id)
    if (error) { toast('خطأ في إلغاء الاعتماد: ' + error.message, 'error'); setActionId(null); return }
    await supabase.from('notifications').insert({
      user_id: id, title: 'تم إيقاف حسابك مؤقتاً',
      body: 'تم إلغاء اعتماد حسابك من قِبَل الإدارة. للاستفسار تواصل معنا.', type: 'teacher_revoked',
    })
    setActionId(null); setModal(null)
    toast('تم إلغاء اعتماد الأستاذ وإشعاره', 'success')
    await loadData()
  }

  const timeAgo = dt => {
    if (!dt) return '—'
    const mins = Math.round((Date.now() - new Date(dt)) / 60000)
    if (mins < 60)   return `${mins} دقيقة`
    if (mins < 1440) return `${Math.round(mins / 60)} ساعة`
    return `${Math.round(mins / 1440)} يوم`
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const baseList = statusFilter === 'approved' ? approved
    : statusFilter === 'pending' ? pending
    : tab === 'pending' ? pending : approved

  const q = search.trim().toLowerCase()
  const list = baseList.filter(t => {
    if (q) {
      const name  = (t.name || '').toLowerCase()
      const phone = (t.phone || t.profile?.phone || '').replace(/\s/g, '')
      if (!name.includes(q) && !phone.includes(q.replace(/\s/g, ''))) return false
    }
    if (priceMin !== '' && (t.price_per_hour ?? 0) < Number(priceMin)) return false
    if (priceMax !== '' && (t.price_per_hour ?? 0) > Number(priceMax)) return false
    return true
  })

  const hasFilter = q || priceMin !== '' || priceMax !== ''

  return (
    <div>
      {/* ── Tabs ──────────────────────────────────────────────── */}
      <div className="tabs mb-14">
        <div className={`tab${tab === 'pending' ? ' active' : ''}`} onClick={() => setTab('pending')}>
          طلبات الاعتماد
          {pending.length > 0 && (
            <span className="badge" style={{ background: '#FEF3C7', color: '#92400E', marginRight: 6, fontSize: 10 }}>{pending.length}</span>
          )}
        </div>
        <div className={`tab${tab === 'approved' ? ' active' : ''}`} onClick={() => setTab('approved')}>
          الأساتذة المعتمدون
          <span className="badge" style={{ background: '#D1FAE5', color: '#065F46', marginRight: 6, fontSize: 10 }}>{approved.length}</span>
        </div>
      </div>

      {/* ── Filter bar ────────────────────────────────────────── */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 16, flexWrap: 'wrap', alignItems: 'center' }}>
        {/* Search */}
        <div style={{ position: 'relative', flex: '1 1 200px', minWidth: 180 }}>
          <span style={{ position: 'absolute', right: 11, top: '50%', transform: 'translateY(-50%)', fontSize: 14, color: 'var(--text3)', pointerEvents: 'none' }}>🔍</span>
          <input
            type="text"
            placeholder="بحث بالاسم أو الهاتف…"
            value={search}
            onChange={e => setSearch(e.target.value)}
            style={{ width: '100%', padding: '8px 34px 8px 12px', borderRadius: 10, border: '1.5px solid var(--border)', fontSize: 13, outline: 'none', background: 'var(--surface)', color: 'var(--text1)', boxSizing: 'border-box' }}
          />
        </div>

        {/* Status */}
        <select
          value={statusFilter}
          onChange={e => { setStatusFilter(e.target.value); if (e.target.value === 'approved') setTab('approved'); else if (e.target.value === 'pending') setTab('pending') }}
          style={{ padding: '8px 12px', borderRadius: 10, border: '1.5px solid var(--border)', fontSize: 13, background: 'var(--surface)', color: 'var(--text1)', cursor: 'pointer' }}
        >
          <option value="all">الكل</option>
          <option value="approved">معتمد</option>
          <option value="pending">غير معتمد</option>
        </select>

        {/* Price range */}
        <input
          type="number"
          placeholder="سعر من"
          value={priceMin}
          onChange={e => setPriceMin(e.target.value)}
          style={{ width: 90, padding: '8px 10px', borderRadius: 10, border: '1.5px solid var(--border)', fontSize: 13, background: 'var(--surface)', color: 'var(--text1)' }}
        />
        <input
          type="number"
          placeholder="إلى"
          value={priceMax}
          onChange={e => setPriceMax(e.target.value)}
          style={{ width: 80, padding: '8px 10px', borderRadius: 10, border: '1.5px solid var(--border)', fontSize: 13, background: 'var(--surface)', color: 'var(--text1)' }}
        />

        {/* Clear */}
        {(hasFilter || statusFilter !== 'all') && (
          <button
            onClick={() => { setSearch(''); setStatusFilter('all'); setPriceMin(''); setPriceMax('') }}
            style={{ padding: '7px 14px', borderRadius: 10, border: '1.5px solid var(--border)', background: '#FEE2E2', color: '#991B1B', fontSize: 12, cursor: 'pointer', fontWeight: 600 }}
          >
            ✕ مسح
          </button>
        )}

        <span style={{ fontSize: 12, color: 'var(--text3)', marginRight: 'auto' }}>
          {list.length} نتيجة
        </span>
      </div>

      {/* ── Pending tab info banner ────────────────────────────── */}
      {tab === 'pending' && statusFilter !== 'approved' && (
        <div className="info-banner blue" style={{ marginBottom: 16 }}>
          ℹ️ &nbsp;للاعتماد يكفي أن يرسل الأستاذ: المادة · سنوات الخبرة · صورة ورقم بطاقة التعريف. اضغط أي بطاقة للمراجعة.
        </div>
      )}

      {/* ── Empty states ──────────────────────────────────────── */}
      {list.length === 0 && (
        <div style={{ textAlign: 'center', padding: '60px 0', color: 'var(--text3)' }}>
          <div style={{ fontSize: 48, marginBottom: 12 }}>{hasFilter ? '🔍' : '✅'}</div>
          <div style={{ fontSize: 16, fontWeight: 700 }}>
            {hasFilter ? 'لا توجد نتائج مطابقة' : tab === 'pending' ? 'لا توجد طلبات معلّقة' : 'لا يوجد أساتذة معتمدون بعد'}
          </div>
          {hasFilter && <div style={{ fontSize: 13, marginTop: 6, color: 'var(--text3)' }}>جرّب تغيير معايير البحث</div>}
        </div>
      )}

      {/* ── Cards grid ────────────────────────────────────────── */}
      <div className="grid-3">
        {list.map(t => (
          <div key={t.id} className="card" style={{ cursor: 'pointer' }} onClick={() => setModal(t)}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <Avatar name={t.name} bg={t.bg} fg={t.fg} photoUrl={t.avatar_url || t.profile?.avatar_url} />
              {tab === 'pending'
                ? <span className="badge" style={{ background: '#FEF3C7', color: '#92400E' }}>بانتظار</span>
                : <span className="badge" style={{ background: '#D1FAE5', color: '#065F46' }}>✓ معتمد</span>
              }
            </div>
            <div style={{ fontSize: 16, fontWeight: 700, marginTop: 13 }}>{t.name}</div>
            <div style={{ fontSize: 12.5, color: 'var(--text2)', marginTop: 2 }}>
              {(t.subjects || []).join('، ')} · {t.years_experience ?? t.years_of_experience ?? '?'} سنوات خبرة
            </div>
            {t.price_per_hour && (
              <div style={{ fontSize: 12, color: 'var(--text3)', marginTop: 4 }}>
                💰 {t.price_per_hour.toLocaleString('ar')} أوقية / ساعة
              </div>
            )}
            <div style={{ display: 'flex', gap: 12, marginTop: 10, fontSize: 12 }}>
              <span style={{ background: '#EDE9FE', color: '#5B21B6', borderRadius: 8, padding: '3px 9px', fontWeight: 600 }}>
                🎓 {t.total_sessions ?? 0} جلسة
              </span>
              <span style={{ background: '#DBEAFE', color: '#1D4ED8', borderRadius: 8, padding: '3px 9px', fontWeight: 600 }}>
                📚 {t.courses_count} درس
              </span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginTop: 10, paddingTop: 10, borderTop: '1px solid var(--border-table)', fontSize: 12, color: 'var(--text3)', direction: 'ltr', justifyContent: 'flex-end' }}>
              📞 {t.phone || t.profile?.phone || '—'}
            </div>
            <div style={{ fontSize: 11, color: 'var(--text4)', marginTop: 6 }}>
              {tab === 'pending' ? `تقدّم منذ ${timeAgo(t.created_at || t.profile?.created_at)}` : `مُعتمد منذ ${timeAgo(t.created_at)}`}
            </div>
          </div>
        ))}
      </div>

      {/* ── Detail / action modal ─────────────────────────────── */}
      {modal && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.45)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}
          onClick={() => !actionId && setModal(null)}
        >
          <div
            style={{ background: '#fff', borderRadius: 20, padding: 28, width: 480, maxWidth: '95vw', maxHeight: '90vh', overflowY: 'auto' }}
            onClick={e => e.stopPropagation()}
          >
            {/* Header */}
            <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 20 }}>
              <Avatar name={modal.name} size={56} bg={modal.bg} fg={modal.fg} photoUrl={modal.avatar_url || modal.profile?.avatar_url} />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 18, fontWeight: 800 }}>{modal.name}</div>
                <div style={{ fontSize: 12.5, color: 'var(--text2)', marginTop: 2, direction: 'ltr' }}>
                  {modal.phone || modal.profile?.phone || '—'}
                </div>
                {modal.approved
                  ? <span className="badge" style={{ background: '#D1FAE5', color: '#065F46', marginTop: 5, display: 'inline-block' }}>✓ معتمد</span>
                  : <span className="badge" style={{ background: '#FEF3C7', color: '#92400E', marginTop: 5, display: 'inline-block' }}>بانتظار الاعتماد</span>
                }
              </div>
            </div>

            {/* Teacher details */}
            <div style={{ background: '#F5F7FF', borderRadius: 12, padding: 16, marginBottom: 20, display: 'flex', flexDirection: 'column', gap: 10, fontSize: 13 }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                <div>
                  <div style={{ fontSize: 10, color: 'var(--text3)', marginBottom: 2 }}>المواد</div>
                  <div style={{ fontWeight: 600 }}>{(modal.subjects || []).join('، ') || '—'}</div>
                </div>
                <div>
                  <div style={{ fontSize: 10, color: 'var(--text3)', marginBottom: 2 }}>سنوات الخبرة</div>
                  <div style={{ fontWeight: 600 }}>{modal.years_experience ?? modal.years_of_experience ?? '—'} سنوات</div>
                </div>
                <div>
                  <div style={{ fontSize: 10, color: 'var(--text3)', marginBottom: 2 }}>سعر الساعة</div>
                  <div style={{ fontWeight: 600, color: '#059669' }}>{modal.price_per_hour?.toLocaleString('ar') || '—'} أوقية</div>
                </div>
                <div>
                  <div style={{ fontSize: 10, color: 'var(--text3)', marginBottom: 2 }}>تاريخ التسجيل</div>
                  <div style={{ fontWeight: 600 }}>{(modal.profile?.created_at || modal.created_at || '').slice(0, 10) || '—'}</div>
                </div>
              </div>

              {modal.bio && (
                <div>
                  <div style={{ fontSize: 10, color: 'var(--text3)', marginBottom: 4 }}>نبذة تعريفية</div>
                  <div style={{ lineHeight: 1.6, color: 'var(--text2)' }}>{modal.bio}</div>
                </div>
              )}

              {modal.education && (
                <div>
                  <div style={{ fontSize: 10, color: 'var(--text3)', marginBottom: 2 }}>المؤهل التعليمي</div>
                  <div style={{ fontWeight: 600 }}>{modal.education}</div>
                </div>
              )}

              <div>
                <div style={{ fontSize: 10, color: 'var(--text3)', marginBottom: 2 }}>رقم الهاتف</div>
                <div style={{ fontWeight: 600, direction: 'ltr', textAlign: 'right' }}>
                  {modal.phone || modal.profile?.phone || '—'}
                </div>
              </div>
            </div>

            {/* ID card image */}
            {modal.id_card_url && (
              <div style={{ marginBottom: 20 }}>
                <div style={{ fontSize: 12, color: 'var(--text3)', marginBottom: 8 }}>🪪 بطاقة التعريف</div>
                <a href={modal.id_card_url} target="_blank" rel="noreferrer">
                  <img src={modal.id_card_url} alt="id" style={{ width: '100%', borderRadius: 10, maxHeight: 200, objectFit: 'cover', border: '1px solid var(--border)', cursor: 'zoom-in' }} />
                  <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 4, textAlign: 'center' }}>انقر للعرض الكامل ↗</div>
                </a>
              </div>
            )}

            {/* Profile photo — try avatar_url from teacher_profiles then profiles */}
            {(modal.avatar_url || modal.profile?.avatar_url) && (
              <div style={{ marginBottom: 20 }}>
                <div style={{ fontSize: 12, color: 'var(--text3)', marginBottom: 8 }}>📷 صورة الملف الشخصي</div>
                <img
                  src={modal.avatar_url || modal.profile?.avatar_url}
                  alt="avatar"
                  style={{ width: 80, height: 80, borderRadius: '50%', objectFit: 'cover', border: '2px solid var(--border)' }}
                />
              </div>
            )}

            {/* Actions */}
            {modal.approved ? (
              /* Approved teacher — revoke button */
              <div>
                <div style={{ background: '#FEF3C7', borderRadius: 10, padding: '10px 14px', marginBottom: 14, fontSize: 12, color: '#92400E' }}>
                  ⚠ إلغاء الاعتماد سيوقف الأستاذ عن استقبال الجلسات الجديدة ويُشعره بذلك.
                </div>
                <div style={{ display: 'flex', gap: 10 }}>
                  <button
                    className="btn btn-danger"
                    style={{ flex: 1, justifyContent: 'center' }}
                    disabled={!!actionId}
                    onClick={() => setRevokeTarget({ id: modal.id, name: modal.name })}
                  >
                    🚫 إلغاء الاعتماد
                  </button>
                  <button className="btn btn-secondary" style={{ flex: 1, justifyContent: 'center' }} onClick={() => setModal(null)}>
                    إغلاق
                  </button>
                </div>
              </div>
            ) : (
              /* Pending teacher — approve / reject */
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {!modal.id_card_url && (
                  <div style={{ background: '#FEE2E2', borderRadius: 10, padding: '10px 14px', fontSize: 12, color: '#991B1B' }}>
                    🚫 لا يمكن الاعتماد — لم يُرفق صورة بطاقة التعريف
                  </div>
                )}
                <div style={{ display: 'flex', gap: 10 }}>
                <button
                  className="btn btn-primary"
                  style={{ flex: 1, justifyContent: 'center' }}
                  disabled={!!actionId || !modal.id_card_url}
                  title={!modal.id_card_url ? 'يجب أن يرفق الأستاذ صورة بطاقته أولاً' : undefined}
                  onClick={() => approve(modal.id)}
                >
                  {actionId === modal.id
                    ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
                    : '✓ اعتماد الأستاذ'}
                </button>
                <button
                  className="btn btn-danger"
                  style={{ flex: 1, justifyContent: 'center' }}
                  disabled={!!actionId}
                  onClick={() => setRejectTarget({ id: modal.id, name: modal.name })}
                >
                  ✕ رفض الطلب
                </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── Reject confirmation ───────────────────────────────── */}
      <ConfirmModal
        open={!!rejectTarget}
        danger
        title={`رفض طلب ${rejectTarget?.name || ''}`}
        message="سيتم حذف ملف الأستاذ وإلغاء تفعيل حسابه. هذا الإجراء لا يمكن التراجع عنه."
        confirm="تأكيد الرفض"
        cancel="إلغاء"
        loading={actionId === rejectTarget?.id}
        onConfirm={() => reject(rejectTarget.id)}
        onCancel={() => !actionId && setRejectTarget(null)}
      />

      {/* ── Revoke confirmation ───────────────────────────────── */}
      <ConfirmModal
        open={!!revokeTarget}
        danger
        title={`إلغاء اعتماد ${revokeTarget?.name || ''}`}
        message="سيتم إيقاف الأستاذ عن استقبال الجلسات وسيُشعَر بذلك. يمكنك إعادة الاعتماد لاحقاً من نفس الصفحة."
        confirm="تأكيد إلغاء الاعتماد"
        cancel="رجوع"
        loading={actionId === revokeTarget?.id}
        onConfirm={() => revoke(revokeTarget.id)}
        onCancel={() => !actionId && setRevokeTarget(null)}
      />
    </div>
  )
}
