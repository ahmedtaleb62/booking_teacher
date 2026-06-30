import React, { useState, useEffect } from 'react'
import { supabase } from './supabase'
import { ToastProvider } from './components/Toast'
import Login from './pages/Login'
import Layout from './components/Layout'
import Overview from './pages/Overview'
import Sessions from './pages/Sessions'
import Payments from './pages/Payments'
import Accounting from './pages/Accounting'
import Subscriptions from './pages/Subscriptions'
import Courses from './pages/Courses'
import AddCourse from './pages/AddCourse'
import Packages from './pages/Packages'
import Teachers from './pages/Teachers'
import Ratings from './pages/Ratings'
import Users from './pages/Users'
import Policy from './pages/Policy'
import Methods from './pages/Methods'
import Notifications from './pages/Notifications'
import Settings from './pages/Settings'

const PAGE_META = {
  overview:     { title: 'لوحة المراقبة',        sub: 'مرحباً بك في لوحة تحكم حصتي' },
  sessions:     { title: 'مراقبة الجلسات',        sub: 'جميع الجلسات المجدولة والنشطة والمكتملة' },
  payments:     { title: 'المدفوعات',             sub: 'مراجعة إثباتات الدفع وتأكيدها' },
  accounting:   { title: 'المحاسبة والتسويات',    sub: 'مستحقات الأساتذة والتسوية الشهرية' },
  subscriptions:{ title: 'الاشتراكات',            sub: 'اشتراكات الطلاب في الدروس والباقات' },
  courses:      { title: 'الدروس',               sub: 'إدارة الدروس والمحتوى التعليمي' },
  addCourse:    { title: 'إضافة درس جديد',        sub: 'أنشئ درساً جديداً وانشره للطلاب' },
  editCourse:   { title: 'تعديل الدرس',           sub: 'تعديل محتوى الدرس وإدارة فصوله' },
  packages:     { title: 'الباقات',              sub: 'إدارة باقات الدروس المجمّعة' },
  teachers:     { title: 'اعتماد الأساتذة',       sub: 'مراجعة طلبات الانضمام والاعتماد' },
  ratings:      { title: 'التقييمات',            sub: 'تقييمات الطلاب للأساتذة' },
  users:        { title: 'المستخدمون',           sub: 'إدارة حسابات الطلاب والأساتذة' },
  policy:       { title: 'السياسات والعمولات',    sub: 'ضبط عمولات المنصة وسياسات التشغيل' },
  methods:      { title: 'طرق الدفع',            sub: 'إدارة طرق الدفع المتاحة للطلاب' },
  notifications:{ title: 'الإشعارات',           sub: 'الإشعارات الواردة وإرسال إشعارات للمستخدمين' },
  settings:     { title: 'الإعدادات',            sub: 'رقم دعم العملاء وكلمة مرور المدير' },
}

const PAGES = {
  overview:     Overview,
  sessions:     Sessions,
  payments:     Payments,
  accounting:   Accounting,
  subscriptions:Subscriptions,
  courses:      Courses,
  addCourse:    AddCourse,
  editCourse:   AddCourse,
  packages:     Packages,
  teachers:     Teachers,
  ratings:      Ratings,
  users:        Users,
  policy:       Policy,
  methods:      Methods,
  notifications:Notifications,
  settings:     Settings,
}

export default function App() {
  const [session, setSession]     = useState(null)
  const [userRole, setUserRole]   = useState(null)
  const [loading, setLoading]     = useState(true)
  const [page, setPage]           = useState('overview')
  const [navParams, setNavParams] = useState({})
  const [badges, setBadges]       = useState({})

  async function fetchRole(userId) {
    const { data } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', userId)
      .single()
    setUserRole(data?.role ?? null)
  }

  async function fetchBadges() {
    try {
      const [payRes, teachRes, sessRes] = await Promise.all([
        supabase.from('payments').select('id', { count: 'exact', head: true }).eq('status', 'submitted'),
        supabase.from('teacher_profiles').select('id', { count: 'exact', head: true }).eq('is_approved', false),
        supabase.from('sessions').select('id', { count: 'exact', head: true }).eq('state', 'ACTIVE_SESSION'),
      ])
      setBadges({
        payments: payRes.count || 0,
        teachers: teachRes.count || 0,
        sessions: sessRes.count || 0,
      })
    } catch (_) {}
  }

  useEffect(() => {
    supabase.auth.getSession().then(async ({ data: { session: s } }) => {
      setSession(s)
      if (s) {
        await fetchRole(s.user.id)
        await fetchBadges()
      }
      setLoading(false)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (_e, s) => {
      setSession(s)
      if (s) {
        await fetchRole(s.user.id)
        await fetchBadges()
      } else {
        setUserRole(null)
        setBadges({})
      }
    })

    // Refresh badges every 60 seconds
    const interval = setInterval(fetchBadges, 60_000)
    return () => { subscription.unsubscribe(); clearInterval(interval) }
  }, [])

  if (loading) return (
    <div className="loading-center" style={{ minHeight: '100vh' }}>
      <div className="spinner" />
    </div>
  )

  if (!session || userRole !== 'admin') return <Login />

  const meta = PAGE_META[page] || PAGE_META.overview
  const PageComponent = PAGES[page] || Overview

  const goTo = (p, params = {}) => {
    setPage(p)
    setNavParams(params)
    fetchBadges()
  }

  return (
    <ToastProvider>
      <Layout page={page} onNavigate={goTo} meta={meta} badges={badges}>
        <PageComponent onNavigate={goTo} adminId={session.user.id} {...navParams} />
      </Layout>
    </ToastProvider>
  )
}
