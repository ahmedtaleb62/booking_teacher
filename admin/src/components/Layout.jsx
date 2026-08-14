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
      { id: 'payments',   label: 'المدفوعات',   icon: <IcoCash />,     badgeKey: 'payments' },
      { id: 'accounting', label: 'المحاسبة',     icon: <IcoCalc /> },
      { id: 'methods',    label: 'طرق الدفع',    icon: <IcoCard /> },
      { id: 'policy',     label: 'السياسات',     icon: <IcoPolicy /> },
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
      { id: 'teachers', label: 'اعتماد الأساتذة', icon: <IcoTeacher />, badgeKey: 'teachers' },
      { id: 'ratings',  label: 'التقييمات',       icon: <IcoStar /> },
      { id: 'users',    label: 'المستخدمون',      icon: <IcoPerson /> },
    ],
  },
  {
    label: 'المتابعة',
    items: [
      { id: 'sessions',      label: 'الجلسات',    icon: <IcoVideo />,    badgeKey: 'sessions', badgeGreen: true },
      { id: 'subscriptions', label: 'الاشتراكات', icon: <IcoBadge /> },
      { id: 'notifications', label: 'الإشعارات',  icon: <IcoBell /> },
    ],
  },
  {
    label: 'النظام',
    items: [
      { id: 'settings', label: 'الإعدادات', icon: <IcoSettings /> },
    ],
  },
]

export default function Layout({ page, onNavigate, meta, badges = {}, children }) {
  const handleLogout = async () => {
    await supabase.auth.signOut()
  }

  const today = new Date().toLocaleDateString('ar-EG-u-nu-latn', { year: 'numeric', month: 'long', day: 'numeric' })

  return (
    <div className="admin-shell">
      {/* ── Sidebar ── */}
      <aside className="admin-sidebar">
        <div className="sidebar-brand">
          <div className="brand-icon">
            <svg viewBox="0 0 24 24" style={{ width: 22, height: 22, fill: 'none', stroke: '#fff', strokeWidth: 1.7, strokeLinecap: 'round', strokeLinejoin: 'round' }}>
              <path d="M3 9.5 12 5l9 4.5-9 4.5z"/>
              <path d="M7 11.5V16c0 1 2.2 2.4 5 2.4S17 17 17 16v-4.5"/>
              <path d="M21 9.5V14"/>
            </svg>
          </div>
          <div>
            <div className="brand-name">حصتي</div>
            <div className="brand-sub">لوحة تحكم الإدارة</div>
          </div>
        </div>

        <nav className="sidebar-nav">
          {NAV_SECTIONS.map(sec => (
            <div key={sec.label}>
              <div className="nav-section-label">{sec.label}</div>
              {sec.items.map(item => {
                const badge = item.badgeKey ? badges[item.badgeKey] : null
                const isActive = page === item.id || (page === 'addCourse' && item.id === 'courses') || (page === 'editCourse' && item.id === 'courses')
                return (
                  <div
                    key={item.id}
                    className={`nav-item${isActive ? ' active' : ''}`}
                    onClick={() => onNavigate(item.id)}
                  >
                    {item.icon}
                    <span style={{ flex: 1 }}>{item.label}</span>
                    {badge != null && badge > 0 && (
                      <span className={item.badgeGreen ? 'nav-badge-green' : 'nav-badge'}>{badge}</span>
                    )}
                  </div>
                )
              })}
            </div>
          ))}
        </nav>

        <div className="sidebar-footer">
          <div className="footer-avatar">أ</div>
          <div style={{ flex: 1 }}>
            <div className="footer-name">المدير</div>
            <div className="footer-role">مدير النظام</div>
          </div>
          <span
            style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'rgba(255,255,255,.65)', cursor: 'pointer', fontSize: 12, fontWeight: 700 }}
            onClick={handleLogout}
            title="تسجيل خروج"
          >
            <IcoLogout />
            تسجيل خروج
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
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="3" width="7" height="7" rx="1.5"/>
      <rect x="14" y="3" width="7" height="7" rx="1.5"/>
      <rect x="3" y="14" width="7" height="7" rx="1.5"/>
      <rect x="14" y="14" width="7" height="7" rx="1.5"/>
    </svg>
  )
}
function IcoCash() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="2.5" y="6" width="19" height="13" rx="2.5"/><path d="M2.5 10h19"/><path d="M6 15h3"/></svg>
}
function IcoCalc() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="4" y="2.5" width="16" height="19" rx="2.5"/><path d="M8 7h8M8 11h2.5M13.5 11H16M8 15h2.5M13.5 15H16"/></svg>
}
function IcoCard() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="2.5" y="5" width="19" height="14" rx="2.5"/><path d="M2.5 9.5h19"/></svg>
}
function IcoPolicy() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M5 6h14M5 12h14M5 18h14"/><circle cx="9" cy="6" r="2" fill="currentColor" stroke="none"/><circle cx="15" cy="12" r="2" fill="currentColor" stroke="none"/><circle cx="8" cy="18" r="2" fill="currentColor" stroke="none"/></svg>
}
function IcoBook() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M4 5a1 1 0 0 1 1-1h6v16H5a1 1 0 0 1-1-1z"/><path d="M13 4h6a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6z"/></svg>
}
function IcoLayers() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3 21 7.5 12 12 3 7.5z"/><path d="M3 12l9 4.5L21 12"/><path d="M3 16.5 12 21l9-4.5"/></svg>
}
function IcoTeacher() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="9" cy="8" r="3.2"/><path d="M3.5 19a5.5 5.5 0 0 1 11 0"/><path d="M16 9.5l1.8 1.8L21 8"/></svg>
}
function IcoStar() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3.5l2.6 5.3 5.9.9-4.25 4.1 1 5.85L12 17.1l-5.25 2.45 1-5.85L3.5 9.7l5.9-.9z"/></svg>
}
function IcoPerson() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="8" r="3.5"/><path d="M5 20a7 7 0 0 1 14 0"/></svg>
}
function IcoVideo() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="2.5" y="6" width="13" height="12" rx="2.5"/><path d="M15.5 10l6-3v10l-6-3"/></svg>
}
function IcoBadge() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="9" r="5.5"/><path d="M8.5 13.5 7 21l5-2.3L17 21l-1.5-7.5"/></svg>
}
function IcoLogout() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M15 17l4-5-4-5"/><path d="M19 12H9"/><path d="M9 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h3"/></svg>
}
function IcoSearch() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="7"/><path d="m21 21-4-4"/></svg>
}
function IcoBell() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M6 9a6 6 0 0 1 12 0v4l1.7 2.5H4.3L6 13z"/><path d="M9.5 18a2.5 2.5 0 0 0 5 0"/></svg>
}
function IcoCalIcon() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="3.5" y="5" width="17" height="16" rx="2.5"/><path d="M3.5 9.5h17M8 3v4M16 3v4"/></svg>
}
function IcoSettings() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
}
