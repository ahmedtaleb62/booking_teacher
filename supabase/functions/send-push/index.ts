import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Called by a database webhook on notifications INSERT
Deno.serve(async (req) => {
  try {
    const payload = await req.json()
    const record  = payload.record   // the inserted notifications row

    if (!record?.user_id) return ok('no user_id')

    const { user_id, title, body, type, session_id } = record

    // Fetch FCM tokens for this user
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )
    const { data: rows } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', user_id)

    if (!rows?.length) return ok('no tokens')

    const accessToken = await getFcmAccessToken()
    const projectId   = Deno.env.get('FCM_PROJECT_ID')!
    const fcmUrl      = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    // Send to every registered device in parallel
    await Promise.allSettled(
      rows.map(({ token }) =>
        fetch(fcmUrl, {
          method:  'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type':  'application/json',
          },
          body: JSON.stringify({
            message: {
              token,
              notification: { title: title ?? '', body: body ?? '' },
              data: {
                type:       type       ?? '',
                session_id: session_id ?? '',
              },
              android: {
                priority: 'high',
                notification: {
                  channel_id:   'hajez_ustad_channel',
                  icon:         'ic_notification',
                  color:        '#4F46E5',
                  click_action: 'FLUTTER_NOTIFICATION_CLICK',
                },
              },
              apns: {
                headers: { 'apns-priority': '10' },
                payload: { aps: { sound: 'default', badge: 1 } },
              },
            },
          }),
        }),
      ),
    )

    return ok('sent')
  } catch (e) {
    return new Response(String(e), { status: 500 })
  }
})

const ok = (msg: string) => new Response(msg, { status: 200 })

// ── Firebase JWT → access token ──────────────────────────────────────────────
async function getFcmAccessToken(): Promise<string> {
  const sa  = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT')!)
  const now = Math.floor(Date.now() / 1000)

  const b64url = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const header  = { alg: 'RS256', typ: 'JWT' }
  const jwtBody = {
    iss:   sa.client_email,
    sub:   sa.client_email,
    aud:   'https://oauth2.googleapis.com/token',
    iat:   now,
    exp:   now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }

  const unsigned = `${b64url(header)}.${b64url(jwtBody)}`

  // Import the RSA private key
  const pem     = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\n/g, '')
  const derBuf  = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0))
  const privKey = await crypto.subtle.importKey(
    'pkcs8', derBuf,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign'],
  )

  const sigBuf  = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', privKey,
    new TextEncoder().encode(unsigned),
  )
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const jwt = `${unsigned}.${sig}`

  // Exchange JWT for OAuth2 access token
  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method:  'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:    `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })
  const data = await resp.json()
  return data.access_token as string
}
