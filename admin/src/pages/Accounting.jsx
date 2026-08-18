import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'
import ConfirmModal from '../components/ConfirmModal'

const LEDGER_TYPE_LABELS = {
  session_payment:     'جلسة',
  course_subscription: 'اشتراك درس',
  package_subscription: 'اشتراك باقة',
  payout_sent:         'تسوية مدفوعة',
}

/* ── Per-teacher earnings trace modal ────────────────────────────── */
function TeacherLedgerModal({ teacher, onClose }) {
  const [entries, setEntries] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    (async () => {
      const { data } = await supabase
        .from('ledger_entries')
        .select('id, type, amount, commission, net_amount, description, created_at')
        .eq('teacher_id', teacher.id)
        .order('created_at', { ascending: false })
      setEntries(data || [])
      setLoading(false)
    })()
  }, [teacher.id])

  const fmt = n => (n ?? 0).toLocaleString('en-US')
  const fmtDate = dt => new Date(dt).toLocaleString('ar-EG-u-nu-latn', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()} style={{ maxWidth: 620, maxHeight: '80vh', display: 'flex', flexDirection: 'column' }}>
        <div className="modal-title">سجل تتبّع أرباح — {teacher.name}</div>
        <div style={{ overflowY: 'auto', marginTop: 8 }}>
          {loading ? (
            <div style={{ padding: 20, textAlign: 'center' }}>...جاري التحميل</div>
          ) : entries.length === 0 ? (
            <div style={{ padding: 20, textAlign: 'center', color: 'var(--text3)' }}>لا توجد حركات مسجّلة لهذا الأستاذ</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {entries.map(e => {
                const isPayout = e.type === 'payout_sent'
                return (
                  <div key={e.id} style={{
                    display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                    padding: '10px 12px', borderRadius: 10, border: '1px solid var(--border)',
                    background: isPayout ? '#F1F5F9' : 'var(--surface)',
                  }}>
                    <div>
                      <div style={{ fontSize: 13, fontWeight: 700 }}>
                        {LEDGER_TYPE_LABELS[e.type] || e.type}
                      </div>
                      <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 2 }}>{e.description || '—'}</div>
                      <div style={{ fontSize: 10, color: 'var(--text3)', marginTop: 2, direction: 'ltr', textAlign: 'right' }}>{fmtDate(e.created_at)}</div>
                    </div>
                    <div style={{ textAlign: 'left' }}>
                      <div style={{ fontSize: 14, fontWeight: 700, color: isPayout ? '#475569' : '#0A6E4E' }}>
                        {isPayout ? '−' : '+'}{fmt(Math.abs(e.net_amount))} <span style={{ fontSize: 10, fontWeight: 400 }}>أوقية</span>
                      </div>
                      {!isPayout && (
                        <div style={{ fontSize: 10, color: 'var(--text3)' }}>
                          إجمالي {fmt(e.amount)} − عمولة {fmt(e.commission)}
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </div>
        <div style={{ marginTop: 14 }}>
          <button className="btn" style={{ width: '100%' }} onClick={onClose}>إغلاق</button>
        </div>
      </div>
    </div>
  )
}

export default function Accounting() {
  const showToast = useToast()
  const [rows, setRows] = useState([])
  const [settledRows, setSettledRows] = useState([])
  const [showSettled, setShowSettled] = useState(false)
  const [search, setSearch] = useState('')
  const [ledgerTeacher, setLedgerTeacher] = useState(null) // { id, name }
  const [totals, setTotals] = useState({ due: 0, paid: 0, pending: 0 })
  const [loading, setLoading] = useState(true)
  const [actionId, setActionId] = useState(null)
  const [confirmModal, setConfirmModal] = useState(null) // { teacherId, amount, name }

  useEffect(() => { loadData() }, [])

  async function loadData() {
    setLoading(true)
    try {
    // Load commission rates
    let sessionCommRate = 0.15
    let subCommRate     = 0.15
    const { data: settingsData } = await supabase.rpc('get_system_settings')
    if (settingsData) {
      const s = Object.fromEntries(settingsData.map(r => [r.key, parseFloat(r.value)]))
      if (!isNaN(s.session_commission_pct))      sessionCommRate = s.session_commission_pct / 100
      if (!isNaN(s.subscription_commission_pct)) subCommRate     = s.subscription_commission_pct / 100
    }

    const { data: tps } = await supabase
      .from('teacher_profiles')
      .select('id, is_approved, subjects')
      .eq('is_approved', true)
    const tpIds = (tps || []).map(t => t.id)
    const { data: profs } = tpIds.length
      ? await supabase.from('profiles').select('id, full_name, phone').in('id', tpIds)
      : { data: [] }
    const profMap = Object.fromEntries((profs || []).map(p => [p.id, p]))
    const teachers = (tps || []).map(t => ({ ...t, profiles: profMap[t.id] || {} }))

    const [{ data: sessionsRaw }, { data: subs }, { data: pkgSubsRaw }, { data: payouts }] = await Promise.all([
      supabase
        .from('sessions')
        .select('teacher_id, amount, state, payments(dispute_status, status)')
        .eq('state', 'COMPLETED'),
      supabase
        .from('subscriptions')
        .select('course:course_id(teacher_id), amount')
        .eq('status', 'active')
        .eq('type', 'course'),
      supabase
        .from('subscriptions')
        .select('package_id, amount')
        .eq('status', 'active')
        .eq('type', 'package'),
      supabase
        .from('ledger_entries')
        .select('teacher_id, net_amount, created_at')
        .eq('type', 'payout_sent')
        .order('created_at', { ascending: false }),
    ])

    // Resolve teacher_ids via package_courses → courses (packages table has no teacher_id column)
    const packageIds = [...new Set((pkgSubsRaw || []).map(s => s.package_id).filter(Boolean))]
    const { data: pkgCoursesData } = packageIds.length
      ? await supabase.from('package_courses').select('package_id, course:course_id(teacher_id)').in('package_id', packageIds)
      : { data: [] }
    const pkgTeacherMap = {}
    ;(pkgCoursesData || []).forEach(pc => {
      const tid = pc.course?.teacher_id
      if (!tid) return
      if (!pkgTeacherMap[pc.package_id]) pkgTeacherMap[pc.package_id] = []
      if (!pkgTeacherMap[pc.package_id].includes(tid)) pkgTeacherMap[pc.package_id].push(tid)
    })
    // Split package subscription revenue equally among all teachers in the package
    const pkgSubs = []
    ;(pkgSubsRaw || []).forEach(s => {
      const teacherIds = pkgTeacherMap[s.package_id] || []
      if (teacherIds.length === 0) return
      const share = (s.amount || 0) / teacherIds.length
      teacherIds.forEach(tid => pkgSubs.push({ amount: share, package: { teacher_id: tid } }))
    })

    // Exclude sessions whose confirmed payment is frozen or refunded (dispute in progress or decided against teacher)
    const sessions = (sessionsRaw || []).filter(s => {
      const confirmedPayment = (s.payments || []).find(p => p.status === 'confirmed')
      if (!confirmedPayment) return true
      const ds = confirmedPayment.dispute_status
      return ds !== 'frozen' && ds !== 'refunded'
    })

    const byTeacher = {}
    ;(sessions || []).forEach(s => {
      if (!byTeacher[s.teacher_id]) byTeacher[s.teacher_id] = { sessions: 0, subs: 0 }
      byTeacher[s.teacher_id].sessions += (s.amount || 0) * (1 - sessionCommRate)
    })
    ;(subs || []).forEach(s => {
      const tid = s.course?.teacher_id
      if (!tid) return
      if (!byTeacher[tid]) byTeacher[tid] = { sessions: 0, subs: 0 }
      byTeacher[tid].subs += (s.amount || 0) * (1 - subCommRate)
    })
    ;(pkgSubs || []).forEach(s => {
      const tid = s.package?.teacher_id
      if (!tid) return
      if (!byTeacher[tid]) byTeacher[tid] = { sessions: 0, subs: 0 }
      byTeacher[tid].subs += (s.amount || 0) * (1 - subCommRate)
    })

    // net_amount for payout_sent is stored as negative — sum gives negative total paid out
    const payoutsByTeacher = {}
    const lastPayoutByTeacher = {}
    ;(payouts || []).forEach(p => {
      payoutsByTeacher[p.teacher_id] = (payoutsByTeacher[p.teacher_id] || 0) + Math.abs(p.net_amount || 0)
      if (!lastPayoutByTeacher[p.teacher_id]) lastPayoutByTeacher[p.teacher_id] = p.created_at // first hit = most recent (query ordered desc)
    })

    const teacherRows = (teachers || []).map((t, i) => {
      const stats = byTeacher[t.id] || { sessions: 0, subs: 0 }
      const paidOut = payoutsByTeacher[t.id] || 0
      const total = Math.max(0, stats.sessions + stats.subs - paidOut)
      const colors = [['#D7F2E6', '#0A6E4E'], ['#E3F4EF', '#0E7C66'], ['#ECE5F7', '#5A3B95'], ['#FBEFD6', '#92620F'], ['#DEEAF7', '#1F5C99']]
      const [bg, fg] = colors[i % colors.length]
      return {
        id: t.id,
        name: t.profiles?.full_name || '—',
        phone: t.profiles?.phone || '',
        subjects: t.subjects || [],
        init: (t.profiles?.full_name || '?')[0],
        bg, fg,
        sessions: Math.round(stats.sessions),
        subs: Math.round(stats.subs),
        total: Math.round(total),
        paidOut: Math.round(paidOut),
        lastPayoutAt: lastPayoutByTeacher[t.id] || null,
        status: total > 0 ? 'قيد التسوية' : 'لا يوجد',
        statusBg: total > 0 ? '#FEF3C7' : '#F1F5F9',
        statusFg: total > 0 ? '#92400E' : '#475569',
      }
    })

    const fromSessions = Math.round(teacherRows.reduce((s, r) => s + r.sessions, 0))
    const fromSubs     = Math.round(teacherRows.reduce((s, r) => s + r.subs, 0))
    const due          = Math.round(teacherRows.reduce((s, r) => s + r.total, 0))
    const settled      = teacherRows.filter(r => r.total === 0 && (byTeacher[r.id]?.sessions || byTeacher[r.id]?.subs || r.paidOut))
    setTotals({ due, fromSessions, fromSubs, settled: settled.length, sessionCommRate: sessionCommRate * 100, subCommRate: subCommRate * 100 })
    // only show teachers with pending balance
    setRows(teacherRows.filter(r => r.total > 0))
    // teachers who earned something and are fully settled (paid out in full)
    setSettledRows(settled.filter(r => r.paidOut > 0))
    } catch (err) {
      console.error('Accounting loadData error:', err)
    } finally {
      setLoading(false)
    }
  }

  function openSettle(teacherId, amount, name) {
    setConfirmModal({ teacherId, amount, name })
  }

  async function confirmSettle() {
    const { teacherId, amount, name } = confirmModal
    setActionId(teacherId)
    const dateLabel = new Date().toLocaleDateString('ar-EG-u-nu-latn')
    const { error } = await supabase.rpc('admin_settle_teacher', {
      p_teacher_id:  teacherId,
      p_amount:      amount,
      p_description: 'تسوية من الإدارة — ' + dateLabel,
    })
    setActionId(null)
    setConfirmModal(null)
    if (error) {
      showToast('خطأ في تسجيل التسوية: ' + error.message, 'error')
    } else {
      showToast(`تمت تسوية مستحقات ${name} وإشعاره`, 'success')
      await loadData()
    }
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const fmt = n => n?.toLocaleString('en-US')
  const fmtDate = dt => dt ? new Date(dt).toLocaleDateString('ar-EG-u-nu-latn', { year: 'numeric', month: 'short', day: 'numeric' }) : '—'

  function matchesSearch(r) {
    const q = search.trim().toLowerCase()
    if (!q) return true
    const digits = q.replace(/\D/g, '')
    const nameMatch    = (r.name || '').toLowerCase().includes(q)
    const phoneMatch    = digits && (r.phone || '').replace(/\D/g, '').includes(digits)
    const subjectMatch = (r.subjects || []).some(s => (s || '').toLowerCase().includes(q))
    return nameMatch || phoneMatch || subjectMatch
  }

  const filteredRows        = rows.filter(matchesSearch)
  const filteredSettledRows = settledRows.filter(matchesSearch)

  return (
    <div>
      <div className="flex justify-between items-center mb-18" style={{ flexWrap: 'wrap', gap: 14 }}>
        <div className="flex gap-14" style={{ flexWrap: 'wrap' }}>
          <div className="card-sm">
            <div className="text-muted" style={{ fontSize: 12 }}>إجمالي المستحقات للأساتذة</div>
            <div style={{ fontSize: 23, fontWeight: 700, marginTop: 3 }}>{fmt(totals.due)} <span style={{ fontSize: 11, color: 'var(--text3)' }}>أوقية</span></div>
          </div>
          <div className="card-sm">
            <div className="text-muted" style={{ fontSize: 12 }}>مستحقات الجلسات</div>
            <div style={{ fontSize: 23, fontWeight: 700, color: '#1B9E77', marginTop: 3 }}>{fmt(totals.fromSessions)} <span style={{ fontSize: 11, color: 'var(--text3)' }}>أوقية</span></div>
          </div>
          <div className="card-sm" style={{ background: '#0C2E28', border: 'none' }}>
            <div style={{ fontSize: 12, color: 'rgba(255,255,255,.5)' }}>مستحقات الاشتراكات</div>
            <div style={{ fontSize: 23, fontWeight: 700, color: '#6FE3C4', marginTop: 3 }}>{fmt(totals.fromSubs)} <span style={{ fontSize: 11, color: 'rgba(255,255,255,.4)' }}>أوقية</span></div>
          </div>
          <button
            className="card-sm"
            style={{ cursor: 'pointer', border: showSettled ? '1px solid #059669' : undefined, textAlign: 'right' }}
            onClick={() => setShowSettled(s => !s)}
            title="عرض/إخفاء جدول الأساتذة المُسوَّون"
          >
            <div className="text-muted" style={{ fontSize: 12 }}>تمت تسويتهم</div>
            <div style={{ fontSize: 23, fontWeight: 700, color: '#059669', marginTop: 3 }}>{totals.settled ?? 0} <span style={{ fontSize: 11, color: 'var(--text3)' }}>أستاذ</span></div>
          </button>
        </div>
      </div>

      <div className="info-banner warn">
        ℹ️ &nbsp;تُحسب مستحقات كل أستاذ = (دخل الجلسات − عمولة {Math.round((totals.sessionCommRate ?? 15))}%) + (دخل الاشتراكات − عمولة {Math.round((totals.subCommRate ?? 15))}%). تتم التسوية والدفع شهرياً.
      </div>

      {/* Search filter */}
      <div style={{
        display: 'flex', flexWrap: 'wrap', gap: 8, alignItems: 'center',
        margin: '14px 0', padding: 12, background: 'var(--surface)',
        border: '1px solid var(--border)', borderRadius: 12,
      }}>
        <input
          className="field-input"
          placeholder="بحث باسم الأستاذ، رقم الهاتف، أو المادة..."
          value={search}
          onChange={e => setSearch(e.target.value)}
          style={{ flex: '1 1 260px', minWidth: 200 }}
        />
        {search.trim() && (
          <button className="btn btn-sm" onClick={() => setSearch('')}>إلغاء</button>
        )}
      </div>

      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: '1.6fr 1fr 1fr 1fr 1fr 1.1fr' }}>
          <span>الأستاذ</span><span>صافي الجلسات</span><span>صافي الاشتراكات</span><span>الإجمالي المستحق</span><span>الحالة</span><span style={{ textAlign: 'left' }}>إجراء</span>
        </div>
        {filteredRows.length === 0 && (
          <div style={{ padding: 40, textAlign: 'center', color: 'var(--text3)' }}>
            {rows.length === 0 ? (
              <>
                <div style={{ fontSize: 36, marginBottom: 10 }}>✅</div>
                <div style={{ fontWeight: 700, fontSize: 15 }}>لا توجد مستحقات معلّقة</div>
                <div style={{ fontSize: 13, marginTop: 6 }}>جميع مستحقات الأساتذة تمت تسويتها</div>
              </>
            ) : (
              <div style={{ fontSize: 13 }}>لا توجد نتائج مطابقة للبحث</div>
            )}
          </div>
        )}
        {filteredRows.map(r => (
          <div key={r.id} className="table-row" style={{ gridTemplateColumns: '1.6fr 1fr 1fr 1fr 1fr 1.1fr' }}>
            <button
              className="flex items-center gap-10"
              style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', textAlign: 'right' }}
              onClick={() => setLedgerTeacher({ id: r.id, name: r.name })}
              title="عرض سجل تتبّع الأرباح"
            >
              <span style={{ width: 34, height: 34, borderRadius: 10, background: r.bg, color: r.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, flexShrink: 0 }}>{r.init}</span>
              <span className="fw-700" style={{ textDecoration: 'underline', textDecorationStyle: 'dotted' }}>{r.name}</span>
            </button>
            <span className="text-2">{fmt(r.sessions)}</span>
            <span className="text-2">{fmt(r.subs)}</span>
            <span className="fw-700">{fmt(r.total)}</span>
            <span><span className="badge" style={{ background: r.statusBg, color: r.statusFg }}>{r.status}</span></span>
            <span style={{ textAlign: 'left' }}>
              {r.total > 0 && (
                <button className="btn btn-sm btn-primary" disabled={!!actionId} onClick={() => openSettle(r.id, r.total, r.name)}>
                  {actionId === r.id ? <span className="spinner" style={{ width: 13, height: 13, borderWidth: 2 }} /> : 'تسوية الدفع'}
                </button>
              )}
            </span>
          </div>
        ))}
      </div>

      {showSettled && (
        <div style={{ marginTop: 24 }}>
          <div className="fw-700" style={{ fontSize: 14, marginBottom: 8 }}>الأساتذة المُسوَّون بالكامل</div>
          <div className="table-wrap">
            <div className="table-head" style={{ gridTemplateColumns: '1.8fr 1fr 1fr' }}>
              <span>الأستاذ</span><span>إجمالي المدفوع</span><span>آخر تسوية</span>
            </div>
            {filteredSettledRows.length === 0 && (
              <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)', fontSize: 13 }}>
                {settledRows.length === 0 ? 'لا يوجد أساتذة تمت تسويتهم بعد' : 'لا توجد نتائج مطابقة للبحث'}
              </div>
            )}
            {filteredSettledRows.map(r => (
              <div key={r.id} className="table-row" style={{ gridTemplateColumns: '1.8fr 1fr 1fr' }}>
                <button
                  className="flex items-center gap-10"
                  style={{ background: 'none', border: 'none', padding: 0, cursor: 'pointer', textAlign: 'right' }}
                  onClick={() => setLedgerTeacher({ id: r.id, name: r.name })}
                  title="عرض سجل تتبّع الأرباح"
                >
                  <span style={{ width: 34, height: 34, borderRadius: 10, background: r.bg, color: r.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, flexShrink: 0 }}>{r.init}</span>
                  <span className="fw-700" style={{ textDecoration: 'underline', textDecorationStyle: 'dotted' }}>{r.name}</span>
                </button>
                <span className="text-2">{fmt(r.paidOut)}</span>
                <span className="text-2 dir-ltr">{fmtDate(r.lastPayoutAt)}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      <ConfirmModal
        open={!!confirmModal}
        title={`تسوية مستحقات ${confirmModal?.name}`}
        message={`سيتم تسجيل دفع بقيمة ${confirmModal?.amount?.toLocaleString('en-US')} أوقية للأستاذ ${confirmModal?.name}. هل تريد المتابعة؟`}
        confirm="تأكيد التسوية"
        cancel="إلغاء"
        danger={false}
        loading={!!actionId}
        onConfirm={confirmSettle}
        onCancel={() => !actionId && setConfirmModal(null)}
      />

      {ledgerTeacher && (
        <TeacherLedgerModal teacher={ledgerTeacher} onClose={() => setLedgerTeacher(null)} />
      )}
    </div>
  )
}
