// Edge Function: GET /functions/v1/download?token=xxx
// Melayani download APK — bisa dipakai ulang sampai max_downloads kali (default 3)
// untuk mendukung skenario reinstall oleh pelanggan yang sama.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

Deno.serve(async (req: Request) => {
  if (req.method !== 'GET') {
    return new Response('Method not allowed', { status: 405 })
  }

  const url   = new URL(req.url)
  const token = url.searchParams.get('token') ?? url.pathname.split('/').pop()

  if (!token || token === 'download') {
    return errText(400, 'Token tidak ditemukan.')
  }

  // Cari token
  const { data: row, error } = await supabase
    .from('download_tokens')
    .select('id, is_used, expires_at, apk_download_url, download_count, max_downloads')
    .eq('token', token)
    .single()

  if (error || !row) {
    return errText(404, 'Link tidak valid atau tidak ditemukan.')
  }

  // Cek sudah expired (waktu)
  if (new Date(row.expires_at) < new Date()) {
    return errText(410, 'Link sudah kedaluwarsa. Hubungi admin untuk link baru.')
  }

  const maxDl = row.max_downloads ?? 1
  const count = row.download_count ?? 0

  // Cek sudah melebihi batas download
  if (row.is_used || count >= maxDl) {
    return errText(410,
      `Link ini sudah digunakan ${count}x (batas maksimal ${maxDl}x).\n` +
      'Hubungi admin untuk link baru.'
    )
  }

  // Increment download_count secara atomic
  const clientIp = req.headers.get('x-forwarded-for') ?? req.headers.get('cf-connecting-ip') ?? 'unknown'
  const newCount = count + 1
  const isNowUsed = newCount >= maxDl  // tandai is_used jika sudah mencapai batas

  const { error: updateError } = await supabase
    .from('download_tokens')
    .update({
      download_count: newCount,
      is_used:        isNowUsed,
      used_at:        isNowUsed ? new Date().toISOString() : undefined,
      used_ip:        clientIp,
    })
    .eq('id', row.id)
    .eq('download_count', count) // optimistic lock: pastikan tidak ada race condition

  if (updateError) {
    // Race condition — request lain baru saja increment
    return errText(410, 'Link sudah mencapai batas penggunaan. Hubungi admin.')
  }

  // Redirect ke loading page di GitHub Pages (Supabase tidak bisa serve HTML)
  const loadingPage = `https://kreatifodoo.github.io/Kompak-POS/loading.html?url=${encodeURIComponent(row.apk_download_url)}`
  return new Response(null, {
    status: 302,
    headers: { 'Location': loadingPage },
  })
})

function errText(status: number, message: string): Response {
  const WA_ADMIN = Deno.env.get('ADMIN_WA') ?? '6285121582718'
  const body = [
    '━━━━━━━━━━━━━━━━━━━━━━━━━',
    '   KOMPAK POS',
    '   Link Download APK',
    '━━━━━━━━━━━━━━━━━━━━━━━━━',
    '',
    `⛔  ${message}`,
    '',
    'Hubungi admin untuk mendapatkan',
    'link baru:',
    `https://wa.me/${WA_ADMIN}`,
    '',
    '━━━━━━━━━━━━━━━━━━━━━━━━━',
  ].join('\n')
  return new Response(body, { status, headers: { 'Content-Type': 'text/plain; charset=utf-8' } })
}
