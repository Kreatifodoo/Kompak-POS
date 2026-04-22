// Supabase Edge Function: POST /functions/v1/license-activate
// Aktivasi lisensi — validasi license key + ikat ke device fingerprint

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

Deno.serve(async (req: Request) => {
  // CORS headers (untuk testing dari browser/Postman)
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'content-type, authorization',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405, corsHeaders)
  }

  let body: {
    license_key?: string
    device_fingerprint?: string
    device_model?: string
    device_brand?: string
    android_version?: string
    app_version?: string
  }

  try {
    body = await req.json()
  } catch {
    return json({ error: 'Body tidak valid (JSON diperlukan)' }, 400, corsHeaders)
  }

  const { license_key, device_fingerprint, device_model, device_brand, android_version } = body

  // Validasi field wajib
  if (!license_key || !device_fingerprint) {
    return json({ error: 'license_key dan device_fingerprint wajib diisi' }, 400, corsHeaders)
  }

  // Validasi format license key: KOMP-XXXX-XXXX-XXXX
  const keyPattern = /^KOMP-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/
  if (!keyPattern.test(license_key.toUpperCase())) {
    return json({ error: 'Format license key tidak valid' }, 400, corsHeaders)
  }

  // Cari lisensi di database
  const { data: license, error: licenseError } = await supabase
    .from('licenses')
    .select('id, customer_name, store_name, max_devices, status, expires_at')
    .eq('license_key', license_key.toUpperCase())
    .single()

  if (licenseError || !license) {
    return json({ error: 'License key tidak ditemukan' }, 404, corsHeaders)
  }

  // Cek status lisensi
  if (license.status === 'revoked') {
    return json({ error: 'Lisensi ini telah dicabut. Hubungi admin.' }, 403, corsHeaders)
  }
  if (license.status === 'expired') {
    return json({ error: 'Lisensi telah kedaluwarsa. Hubungi admin.' }, 403, corsHeaders)
  }
  if (license.expires_at && new Date(license.expires_at) < new Date()) {
    // Update status ke expired
    await supabase.from('licenses').update({ status: 'expired' }).eq('id', license.id)
    return json({ error: 'Lisensi telah kedaluwarsa. Hubungi admin.' }, 403, corsHeaders)
  }

  // Cek apakah device fingerprint ini sudah pernah diaktivasi (re-aktivasi device yang sama = OK)
  const { data: existingActivation } = await supabase
    .from('device_activations')
    .select('id, activation_token, is_active')
    .eq('license_id', license.id)
    .eq('device_fingerprint', device_fingerprint)
    .single()

  if (existingActivation) {
    if (!existingActivation.is_active) {
      return json({ error: 'Perangkat ini telah dinonaktifkan. Hubungi admin.' }, 403, corsHeaders)
    }
    // Device ini sudah terdaftar — kembalikan token yang sudah ada (re-aktivasi)
    await supabase
      .from('device_activations')
      .update({ last_verified_at: new Date().toISOString() })
      .eq('id', existingActivation.id)

    return json({
      activation_token: existingActivation.activation_token,
      customer_name: license.customer_name,
      store_name: license.store_name,
      license_key: license_key.toUpperCase(),
      expires_at: license.expires_at,
    }, 200, corsHeaders)
  }

  // Device baru — cek apakah sudah mencapai batas max_devices
  const { count: activeCount } = await supabase
    .from('device_activations')
    .select('id', { count: 'exact', head: true })
    .eq('license_id', license.id)
    .eq('is_active', true)

  if ((activeCount ?? 0) >= license.max_devices) {
    return json({
      error: `Lisensi ini sudah digunakan di ${license.max_devices} perangkat (batas maksimal). Hubungi admin untuk menambah slot atau menonaktifkan perangkat lama.`
    }, 403, corsHeaders)
  }

  // Aktivasi device baru
  const { data: newActivation, error: activationError } = await supabase
    .from('device_activations')
    .insert({
      license_id: license.id,
      device_fingerprint,
      device_model: device_model ?? 'Unknown',
      device_brand: device_brand ?? 'Unknown',
      android_version: android_version ?? 'Unknown',
    })
    .select('activation_token')
    .single()

  if (activationError || !newActivation) {
    console.error('Activation error:', activationError)
    return json({ error: 'Gagal mengaktivasi. Coba lagi.' }, 500, corsHeaders)
  }

  // Update status lisensi menjadi active
  await supabase
    .from('licenses')
    .update({ status: 'active' })
    .eq('id', license.id)

  return json({
    activation_token: newActivation.activation_token,
    customer_name: license.customer_name,
    store_name: license.store_name,
    license_key: license_key.toUpperCase(),
    expires_at: license.expires_at,
  }, 200, corsHeaders)
})

function json(data: object, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...extraHeaders },
  })
}
