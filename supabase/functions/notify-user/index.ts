/**
 * Supabase Edge Function: notify-user
 *
 * Sends an FCM push notification to all devices registered for a user.
 * Called by a Postgres trigger (via pg_net) whenever a row is inserted
 * into the `notifications` table.
 *
 * Required Supabase secrets (set via Dashboard → Settings → Edge Functions):
 *   FIREBASE_SERVICE_ACCOUNT  — full JSON of the Firebase service account key
 *                               (Firebase Console → Project Settings → Service accounts
 *                                → Generate new private key)
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL        = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!

// ── JWT helpers for FCM HTTP v1 API ────────────────────────────────────────

function base64url(data: Uint8Array | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  let binary = ''
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s/g, '')
  const binary = atob(b64)
  const buf = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) buf[i] = binary.charCodeAt(i)
  return buf.buffer
}

async function getAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header  = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = base64url(JSON.stringify({
    iss:   sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud:   'https://oauth2.googleapis.com/token',
    iat:   now,
    exp:   now + 3600,
  }))
  const unsigned = `${header}.${payload}`

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key,
    new TextEncoder().encode(unsigned),
  )
  const jwt = `${unsigned}.${base64url(new Uint8Array(sig))}`

  const res  = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  const json = await res.json()
  return json.access_token
}

// ── Main handler ────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  try {
    const { user_id, title, body, data } = await req.json()
    if (!user_id || !title) {
      return new Response('Missing user_id or title', { status: 400 })
    }

    // Get FCM tokens for this user
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    const { data: tokens, error } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', user_id)

    if (error || !tokens?.length) {
      console.log(`[notify-user] No tokens for user ${user_id}`)
      return new Response('No tokens found', { status: 200 })
    }

    console.log(`[notify-user] Found ${tokens.length} token(s) for user ${user_id}`)

    // Build FCM access token
    const sa          = JSON.parse(SERVICE_ACCOUNT_JSON)
    const accessToken = await getAccessToken(sa)
    const projectId   = sa.project_id

    console.log(`[notify-user] Sending via project: ${projectId}`)

    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    // Send to every registered device, log results, remove stale tokens
    const results = await Promise.allSettled(
      tokens.map(async ({ token }) => {
        const res = await fetch(url, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title, body: body ?? '' },
              // FCM requires all data values to be strings
              data: Object.fromEntries(
                Object.entries(data ?? {}).map(([k, v]) => [k, String(v)])
              ),
              android: {
                priority: 'high',
                notification: {
                  channel_id: 'hajez_ustad_channel',
                  icon:        'ic_notification',
                  color:       '#4F46E5',
                },
              },
              apns: {
                headers: { 'apns-priority': '10' },
                payload: { aps: { sound: 'default', badge: 1 } },
              },
            },
          }),
        })
        const json = await res.json()
        if (!res.ok) {
          console.error(`[notify-user] FCM error for token ${token.slice(-8)}: ${JSON.stringify(json)}`)
          // Remove token that FCM says is no longer valid
          const errCode = json?.error?.details?.[0]?.errorCode ?? json?.error?.status ?? ''
          if (errCode === 'UNREGISTERED' || errCode === 'INVALID_ARGUMENT') {
            await supabase.from('device_tokens').delete()
              .eq('user_id', user_id).eq('token', token)
            console.log(`[notify-user] Removed stale token ${token.slice(-8)}`)
          }
        } else {
          console.log(`[notify-user] FCM OK for token ${token.slice(-8)}: ${json?.name ?? 'sent'}`)
        }
        return json
      })
    )

    const ok    = results.filter(r => r.status === 'fulfilled').length
    const failed = results.filter(r => r.status === 'rejected').length
    console.log(`[notify-user] Done: ${ok} sent, ${failed} failed`)

    return new Response('OK', { status: 200 })
  } catch (e) {
    console.error('notify-user error:', e)
    return new Response(String(e), { status: 500 })
  }
})
