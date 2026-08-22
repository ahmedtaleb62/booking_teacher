import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

const WEEKDAY_SHORT = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت']

/* ── Reschedule modal: pick a new time from the teacher's real availability ── */
function RescheduleModal({ session, onClose, onDone, adminId }) {
  const toast = useToast()
  const [availability, setAvailability] = useState([])
  const [bookedByDay, setBookedByDay]   = useState({}) // { 'YYYY-MM-DD': [Date, ...] }
  const [loading, setLoading]           = useState(true)
  const [selectedDayIdx, setSelectedDayIdx] = useState(0)
  const [selectedSlot, setSelectedSlot]     = useState(null) // { h, m }
  const [saving, setSaving]                 = useState(false)

  const days = Array.from({ length: 14 }, (_, i) => {
    const d = new Date()
    d.setDate(d.getDate() + i)
    d.setHours(0, 0, 0, 0)
    return d
  })

  useEffect(() => {
    (async () => {
      const { data: avail } = await supabase
        .from('teacher_availability')
        .select('day_of_week, start_time, end_time')
        .eq('teacher_id', session.teacher_id)
        .eq('is_active', true)

      const rangeStart = new Date(); rangeStart.setHours(0, 0, 0, 0)
      const rangeEnd = new Date(rangeStart); rangeEnd.setDate(rangeEnd.getDate() + 14)
      const { data: booked } = await supabase
        .from('sessions')
        .select('id, scheduled_at')
        .eq('teacher_id', session.teacher_id)
        .gte('scheduled_at', rangeStart.toISOString())
        .lt('scheduled_at', rangeEnd.toISOString())
        .not('state', 'in', '(TEACHER_REJECTED,CANCELLED)')

      const byDay = {}
      ;(booked || []).forEach(b => {
        if (b.id === session.id) return // exclude the session being rescheduled itself
        const key = b.scheduled_at.slice(0, 10)
        if (!byDay[key]) byDay[key] = []
        byDay[key].push(new Date(b.scheduled_at))
      })

      setAvailability(avail || [])
      setBookedByDay(byDay)
      setLoading(false)
    })()
  }, [session.id, session.teacher_id])

  function slotsForDay(day) {
    const dayOfWeek = day.getDay()
    const duration = session.duration_minutes
    const ranges = availability.filter(a => a.day_of_week === dayOfWeek)
    if (ranges.length === 0) return []

    const now = new Date()
    const isToday = day.toDateString() === now.toDateString()
    const dayKey = day.toISOString().slice(0, 10)
    const bookedTimes = bookedByDay[dayKey] || []

    const slots = []
    for (const range of ranges) {
      const [sH, sM] = range.start_time.split(':').map(Number)
      const [eH, eM] = range.end_time.split(':').map(Number)
      let h = sH, m = sM
      while (true) {
        const slotEndMin = h * 60 + m + duration
        if (slotEndMin > eH * 60 + eM) break

        const slotStart = new Date(day); slotStart.setHours(h, m, 0, 0)
        if (isToday && slotStart.getTime() < now.getTime() + 30 * 60000) {
          m += duration; h += Math.floor(m / 60); m = m % 60
          continue
        }

        const isBooked = bookedTimes.some(bt => Math.abs(bt.getTime() - slotStart.getTime()) / 60000 < duration)
        const period = h >= 12 ? 'م' : 'ص'
        const h12 = h === 0 ? 12 : (h > 12 ? h - 12 : h)
        slots.push({ h, m, label: `${h12}:${String(m).padStart(2, '0')} ${period}`, booked: isBooked })

        m += duration; h += Math.floor(m / 60); m = m % 60
      }
    }
    return slots
  }

  async function confirm() {
    if (!selectedSlot) return
    const day = days[selectedDayIdx]
    const newDt = new Date(day)
    newDt.setHours(selectedSlot.h, selectedSlot.m, 0, 0)

    setSaving(true)
    try {
      const { error } = await supabase.rpc('admin_reschedule_session', {
        p_session_id: session.id, p_admin_id: adminId, p_new_scheduled_at: newDt.toISOString(),
      })
      if (error) throw error
      toast('تمت إعادة جدولة الجلسة وإشعار الطرفين', 'success')
      onDone()
    } catch (err) {
      toast('خطأ: ' + (err.message || 'حدث خطأ'), 'error')
    } finally {
      setSaving(false)
    }
  }

  const currentSlots = loading ? [] : slotsForDay(days[selectedDayIdx])

  return (
    <div
      style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.55)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1100 }}
      onClick={() => !saving && onClose()}
    >
      <div
        style={{ background: '#fff', borderRadius: 20, padding: 28, width: 640, maxWidth: '96vw', maxHeight: '90vh', overflowY: 'auto' }}
        onClick={e => e.stopPropagation()}
      >
        <div style={{ fontSize: 17, fontWeight: 800, marginBottom: 4 }}>إعادة جدولة الجلسة</div>
        <div style={{ fontSize: 12, color: 'var(--text3)', marginBottom: 20 }}>
          {session.studentName} ← {session.teacherName} · {session.duration_minutes} دقيقة
        </div>

        {loading ? (
          <div style={{ textAlign: 'center', padding: 30 }}><div className="spinner" /></div>
        ) : (
          <>
            {/* Day picker */}
            <div style={{ display: 'flex', gap: 8, overflowX: 'auto', paddingBottom: 8, marginBottom: 16 }}>
              {days.map((d, i) => {
                const hasAvail = availability.some(a => a.day_of_week === d.getDay())
                const sel = i === selectedDayIdx
                return (
                  <button
                    key={i}
                    onClick={() => { setSelectedDayIdx(i); setSelectedSlot(null) }}
                    disabled={!hasAvail}
                    style={{
                      flexShrink: 0, minWidth: 58, padding: '8px 6px', borderRadius: 10, cursor: hasAvail ? 'pointer' : 'not-allowed',
                      border: sel ? '1.5px solid var(--primary)' : '1px solid var(--border)',
                      background: sel ? 'var(--primary)' : hasAvail ? '#fff' : '#F7F9FA',
                      color: sel ? '#fff' : hasAvail ? 'var(--text1)' : 'var(--text3)',
                      opacity: hasAvail ? 1 : 0.5,
                    }}
                  >
                    <div style={{ fontSize: 10, fontWeight: 700 }}>{WEEKDAY_SHORT[d.getDay()]}</div>
                    <div style={{ fontSize: 13, fontWeight: 700 }}>{d.getDate()}/{d.getMonth() + 1}</div>
                  </button>
                )
              })}
            </div>

            {/* Slot grid */}
            {currentSlots.length === 0 ? (
              <div style={{ textAlign: 'center', padding: 24, color: 'var(--text3)', fontSize: 13, background: '#F7F9FA', borderRadius: 12 }}>
                لا توجد أوقات متاحة لهذا الأستاذ في هذا اليوم
              </div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginBottom: 20 }}>
                {currentSlots.map((s, i) => {
                  const sel = selectedSlot && selectedSlot.h === s.h && selectedSlot.m === s.m
                  return (
                    <button
                      key={i}
                      disabled={s.booked}
                      onClick={() => setSelectedSlot({ h: s.h, m: s.m })}
                      style={{
                        padding: '9px 4px', borderRadius: 9, fontSize: 12.5, fontWeight: 700, cursor: s.booked ? 'not-allowed' : 'pointer',
                        border: sel ? '1.5px solid var(--primary)' : '1px solid var(--border)',
                        background: s.booked ? '#F1F5F9' : sel ? 'var(--primary)' : '#fff',
                        color: s.booked ? '#B0BEC5' : sel ? '#fff' : 'var(--text1)',
                        textDecoration: s.booked ? 'line-through' : 'none',
                      }}
                    >
                      {s.label}
                    </button>
                  )
                })}
              </div>
            )}

            <div style={{ display: 'flex', gap: 10 }}>
              <button className="btn btn-secondary" style={{ flex: 1 }} onClick={onClose} disabled={saving}>إلغاء</button>
              <button className="btn btn-primary" style={{ flex: 2, justifyContent: 'center' }} disabled={!selectedSlot || saving} onClick={confirm}>
                {saving ? '...جارٍ الحفظ' : '✓ تأكيد الموعد الجديد'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

/* ── Readable labels for DB enum values ─────────────────────── */
const CANCEL_REASON_LABELS = {
  teacher_timeout:        'انتهت مهلة رد الأستاذ — إلغاء تلقائي',
  payment_timeout:        'انتهت مهلة الدفع — إلغاء تلقائي',
  student_cancelled:      'إلغاء الطالب',
  fake_proof:             'الوصل مزيف — مرفوض نهائياً',
  insufficient_refund:    'مبلغ ناقص — سيُستَرد',
  no_payment_deadline:    'انتهت مهلة الدفع — لم يُرسَل إثبات',
  teacher_no_show_refund: 'غياب الأستاذ — سيُستَرد',
  admin_cancelled:        'ألغتها الإدارة',
}

const REJECT_REASON_LABELS = {
  FAKE_PROOF:        'الوصل مزيف',
  INCOMPLETE_AMOUNT: 'المبلغ غير مكتمل',
}

const STATE_MAP = {
  REQUESTED:         ['بانتظار الأستاذ',  '#FBEFD6', '#92620F'],
  TEACHER_APPROVED:  ['وافق الأستاذ',     '#DEEAF7', '#1F5C99'],
  AWAITING_PAYMENT:  ['انتظار الدفع',     '#FBEFD6', '#92620F'],
  PAYMENT_SUBMITTED: ['دفع مُرسَل',        '#ECE5F7', '#5A3B95'],
  PAYMENT_REJECTED:  ['دفع مرفوض',        '#FBE0DB', '#A12B1D'],
  CONFIRMED_BOOKING: ['محجوز',            '#D7F2E6', '#0A6E4E'],
  ACTIVE_SESSION:    ['جارية',            '#D7F2E6', '#0A6E4E'],
  COMPLETED:         ['مكتملة',           '#F1F5F3', '#566963'],
  CANCELLED:         ['ملغية',            '#FBE0DB', '#A12B1D'],
  TEACHER_REJECTED:  ['رفض الأستاذ',     '#FBE0DB', '#A12B1D'],
}

const EVENT_LABELS = {
  REQUESTED:         { label: 'أرسل الطالب طلب الجلسة',          icon: '📩' },
  TEACHER_APPROVED:  { label: 'وافق الأستاذ على الطلب',           icon: '✅' },
  AWAITING_PAYMENT:  { label: 'في انتظار إثبات الدفع من الطالب',  icon: '💳' },
  PAYMENT_SUBMITTED: { label: 'أرسل الطالب إثبات الدفع',          icon: '🧾' },
  PAYMENT_REJECTED:  { label: 'رفض الإدارة إثبات الدفع',          icon: '❌' },
  CONFIRMED_BOOKING: { label: 'تأكيد الحجز — الجلسة مجدولة',     icon: '📅' },
  ACTIVE_SESSION:    { label: 'بدأت الجلسة',                       icon: '🔴' },
  COMPLETED:         { label: 'اكتملت الجلسة بنجاح',              icon: '🏁' },
  CANCELLED:         { label: 'أُلغيت الجلسة',                     icon: '🚫' },
  TEACHER_REJECTED:  { label: 'رفض الأستاذ طلب الجلسة',           icon: '🙅' },
  PAYMENT_CONFIRMED: { label: 'تأكدت الدفعة',                     icon: '✅' },
}

function StateBadge({ state }) {
  const [label, bg, fg] = STATE_MAP[state] || [state, '#F1F3F5', '#516170']
  return (
    <span style={{ fontSize: 11, fontWeight: 700, padding: '3px 9px', borderRadius: 6, background: bg, color: fg, whiteSpace: 'nowrap' }}>
      {label}
    </span>
  )
}

/* Build timeline from DB events + infer missing steps from session fields + payments */
function buildTimeline(dbEvents, s, payments = []) {
  // If DB has real events, use them
  if (dbEvents.length > 0) return dbEvents.map(ev => ({
    event_type: ev.event_type,
    created_at: ev.created_at,
    note:       ev.note || ev.metadata?.reason || ev.metadata?.reject_reason ||
                (ev.event_type === 'CANCELLED' && s.cancellation_reason
                  ? CANCEL_REASON_LABELS[s.cancellation_reason] || s.cancellation_reason
                  : ''),
    synthetic:  false,
  }))

  const steps = []
  const push  = (event_type, created_at, note = '') =>
    steps.push({ event_type, created_at, note, synthetic: true })

  const state        = s.state
  const pay          = payments[0]                          // most recent payment
  const hadPayment   = payments.length > 0
  const rejectedPay  = payments.find(p => p.status === 'rejected')
  const approxApproval = s.payment_deadline
    ? new Date(new Date(s.payment_deadline).getTime() - 60 * 60 * 1000).toISOString()
    : s.updated_at

  // ── Step 1: always REQUESTED ────────────────────────────────────
  push('REQUESTED', s.created_at)

  // ── Step 2: teacher rejected early ─────────────────────────────
  if (state === 'TEACHER_REJECTED') {
    push('TEACHER_REJECTED', s.updated_at, s.rejection_reason || '')
    return steps
  }

  // ── Step 3: teacher approved → AWAITING_PAYMENT ────────────────
  // Skip if teacher never responded (teacher_timeout cancellation)
  const teacherTimedOut = state === 'CANCELLED' && s.cancellation_reason === 'teacher_timeout'
  if (state !== 'REQUESTED' && !teacherTimedOut) {
    push('TEACHER_APPROVED',  approxApproval)
    push('AWAITING_PAYMENT',  approxApproval)
  }

  // ── Step 4: payment submitted ───────────────────────────────────
  if (hadPayment || ['PAYMENT_SUBMITTED','PAYMENT_REJECTED','CONFIRMED_BOOKING',
                     'ACTIVE_SESSION','COMPLETED'].includes(state)) {
    push('PAYMENT_SUBMITTED', pay?.created_at || s.updated_at)
  }

  // ── Step 5: payment rejected — only for non-CANCELLED states ──
  // For CANCELLED, we derive the rejection note from cancellation_reason (source of truth),
  // not from payment.reject_reason, to avoid contradictions (e.g. fake_proof + insufficient_refund).
  if (rejectedPay && state !== 'CANCELLED') {
    const reason = rejectedPay.reject_reason || ''
    const isFake = reason.toLowerCase().includes('fake') || reason.includes('مزيف')
    push('PAYMENT_REJECTED', rejectedPay.confirmed_at || rejectedPay.updated_at,
      isFake ? 'الوصل مزيف' : reason || 'رُفض الوصل')
  }

  // ── CANCELLED ──────────────────────────────────────────────────
  if (state === 'CANCELLED') {
    const cr       = s.cancellation_reason
    const payTs    = rejectedPay?.confirmed_at || rejectedPay?.updated_at || s.updated_at

    if (cr === 'teacher_timeout') {
      push('CANCELLED', s.updated_at, 'انتهت مهلة رد الأستاذ — أُلغيت تلقائياً')

    } else if (cr === 'payment_timeout') {
      push('CANCELLED', s.updated_at, 'انتهت مهلة الدفع — أُلغيت تلقائياً')

    } else if (cr === 'student_cancelled') {
      push('CANCELLED', s.updated_at, 'ألغى الطالب الجلسة')

    } else if (cr === 'fake_proof') {
      push('PAYMENT_REJECTED', payTs, 'الوصل مزيف')
      push('CANCELLED', s.updated_at, 'الوصل مزيف — مرفوض نهائياً · لا استرداد')

    } else if (cr === 'insufficient_refund') {
      push('PAYMENT_REJECTED', payTs, 'المبلغ غير مكتمل')
      push('CANCELLED', s.updated_at, 'مبلغ ناقص — سيُستَرد المبلغ تلقائياً')

    } else if (cr === 'no_payment_deadline') {
      push('CANCELLED', s.updated_at, 'انتهت مهلة الدفع — لم يُرسَل إثبات الدفع')

    } else if (cr === 'teacher_no_show_refund') {
      push('CANCELLED', s.updated_at, 'غياب الأستاذ — سيُستَرد المبلغ')

    } else if (hadPayment) {
      push('CANCELLED', s.updated_at, 'ملغاة بعد تقديم الدفع')

    } else {
      push('CANCELLED', s.updated_at, 'ملغاة')
    }
    return steps
  }

  // ── PAYMENT_REJECTED state (deadline still running) ─────────────
  if (state === 'PAYMENT_REJECTED') {
    if (!rejectedPay) push('PAYMENT_REJECTED', s.updated_at, s.rejection_reason || '')
    return steps
  }

  // ── Confirmed ──────────────────────────────────────────────────
  if (['CONFIRMED_BOOKING','ACTIVE_SESSION','COMPLETED'].includes(state)) {
    push('CONFIRMED_BOOKING', s.started_at
      ? new Date(new Date(s.started_at).getTime() - 5 * 60 * 1000).toISOString()
      : s.updated_at)
  }

  if (['ACTIVE_SESSION','COMPLETED'].includes(state) && s.started_at)
    push('ACTIVE_SESSION', s.started_at)

  if (state === 'COMPLETED' && s.ended_at)
    push('COMPLETED', s.ended_at)


  return steps
}

function Timeline({ events, payments, session }) {
  const fmtFull = dt => dt
    ? new Date(dt).toLocaleString('ar-EG-u-nu-latn', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
    : '—'

  const steps = buildTimeline(events, session, payments)

  return (
    <div style={{ position: 'relative', paddingRight: 30 }}>
      <div style={{ position: 'absolute', right: 10, top: 8, bottom: 8, width: 2, background: '#E2E8F0' }} />

      {steps.map((ev, i) => {
        const info   = EVENT_LABELS[ev.event_type] || { label: ev.event_type, icon: '•' }
        const isLast = i === steps.length - 1
        const [, bg, fg] = STATE_MAP[ev.event_type] || ['', '#F1F3F5', '#475569']

        return (
          <div key={i} style={{ display: 'flex', gap: 14, marginBottom: isLast ? 0 : 22, alignItems: 'flex-start' }}>
            <div style={{
              width: 24, height: 24, borderRadius: '50%',
              background: bg || '#E2E8F0', border: `2px solid ${fg || '#94A3B8'}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 12, flexShrink: 0, position: 'relative', zIndex: 1,
            }}>
              {info.icon}
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text1)' }}>{info.label}</div>
              {ev.note && (
                <div style={{ fontSize: 11, color: '#A12B1D', marginTop: 3, background: '#FBE0DB', borderRadius: 6, padding: '3px 8px', display: 'inline-block' }}>
                  {ev.note}
                </div>
              )}
              <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 3 }}>
                {fmtFull(ev.created_at)}
                {ev.synthetic && <span style={{ marginRight: 5, fontSize: 10, color: '#94A3B8' }}>(مُستنتج)</span>}
              </div>
            </div>
          </div>
        )
      })}
    </div>
  )
}

export default function Sessions({ adminId }) {
  const toast = useToast()
  const [rows, setRows]       = useState([])
  const [loading, setLoading] = useState(true)
  const [stats, setStats]     = useState({})
  const [modal, setModal]     = useState(null)   // { session, events, loadingEvents }
  const [cancelTarget, setCancelTarget] = useState(null) // session object
  const [cancelling, setCancelling]     = useState(false)
  const [rescheduleTarget, setRescheduleTarget] = useState(null) // session object

  useEffect(() => {
    loadData()
    const ch = supabase.channel('admin-sessions')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'sessions' }, () => loadData(true))
      .subscribe()
    return () => supabase.removeChannel(ch)
  }, [])

  async function loadData(silent = false) {
    if (!silent) setLoading(true)
    const { data } = await supabase
      .from('sessions')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200)

    const sessData = data || []
    const userIds = [...new Set([
      ...sessData.map(s => s.student_id),
      ...sessData.map(s => s.teacher_id),
    ].filter(Boolean))]

    const { data: profiles } = userIds.length
      ? await supabase.from('profiles').select('id, full_name').in('id', userIds)
      : { data: [] }
    const nameMap = Object.fromEntries((profiles || []).map(p => [p.id, p.full_name]))

    const sessions = sessData.map(s => ({
      ...s,
      teacherName: nameMap[s.teacher_id] || '—',
      studentName: nameMap[s.student_id] || '—',
    }))

    const today = new Date().toISOString().slice(0, 10)
    setStats({
      active:    sessions.filter(s => s.state === 'ACTIVE_SESSION').length,
      booked:    sessions.filter(s => s.state === 'CONFIRMED_BOOKING').length,
      cancelled: sessions.filter(s => s.state === 'CANCELLED' && s.created_at?.startsWith(today)).length,
      completed: sessions.filter(s => s.state === 'COMPLETED').length,
    })
    setRows(sessions)
    setLoading(false)
  }

  async function confirmCancel(refund) {
    setCancelling(true)
    try {
      const { error } = await supabase.rpc('admin_cancel_session', {
        p_session_id: cancelTarget.id, p_admin_id: adminId, p_refund: refund,
      })
      if (error) throw error
      toast(refund ? 'تم إلغاء الجلسة واسترداد المبلغ — تم إشعار الطالب والأستاذ' : 'تم إلغاء الجلسة وإشعار الطرفين', 'success')
      setCancelTarget(null)
      setModal(null)
      await loadData()
    } catch (err) {
      toast('خطأ: ' + (err.message || 'حدث خطأ'), 'error')
    } finally {
      setCancelling(false)
    }
  }

  async function openSession(s) {
    setModal({ session: s, events: [], payments: [], loadingEvents: true })
    const [evRes, payRes] = await Promise.all([
      supabase.from('session_events').select('*').eq('session_id', s.id).order('created_at', { ascending: true }),
      supabase.from('payments').select('*').eq('session_id', s.id).order('created_at', { ascending: true }),
    ])
    setModal(prev => prev
      ? { ...prev, events: evRes.data || [], payments: payRes.data || [], loadingEvents: false }
      : null
    )
  }

  const fmtDate = dt => dt
    ? new Date(dt).toLocaleString('ar-EG-u-nu-latn', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
    : '—'

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const COLS = '0.5fr 0.8fr 1fr 1fr 0.8fr 0.8fr 0.9fr 0.8fr'

  return (
    <div>
      {/* ── Stats ─────────────────────────────────────────────────── */}
      <div className="grid-4 mb-18">
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>نشطة الآن</div>
          <div className="flex items-center gap-8 mt-3">
            <span className="live-dot" />
            <span style={{ fontSize: 21, fontWeight: 700, color: '#16A34A' }}>{stats.active}</span>
          </div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>محجوزة قادمة</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: '#0A6E4E', marginTop: 3 }}>{stats.booked}</div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>ملغية اليوم</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: '#A12B1D', marginTop: 3 }}>{stats.cancelled}</div>
        </div>
        <div className="card-sm">
          <div className="text-muted" style={{ fontSize: 12 }}>مكتملة</div>
          <div style={{ fontSize: 21, fontWeight: 700, color: 'var(--text2)', marginTop: 3 }}>{stats.completed}</div>
        </div>
      </div>

      {/* ── Table ─────────────────────────────────────────────────── */}
      <div className="table-wrap">
        <div className="table-head" style={{ gridTemplateColumns: COLS }}>
          <span>#</span>
          <span>المادة</span>
          <span>الطالب</span>
          <span>الأستاذ</span>
          <span>المجدول</span>
          <span>المدة</span>
          <span>المبلغ</span>
          <span style={{ textAlign: 'left' }}>الحالة</span>
        </div>

        {rows.length === 0 && (
          <div style={{ padding: 24, textAlign: 'center', color: 'var(--text3)' }}>لا توجد جلسات</div>
        )}

        {rows.map(s => (
          <div
            key={s.id}
            className="table-row"
            style={{ gridTemplateColumns: COLS, cursor: 'pointer' }}
            onClick={() => openSession(s)}
            title="انقر لعرض تفاصيل الجلسة"
          >
            <span className="fw-700 dir-ltr" style={{ fontSize: 11, color: 'var(--text3)' }}>
              {s.id.slice(0, 6)}
            </span>
            <span className="text-2" style={{ fontSize: 12 }}>{s.subject}</span>
            <span style={{ fontSize: 12 }}>{s.studentName}</span>
            <span style={{ fontSize: 12 }}>{s.teacherName}</span>
            <span className="text-2 dir-ltr" style={{ fontSize: 11 }}>{fmtDate(s.scheduled_at)}</span>
            <span className="text-2" style={{ fontSize: 12 }}>{s.duration_minutes} د</span>
            <span className="fw-700" style={{ fontSize: 12 }}>{s.amount?.toLocaleString('en-US')}</span>
            <span style={{ textAlign: 'left' }}><StateBadge state={s.state} /></span>
          </div>
        ))}
      </div>

      {/* ── Session detail modal ───────────────────────────────────── */}
      {modal && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.45)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}
          onClick={() => setModal(null)}
        >
          <div
            style={{ background: '#fff', borderRadius: 20, padding: 28, width: 500, maxWidth: '95vw', maxHeight: '90vh', overflowY: 'auto' }}
            onClick={e => e.stopPropagation()}
          >
            {/* Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 18 }}>
              <div>
                <div style={{ fontSize: 16, fontWeight: 800 }}>{modal.session.subject}</div>
                <div style={{ fontSize: 12, color: 'var(--text3)', marginTop: 3 }}>
                  {modal.session.studentName} ← {modal.session.teacherName}
                </div>
              </div>
              <StateBadge state={modal.session.state} />
            </div>

            {/* Session info */}
            <div style={{ background: '#F2F7F5', borderRadius: 12, padding: 14, marginBottom: 22, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, fontSize: 12 }}>
              <div><span style={{ color: 'var(--text3)' }}>الموعد: </span><b>{fmtDate(modal.session.scheduled_at)}</b></div>
              <div><span style={{ color: 'var(--text3)' }}>المدة: </span><b>{modal.session.duration_minutes} دقيقة</b></div>
              <div><span style={{ color: 'var(--text3)' }}>المبلغ: </span><b>{modal.session.amount?.toLocaleString('en-US')} أوقية</b></div>
              <div><span style={{ color: 'var(--text3)' }}>المرجع: </span><b className="dir-ltr">{modal.session.id.slice(0, 8)}</b></div>
              {modal.session.rejection_reason && (() => {
                const raw   = (modal.session.rejection_reason || '').toUpperCase()
                const label = REJECT_REASON_LABELS[raw] || modal.session.rejection_reason
                return (
                  <div style={{ gridColumn: '1/-1' }}>
                    <span style={{ color: 'var(--text3)' }}>سبب الرفض: </span>
                    <b style={{ color: '#A12B1D' }}>{label}</b>
                  </div>
                )
              })()}
              {modal.session.cancellation_reason && (() => {
                const cr      = modal.session.cancellation_reason
                const label   = CANCEL_REASON_LABELS[cr] || cr
                const isRefund = cr === 'insufficient_refund' || cr === 'teacher_no_show_refund'
                const noPayment = cr === 'no_payment_deadline'
                const color   = isRefund ? '#5A3B95' : '#A12B1D'
                const bg      = isRefund ? '#ECE5F7' : noPayment ? '#FBEFD6' : '#FBE0DB'
                return (
                  <div style={{ gridColumn: '1/-1', display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ color: 'var(--text3)' }}>سبب الإلغاء: </span>
                    <span style={{ fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 6, background: bg, color }}>
                      {label}
                    </span>
                  </div>
                )
              })()}
              {modal.session.payment_deadline && !['CANCELLED','CONFIRMED_BOOKING','ACTIVE_SESSION','COMPLETED'].includes(modal.session.state) && (() => {
                const dl  = new Date(modal.session.payment_deadline)
                const exp = dl < new Date()
                return (
                  <div style={{ gridColumn: '1/-1' }}>
                    <span style={{ color: 'var(--text3)' }}>مهلة الدفع: </span>
                    <span style={{ fontWeight: 700, color: exp ? '#A12B1D' : '#92400E' }}>
                      {dl.toLocaleString('ar-EG-u-nu-latn', { dateStyle: 'short', timeStyle: 'short' })}
                      {exp ? ' ⚠ منتهية' : ''}
                    </span>
                  </div>
                )
              })()}
            </div>

            {/* Admin actions — only for a stuck confirmed booking nobody joined */}
            {modal.session.state === 'CONFIRMED_BOOKING' && (
              <div style={{ display: 'flex', gap: 10, marginBottom: 22 }}>
                <button
                  className="btn btn-sm"
                  style={{ flex: 1, justifyContent: 'center', background: '#FBE0DB', color: '#A12B1D', border: '1px solid #F3C5BD' }}
                  onClick={() => setCancelTarget(modal.session)}
                >
                  🚫 إلغاء الجلسة
                </button>
                <button
                  className="btn btn-sm"
                  style={{ flex: 1, justifyContent: 'center', background: '#DEEAF7', color: '#1F5C99', border: '1px solid #B9D2F0' }}
                  onClick={() => setRescheduleTarget(modal.session)}
                >
                  📅 إعادة جدولة
                </button>
              </div>
            )}

            {/* Timeline */}
            <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text2)', marginBottom: 14 }}>
              🕐 مسار الجلسة
            </div>

            {modal.loadingEvents
              ? <div style={{ textAlign: 'center', padding: '20px 0' }}><div className="spinner" /></div>
              : <Timeline events={modal.events} payments={modal.payments || []} session={modal.session} />
            }

            <button
              style={{ marginTop: 22, width: '100%', padding: '10px 0', borderRadius: 12, border: '1.5px solid var(--border)', background: 'var(--surface)', cursor: 'pointer', fontSize: 14, fontWeight: 600 }}
              onClick={() => setModal(null)}
            >
              إغلاق
            </button>
          </div>
        </div>
      )}

      {/* ── Cancel confirm ─────────────────────────────────────────── */}
      {cancelTarget && (
        <div
          style={{ position: 'fixed', inset: 0, background: 'rgba(30,27,75,.55)', backdropFilter: 'blur(2px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1100 }}
          onClick={() => !cancelling && setCancelTarget(null)}
        >
          <div
            style={{ background: '#fff', borderRadius: 20, padding: 26, width: 400, maxWidth: '95vw' }}
            onClick={e => e.stopPropagation()}
          >
            <div style={{ fontSize: 16, fontWeight: 800, marginBottom: 8 }}>إلغاء الجلسة</div>
            <div style={{ fontSize: 13, color: 'var(--text3)', marginBottom: 20, lineHeight: 1.6 }}>
              سيتم إلغاء هذه الجلسة نهائياً وإشعار الطالب والأستاذ. اختر هل تريد استرداد المبلغ
              ({cancelTarget.amount?.toLocaleString('en-US')} أوقية) للطالب أم لا. لا يمكن التراجع.
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              <button className="btn btn-danger" style={{ justifyContent: 'center' }} onClick={() => confirmCancel(true)} disabled={cancelling}>
                {cancelling ? '...جارٍ الإلغاء' : '💰 إلغاء مع استرداد المبلغ للطالب'}
              </button>
              <button className="btn btn-secondary" style={{ justifyContent: 'center' }} onClick={() => confirmCancel(false)} disabled={cancelling}>
                {cancelling ? '...جارٍ الإلغاء' : 'إلغاء بدون استرداد'}
              </button>
              <button className="btn" style={{ justifyContent: 'center' }} onClick={() => setCancelTarget(null)} disabled={cancelling}>تراجع</button>
            </div>
          </div>
        </div>
      )}

      {/* ── Reschedule ─────────────────────────────────────────────── */}
      {rescheduleTarget && (
        <RescheduleModal
          session={rescheduleTarget}
          adminId={adminId}
          onClose={() => setRescheduleTarget(null)}
          onDone={() => { setRescheduleTarget(null); setModal(null); loadData() }}
        />
      )}
    </div>
  )
}
