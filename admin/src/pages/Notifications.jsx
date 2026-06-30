import React, { useState, useEffect, useCallback } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

const TARGET_OPTIONS = [
  { value: 'all',      label: 'جميع المستخدمين',  desc: 'الطلاب والأساتذة' },
  { value: 'students', label: 'جميع الطلاب',       desc: 'فقط حسابات الطلاب' },
  { value: 'teachers', label: 'جميع الأساتذة',     desc: 'فقط حسابات الأساتذة' },
  { value: 'user',     label: 'مستخدم محدد',       desc: 'ابحث عن مستخدم بالاسم أو البريد' },
]

const TYPE_ICONS = {
  PAYMENT_SUBMITTED:  { icon: '💳', bg: '#FFFBEB', border: '#FCD34D', label: 'دفع' },
  TEACHER_ONBOARDING: { icon: '👨‍🏫', bg: '#EFF6FF', border: '#93C5FD', label: 'أستاذ' },
  ADMIN_BROADCAST:    { icon: '📢', bg: '#F0FDF4', border: '#86EFAC', label: 'بث' },
  SESSION_REQUESTED:  { icon: '📅', bg: '#E3F4EF', border: '#9FD5C4', label: 'جلسة' },
  default:            { icon: '🔔', bg: '#F8FAFC', border: '#CBD5E1', label: 'إشعار' },
}

function timeAgo(iso) {
  const diff = Math.floor((Date.now() - new Date(iso)) / 1000)
  if (diff < 60)   return 'الآن'
  if (diff < 3600) return `منذ ${Math.floor(diff / 60)} د`
  if (diff < 86400) return `منذ ${Math.floor(diff / 3600)} س`
  return `منذ ${Math.floor(diff / 86400)} يوم`
}

// ── Main Component ────────────────────────────────────────────────────────────

export default function Notifications({ adminId }) {
  const showToast               = useToast()
  const [tab, setTab]           = useState('inbox')
  const [inbox, setInbox]       = useState([])
  const [sent, setSent]         = useState([])
  const [loading, setLoading]   = useState(true)
  const [sending, setSending]   = useState(false)

  // Send form state
  const [targetType, setTargetType]     = useState('all')
  const [searchQuery, setSearchQuery]   = useState('')
  const [selectedUser, setSelectedUser] = useState(null)
  const [title, setTitle]               = useState('')
  const [body, setBody]                 = useState('')

  // ── Data loading ────────────────────────────────────────────────────────────

  const loadData = useCallback(async () => {
    setLoading(true)
    try {
      const [inboxRes, sentRes] = await Promise.all([
        supabase
          .from('notifications')
          .select('*')
          .eq('user_id', adminId)
          .order('created_at', { ascending: false })
          .limit(100),
        supabase
          .from('notifications')
          .select('*, recipient:user_id(full_name, role)')
          .eq('type', 'ADMIN_BROADCAST')
          .order('created_at', { ascending: false })
          .limit(100),
      ])
      setInbox(inboxRes.data || [])
      setSent(sentRes.data || [])
    } finally {
      setLoading(false)
    }
  }, [adminId])

  useEffect(() => { loadData() }, [loadData])

  // Realtime: refresh inbox on new notification for admin
  useEffect(() => {
    const channel = supabase
      .channel('admin-notif-inbox')
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${adminId}`,
      }, () => loadData())
      .subscribe()
    return () => supabase.removeChannel(channel)
  }, [adminId, loadData])

  // ── User list (for 'user' target type) ────────────────────────────────────
  // Load all users once when target switches to 'user'; filter locally.

  const [allUsers, setAllUsers] = useState([])
  const [usersLoading, setUsersLoading] = useState(false)

  useEffect(() => {
    if (targetType !== 'user') {
      setAllUsers([])
      setSearchQuery('')
      return
    }
    setUsersLoading(true)
    supabase
      .from('profiles')
      .select('id, full_name, role')
      .neq('role', 'admin')
      .order('full_name', { ascending: true })
      .limit(200)
      .then(({ data }) => {
        setAllUsers(data || [])
        setUsersLoading(false)
      })
  }, [targetType])

  const filteredUsers = searchQuery.trim().length === 0
    ? allUsers
    : allUsers.filter(u =>
        u.full_name?.toLowerCase().includes(searchQuery.toLowerCase())
      )

  // ── Mark all as read ────────────────────────────────────────────────────────

  async function markAllRead() {
    await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('user_id', adminId)
      .eq('is_read', false)
    setInbox(prev => prev.map(n => ({ ...n, is_read: true })))
  }

  // ── Send notification ───────────────────────────────────────────────────────

  async function handleSend(e) {
    e.preventDefault()
    if (!title.trim() || !body.trim()) {
      showToast('يرجى كتابة العنوان والمحتوى', 'error')
      return
    }
    if (targetType === 'user' && !selectedUser) {
      showToast('يرجى اختيار مستخدم', 'error')
      return
    }
    setSending(true)
    try {
      const { data: count, error } = await supabase.rpc('send_admin_notification', {
        p_target_type: targetType,
        p_title:       title.trim(),
        p_body:        body.trim(),
        p_target_id:   targetType === 'user' ? selectedUser.id : null,
      })
      if (error) throw error

      showToast(`تم الإرسال بنجاح إلى ${count} مستخدم`, 'success')
      setTitle('')
      setBody('')
      setSelectedUser(null)
      setSearchQuery('')
      loadData()
      setTab('sent')
    } catch (err) {
      showToast('فشل الإرسال: ' + err.message, 'error')
    } finally {
      setSending(false)
    }
  }

  // ── Unread count ────────────────────────────────────────────────────────────
  const unreadCount = inbox.filter(n => !n.is_read).length

  // ─────────────────────────────────────────────────────────────────────────────

  return (
    <div style={{ maxWidth: 900, margin: '0 auto', display: 'flex', flexDirection: 'column', gap: 24 }}>

      {/* ── Tabs ── */}
      <div style={{ display: 'flex', gap: 8, borderBottom: '1px solid #E2E8F0', paddingBottom: 0 }}>
        {[
          { key: 'inbox', label: 'الإشعارات الواردة', badge: unreadCount },
          { key: 'send',  label: 'إرسال إشعار' },
          { key: 'sent',  label: 'سجل الإرسال' },
        ].map(t => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            style={{
              padding: '10px 18px',
              border: 'none',
              background: 'none',
              cursor: 'pointer',
              fontFamily: 'inherit',
              fontSize: 14,
              fontWeight: 600,
              color: tab === t.key ? '#1B5E7A' : '#64748B',
              borderBottom: tab === t.key ? '2px solid #1B5E7A' : '2px solid transparent',
              marginBottom: -1,
              display: 'flex',
              alignItems: 'center',
              gap: 7,
            }}
          >
            {t.label}
            {t.badge > 0 && (
              <span style={{
                background: '#EF4444', color: '#FFF',
                borderRadius: 999, fontSize: 11, fontWeight: 700,
                padding: '1px 6px', lineHeight: 1.5,
              }}>{t.badge}</span>
            )}
          </button>
        ))}
      </div>

      {/* ── INBOX ── */}
      {tab === 'inbox' && (
        <div>
          {unreadCount > 0 && (
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
              <button className="btn btn-sm" onClick={markAllRead}
                style={{ padding: '6px 14px', fontSize: 13 }}>
                تحديد الكل كمقروء
              </button>
            </div>
          )}
          {loading ? (
            <div className="loading-center"><div className="spinner" /></div>
          ) : inbox.length === 0 ? (
            <Empty text="لا توجد إشعارات واردة" />
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {inbox.map(n => <NotifCard key={n.id} notif={n} />)}
            </div>
          )}
        </div>
      )}

      {/* ── SEND FORM ── */}
      {tab === 'send' && (
        <form onSubmit={handleSend}
          style={{
            background: '#FFF', border: '1px solid #E2E8F0',
            borderRadius: 16, padding: 28,
            display: 'flex', flexDirection: 'column', gap: 20,
          }}>

          {/* Target type */}
          <div>
            <label style={labelStyle}>المستلمون</label>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginTop: 8 }}>
              {TARGET_OPTIONS.map(opt => (
                <div key={opt.value}
                  onClick={() => { setTargetType(opt.value); setSelectedUser(null); setSearchQuery('') }}
                  style={{
                    padding: '12px 16px', borderRadius: 12, cursor: 'pointer',
                    border: `1.5px solid ${targetType === opt.value ? '#1B5E7A' : '#E2E8F0'}`,
                    background: targetType === opt.value ? '#F0F7FB' : '#FFF',
                    transition: 'all .15s',
                  }}>
                  <div style={{ fontSize: 13, fontWeight: 700, color: targetType === opt.value ? '#1B5E7A' : '#1E293B' }}>
                    {opt.label}
                  </div>
                  <div style={{ fontSize: 11.5, color: '#64748B', marginTop: 2 }}>{opt.desc}</div>
                </div>
              ))}
            </div>
          </div>

          {/* User picker (only for 'user' target) */}
          {targetType === 'user' && (
            <div>
              <label style={labelStyle}>اختر المستخدم</label>

              {/* Selected user chip */}
              {selectedUser ? (
                <div style={{
                  marginTop: 8, padding: '10px 14px', borderRadius: 10,
                  background: '#F0F7FB', border: '1.5px solid #1B5E7A',
                  display: 'flex', alignItems: 'center', gap: 10,
                }}>
                  <div style={{
                    width: 36, height: 36, borderRadius: 10, background: '#1B5E7A',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    color: '#FFF', fontWeight: 700, fontSize: 15, flexShrink: 0,
                  }}>{selectedUser.full_name?.[0] ?? '?'}</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13.5, fontWeight: 700, color: '#1E293B' }}>{selectedUser.full_name}</div>
                    <div style={{ fontSize: 12, color: '#64748B' }}>{selectedUser.role === 'teacher' ? 'أستاذ' : 'طالب'}</div>
                  </div>
                  <button type="button" onClick={() => { setSelectedUser(null); setSearchQuery('') }}
                    style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#94A3B8', fontSize: 22, lineHeight: 1 }}>×</button>
                </div>
              ) : (
                <div style={{
                  marginTop: 8, border: '1.5px solid #E2E8F0', borderRadius: 12,
                  background: '#FFF', overflow: 'hidden',
                }}>
                  {/* Filter input */}
                  <div style={{ padding: '10px 12px', borderBottom: '1px solid #F1F5F9', display: 'flex', alignItems: 'center', gap: 8 }}>
                    <span style={{ color: '#94A3B8', fontSize: 15 }}>🔍</span>
                    <input
                      value={searchQuery}
                      onChange={e => setSearchQuery(e.target.value)}
                      placeholder="فلتر بالاسم…"
                      style={{
                        border: 'none', outline: 'none', background: 'transparent',
                        fontSize: 13.5, fontFamily: 'inherit', color: '#1E293B',
                        width: '100%',
                      }}
                    />
                    {searchQuery && (
                      <button type="button" onClick={() => setSearchQuery('')}
                        style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#94A3B8', fontSize: 18, lineHeight: 1, padding: 0 }}>×</button>
                    )}
                  </div>

                  {/* User list */}
                  <div style={{ maxHeight: 220, overflowY: 'auto' }}>
                    {usersLoading ? (
                      <div style={{ padding: '18px 0', display: 'flex', justifyContent: 'center' }}>
                        <div className="spinner" style={{ width: 22, height: 22, borderWidth: 2 }} />
                      </div>
                    ) : filteredUsers.length === 0 ? (
                      <div style={{ padding: '18px 14px', textAlign: 'center', color: '#94A3B8', fontSize: 13 }}>
                        {searchQuery ? 'لا توجد نتائج' : 'لا يوجد مستخدمون'}
                      </div>
                    ) : (
                      filteredUsers.map(u => (
                        <div key={u.id}
                          onClick={() => { setSelectedUser(u); setSearchQuery('') }}
                          style={{
                            padding: '10px 14px', cursor: 'pointer',
                            display: 'flex', alignItems: 'center', gap: 10,
                            borderBottom: '1px solid #F8FAFC',
                            transition: 'background .12s',
                          }}
                          onMouseEnter={e => e.currentTarget.style.background = '#F0F7FB'}
                          onMouseLeave={e => e.currentTarget.style.background = ''}
                        >
                          <div style={{
                            width: 34, height: 34, borderRadius: 9, flexShrink: 0,
                            background: u.role === 'teacher' ? '#ECE5F7' : '#DEEAF7',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            fontWeight: 700, fontSize: 14,
                            color: u.role === 'teacher' ? '#5A3B95' : '#1F5C99',
                          }}>{u.full_name?.[0] ?? '?'}</div>
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={{ fontSize: 13.5, fontWeight: 600, color: '#1E293B', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                              {u.full_name}
                            </div>
                            <div style={{ fontSize: 11, color: '#94A3B8', marginTop: 1 }}>
                              {u.role === 'teacher' ? '👨‍🏫 أستاذ' : '🎓 طالب'}
                            </div>
                          </div>
                          <span style={{ fontSize: 16, color: '#CBD5E1' }}>›</span>
                        </div>
                      ))
                    )}
                  </div>

                  {/* Count */}
                  {!usersLoading && filteredUsers.length > 0 && (
                    <div style={{ padding: '6px 14px', borderTop: '1px solid #F1F5F9', fontSize: 11, color: '#94A3B8' }}>
                      {filteredUsers.length} مستخدم
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* Title */}
          <div>
            <label style={labelStyle}>العنوان *</label>
            <input
              value={title}
              onChange={e => setTitle(e.target.value)}
              placeholder="عنوان الإشعار…"
              maxLength={80}
              style={{ ...inputStyle, marginTop: 8 }}
            />
            <div style={{ textAlign: 'left', fontSize: 11, color: '#94A3B8', marginTop: 4 }}>{title.length}/80</div>
          </div>

          {/* Body */}
          <div>
            <label style={labelStyle}>المحتوى *</label>
            <textarea
              value={body}
              onChange={e => setBody(e.target.value)}
              placeholder="محتوى الإشعار…"
              rows={4}
              maxLength={300}
              style={{ ...inputStyle, marginTop: 8, resize: 'vertical', minHeight: 100 }}
            />
            <div style={{ textAlign: 'left', fontSize: 11, color: '#94A3B8', marginTop: 4 }}>{body.length}/300</div>
          </div>

          {/* Preview */}
          {(title || body) && (
            <div style={{
              padding: 16, borderRadius: 12,
              background: '#F8FAFC', border: '1px solid #E2E8F0',
            }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: '#94A3B8', marginBottom: 8, letterSpacing: 0.5 }}>
                معاينة الإشعار
              </div>
              <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                <div style={{
                  width: 38, height: 38, borderRadius: 10, background: '#1B5E7A',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18,
                }}>📢</div>
                <div>
                  <div style={{ fontSize: 14, fontWeight: 700, color: '#1E293B' }}>{title || '…'}</div>
                  <div style={{ fontSize: 13, color: '#64748B', marginTop: 3, lineHeight: 1.5 }}>{body || '…'}</div>
                </div>
              </div>
            </div>
          )}

          {/* Submit */}
          <button type="submit" disabled={sending}
            className="btn btn-primary"
            style={{ alignSelf: 'flex-start', padding: '11px 28px', fontSize: 14 }}>
            {sending ? 'جاري الإرسال…' : '📤 إرسال الإشعار'}
          </button>
        </form>
      )}

      {/* ── SENT LOG ── */}
      {tab === 'sent' && (
        <div>
          {loading ? (
            <div className="loading-center"><div className="spinner" /></div>
          ) : sent.length === 0 ? (
            <Empty text="لا يوجد سجل إرسال حتى الآن" />
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {sent.map(n => (
                <div key={n.id} style={{
                  background: '#FFF', border: '1px solid #E2E8F0',
                  borderRadius: 14, padding: '14px 18px',
                  display: 'flex', gap: 14, alignItems: 'center',
                }}>
                  <div style={{
                    width: 40, height: 40, borderRadius: 11, background: '#F0F7FB',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 19,
                  }}>📢</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13.5, fontWeight: 700, color: '#1E293B' }}>{n.title}</div>
                    <div style={{ fontSize: 12.5, color: '#64748B', marginTop: 2 }}>{n.body}</div>
                    <div style={{ fontSize: 11, color: '#94A3B8', marginTop: 5 }}>
                      {n.recipient?.full_name
                        ? `→ ${n.recipient.full_name} (${n.recipient.role === 'teacher' ? 'أستاذ' : 'طالب'})`
                        : '→ بث عام'
                      }
                      {' · '}{timeAgo(n.created_at)}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

// ── Sub-components ─────────────────────────────────────────────────────────────

function NotifCard({ notif }) {
  const cfg = TYPE_ICONS[notif.type] || TYPE_ICONS.default
  return (
    <div style={{
      background: notif.is_read ? '#FFF' : '#F8FDFF',
      border: `1px solid ${notif.is_read ? '#E2E8F0' : '#BAE6FD'}`,
      borderRadius: 14, padding: '14px 18px',
      display: 'flex', gap: 14, alignItems: 'flex-start',
      transition: 'background .2s',
    }}>
      <div style={{
        width: 42, height: 42, borderRadius: 12, flexShrink: 0,
        background: cfg.bg, border: `1.5px solid ${cfg.border}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 19,
      }}>{cfg.icon}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'center' }}>
          <div style={{ fontSize: 13.5, fontWeight: notif.is_read ? 600 : 700, color: '#1E293B' }}>
            {notif.title}
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 7, flexShrink: 0,
          }}>
            {!notif.is_read && (
              <span style={{
                width: 8, height: 8, borderRadius: '50%', background: '#3B82F6', display: 'inline-block',
              }} />
            )}
            <span style={{ fontSize: 11, color: '#94A3B8', whiteSpace: 'nowrap' }}>
              {timeAgo(notif.created_at)}
            </span>
          </div>
        </div>
        <div style={{ fontSize: 12.5, color: '#64748B', marginTop: 3, lineHeight: 1.5 }}>{notif.body}</div>
        <div style={{
          display: 'inline-block', marginTop: 6,
          padding: '2px 9px', borderRadius: 999, fontSize: 11, fontWeight: 600,
          background: cfg.bg, color: '#1B5E7A', border: `1px solid ${cfg.border}`,
        }}>{cfg.label}</div>
      </div>
    </div>
  )
}

function Empty({ text }) {
  return (
    <div style={{
      padding: '60px 20px', textAlign: 'center',
      color: '#94A3B8', fontSize: 14,
      background: '#F8FAFC', borderRadius: 14,
      border: '1px dashed #CBD5E1',
    }}>
      <div style={{ fontSize: 36, marginBottom: 12 }}>🔔</div>
      {text}
    </div>
  )
}

// ── Styles ─────────────────────────────────────────────────────────────────────

const labelStyle = {
  fontSize: 13, fontWeight: 700, color: '#374151', display: 'block',
}

const inputStyle = {
  width: '100%', padding: '10px 14px', borderRadius: 10,
  border: '1.5px solid #E2E8F0', fontSize: 13.5, fontFamily: 'inherit',
  outline: 'none', background: '#FAFAFA', boxSizing: 'border-box',
  color: '#1E293B', transition: 'border-color .15s',
}
