import React from 'react'

/**
 * ConfirmModal — professional in-app confirmation dialog
 *
 * Props:
 *   open     {bool}   — whether the modal is visible
 *   title    {string} — dialog title
 *   message  {string} — body message / detail line
 *   confirm  {string} — confirm button label (default: 'تأكيد')
 *   cancel   {string} — cancel button label  (default: 'إلغاء')
 *   danger   {bool}   — use red confirm button (default: false → primary)
 *   loading  {bool}   — show spinner on confirm button and disable both buttons
 *   onConfirm {fn}   — called when confirm button is clicked
 *   onCancel  {fn}   — called when cancel button / backdrop is clicked
 */
export default function ConfirmModal({
  open,
  title,
  message,
  confirm = 'تأكيد',
  cancel  = 'إلغاء',
  danger  = false,
  loading = false,
  onConfirm,
  onCancel,
}) {
  if (!open) return null

  const confirmBg    = danger ? '#DC2626' : 'var(--primary)'
  const confirmHover = danger ? '#B91C1C' : 'var(--primary-dark, #3730A3)'
  const iconBg       = danger ? '#FEF2F2' : '#EEF2FF'
  const iconColor    = danger ? '#DC2626' : 'var(--primary)'
  const icon         = danger ? '⚠️'      : 'ℹ️'

  return (
    <div
      style={{
        position: 'fixed', inset: 0,
        background: 'rgba(30,27,75,.45)',
        backdropFilter: 'blur(3px)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 2000, padding: 20,
      }}
      onClick={loading ? undefined : onCancel}
    >
      <div
        style={{
          background: '#fff', borderRadius: 20,
          padding: '32px 28px 26px',
          width: 400, maxWidth: '95vw',
          boxShadow: '0 20px 60px rgba(30,27,75,.18)',
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          textAlign: 'center',
        }}
        onClick={e => e.stopPropagation()}
      >
        {/* Icon */}
        <div style={{
          width: 58, height: 58, borderRadius: '50%',
          background: iconBg, display: 'flex',
          alignItems: 'center', justifyContent: 'center',
          fontSize: 26, marginBottom: 18,
        }}>
          {icon}
        </div>

        {/* Title */}
        <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text)', marginBottom: 10, lineHeight: 1.4 }}>
          {title}
        </div>

        {/* Message */}
        {message && (
          <div style={{ fontSize: 13.5, color: 'var(--text2)', lineHeight: 1.65, marginBottom: 26, maxWidth: 320 }}>
            {message}
          </div>
        )}

        {/* Buttons */}
        <div style={{ display: 'flex', gap: 10, width: '100%' }}>
          <button
            className="btn"
            style={{
              flex: 1, justifyContent: 'center',
              padding: '11px 0',
              background: '#F1F5F9', color: 'var(--text2)',
              border: '1.5px solid var(--border)',
              borderRadius: 12, fontWeight: 700, fontSize: 14,
              cursor: loading ? 'not-allowed' : 'pointer',
              opacity: loading ? 0.6 : 1,
            }}
            disabled={loading}
            onClick={onCancel}
          >
            {cancel}
          </button>
          <button
            className="btn"
            style={{
              flex: 1, justifyContent: 'center',
              padding: '11px 0',
              background: confirmBg, color: '#fff',
              border: 'none', borderRadius: 12,
              fontWeight: 700, fontSize: 14,
              cursor: loading ? 'not-allowed' : 'pointer',
              opacity: loading ? 0.75 : 1,
              display: 'flex', alignItems: 'center', gap: 8,
            }}
            disabled={loading}
            onClick={onConfirm}
          >
            {loading
              ? <span className="spinner" style={{ width: 16, height: 16, borderWidth: 2, borderColor: 'rgba(255,255,255,.3)', borderTopColor: '#fff' }} />
              : confirm}
          </button>
        </div>
      </div>
    </div>
  )
}
