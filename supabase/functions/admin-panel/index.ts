// Supabase Edge Function: Admin Panel — Generate License + Download Link
// GET  → tampilkan form HTML
// POST → proses form, generate license key + download token, tampilkan hasil

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

// Password admin — GANTI dengan password yang lebih kuat sebelum production!
const ADMIN_PASSWORD = Deno.env.get('ADMIN_PASSWORD') ?? 'kompakadmin2024'
// URL APK terbaru (update setiap kali ada versi baru)
const DEFAULT_APK_URL = Deno.env.get('APK_DOWNLOAD_URL') ?? 'https://drive.google.com/uc?export=download&id=GANTI_FILE_ID_APK'
const APP_VERSION = '1.0.8'


Deno.serve(async (req: Request) => {
  if (req.method === 'GET') {
    return htmlResponse(renderForm({ success: false, submitted: false }))
  }

  if (req.method === 'POST') {
    try {
      const formData = await req.formData()
      const password      = formData.get('password')?.toString() ?? ''
      const customerName  = formData.get('customer_name')?.toString().trim() ?? ''
      const storeName     = formData.get('store_name')?.toString().trim() ?? ''
      const maxDevices    = parseInt(formData.get('max_devices')?.toString() ?? '1')
      const expiryDays    = parseInt(formData.get('expiry_days')?.toString() ?? '0')
      const apkUrl        = formData.get('apk_url')?.toString().trim() || DEFAULT_APK_URL
      const linkValidDays = parseInt(formData.get('link_valid_days')?.toString() ?? '7')
      const notes         = formData.get('notes')?.toString().trim() ?? ''

      // Cek password admin
      if (password !== ADMIN_PASSWORD) {
        return htmlResponse(renderForm({
          success: false, submitted: true,
          error: '❌ Password salah. Akses ditolak.',
          prefill: { customerName, storeName, maxDevices, expiryDays, apkUrl, linkValidDays, notes },
        }))
      }

      // Validasi input
      if (!customerName) {
        return htmlResponse(renderForm({
          success: false, submitted: true,
          error: '❌ Nama pelanggan wajib diisi.',
          prefill: { customerName, storeName, maxDevices, expiryDays, apkUrl, linkValidDays, notes },
        }))
      }

      // Generate license key: KOMP-XXXX-XXXX-XXXX
      const licenseKey = await generateLicenseKey()

    // Hitung expires_at
    const expiresAt = expiryDays > 0
      ? new Date(Date.now() + expiryDays * 86400000).toISOString()
      : null

    // Insert lisensi
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
      return htmlResponse(renderForm({
        success: false, submitted: true,
        error: '❌ Gagal membuat lisensi: ' + (licErr?.message ?? 'Unknown error'),
        prefill: { customerName, storeName, maxDevices, expiryDays, apkUrl, linkValidDays, notes },
      }))
    }

    // Generate download token
    const token = generateToken()
    const tokenExpiresAt = new Date(Date.now() + linkValidDays * 86400000).toISOString()

    const { error: tokErr } = await supabase
      .from('download_tokens')
      .insert({
        token,
        license_id: license.id,
        apk_download_url: apkUrl,
        apk_version: APP_VERSION,
        expires_at: tokenExpiresAt,
      })

    if (tokErr) {
      return htmlResponse(renderForm({
        success: false, submitted: true,
        error: '❌ Lisensi dibuat tapi gagal buat download link: ' + tokErr.message,
        prefill: { customerName, storeName, maxDevices, expiryDays, apkUrl, linkValidDays, notes },
      }))
    }

    const baseUrl = Deno.env.get('SUPABASE_URL')!
    const downloadUrl = `${baseUrl}/functions/v1/download?token=${token}`

      return htmlResponse(renderForm({
        success: true,
        submitted: true,
        result: {
          licenseKey: license.license_key,
          customerName: license.customer_name,
          storeName: license.store_name,
          downloadUrl,
          tokenExpiresAt,
          expiresAt,
          maxDevices,
        },
      }))
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err)
      return htmlResponse(renderForm({
        success: false, submitted: true,
        error: '❌ Terjadi kesalahan: ' + msg,
      }))
    }
  }

  return new Response('Method not allowed', { status: 405 })
})

// ── Helpers ──────────────────────────────────────────────────────────────────

async function generateLicenseKey(): Promise<string> {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  const rand = (n: number) => Array.from(crypto.getRandomValues(new Uint8Array(n)))
    .map(b => chars[b % chars.length]).join('')
  return `KOMP-${rand(4)}-${rand(4)}-${rand(4)}`
}

function generateToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(24))
  return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('').toUpperCase()
}

function htmlResponse(html: string): Response {
  return new Response(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  })
}

// ── HTML Renderer ─────────────────────────────────────────────────────────────

interface FormState {
  success: boolean
  submitted: boolean
  error?: string
  result?: {
    licenseKey: string
    customerName: string
    storeName: string | null
    downloadUrl: string
    tokenExpiresAt: string
    expiresAt: string | null
    maxDevices: number
  }
  prefill?: {
    customerName?: string
    storeName?: string
    maxDevices?: number
    expiryDays?: number
    apkUrl?: string
    linkValidDays?: number
    notes?: string
  }
}

function renderForm(state: FormState): string {
  const p = state.prefill ?? {}
  const r = state.result

  const resultHtml = r ? `
    <div class="result-card">
      <div class="result-header">
        <span class="result-icon">🎉</span>
        <h2>Lisensi Berhasil Dibuat!</h2>
        <p>untuk <strong>${r.customerName}</strong>${r.storeName ? ` — ${r.storeName}` : ''}</p>
      </div>

      <div class="result-items">
        <div class="result-item">
          <label>🔑 License Key (kirim via WA/Email)</label>
          <div class="copy-row">
            <code id="licKey">${r.licenseKey}</code>
            <button onclick="copy('licKey', this)" class="copy-btn">Copy</button>
          </div>
        </div>

        <div class="result-item">
          <label>🔗 Link Download APK (sekali pakai, berlaku ${Math.round((new Date(r.tokenExpiresAt).getTime() - Date.now()) / 86400000)} hari)</label>
          <div class="copy-row">
            <code id="dlUrl" class="small">${r.downloadUrl}</code>
            <button onclick="copy('dlUrl', this)" class="copy-btn">Copy</button>
          </div>
        </div>

        <div class="result-meta">
          <span>📱 Max Perangkat: <strong>${r.maxDevices}</strong></span>
          <span>⏰ Masa Berlaku Lisensi: <strong>${r.expiresAt ? new Date(r.expiresAt).toLocaleDateString('id-ID', {day:'2-digit',month:'long',year:'numeric'}) : 'Seumur Hidup'}</strong></span>
        </div>

        <div class="wa-template">
          <label>💬 Template Pesan WhatsApp</label>
          <textarea id="waMsg" readonly rows="6">Halo ${r.customerName}! 👋

Berikut informasi aktivasi Kompak POS Anda:

🔗 *Link Download APK* (sekali pakai):
${r.downloadUrl}

🔑 *License Key*:
${r.licenseKey}

Langkah:
1. Tap link download → install APK
2. Buka app → masukkan License Key
3. Selesai! App siap digunakan ✅

Masa berlaku link: ${new Date(r.tokenExpiresAt).toLocaleDateString('id-ID', {day:'2-digit',month:'long',year:'numeric'})}

Hubungi kami jika ada kendala 🙏</textarea>
          <button onclick="copy('waMsg', this)" class="copy-btn full">📋 Copy Pesan WA</button>
        </div>
      </div>

      <div class="new-btn-row">
        <button onclick="window.location.reload()" class="btn-new">+ Buat Lisensi Baru</button>
      </div>
    </div>
  ` : ''

  const errorHtml = state.error ? `
    <div class="alert error">${state.error}</div>
  ` : ''

  const formHtml = !state.success ? `
    <form method="POST" class="form-card">
      ${errorHtml}

      <div class="form-section">
        <h3>📋 Informasi Pelanggan</h3>
        <div class="form-group">
          <label>Nama Pelanggan <span class="required">*</span></label>
          <input type="text" name="customer_name" value="${p.customerName ?? ''}"
            placeholder="contoh: Toko Maju Jaya" required>
        </div>
        <div class="form-group">
          <label>Nama Toko / Cabang</label>
          <input type="text" name="store_name" value="${p.storeName ?? ''}"
            placeholder="contoh: Cabang Jakarta Selatan">
        </div>
        <div class="form-row">
          <div class="form-group">
            <label>Maks. Perangkat</label>
            <select name="max_devices">
              <option value="1" ${(p.maxDevices??1)==1?'selected':''}>1 Perangkat</option>
              <option value="2" ${(p.maxDevices??1)==2?'selected':''}>2 Perangkat</option>
              <option value="3" ${(p.maxDevices??1)==3?'selected':''}>3 Perangkat</option>
              <option value="5" ${(p.maxDevices??1)==5?'selected':''}>5 Perangkat</option>
            </select>
          </div>
          <div class="form-group">
            <label>Masa Berlaku Lisensi</label>
            <select name="expiry_days">
              <option value="0" ${(p.expiryDays??0)==0?'selected':''}>Seumur Hidup</option>
              <option value="365" ${(p.expiryDays??0)==365?'selected':''}>1 Tahun</option>
              <option value="730" ${(p.expiryDays??0)==730?'selected':''}>2 Tahun</option>
              <option value="180" ${(p.expiryDays??0)==180?'selected':''}>6 Bulan</option>
              <option value="90" ${(p.expiryDays??0)==90?'selected':''}>3 Bulan</option>
            </select>
          </div>
        </div>
        <div class="form-group">
          <label>Catatan (opsional)</label>
          <input type="text" name="notes" value="${p.notes ?? ''}"
            placeholder="contoh: Bayar via transfer BCA">
        </div>
      </div>

      <div class="form-section">
        <h3>📦 Link Download APK</h3>
        <div class="form-group">
          <label>URL File APK</label>
          <input type="url" name="apk_url" value="${p.apkUrl ?? DEFAULT_APK_URL}"
            placeholder="https://drive.google.com/uc?export=download&id=...">
          <small>Gunakan link Google Drive / Dropbox yang bisa didownload langsung</small>
        </div>
        <div class="form-group">
          <label>Link berlaku selama</label>
          <select name="link_valid_days">
            <option value="3" ${(p.linkValidDays??7)==3?'selected':''}>3 Hari</option>
            <option value="7" ${(p.linkValidDays??7)==7?'selected':''}>7 Hari</option>
            <option value="14" ${(p.linkValidDays??7)==14?'selected':''}>14 Hari</option>
            <option value="30" ${(p.linkValidDays??7)==30?'selected':''}>30 Hari</option>
          </select>
        </div>
      </div>

      <div class="form-section">
        <h3>🔐 Password Admin</h3>
        <div class="form-group">
          <label>Password <span class="required">*</span></label>
          <input type="password" name="password" placeholder="Masukkan password admin" required>
        </div>
      </div>

      <button type="submit" class="btn-submit">
        ⚡ Generate License + Download Link
      </button>
    </form>
  ` : ''

  return `<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kompak POS — Admin Panel</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: linear-gradient(135deg, #e8f4f8 0%, #f0f7ff 100%);
      min-height: 100vh; padding: 24px 16px;
    }
    .container { max-width: 600px; margin: 0 auto; }
    header { text-align: center; margin-bottom: 28px; }
    header .logo { font-size: 36px; margin-bottom: 8px; }
    header h1 { font-size: 22px; color: #1990B3; font-weight: 700; }
    header p { color: #666; font-size: 14px; margin-top: 4px; }

    .form-card, .result-card {
      background: white; border-radius: 16px;
      box-shadow: 0 4px 24px rgba(0,0,0,0.08); overflow: hidden;
    }
    .form-section {
      padding: 20px 24px;
      border-bottom: 1px solid #f0f0f0;
    }
    .form-section h3 {
      font-size: 14px; font-weight: 600; color: #555;
      text-transform: uppercase; letter-spacing: 0.5px;
      margin-bottom: 16px;
    }
    .form-group { margin-bottom: 14px; }
    .form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    label { display: block; font-size: 13px; font-weight: 500; color: #444; margin-bottom: 6px; }
    .required { color: #e53e3e; }
    input, select, textarea {
      width: 100%; padding: 10px 12px; border: 1.5px solid #e2e8f0;
      border-radius: 8px; font-size: 14px; color: #333;
      transition: border-color 0.2s; font-family: inherit;
    }
    input:focus, select:focus, textarea:focus {
      outline: none; border-color: #1990B3;
      box-shadow: 0 0 0 3px rgba(25,144,179,0.1);
    }
    small { display: block; margin-top: 5px; font-size: 12px; color: #888; }

    .btn-submit {
      display: block; width: calc(100% - 48px); margin: 20px 24px;
      padding: 14px; background: #1990B3; color: white;
      border: none; border-radius: 10px; font-size: 16px;
      font-weight: 700; cursor: pointer; transition: background 0.2s;
    }
    .btn-submit:hover { background: #147a9a; }

    .alert.error {
      margin: 0 0 16px; padding: 12px 16px; background: #fff5f5;
      border: 1px solid #fc8181; border-radius: 8px;
      color: #c53030; font-size: 14px;
    }

    /* Result */
    .result-header {
      background: linear-gradient(135deg, #1990B3, #0f6d8a);
      padding: 28px 24px; text-align: center; color: white;
    }
    .result-icon { font-size: 40px; display: block; margin-bottom: 10px; }
    .result-header h2 { font-size: 20px; margin-bottom: 4px; }
    .result-header p { opacity: 0.85; font-size: 14px; }
    .result-items { padding: 20px 24px; }
    .result-item { margin-bottom: 20px; }
    .result-item label {
      display: block; font-size: 12px; font-weight: 600;
      color: #888; margin-bottom: 8px; text-transform: uppercase;
    }
    .copy-row {
      display: flex; gap: 8px; align-items: stretch;
    }
    code {
      flex: 1; background: #f7fafc; border: 1.5px solid #e2e8f0;
      border-radius: 8px; padding: 10px 14px;
      font-family: 'Courier New', monospace; font-size: 15px;
      color: #1990B3; font-weight: 700; word-break: break-all;
    }
    code.small { font-size: 11px; font-weight: 400; color: #444; }
    .copy-btn {
      padding: 8px 14px; background: #1990B3; color: white;
      border: none; border-radius: 8px; cursor: pointer;
      font-size: 13px; font-weight: 600; white-space: nowrap;
      transition: background 0.2s;
    }
    .copy-btn:hover { background: #147a9a; }
    .copy-btn.full { width: 100%; margin-top: 8px; padding: 10px; }
    .copy-btn.copied { background: #38a169; }

    .result-meta {
      display: flex; gap: 16px; flex-wrap: wrap;
      background: #f7fafc; border-radius: 10px;
      padding: 12px 14px; margin-bottom: 20px;
    }
    .result-meta span { font-size: 13px; color: #555; }

    .wa-template label {
      font-size: 12px; font-weight: 600; color: #888;
      margin-bottom: 8px; display: block; text-transform: uppercase;
    }
    .wa-template textarea {
      font-family: 'Courier New', monospace; font-size: 12px;
      color: #444; resize: none; background: #f7fafc;
    }

    .new-btn-row { padding: 16px 24px; border-top: 1px solid #f0f0f0; text-align: center; }
    .btn-new {
      padding: 12px 28px; background: white; color: #1990B3;
      border: 2px solid #1990B3; border-radius: 10px;
      font-size: 15px; font-weight: 700; cursor: pointer;
      transition: all 0.2s;
    }
    .btn-new:hover { background: #1990B3; color: white; }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div class="logo">🏪</div>
      <h1>Kompak POS — Admin Panel</h1>
      <p>Generate license key + download link untuk pelanggan baru</p>
    </header>

    ${formHtml}
    ${resultHtml}
  </div>

  <script>
    function copy(id, btn) {
      const el = document.getElementById(id);
      const text = el.tagName === 'TEXTAREA' ? el.value : el.innerText;
      navigator.clipboard.writeText(text).then(() => {
        btn.textContent = '✓ Copied!';
        btn.classList.add('copied');
        setTimeout(() => {
          btn.textContent = id === 'waMsg' ? '📋 Copy Pesan WA' : 'Copy';
          btn.classList.remove('copied');
        }, 2000);
      });
    }
  </script>
</body>
</html>`
}
