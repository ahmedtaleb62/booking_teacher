import React, { createContext, useContext, useState, useCallback } from 'react'

const ToastCtx = createContext(null)

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([])

  const show = useCallback((message, type = 'success') => {
    const id = Date.now() + Math.random()
    setToasts(prev => [...prev, { id, message, type }])
    if (type === 'success') {
      setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 3500)
    }
  }, [])

  const dismiss = useCallback((id) => {
    setToasts(prev => prev.filter(t => t.id !== id))
  }, [])

  const styleMap = {
    success: { bg: '#059669', icon: '✓' },
    error:   { bg: '#DC2626', icon: '✕' },
    info:    { bg: '#4F46E5', icon: 'ℹ' },
  }

  return (
    <ToastCtx.Provider value={show}>
      {children}
      <div style={{
        position: 'fixed', bottom: 28, left: 28, zIndex: 9999,
        display: 'flex', flexDirection: 'column-reverse', gap: 10,
        minWidth: 280, maxWidth: 400, pointerEvents: 'none',
      }}>
        {toasts.map(t => {
          const { bg, icon } = styleMap[t.type] || styleMap.info
          return (
            <div key={t.id} style={{
              background: bg, color: '#fff', borderRadius: 14,
              padding: '13px 16px', display: 'flex', alignItems: 'center', gap: 11,
              boxShadow: '0 6px 20px rgba(0,0,0,.22)', fontSize: 14,
              fontFamily: 'Tajawal, sans-serif', direction: 'rtl',
              pointerEvents: 'all', animation: 'slideIn .22s ease',
            }}>
              <span style={{ width: 26, height: 26, borderRadius: 8, background: 'rgba(255,255,255,.22)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, flexShrink: 0 }}>
                {icon}
              </span>
              <span style={{ flex: 1, lineHeight: 1.45 }}>{t.message}</span>
              <span onClick={() => dismiss(t.id)} style={{ cursor: 'pointer', opacity: .65, fontSize: 18, lineHeight: 1, flexShrink: 0 }}>×</span>
            </div>
          )
        })}
      </div>
      <style>{`@keyframes slideIn { from { opacity:0; transform:translateX(-18px) } to { opacity:1; transform:translateX(0) } }`}</style>
    </ToastCtx.Provider>
  )
}

export const useToast = () => useContext(ToastCtx)
