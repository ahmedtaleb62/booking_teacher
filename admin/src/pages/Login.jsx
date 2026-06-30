import React, { useState } from 'react'
import { supabase } from '../supabase'

export default function Login() {
  const [email, setEmail]       = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading]   = useState(false)
  const [error, setError]       = useState('')

  const handleLogin = async (e) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    const { error: err } = await supabase.auth.signInWithPassword({ email, password })
    if (err) setError('البريد الإلكتروني أو كلمة المرور غير صحيحة')
    setLoading(false)
  }

  return (
    <div className="login-wrap">
      <form className="login-card" onSubmit={handleLogin}>
        <div className="login-logo">
          <svg viewBox="0 0 24 24" style={{ width: 30, height: 30, fill: 'none', stroke: '#fff', strokeWidth: 1.7, strokeLinecap: 'round', strokeLinejoin: 'round' }}>
            <path d="M3 9.5 12 5l9 4.5-9 4.5z"/>
            <path d="M7 11.5V16c0 1 2.2 2.4 5 2.4S17 17 17 16v-4.5"/>
            <path d="M21 9.5V14"/>
          </svg>
        </div>
        <div className="login-title">حصتي</div>
        <div className="login-sub">لوحة تحكم الإدارة</div>

        {error && <div className="login-error">{error}</div>}

        <div style={{ marginBottom: 14 }}>
          <div className="field-label">البريد الإلكتروني</div>
          <input
            className="field-input"
            type="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            placeholder="admin@hissati.mr"
            required
            dir="ltr"
            style={{ textAlign: 'right' }}
          />
        </div>
        <div style={{ marginBottom: 22 }}>
          <div className="field-label">كلمة المرور</div>
          <input
            className="field-input"
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            placeholder="••••••••"
            required
            dir="ltr"
            style={{ textAlign: 'right' }}
          />
        </div>
        <button
          type="submit"
          className="btn btn-primary"
          style={{ width: '100%', justifyContent: 'center', padding: '13px', fontSize: '14px' }}
          disabled={loading}
        >
          {loading ? <span className="spinner" style={{ width: 20, height: 20, borderWidth: 2 }} /> : 'تسجيل الدخول'}
        </button>
      </form>
    </div>
  )
}
