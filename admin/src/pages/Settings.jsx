import React, { useState, useEffect } from 'react'
import { supabase } from '../supabase'
import { useToast } from '../components/Toast'

export default function Settings() {
  const toast = useToast()

  // ── Support phone ──────────────────────────────────────────────
  const [phone, setPhone]             = useState('')
  const [phoneLoading, setPhoneLoading] = useState(true)
  const [phoneSaving, setPhoneSaving] = useState(false)

  // ── Change password ────────────────────────────────────────────
  const [curPwd, setCurPwd]   = useState('')
  const [newPwd, setNewPwd]   = useState('')
  const [confPwd, setConfPwd] = useState('')
  const [showPwd, setShowPwd] = useState(false)
  const [pwdSaving, setPwdSaving] = useState(false)

  useEffect(() => { loadPhone() }, [])

  async function loadPhone() {
    setPhoneLoading(true)
    const { data } = await supabase.rpc('get_system_settings')
    if (data) {
      const row = data.find(r => r.key === 'support_phone')
      if (row?.value != null) setPhone(String(row.value).replace(/"/g, '').trim())
    }
    setPhoneLoading(false)
  }

  async function savePhone() {
    if (!phone.trim()) { toast('أدخل رقم الهاتف أولاً', 'error'); return }
    setPhoneSaving(true)
    const { error } = await supabase.rpc('admin_upsert_settings', {
      p_entries: [{ key: 'support_phone', value: phone.trim() }],
    })
    setPhoneSaving(false)
    if (error) toast('فشل الحفظ: ' + error.message, 'error')
    else toast('تم حفظ رقم الدعم ✓', 'success')
  }

  async function changePassword() {
    if (!curPwd || !newPwd || !confPwd) { toast('أكمل جميع الحقول', 'error'); return }
    if (newPwd !== confPwd) { toast('كلمتا المرور غير متطابقتان', 'error'); return }
    if (newPwd.length < 8) { toast('يجب أن تكون كلمة المرور 8 أحرف على الأقل', 'error'); return }
    setPwdSaving(true)
    const { data: { session } } = await supabase.auth.getSession()
    const { error: signInErr } = await supabase.auth.signInWithPassword({
      email: session.user.email,
      password: curPwd,
    })
    if (signInErr) {
      toast('كلمة المرور الحالية غير صحيحة', 'error')
      setPwdSaving(false)
      return
    }
    const { error } = await supabase.auth.updateUser({ password: newPwd })
    setPwdSaving(false)
    if (error) toast('فشل التغيير: ' + error.message, 'error')
    else {
      toast('تم تغيير كلمة المرور بنجاح ✓', 'success')
      setCurPwd(''); setNewPwd(''); setConfPwd('')
    }
  }

  const inputStyle = {
    width: '100%',
    padding: '10px 14px',
    border: '1.5px solid var(--border)',
    borderRadius: 10,
    fontSize: 14,
    fontFamily: 'inherit',
    color: 'var(--text)',
    background: 'var(--surface)',
    outline: 'none',
  }

  const labelStyle = {
    fontSize: 12.5,
    fontWeight: 600,
    color: 'var(--text2)',
    marginBottom: 6,
    display: 'block',
  }

  return (
    <div style={{ maxWidth: 640 }}>

      {/* ── Support phone ── */}
      <div className="card" style={{ marginBottom: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
          <span style={{
            width: 40, height: 40, borderRadius: 12, background: '#D7F2E6',
            display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20,
          }}>📞</span>
          <div>
            <div className="card-title">رقم دعم العملاء</div>
            <div style={{ fontSize: 12, color: 'var(--text3)', marginTop: 3 }}>
              يُعرض للأساتذة عند السحب وللطلاب في صفحة المساعدة
            </div>
          </div>
        </div>

        <div style={{ marginBottom: 16 }}>
          <label style={labelStyle}>رقم الهاتف / واتساب</label>
          <input
            type="tel"
            value={phone}
            onChange={e => setPhone(e.target.value)}
            placeholder={phoneLoading ? 'جارٍ التحميل...' : 'مثال: 42740370'}
            disabled={phoneLoading}
            style={{ ...inputStyle, direction: 'ltr', textAlign: 'left' }}
            onKeyDown={e => e.key === 'Enter' && savePhone()}
          />
        </div>

        {phone && (
          <div style={{
            background: '#D7F2E6', borderRadius: 10, padding: '10px 14px',
            marginBottom: 16, fontSize: 12.5, color: '#0A5C3E', display: 'flex', gap: 8, alignItems: 'center',
          }}>
            <span>✅</span>
            <span>سيُعرض هذا الرقم: <b style={{ direction: 'ltr', unicodeBidi: 'embed' }}>{phone}</b></span>
          </div>
        )}

        <button
          className="btn btn-primary"
          style={{ padding: '11px 28px', fontSize: 13.5 }}
          disabled={phoneSaving || phoneLoading}
          onClick={savePhone}
        >
          {phoneSaving
            ? <span className="spinner" style={{ width: 15, height: 15, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
            : '💾 حفظ الرقم'}
        </button>
      </div>

      {/* ── Change password ── */}
      <div className="card">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
          <span style={{
            width: 40, height: 40, borderRadius: 12, background: '#DEEAF7',
            display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20,
          }}>🔑</span>
          <div>
            <div className="card-title">تغيير كلمة المرور</div>
            <div style={{ fontSize: 12, color: 'var(--text3)', marginTop: 3 }}>
              أدخل كلمة المرور الحالية للتحقق من هويتك ثم أدخل الجديدة
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginBottom: 16 }}>
          {[
            { label: 'كلمة المرور الحالية',          val: curPwd,  fn: setCurPwd  },
            { label: 'كلمة المرور الجديدة',           val: newPwd,  fn: setNewPwd  },
            { label: 'تأكيد كلمة المرور الجديدة',    val: confPwd, fn: setConfPwd },
          ].map(({ label, val, fn }) => (
            <div key={label}>
              <label style={labelStyle}>{label}</label>
              <input
                type={showPwd ? 'text' : 'password'}
                value={val}
                onChange={e => fn(e.target.value)}
                style={{ ...inputStyle, direction: 'ltr', textAlign: 'left' }}
                autoComplete="new-password"
              />
            </div>
          ))}
        </div>

        <div
          style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 18, cursor: 'pointer', userSelect: 'none' }}
          onClick={() => setShowPwd(v => !v)}
        >
          <div style={{
            width: 18, height: 18, flexShrink: 0,
            border: `2px solid ${showPwd ? 'var(--primary)' : 'var(--border-strong)'}`,
            borderRadius: 5,
            background: showPwd ? 'var(--primary)' : 'transparent',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            transition: 'all .15s',
          }}>
            {showPwd && <span style={{ color: '#fff', fontSize: 11, lineHeight: 1, fontWeight: 700 }}>✓</span>}
          </div>
          <span style={{ fontSize: 12.5, color: 'var(--text2)' }}>إظهار كلمة المرور</span>
        </div>

        <div style={{ background: '#FEF3C7', borderRadius: 10, padding: '9px 14px', marginBottom: 18, fontSize: 12, color: '#92400E' }}>
          ⚠ بعد تغيير كلمة المرور ستُسجَّل خروجاً وتحتاج لتسجيل الدخول مجدداً.
        </div>

        <button
          className="btn btn-primary"
          style={{ padding: '11px 28px', fontSize: 13.5 }}
          disabled={pwdSaving}
          onClick={changePassword}
        >
          {pwdSaving
            ? <span className="spinner" style={{ width: 15, height: 15, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
            : '🔒 تغيير كلمة المرور'}
        </button>
      </div>
    </div>
  )
}
