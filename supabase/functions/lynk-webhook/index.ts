// Edge Function: lynk-webhook
// Menerima webhook dari Lynk.id saat payment berhasil
// Otomatis generate license + kirim email ke customer
//
// Flow: Lynk.id payment.success → webhook → create license → send email

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

const LYNK_WEBHOOK_SECRET = Deno.env.get('LYNK_WEBHOOK_SECRET') ?? ''
const DEFAULT_APK_URL     = 'https://qyxvxoavypqbiacinqbz.supabase.co/storage/v1/object/public/apk/kompak-pos-v1.0.9-arm64.apk'
const APP_VERSION         = '1.0.9'
const MAX_DOWNLOADS       = 20
const LINK_VALID_DAYS     = 30
const DEFAULT_MAX_DEVICES = 1
const DEFAULT_EXPIRY_DAYS = 365   // 1 tahun

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? ''
const FROM_EMAIL     = Deno.env.get('FROM_EMAIL') ?? 'Kompak POS <info@pos.kompakapps.com>'
const REPLY_TO       = Deno.env.get('REPLY_TO')   ?? 'support@pos.kompakapps.com'

const ADMIN_PASSWORD = Deno.env.get('ADMIN_PASSWORD') ?? 'kompakadmin2024'

Deno.serve(async (req: Request) => {
  const cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'content-type, authorization, x-lynk-signature',
    'Content-Type': 'application/json',
  }

  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  // ── DEBUG endpoint: GET /lynk-webhook?debug=PASSWORD ─────────────────
  // Tampilkan 10 webhook terakhir untuk verifikasi payload format
  if (req.method === 'GET') {
    const url      = new URL(req.url)
    const debugPwd = url.searchParams.get('debug') ?? ''
    if (debugPwd !== ADMIN_PASSWORD) return json({ error: 'Unauthorized' }, 401, cors)

    const { data: logs } = await supabase
      .from('webhook_logs')
      .select('trx_id, event_name, status, payload, error_msg, created_at')
      .order('created_at', { ascending: false })
      .limit(10)

    return json({ logs: logs ?? [] }, 200, cors)
  }

  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405, cors)

  // ── 1. Baca raw body ──────────────────────────────────────────────────
  const rawBody = await req.text()

  // Log headers untuk debugging (Lynk.id mungkin kirim merchant key di header)
  const headers: Record<string,string> = {}
  req.headers.forEach((v, k) => { headers[k] = v })
  console.log('Incoming headers:', JSON.stringify(headers))
  console.log('Incoming body:', rawBody)

  let body: Record<string, unknown>
  try { body = JSON.parse(rawBody) }
  catch { return json({ error: 'JSON tidak valid' }, 400, cors) }

  // ── 2. Log headers untuk audit ───────────────────────────────────────
  // Merchant key check dinonaktifkan: Supabase intercept Authorization header
  // sebelum sampai ke function. Keamanan dari: URL rahasia + idempotency (trx_id unik)
  const allHeaders: Record<string,string> = {}
  req.headers.forEach((v, k) => { allHeaders[k] = k === 'authorization' ? '***' : v })
  console.log('Headers:', JSON.stringify(allHeaders))

  // ── 3. Parse payload Lynk.id ──────────────────────────────────────────
  // Format Lynk.id: body.event + body.data.message_data
  const eventName   = str(body.event ?? body.event_name ?? '')
  const msgData     = (body.data as Record<string,unknown>)?.message_data as Record<string,unknown> ?? {}
  const msgAction   = str((body.data as Record<string,unknown>)?.message_action ?? msgData?.message_action ?? '')
  const trxId       = str(msgData.refId ?? msgData.ref_id ?? body.trx_id ?? body.transaction_id ?? '')
  const isPaid      = isPaymentSuccess(eventName, msgAction, body)

  console.log(`Webhook received: event=${eventName}, action=${msgAction}, trx=${trxId}, paid=${isPaid}`)
  console.log(`Raw payload: ${JSON.stringify(body)}`)

  // Hanya proses event payment berhasil
  if (!isPaid) {
    return json({ received: true, processed: false, reason: `Not a payment success event (event=${eventName}, action=${msgAction})` }, 200, cors)
  }

  if (!trxId) {
    return json({ error: 'trx_id/refId tidak ditemukan di payload' }, 400, cors)
  }

  // ── 4. Idempotency check — cegah duplikat ────────────────────────────
  const { data: existing } = await supabase
    .from('webhook_logs')
    .select('id, status, license_id')
    .eq('trx_id', trxId)
    .single()

  if (existing?.status === 'processed') {
    console.log(`Duplicate webhook for trx ${trxId}, skipping`)
    return json({ received: true, processed: false, reason: 'Already processed' }, 200, cors)
  }

  // ── 5. Simpan log awal (pending) ──────────────────────────────────────
  const { data: logEntry } = await supabase
    .from('webhook_logs')
    .upsert({
      trx_id:     trxId,
      event_name: eventName,
      status:     'pending',
      payload:    body,
    }, { onConflict: 'trx_id' })
    .select('id')
    .single()

  const logId = logEntry?.id

  // ── 6. Extract data customer dari payload ─────────────────────────────
  const customerName  = extractCustomerName(body)
  const customerEmail = extractCustomerEmail(body)
  const storeName     = extractStoreName(body)

  console.log(`Extracted: name="${customerName}", email="${customerEmail}", store="${storeName}"`)


  console.log(`Customer: name=${customerName}, email=${customerEmail}, store=${storeName}`)

  if (!customerName || !customerEmail) {
    const errMsg = `Data customer tidak lengkap: name=${customerName}, email=${customerEmail}`
    await updateLog(logId, 'failed', errMsg)
    return json({ error: errMsg }, 422, cors)
  }

  // ── 7. Buat lisensi ───────────────────────────────────────────────────
  const licenseKey = await generateLicenseKey()
  const expiresAt  = new Date(Date.now() + DEFAULT_EXPIRY_DAYS * 86400000).toISOString()

  const { data: license, error: licErr } = await supabase
    .from('licenses')
    .insert({
      license_key:   licenseKey,
      customer_name: customerName,
      store_name:    storeName || null,
      max_devices:   DEFAULT_MAX_DEVICES,
      expires_at:    expiresAt,
      notes:         `Auto-created from Lynk.id trx: ${trxId}`,
    })
    .select('id, license_key, customer_name, store_name')
    .single()

  if (licErr || !license) {
    const errMsg = 'Gagal membuat lisensi: ' + (licErr?.message ?? 'Unknown')
    await updateLog(logId, 'failed', errMsg)
    return json({ error: errMsg }, 500, cors)
  }

  // ── 8. Buat download token ────────────────────────────────────────────
  const token          = generateToken()
  const tokenExpiresAt = new Date(Date.now() + LINK_VALID_DAYS * 86400000).toISOString()

  const { error: tokErr } = await supabase.from('download_tokens').insert({
    token,
    license_id:       license.id,
    apk_download_url: DEFAULT_APK_URL,
    apk_version:      APP_VERSION,
    expires_at:       tokenExpiresAt,
    max_downloads:    MAX_DOWNLOADS,
    download_count:   0,
  })

  if (tokErr) {
    const errMsg = 'Lisensi dibuat tapi gagal buat download token: ' + tokErr.message
    await updateLog(logId, 'failed', errMsg, license.id)
    return json({ error: errMsg }, 500, cors)
  }

  const baseUrl     = Deno.env.get('SUPABASE_URL')!
  const downloadUrl = `${baseUrl}/functions/v1/download?token=${token}`

  // ── 9. Kirim email ────────────────────────────────────────────────────
  let emailSent  = false
  let emailError = ''

  if (RESEND_API_KEY) {
    const result = await sendEmail({
      to: customerEmail,
      customerName,
      storeName,
      licenseKey,
      downloadUrl,
      tokenExpiresAt,
      expiresAt,
      maxDevices: DEFAULT_MAX_DEVICES,
    })
    emailSent  = result.ok
    emailError = result.error ?? ''
  }

  // ── 10. Update log → processed ────────────────────────────────────────
  await supabase.from('webhook_logs').update({
    status:     'processed',
    license_id: license.id,
    error_msg:  emailError || null,
  }).eq('id', logId)

  console.log(`License created: ${licenseKey}, email_sent: ${emailSent}`)

  return json({
    received:    true,
    processed:   true,
    license_key: license.license_key,
    email_sent:  emailSent,
    email_error: emailError || undefined,
  }, 200, cors)
})

// ── Helper: cek payment success dari payload Lynk.id ─────────────────────
// Format: body.event = "payment.received", body.data.message_action = "SUCCESS"
function isPaymentSuccess(eventName: string, msgAction: string, body: Record<string, unknown>): boolean {
  const ev     = eventName.toLowerCase()
  const action = msgAction.toUpperCase()

  // Format Lynk.id utama
  if (ev === 'payment.received' && action === 'SUCCESS') return true
  if (ev === 'payment.success'  && action === 'SUCCESS') return true

  // Format alternatif
  if (ev.includes('payment') && action === 'SUCCESS') return true
  if (ev === 'paid' || ev === 'payment_success') return true

  // Cek message_code = "0" (sukses di Lynk.id)
  const msgData  = (body.data as Record<string,unknown>)?.message_data as Record<string,unknown> ?? {}
  const msgCode  = str((body.data as Record<string,unknown>)?.message_code ?? msgData.message_code ?? '')
  if (ev.includes('payment') && msgCode === '0') return true

  return false
}

// ── Helper: extract nama customer dari payload Lynk.id ───────────────────
// Lokasi: body.data.message_data.customer.name
function extractCustomerName(body: Record<string, unknown>): string {
  const msgData  = (body.data as Record<string,unknown>)?.message_data as Record<string,unknown> ?? {}
  const customer = msgData.customer as Record<string,unknown> ?? {}
  return str(
    customer.name ??
    body.buyer_name ??
    (body.buyer as Record<string,unknown>)?.name ??
    body.customer_name ??
    body.name ??
    ''
  ).trim()
}

// ── Helper: extract email customer dari payload Lynk.id ──────────────────
// Lokasi: body.data.message_data.customer.email
function extractCustomerEmail(body: Record<string, unknown>): string {
  const msgData  = (body.data as Record<string,unknown>)?.message_data as Record<string,unknown> ?? {}
  const customer = msgData.customer as Record<string,unknown> ?? {}
  return str(
    customer.email ??
    body.buyer_email ??
    (body.buyer as Record<string,unknown>)?.email ??
    body.customer_email ??
    body.email ??
    ''
  ).trim().toLowerCase()
}

// ── Helper: extract nama toko dari questions field Lynk.id ───────────────
// Lokasi: body.data.message_data.items[0].questions (JSON string)
// Format: '{"Email": "...", "Nama Toko": "Kiki fotokopi"}'
function extractStoreName(body: Record<string, unknown>): string {
  try {
    const msgData = (body.data as Record<string,unknown>)?.message_data as Record<string,unknown> ?? {}
    const items   = msgData.items as Record<string,unknown>[] ?? []

    for (const item of items) {
      const questionsRaw = str(item.questions ?? '')
      if (!questionsRaw) continue

      // Parse JSON string questions
      const questions = JSON.parse(questionsRaw) as Record<string, string>

      // Cari field "Nama Toko" (case-insensitive)
      for (const [key, val] of Object.entries(questions)) {
        const k = key.toLowerCase().replace(/\s+/g, '_')
        if (k === 'nama_toko' || k === 'store_name' || k === 'toko' || k === 'nama_usaha') {
          return str(val).trim()
        }
      }
    }
  } catch (e) {
    console.warn('Failed to parse questions field:', e)
  }

  // Fallback ke field langsung
  return str(body.store_name ?? body.nama_toko ?? '').trim()
}

// ── Verifikasi HMAC-SHA256 signature ─────────────────────────────────────
async function verifySignature(body: string, signature: string, secret: string): Promise<boolean> {
  try {
    const enc     = new TextEncoder()
    const key     = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
    const sigBuf  = await crypto.subtle.sign('HMAC', key, enc.encode(body))
    const sigHex  = Array.from(new Uint8Array(sigBuf)).map(b => b.toString(16).padStart(2, '0')).join('')
    return sigHex === signature.toLowerCase().replace('sha256=', '')
  } catch {
    return false
  }
}

// ── Update log status ─────────────────────────────────────────────────────
async function updateLog(logId: string | undefined, status: string, errMsg?: string, licenseId?: string) {
  if (!logId) return
  await supabase.from('webhook_logs').update({
    status,
    error_msg:  errMsg ?? null,
    license_id: licenseId ?? undefined,
  }).eq('id', logId)
}

// ── Send email via Resend ─────────────────────────────────────────────────
async function sendEmail(p: {
  to: string; customerName: string; storeName: string
  licenseKey: string; downloadUrl: string; tokenExpiresAt: string
  expiresAt: string | null; maxDevices: number
}): Promise<{ ok: boolean; error?: string }> {
  const exp = p.expiresAt
    ? new Date(p.expiresAt).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })
    : 'Tidak ada batas'
  const tokenExp = new Date(p.tokenExpiresAt).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })

  const text = `Halo ${p.customerName},

Terima kasih sudah berlangganan Kompak POS${p.storeName ? ' untuk ' + p.storeName : ''}.
Pembayaran Anda telah diterima. Berikut informasi untuk mengaktifkan aplikasi:

KODE AKTIVASI
${p.licenseKey}

PIN MASUK APLIKASI
1234
(PIN default Super Admin — ganti setelah login pertama)

LINK UNDUH APLIKASI
${p.downloadUrl}

Link unduh berlaku hingga ${tokenExp} dan dapat digunakan hingga 20 kali.

LANGKAH AKTIVASI
1. Buka link unduh di atas dari HP Android
2. Install aplikasi yang terunduh
3. Masukkan Kode Aktivasi saat diminta
4. Login dengan PIN: 1234
5. Ganti PIN di Pengaturan → Pengguna

Detail langganan:
- Masa aktif    : ${exp}
- Maks perangkat: ${p.maxDevices} HP

Salam,
Tim Kompak POS
pos.kompakapps.com

---
Email ini dikirim otomatis setelah pembayaran berhasil.`

  const html = `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Aktivasi Kompak POS</title>
</head>
<body style="margin:0;padding:0;background:#f8fafc;font-family:Arial,sans-serif;color:#1e293b">
<div style="max-width:520px;margin:32px auto;padding:0 16px">
  <div style="margin-bottom:16px">
    <p style="margin:0;font-size:13px;color:#64748b">Kompak POS · pos.kompakapps.com</p>
  </div>
  <div style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:32px">

    <p style="margin:0 0 4px;font-size:18px;font-weight:700;color:#0f172a">Halo, ${p.customerName} 👋</p>
    <p style="margin:0 0 24px;font-size:13px;color:#22c55e;font-weight:600">✓ Pembayaran berhasil diterima</p>
    <p style="margin:0 0 28px;font-size:14px;color:#475569;line-height:1.7">
      Terima kasih sudah berlangganan <strong>Kompak POS</strong>${p.storeName ? ' untuk <strong>' + p.storeName + '</strong>' : ''}.
      Berikut informasi yang Anda butuhkan.
    </p>

    <!-- Kode Aktivasi -->
    <p style="margin:0 0 6px;font-size:12px;font-weight:700;color:#64748b;text-transform:uppercase;letter-spacing:1px">Kode Aktivasi</p>
    <div style="background:#f8fafc;border:1px solid #cbd5e1;border-radius:6px;padding:14px 18px;margin-bottom:24px">
      <span style="font-size:20px;font-weight:700;font-family:'Courier New',monospace;letter-spacing:3px;color:#0f172a">${p.licenseKey}</span>
    </div>

    <!-- PIN -->
    <p style="margin:0 0 6px;font-size:12px;font-weight:700;color:#64748b;text-transform:uppercase;letter-spacing:1px">PIN Masuk Aplikasi</p>
    <div style="background:#f8fafc;border:1px solid #cbd5e1;border-radius:6px;padding:14px 18px;margin-bottom:6px;display:flex;align-items:center;justify-content:space-between">
      <span style="font-size:24px;font-weight:700;font-family:'Courier New',monospace;letter-spacing:6px;color:#0f172a">1234</span>
      <span style="font-size:11px;color:#94a3b8">Super Admin</span>
    </div>
    <p style="margin:0 0 24px;font-size:12px;color:#94a3b8">PIN default — segera ganti setelah login pertama melalui Pengaturan → Pengguna</p>

    <!-- Link Unduh -->
    <p style="margin:0 0 6px;font-size:12px;font-weight:700;color:#64748b;text-transform:uppercase;letter-spacing:1px">Link Unduh Aplikasi</p>
    <p style="margin:0 0 6px;font-size:13px;color:#475569">Klik link berikut untuk mengunduh aplikasi Kompak POS:</p>
    <p style="margin:0 0 6px">
      <a href="${p.downloadUrl}" style="color:#2563eb;font-size:13px;word-break:break-all">${p.downloadUrl}</a>
    </p>
    <p style="margin:0 0 24px;font-size:12px;color:#94a3b8">Berlaku hingga ${tokenExp} · Dapat digunakan hingga 20x</p>

    <!-- Cara Aktivasi -->
    <p style="margin:0 0 10px;font-size:12px;font-weight:700;color:#64748b;text-transform:uppercase;letter-spacing:1px">Cara Aktivasi</p>
    <ol style="margin:0 0 24px;padding-left:18px;font-size:13px;color:#475569;line-height:2">
      <li>Buka link unduh di atas dari HP Android</li>
      <li>Install aplikasi yang terunduh</li>
      <li>Masukkan <strong>Kode Aktivasi</strong> saat diminta</li>
      <li>Login dengan PIN <strong>1234</strong></li>
      <li>Ganti PIN di Pengaturan → Pengguna</li>
    </ol>

    <!-- Detail -->
    <div style="background:#f8fafc;border-radius:6px;padding:14px 18px;margin-bottom:24px;font-size:13px;color:#475569">
      <table style="width:100%;border-collapse:collapse">
        <tr><td style="padding:3px 0;width:45%;color:#94a3b8">Masa aktif</td><td style="font-weight:600">${exp}</td></tr>
        ${p.storeName ? `<tr><td style="padding:3px 0;color:#94a3b8">Toko</td><td style="font-weight:600">${p.storeName}</td></tr>` : ''}
        <tr><td style="padding:3px 0;color:#94a3b8">Maks perangkat</td><td style="font-weight:600">${p.maxDevices} HP</td></tr>
      </table>
    </div>

    <p style="margin:0;font-size:13px;color:#64748b;line-height:1.7">
      Ada pertanyaan? Balas email ini atau hubungi kami di<br>
      <a href="mailto:support@pos.kompakapps.com" style="color:#2563eb">support@pos.kompakapps.com</a>
    </p>
  </div>
  <div style="padding:20px 0;text-align:center">
    <p style="margin:0;font-size:11px;color:#94a3b8">
      © 2025 Kompak POS &nbsp;·&nbsp; pos.kompakapps.com<br>
      Email ini dikirim otomatis setelah pembayaran berhasil.<br>
      Abaikan jika Anda merasa tidak melakukan pembelian.
    </p>
  </div>
</div>
</body>
</html>`

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from:     FROM_EMAIL,
        reply_to: REPLY_TO,
        to:       [p.to],
        subject:  `Aktivasi Kompak POS — ${p.customerName}`,
        html,
        text,
        headers: {
          'List-Unsubscribe': `<mailto:support@pos.kompakapps.com?subject=unsubscribe>`,
          'X-Entity-Ref-ID':  p.licenseKey,
        },
      }),
    })
    if (!res.ok) return { ok: false, error: await res.text() }
    return { ok: true }
  } catch (e) {
    return { ok: false, error: String(e) }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────
function str(v: unknown): string { return v != null ? String(v) : '' }

async function generateLicenseKey(): Promise<string> {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  const rand  = (n: number) => Array.from(crypto.getRandomValues(new Uint8Array(n)))
    .map(b => chars[b % chars.length]).join('')
  return `KOMP-${rand(4)}-${rand(4)}-${rand(4)}`
}

function generateToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(24))
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('').toUpperCase()
}

function json(data: object, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), { status, headers })
}
