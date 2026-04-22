// Edge Function: admin-create
// POST → buat license + download token + kirim email otomatis via Resend

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

const ADMIN_PASSWORD  = Deno.env.get('ADMIN_PASSWORD') ?? 'kompakadmin2024'
const DEFAULT_APK_URL = Deno.env.get('APK_DOWNLOAD_URL') ?? 'https://qyxvxoavypqbiacinqbz.supabase.co/storage/v1/object/public/apk/kompak-pos-v1.0.9-arm64.apk'
const APP_VERSION     = '1.0.9'
const RESEND_API_KEY  = Deno.env.get('RESEND_API_KEY') ?? ''
const FROM_EMAIL      = Deno.env.get('FROM_EMAIL') ?? 'Kompak POS <info@pos.kompakapps.com>'
const REPLY_TO        = Deno.env.get('REPLY_TO')   ?? 'support@pos.kompakapps.com'
const MAX_DOWNLOADS   = 20  // izinkan reinstall sampai 20x dengan link yang sama

Deno.serve(async (req: Request) => {
  const cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'content-type, authorization',
    'Content-Type': 'application/json',
  }

  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405, cors)

  let body: Record<string, unknown>
  try { body = await req.json() }
  catch { return json({ error: 'JSON tidak valid' }, 400, cors) }

  const password      = (body.password as string ?? '').trim()
  const customerName  = (body.customer_name as string ?? '').trim()
  const storeName     = (body.store_name as string ?? '').trim()
  const customerEmail = (body.customer_email as string ?? '').trim()
  const maxDevices    = parseInt(body.max_devices as string ?? '1')
  const expiryDays    = parseInt(body.expiry_days as string ?? '0')
  const apkUrl        = (body.apk_url as string ?? DEFAULT_APK_URL).trim()
  const linkValidDays = parseInt(body.link_valid_days as string ?? '7')
  const notes         = (body.notes as string ?? '').trim()

  if (password !== ADMIN_PASSWORD)  return json({ error: 'Password salah' }, 401, cors)
  if (!customerName)                return json({ error: 'Nama pelanggan wajib diisi' }, 400, cors)
  if (!apkUrl)                      return json({ error: 'URL APK wajib diisi' }, 400, cors)
  if (customerEmail && !customerEmail.includes('@'))
    return json({ error: 'Format email tidak valid' }, 400, cors)

  // ── 1. Buat lisensi ───────────────────────────────────────────────────
  const licenseKey = await generateLicenseKey()
  const expiresAt  = expiryDays > 0
    ? new Date(Date.now() + expiryDays * 86400000).toISOString()
    : null

  const { data: license, error: licErr } = await supabase
    .from('licenses')
    .insert({
      license_key: licenseKey,
      customer_name: customerName,
      store_name: storeName || null,
      max_devices: maxDevices,
      expires_at: expiresAt,
      notes: notes || null,
    })
    .select('id, license_key, customer_name, store_name')
    .single()

  if (licErr || !license) {
    return json({ error: 'Gagal membuat lisensi: ' + (licErr?.message ?? 'Unknown') }, 500, cors)
  }

  // ── 2. Buat download token (mendukung re-download max 3x untuk reinstall) ──
  const token          = generateToken()
  const tokenExpiresAt = new Date(Date.now() + linkValidDays * 86400000).toISOString()

  const { error: tokErr } = await supabase.from('download_tokens').insert({
    token,
    license_id:       license.id,
    apk_download_url: apkUrl,
    apk_version:      APP_VERSION,
    expires_at:       tokenExpiresAt,
    max_downloads:    MAX_DOWNLOADS,
    download_count:   0,
  })

  if (tokErr) {
    return json({ error: 'Lisensi dibuat tapi gagal buat link: ' + tokErr.message }, 500, cors)
  }

  const baseUrl     = Deno.env.get('SUPABASE_URL')!
  const downloadUrl = `${baseUrl}/functions/v1/download?token=${token}`

  // ── 3. Kirim email otomatis via Resend (jika email diisi & API key ada) ──
  let emailSent   = false
  let emailError  = ''

  if (customerEmail && RESEND_API_KEY) {
    const result = await sendEmail({
      to: customerEmail,
      customerName,
      storeName,
      licenseKey,
      downloadUrl,
      tokenExpiresAt,
      expiresAt,
      maxDevices,
    })
    emailSent  = result.ok
    emailError = result.error ?? ''
  }

  return json({
    success:         true,
    license_key:     license.license_key,
    customer_name:   license.customer_name,
    store_name:      license.store_name,
    download_url:    downloadUrl,
    token_expires_at: tokenExpiresAt,
    expires_at:      expiresAt,
    max_devices:     maxDevices,
    email_sent:      emailSent,
    email_error:     emailError || undefined,
  }, 200, cors)
})

// ── Email via Resend ───────────────────────────────────────────────────────
async function sendEmail(p: {
  to: string
  customerName: string
  storeName: string
  licenseKey: string
  downloadUrl: string
  tokenExpiresAt: string
  expiresAt: string | null
  maxDevices: number
}): Promise<{ ok: boolean; error?: string }> {
  const exp      = p.expiresAt
    ? new Date(p.expiresAt).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })
    : 'Tidak ada batas'
  const tokenExp = new Date(p.tokenExpiresAt).toLocaleDateString('id-ID', { day: '2-digit', month: 'long', year: 'numeric' })

  // Plain text version (wajib untuk deliverability)
  const text = `Halo ${p.customerName},

Terima kasih sudah menggunakan Kompak POS${p.storeName ? ' untuk ' + p.storeName : ''}.

Kami telah menyiapkan akun Anda. Berikut informasi yang Anda butuhkan:

KODE AKTIVASI
${p.licenseKey}

LINK UNDUH APLIKASI
${p.downloadUrl}

Link unduh berlaku hingga ${tokenExp} dan dapat digunakan hingga 20 kali.

PIN MASUK APLIKASI
1234
(PIN default Super Admin — ganti setelah login pertama)

LANGKAH SELANJUTNYA
1. Buka link unduh di atas menggunakan HP Android
2. Install aplikasi yang terunduh
3. Saat pertama buka, masukkan Kode Aktivasi di atas
4. Login menggunakan PIN: 1234
5. Segera ganti PIN di menu Pengaturan → Pengguna

Detail akun:
- Masa aktif  : ${exp}
- Maks perangkat: ${p.maxDevices} HP

Salam,
Tim Kompak POS
pos.kompakapps.com

---
Email ini dikirim khusus untuk ${p.customerName}. Abaikan jika Anda merasa tidak mendaftar.`

  // HTML version — sederhana, hindari pola phishing
  const html = `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Informasi Akun Kompak POS</title>
</head>
<body style="margin:0;padding:0;background:#f8fafc;font-family:Arial,sans-serif;color:#1e293b">

<div style="max-width:520px;margin:32px auto;padding:0 16px">

  <!-- Header sederhana -->
  <div style="margin-bottom:24px">
    <p style="margin:0;font-size:13px;color:#64748b">Kompak POS · pos.kompakapps.com</p>
  </div>

  <!-- Card -->
  <div style="background:#fff;border:1px solid #e2e8f0;border-radius:8px;padding:32px">

    <p style="margin:0 0 8px;font-size:18px;font-weight:700;color:#0f172a">Halo, ${p.customerName} 👋</p>
    <p style="margin:0 0 28px;font-size:14px;color:#475569;line-height:1.7">
      Terima kasih sudah menggunakan <strong>Kompak POS</strong>${p.storeName ? ' untuk <strong>' + p.storeName + '</strong>' : ''}.
      Berikut informasi yang Anda butuhkan untuk mulai menggunakan aplikasi.
    </p>

    <!-- Kode Aktivasi -->
    <p style="margin:0 0 6px;font-size:12px;font-weight:700;color:#64748b;text-transform:uppercase;letter-spacing:1px">Kode Aktivasi</p>
    <div style="background:#f8fafc;border:1px solid #cbd5e1;border-radius:6px;padding:14px 18px;margin-bottom:24px">
      <span style="font-size:20px;font-weight:700;font-family:'Courier New',monospace;letter-spacing:3px;color:#0f172a">${p.licenseKey}</span>
    </div>

    <!-- Link Unduh -->
    <p style="margin:0 0 6px;font-size:12px;font-weight:700;color:#64748b;text-transform:uppercase;letter-spacing:1px">Link Unduh Aplikasi</p>
    <p style="margin:0 0 6px;font-size:13px;color:#475569">Klik link berikut untuk mengunduh aplikasi Kompak POS:</p>
    <p style="margin:0 0 6px">
      <a href="${p.downloadUrl}" style="color:#2563eb;font-size:13px;word-break:break-all">${p.downloadUrl}</a>
    </p>
    <p style="margin:0 0 24px;font-size:12px;color:#94a3b8">Berlaku hingga ${tokenExp} · Dapat digunakan hingga 20x</p>

    <!-- PIN Login -->
    <p style="margin:0 0 6px;font-size:12px;font-weight:700;color:#64748b;text-transform:uppercase;letter-spacing:1px">PIN Masuk Aplikasi</p>
    <div style="background:#f8fafc;border:1px solid #cbd5e1;border-radius:6px;padding:14px 18px;margin-bottom:6px;display:flex;align-items:center;justify-content:space-between">
      <span style="font-size:24px;font-weight:700;font-family:'Courier New',monospace;letter-spacing:6px;color:#0f172a">1234</span>
      <span style="font-size:11px;color:#94a3b8">Super Admin</span>
    </div>
    <p style="margin:0 0 24px;font-size:12px;color:#94a3b8">PIN default — segera ganti setelah login pertama melalui Pengaturan → Pengguna</p>

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

  <!-- Footer -->
  <div style="padding:20px 0;text-align:center">
    <p style="margin:0;font-size:11px;color:#94a3b8">
      © 2025 Kompak POS &nbsp;·&nbsp; pos.kompakapps.com<br>
      Email ini dikirim khusus untuk ${p.customerName}.<br>
      Abaikan jika Anda merasa tidak mendaftar.
    </p>
  </div>

</div>
</body>
</html>`

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from:     FROM_EMAIL,
        reply_to: REPLY_TO,
        to:       [p.to],
        subject:  `Informasi akun Kompak POS untuk ${p.customerName}`,
        html,
        text,   // plain text wajib untuk inbox rate
        headers: {
          'List-Unsubscribe': `<mailto:support@pos.kompakapps.com?subject=unsubscribe>`,
          'X-Entity-Ref-ID': p.licenseKey,
        },
      }),
    })
    if (!res.ok) {
      const err = await res.text()
      return { ok: false, error: err }
    }
    return { ok: true }
  } catch (e) {
    return { ok: false, error: String(e) }
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────
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
