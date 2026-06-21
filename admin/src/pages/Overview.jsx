import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'

export default function Overview({ onNavigate }) {
  const [stats, setStats] = useState(null)
  const [pending, setPending] = useState([])
  const [live, setLive] = useState([])
  const [weekData, setWeekData] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    loadData()
  }, [])

  async function loadData() {
    setLoading(true)
    const currentMonth = new Date().toISOString().slice(0, 7)
    const [sessRes, payRes, teachRes, subRes, subCommRes] = await Promise.all([
      supabase.from('sessions').select('id,state,amount,created_at').order('created_at', { ascending: false }),
      supabase.from('payments').select('id,status,amount,created_at').order('created_at', { ascending: false }),
      supabase.from('teacher_profiles').select('id,is_approved').eq('is_approved', false),
      supabase.from('subscriptions').select('id,status').eq('status', 'pending'),
      supabase.from('subscriptions').select('amount,platform_commission').eq('status', 'active').gte('started_at', currentMonth + '-01'),
    ])

    const sessions = sessRes.data || []
    const payments = payRes.data || []
    const teachersPending = teachRes.data || []
    const subsPending = subRes.data || []

    const today = new Date().toISOString().slice(0, 10)
    const todayPay = payments.filter(p => p.status === 'confirmed' && p.created_at?.startsWith(today))
    const todayRevenue = todayPay.reduce((s, p) => s + (p.amount || 0), 0)
    const commission = todayRevenue * 0.15

    const activeSubs = subCommRes.data || []
    const monthlySessionComm = payments
      .filter(p => p.status === 'confirmed' && p.created_at?.startsWith(currentMonth))
      .reduce((s, p) => s + (p.amount || 0) * 0.15, 0)
    const monthlySubComm = activeSubs.reduce((s, r) => s + (r.platform_commission ?? r.amount * 0.15), 0)

    setStats({
      totalSessions: sessions.length,
      activeSessions: sessions.filter(s => s.state === 'ACTIVE_SESSION').length,
      revenue: todayRevenue,
      commission,
      monthlySessionComm: Math.round(monthlySessionComm),
      monthlySubComm: Math.round(monthlySubComm),
      monthlyTotalComm: Math.round(monthlySessionComm + monthlySubComm),
      pendingPayments: payments.filter(p => p.status === 'submitted').length,
      pendingTeachers: teachersPending.length,
      pendingSubs: subsPending.length,
    })

    const liveNow = sessions.filter(s => s.state === 'ACTIVE_SESSION').slice(0, 4)
    setLive(liveNow)

    const last7Days = Array.from({ length: 7 }, (_, i) => {
      const d = new Date()
      d.setDate(d.getDate() - (6 - i))
      return d.toISOString().slice(0, 10)
    })
    const dayRevMap = {}
    payments.filter(p => p.status === 'confirmed').forEach(p => {
      const day = p.created_at?.slice(0, 10)
      if (day && last7Days.includes(day)) dayRevMap[day] = (dayRevMap[day] || 0) + (p.amount || 0)
    })
    setWeekData(last7Days.map(d => ({
      label: new Date(d + 'T12:00:00').toLocaleDateString('ar-EG', { weekday: 'short' }),
      revenue: dayRevMap[d] || 0,
    })))

    const pendingList = []
    if (payments.filter(p => p.status === 'submitted').length > 0)
      pendingList.push({ tag: 'دفع', bg: '#FEF3C7', fg: '#92400E', title: `${payments.filter(p => p.status === 'submitted').length} إثبات دفع بانتظار التأكيد`, sub: 'مدفوعات الجلسات', cta: 'مراجعة', page: 'payments' })
    if (subsPending.length > 0)
      pendingList.push({ tag: 'اشتر', bg: '#EDE9FE', fg: '#5B21B6', title: `${subsPending.length} اشتراك قيد المراجعة`, sub: 'اشتراكات الدروس والباقات', cta: 'مراجعة', page: 'subscriptions' })
    if (teachersPending.length > 0)
      pendingList.push({ tag: 'أست', bg: '#DBEAFE', fg: '#1D4ED8', title: `${teachersPending.length} طلب اعتماد أستاذ`, sub: 'طلبات الانضمام الجديدة', cta: 'مراجعة', page: 'teachers' })
    setPending(pendingList)
    setLoading(false)
  }

  if (loading) return <div className="loading-center"><div className="spinner" /></div>

  const kpis = [
    { icon: '💼', bg: '#E0E7FF', value: stats?.totalSessions || 0, label: 'إجمالي الجلسات', trend: '', trendColor: '#4F46E5' },
    { icon: '🎯', bg: '#D1FAE5', value: stats?.activeSessions || 0, label: 'نشطة الآن', trend: '', trendColor: '#059669' },
    { icon: '💰', bg: '#FEF3C7', value: `${(stats?.revenue || 0).toLocaleString('ar')}`, label: 'إيرادات اليوم (أوقية)', trend: '', trendColor: '#D97706' },
    { icon: '📊', bg: '#EDE9FE', value: `${(stats?.commission || 0).toLocaleString('ar')}`, label: 'عمولة المنصة اليوم', trend: '', trendColor: '#7C3AED' },
  ]

  return (
    <div>
      {/* KPIs */}
      <div className="kpi-grid">
        {kpis.map((k, i) => (
          <div key={i} className="kpi-card">
            <div className="flex justify-between items-center">
              <div className="kpi-icon" style={{ background: k.bg, fontSize: 20 }}>{k.icon}</div>
              {k.trend && <span className="kpi-trend" style={{ color: k.trendColor }}>{k.trend}</span>}
            </div>
            <div className="kpi-value">{k.value}</div>
            <div className="kpi-label">{k.label}</div>
          </div>
        ))}
      </div>

      <div className="grid-14">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          {/* Revenue split */}
          <div className="card">
            <div className="flex justify-between items-center mb-14">
              <span className="card-title">الإيرادات وعمولة المنصة</span>
              <span style={{ fontSize: 12, color: 'var(--text3)' }}>هذا الشهر</span>
            </div>
            <div style={{ display: 'flex', gap: 14 }}>
              <div style={{ flex: 1, background: '#F5F7FF', borderRadius: 12, padding: 15 }}>
                <div style={{ fontSize: 11.5, color: 'var(--text3)' }}>عمولة الجلسات (15%)</div>
                <div style={{ fontSize: 21, fontWeight: 700, color: '#4F46E5', marginTop: 3 }}>{stats?.monthlySessionComm?.toLocaleString('ar') ?? '—'}</div>
                <div style={{ fontSize: 10.5, color: 'var(--text3)' }}>أوقية</div>
              </div>
              <div style={{ flex: 1, background: '#F5F7FF', borderRadius: 12, padding: 15 }}>
                <div style={{ fontSize: 11.5, color: 'var(--text3)' }}>عمولة الاشتراكات (15%)</div>
                <div style={{ fontSize: 21, fontWeight: 700, color: '#7C3AED', marginTop: 3 }}>{stats?.monthlySubComm?.toLocaleString('ar') ?? '—'}</div>
                <div style={{ fontSize: 10.5, color: 'var(--text3)' }}>أوقية</div>
              </div>
              <div style={{ flex: 1, background: '#1E1B4B', borderRadius: 12, padding: 15, color: '#fff' }}>
                <div style={{ fontSize: 11.5, color: 'rgba(255,255,255,.55)' }}>إجمالي عمولة الشهر</div>
                <div style={{ fontSize: 21, fontWeight: 700, color: '#A5B4FC', marginTop: 3 }}>{stats?.monthlyTotalComm?.toLocaleString('ar') ?? '—'}</div>
                <div style={{ fontSize: 10.5, color: 'rgba(255,255,255,.4)' }}>أوقية</div>
              </div>
            </div>
            {/* Mini chart bars — last 7 days real data */}
            {weekData.length > 0 && (() => {
              const maxRev = Math.max(...weekData.map(d => d.revenue), 1)
              return (
                <div style={{ display: 'flex', alignItems: 'flex-end', gap: 9, height: 90, marginTop: 18 }}>
                  {weekData.map((d, i) => {
                    const pct = Math.max(8, Math.round((d.revenue / maxRev) * 100))
                    const isToday = i === weekData.length - 1
                    return (
                      <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, height: '100%', justifyContent: 'flex-end' }}>
                        <div style={{ width: '100%', borderRadius: 6, background: isToday ? '#818CF8' : '#4F46E5', height: `${pct}%` }} />
                        <span style={{ fontSize: 10, color: 'var(--text3)' }}>{d.label}</span>
                      </div>
                    )
                  })}
                </div>
              )
            })()}
          </div>

          {/* Pending actions */}
          {pending.length > 0 && (
            <div className="card">
              <div className="flex justify-between items-center mb-14">
                <span className="card-title">بانتظار إجراء منك</span>
                <span style={{ background: '#FDECEC', color: '#C0392B', fontSize: 11, fontWeight: 700, padding: '4px 10px', borderRadius: 999 }}>{pending.length} عناصر</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
                {pending.map((p, i) => (
                  <div key={i} onClick={() => onNavigate(p.page)} style={{ display: 'flex', alignItems: 'center', gap: 12, border: '1px solid var(--border-table)', borderRadius: 12, padding: 12, cursor: 'pointer' }}>
                    <span style={{ width: 36, height: 36, borderRadius: 10, background: p.bg, color: p.fg, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none', fontWeight: 700, fontSize: 11 }}>{p.tag}</span>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontSize: 13, fontWeight: 700 }}>{p.title}</div>
                      <div style={{ fontSize: 11, color: 'var(--text3)' }}>{p.sub}</div>
                    </div>
                    <span style={{ background: 'var(--primary-btn)', color: '#fff', fontSize: 11.5, fontWeight: 700, padding: '7px 14px', borderRadius: 9 }}>{p.cta}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>

        {/* Live sessions */}
        <div className="card" style={{ alignSelf: 'flex-start' }}>
          <div className="flex items-center gap-8 mb-14">
            <span className="live-dot" />
            <span className="card-title">جلسات نشطة الآن</span>
          </div>
          {live.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '24px 0', color: 'var(--text3)', fontSize: 13 }}>لا توجد جلسات نشطة</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {live.map(s => (
                <div key={s.id} style={{ border: '1px solid var(--border-table)', borderRadius: 12, padding: 13 }}>
                  <div className="flex justify-between items-center">
                    <span style={{ fontSize: 12.5, fontWeight: 700 }}>جلسة نشطة</span>
                    <span style={{ fontSize: 11, fontWeight: 700, color: '#16A34A', direction: 'ltr' }}>LIVE</span>
                  </div>
                  <div style={{ fontSize: 11, color: 'var(--text3)', marginTop: 4 }}>{s.id.slice(0, 8)}…</div>
                  <div style={{ height: 4, borderRadius: 2, background: '#EDF0F2', marginTop: 9, overflow: 'hidden' }}>
                    <span style={{ display: 'block', height: '100%', width: '60%', background: '#16A34A' }} />
                  </div>
                </div>
              ))}
            </div>
          )}

          <div style={{ borderTop: '1px solid var(--border-table)', marginTop: 14, paddingTop: 14 }}>
            <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 10 }}>آخر النزاعات</div>
            <div onClick={() => onNavigate('disputes')} style={{ display: 'flex', alignItems: 'center', gap: 10, background: '#FDECEC', borderRadius: 11, padding: 11, cursor: 'pointer' }}>
              <span style={{ color: '#C0392B', fontSize: 20 }}>🛡</span>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 12, fontWeight: 700 }}>النزاعات المفتوحة</div>
                <div style={{ fontSize: 10.5, color: '#8A5A5A' }}>مراجعة وحل النزاعات</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
