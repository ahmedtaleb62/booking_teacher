import { AwsClient } from 'aws4fetch'

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json' },
  })
}

function decodeJwtSub(token) {
  try {
    const payload = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    return JSON.parse(atob(payload)).sub || null
  } catch {
    return null
  }
}

export async function onRequestPost({ request, env }) {
  const authHeader = request.headers.get('authorization') || ''
  const token = authHeader.replace(/^Bearer\s+/i, '')
  const userId = token && decodeJwtSub(token)
  if (!userId) return json({ error: 'unauthorized' }, 401)

  // Supabase verifies the JWT itself and RLS scopes the read to the caller's
  // own row — we never handle/verify the token's signature ourselves.
  const profileRes = await fetch(
    `${env.SUPABASE_URL}/rest/v1/profiles?select=role&id=eq.${userId}`,
    { headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${token}` } }
  )
  if (!profileRes.ok) return json({ error: 'unauthorized' }, 401)
  const rows = await profileRes.json()
  if (rows?.[0]?.role !== 'admin') return json({ error: 'forbidden' }, 403)

  let body
  try {
    body = await request.json()
  } catch {
    return json({ error: 'invalid request' }, 400)
  }
  const filename = String(body?.filename || '')
  const kind = body?.kind === 'file' ? 'file' : 'video'
  const ext = (filename.split('.').pop() || 'bin').toLowerCase().replace(/[^a-z0-9]/g, '') || 'bin'
  const key = `${kind}s/${Date.now()}_${crypto.randomUUID()}.${ext}`

  const client = new AwsClient({
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY,
  })
  const objectUrl = new URL(`https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${env.R2_BUCKET_NAME}/${key}`)
  const signed = await client.sign(objectUrl, {
    method: 'PUT',
    aws: { signQuery: true },
  })

  return json({
    uploadUrl: signed.url,
    publicUrl: `${env.R2_PUBLIC_BASE_URL}/${key}`,
  })
}
