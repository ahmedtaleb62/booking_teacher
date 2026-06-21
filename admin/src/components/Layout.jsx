import React from 'react'
import { supabase } from '../supabase'

const NAV_SECTIONS = [
  {
    label: 'الرئيسية',
    items: [
      { id: 'overview', label: 'لوحة المراقبة', icon: <IcoGrid /> },
    ],
  },
  {
    label: 'المالية',
    items: [
      { id: 'payments',   label: 'المدفوعات',   icon: <IcoCash /> },
      { id: 'accounting', label: 'المحاسبة',     icon: <IcoCalc /> },
      { id: 'methods',    label: 'طرق الدفع',    icon: <IcoCard /> },
      { id: 'policy',     label: 'السياسات',     icon: <IcoSettings /> },
    ],
  },
  {
    label: 'المحتوى',
    items: [
      { id: 'courses',  label: 'الدروس',  icon: <IcoBook /> },
      { id: 'packages', label: 'الباقات', icon: <IcoLayers /> },
    ],
  },
  {
    label: 'المستخدمون',
    items: [
      { id: 'teachers', label: 'اعتماد الأساتذة', icon: <IcoUsers /> },
      { id: 'ratings',  label: 'التقييمات',       icon: <IcoStar /> },
      { id: 'users',    label: 'المستخدمون',      icon: <IcoPerson /> },
    ],
  },
  {
    label: 'المتابعة',
    items: [
      { id: 'sessions',      label: 'الجلسات',      icon: <IcoVideo /> },
      { id: 'subscriptions', label: 'الاشتراكات',   icon: <IcoBadge /> },
      { id: 'disputes',      label: 'النزاعات',     icon: <IcoShield /> },
      { id: 'notifications', label: 'الإشعارات',    icon: <IcoBell /> },
    ],
  },
]

export default function Layout({ page, onNavigate, meta, children }) {
  const handleLogout = async () => {
    await supabase.auth.signOut()
  }

  const today = new Date().toLocaleDateString('ar-EG', { year: 'numeric', month: 'long', day: 'numeric' })

  return (
    <div className="admin-shell">
      {/* ── Sidebar ── */}
      <aside className="admin-sidebar">
        <div className="sidebar-brand">
          <div className="brand-icon">س</div>
          <div>
            <div className="brand-name">سولني</div>
            <div className="brand-sub">لوحة تحكم الإدارة</div>
          </div>
        </div>

        <nav className="sidebar-nav">
          {NAV_SECTIONS.map(sec => (
            <div key={sec.label}>
              <div className="nav-section-label">{sec.label}</div>
              {sec.items.map(item => (
                <div
                  key={item.id}
                  className={`nav-item${page === item.id || (page === 'addCourse' && item.id === 'courses') ? ' active' : ''}`}
                  onClick={() => onNavigate(item.id)}
                >
                  {item.icon}
                  <span style={{ flex: 1 }}>{item.label}</span>
                  {item.badge != null && <span className="nav-badge">{item.badge}</span>}
                </div>
              ))}
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="footer-avatar">أ</div>
          <div style={{ flex: 1 }}>
            <div className="footer-name">المدير</div>
            <div className="footer-role">مدير النظام</div>
          </div>
          <span style={{ color: 'rgba(255,255,255,.4)', cursor: 'pointer' }} onClick={handleLogout} title="تسجيل خروج">
            <IcoLogout />
          </span>
        </div>
      </aside>

      {/* ── Main ── */}
      <main className="admin-main">
        <header className="admin-header">
          <div>
            <div className="header-title">{meta.title}</div>
            <div className="header-sub">{meta.sub}</div>
          </div>
          <div className="flex items-center gap-12">
            <div className="header-search">
              <IcoSearch /> بحث…
            </div>
            <div className="header-notif">
              <IcoBell />
              <span className="header-notif-dot" />
            </div>
            <div className="header-date">
              <IcoCalIcon /> {today}
            </div>
          </div>
        </header>
        <div className="admin-content">
          {children}
        </div>
      </main>
    </div>
  )
}

/* ── Icons ── */
function IcoGrid() {
  return (
    <svg viewBox="0 0 20 20" fill="currentColor">
      <rect x="2" y="2" width="7" height="7" rx="1.5"/>
      <rect x="11" y="2" width="7" height="7" rx="1.5"/>
      <rect x="2" y="11" width="7" height="7" rx="1.5"/>
      <rect x="11" y="11" width="7" height="7" rx="1.5"/>
    </svg>
  )
}
function IcoCash() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><rect x="2" y="5" width="16" height="11" rx="2"/><path d="M2 8h16M6 13h2"/></svg>
}
function IcoCalc() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><rect x="3" y="2" width="14" height="16" rx="2"/><path d="M7 7h6M7 10h2M11 10h2M7 13h2M11 13h2"/></svg>
}
function IcoCard() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><rect x="2" y="5" width="16" height="11" rx="2"/><path d="M2 9h16M5 13h3"/></svg>
}
function IcoSettings() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><circle cx="10" cy="10" r="2.5"/><path d="M10 2v2M10 16v2M2 10h2M16 10h2M4.22 4.22l1.41 1.41M14.37 14.37l1.41 1.41M4.22 15.78l1.41-1.41M14.37 5.63l1.41-1.41"/></svg>
}
function IcoBook() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M3 4a1 1 0 011-1h5v14H4a1 1 0 01-1-1V4z"/><path d="M11 3h5a1 1 0 011 1v12a1 1 0 01-1 1h-5V3z"/></svg>
}
function IcoLayers() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M10 2l8 4-8 4-8-4 8-4z"/><path d="M2 10l8 4 8-4"/><path d="M2 14l8 4 8-4"/></svg>
}
function IcoUsers() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><circle cx="7" cy="7" r="3"/><path d="M1 18a6 6 0 0112 0"/><path d="M15 5a3 3 0 110 6"/><path d="M19 18a5 5 0 00-4-4.9"/></svg>
}
function IcoStar() {
  return <svg viewBox="0 0 20 20" fill="currentColor"><path d="M10 1l2.39 5.26L18 7.27l-4 3.89.94 5.5L10 14.01 5.06 16.66 6 11.16 2 7.27l5.61-.01L10 1z" opacity=".9"/></svg>
}
function IcoPerson() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><circle cx="10" cy="7" r="3.5"/><path d="M3 18a7 7 0 0114 0"/></svg>
}
function IcoVideo() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><rect x="2" y="5" width="12" height="10" rx="2"/><path d="M14 8l4-2v8l-4-2"/></svg>
}
function IcoBadge() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><circle cx="10" cy="9" r="5"/><path d="M6.7 13.6L5 18l5-2 5 2-1.7-4.4"/></svg>
}
function IcoShield() {
  return <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M10 2l7 3v5c0 4-3 7-7 8-4-1-7-4-7-8V5l7-3z"/></svg>
}
function IcoLogout() {
  return <svg width="18" height="18" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M13 15l4-5-4-5"/><path d="M17 10H7"/><path d="M7 3H4a1 1 0 00-1 1v12a1 1 0 001 1h3"/></svg>
}
function IcoSearch() {
  return <svg width="15" height="15" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="9" cy="9" r="6"/><path d="M15 15l3 3"/></svg>
}
function IcoBell() {
  return <svg width="18" height="18" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><path d="M10 2a6 6 0 00-6 6v3l-1.5 2h15L16 11V8a6 6 0 00-6-6z"/><path d="M8 15a2 2 0 004 0"/></svg>
}
function IcoCalIcon() {
  return <svg width="15" height="15" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6"><rect x="3" y="4" width="14" height="13" rx="2"/><path d="M3 8h14M7 2v4M13 2v4"/></svg>
}
