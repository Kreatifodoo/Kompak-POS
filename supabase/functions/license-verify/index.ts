// Supabase Edge Function: POST /functions/v1/license-verify
// Verifikasi berkala (tiap 30 hari) — cek apakah lisensi masih aktif / belum direvoke

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

Deno.serve(async (req: Request) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405, corsHeaders)
  }

  let body: { activation_token?: string; device_fingerprint?: string }
  try {
    body = await req.json()
  } catch {
    return json({ error: 'Body tidak valid' }, 400, corsHeaders)
  }

  const { activation_token, device_fingerprint } = body

  if (!activation_token || !device_fingerprint) {
    return json({ error: 'activation_token dan device_fingerprint wajib diisi' }, 400, corsHeaders)
  }

  // Cari aktivasi berdasarkan token
  const { data: activation, error } = await supabase
    .from('device_activations')
    .select('id, device_fingerprint, is_active, license_id, licenses(status, expires_at)')
    .eq('activation_token', activation_token)
    .single()

  if (error || !activation) {
    return json({ valid: false, reason: 'token_not_found' }, 403, corsHeaders)
  }

  // Cek device fingerprint cocok
  if (activation.device_fingerprint !== device_fingerprint) {
    return json({ valid: false, reason: 'device_mismatch' }, 403, corsHeaders)
  }

  // Cek aktivasi masih aktif
  if (!activation.is_active) {
    return json({ valid: false, reason: 'device_deactivated' }, 403, corsHeaders)
  }

  // Cek status lisensi
  const license = (activation as any).licenses
  if (license?.status === 'revoked') {
    return json({ valid: false, reason: 'license_revoked' }, 403, corsHeaders)
  }
  if (license?.expires_at && new Date(license.expires_at) < new Date()) {
    return json({ valid: false, reason: 'license_expired' }, 403, corsHeaders)
  }

  // Update last_verified_at
  await supabase
    .from('device_activations')
    .update({ last_verified_at: new Date().toISOString() })
    .eq('id', activation.id)

  return json({ valid: true }, 200, corsHeaders)
})

function json(data: object, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...extraHeaders },
  })
}
