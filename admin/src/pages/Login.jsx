import React, { useState } from 'react'
import { supabase } from '../supabase'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

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
        <div className="login-logo">س</div>
        <div className="login-title">سولني</div>
        <div className="login-sub">لوحة الإدارة الاحترافية</div>

        {error && <div className="login-error">{error}</div>}

        <div style={{ marginBottom: 14 }}>
          <div className="field-label">البريد الإلكتروني</div>
          <input
            className="field-input"
            type="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            placeholder="admin@example.com"
            required
            dir="ltr"
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
