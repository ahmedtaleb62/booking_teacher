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
import Disputes from './pages/Disputes'
import Users from './pages/Users'
import Policy from './pages/Policy'
import Methods from './pages/Methods'
import Notifications from './pages/Notifications'

const PAGE_META = {
  overview:     { title: 'لوحة المراقبة',        sub: 'مرحباً بك في لوحة تحكم سولني' },
  sessions:     { title: 'مراقبة الجلسات',        sub: 'جميع الجلسات المجدولة والنشطة والمكتملة' },
  payments:     { title: 'المدفوعات',             sub: 'مراجعة إثباتات الدفع وتأكيدها' },
  accounting:   { title: 'المحاسبة والتسويات',    sub: 'مستحقات الأساتذة والتسوية الشهرية' },
  subscriptions:{ title: 'الاشتراكات',            sub: 'اشتراكات الطلاب في الدروس والباقات' },
  courses:      { title: 'الدروس',               sub: 'إدارة الدروس والمحتوى التعليمي' },
  addCourse:    { title: 'إضافة درس جديد',        sub: 'أنشئ درساً جديداً وانشره للطلاب' },
  packages:     { title: 'الباقات',              sub: 'إدارة باقات الدروس المجمّعة' },
  teachers:     { title: 'اعتماد الأساتذة',       sub: 'مراجعة طلبات الانضمام والاعتماد' },
  ratings:      { title: 'التقييمات',            sub: 'تقييمات الطلاب للأساتذة' },
  disputes:     { title: 'النزاعات',             sub: 'إدارة النزاعات والشكاوى' },
  users:        { title: 'المستخدمون',           sub: 'إدارة حسابات الطلاب والأساتذة' },
  policy:       { title: 'السياسات والعمولات',    sub: 'ضبط عمولات المنصة وسياسات التشغيل' },
  methods:       { title: 'طرق الدفع',            sub: 'إدارة طرق الدفع المتاحة للطلاب' },
  notifications: { title: 'الإشعارات',           sub: 'الإشعارات الواردة وإرسال إشعارات للمستخدمين' },
}

const PAGES = {
  overview:     Overview,
  sessions:     Sessions,
  payments:     Payments,
  accounting:   Accounting,
  subscriptions:Subscriptions,
  courses:      Courses,
  addCourse:    AddCourse,
  packages:     Packages,
  teachers:     Teachers,
  ratings:      Ratings,
  disputes:     Disputes,
  users:        Users,
  policy:       Policy,
  methods:       Methods,
  notifications: Notifications,
}

export default function App() {
  const [session, setSession] = useState(null)
  const [loading, setLoading] = useState(true)
  const [page, setPage] = useState('overview')

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
      setLoading(false)
    })
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => subscription.unsubscribe()
  }, [])

  if (loading) return (
    <div className="loading-center" style={{ minHeight: '100vh' }}>
      <div className="spinner" />
    </div>
  )

  if (!session) return <Login />

  const meta = PAGE_META[page] || PAGE_META.overview
  const PageComponent = PAGES[page] || Overview

  const goTo = (p) => setPage(p)

  return (
    <ToastProvider>
      <Layout page={page} onNavigate={goTo} meta={meta}>
        <PageComponent onNavigate={goTo} adminId={session.user.id} />
      </Layout>
    </ToastProvider>
  )
}
