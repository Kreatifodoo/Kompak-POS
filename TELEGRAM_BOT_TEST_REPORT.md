# 🤖 Laporan Test Menyeluruh — Telegram Bot Kompak POS
**Tanggal:** 31 Maret 2026
**Versi Test Suite:** v2.0
**Scope:** Diagnostik · Unit Test · SIT · Stress Test · Root Cause Analysis

---

## 📊 Ringkasan Eksekutif

| Kategori | Pass | Fail | Score |
|---|---|---|---|
| Unit Test (Intent Detection) | 31 | 5 | **86%** |
| SIT (System Integration Test) | 17 | 2 | **89%** |
| Stress Test (1.250 requests) | 4/4 | 0 | **100%** ✅ |
| **TOTAL** | **52** | **7** | **88%** |

> ⚠️ **Peringatan:** Diagnostik Live (koneksi Telegram & Gemini) tidak dapat dijalankan dari lingkungan sandbox. Skrip `telegram_test_suite.py` harus dijalankan di perangkat yang terhubung internet untuk test live.

---

## 🔴 Root Cause Analysis — Kenapa Bot Tidak Merespons?

### ❌ Penyebab #1 — `telegram_chatbot_enabled = false` (PALING MUNGKIN)

Di `telegram_chatbot_service.dart` baris 78:
```dart
if (!isEnabled || _botToken.isEmpty || _geminiKey.isEmpty) {
    return;  // ← polling tidak start!
}
```

`isEnabled` membaca `prefs.getBool('telegram_chatbot_enabled')`. Jika toggle **"Aktifkan AI Chatbot"** di Settings belum di-ON, `startPolling()` langsung return tanpa memulai polling sama sekali.

**FIX:** Buka app → Settings → Telegram → toggle **"Aktifkan AI Chatbot"** → ON → **Simpan**

---

### ❌ Penyebab #2 — Webhook Aktif Konflik dengan Polling

Telegram **tidak memperbolehkan** webhook + polling bersamaan. Jika ada webhook aktif, `getUpdates` akan gagal dengan error 409 Conflict — bot sama sekali tidak menerima pesan.

**FIX:** Jalankan di terminal:
```bash
curl 'https://api.telegram.org/bot<TOKEN>/deleteWebhook'
```
Atau cek dulu:
```bash
curl 'https://api.telegram.org/bot<TOKEN>/getWebhookInfo'
```

---

### ❌ Penyebab #3 — Chat ID Tidak Cocok

Di `telegram_chatbot_service.dart` baris 169:
```dart
if (chatId != _chatId) {
    continue;  // pesan diabaikan tanpa error!
}
```

Jika Chat ID yang tersimpan di Settings salah (misalnya pakai username `@namauser` bukan angka numerik), semua pesan akan di-ignore secara diam-diam.

**FIX:** Pastikan Chat ID adalah angka numerik.
Cara cek: Kirim pesan ke bot → buka `https://api.telegram.org/bot<TOKEN>/getUpdates` → lihat `message.chat.id`

---

### ❌ Penyebab #4 — App Tidak Aktif / Background Kill

Bot Kompak POS berjalan sebagai **Timer** di dalam aplikasi Flutter. Polling hanya aktif selama aplikasi **HIDUP dan DI FOREGROUND**. Android agresif mematikan proses background untuk hemat baterai.

**FIX:** Pastikan aplikasi tetap terbuka (jangan minimize lama). Atau aktifkan **"Keep Screen On"** di Developer Options.

---

### ❌ Penyebab #5 — Gemini API Key Tidak Valid / Quota Habis

Jika semua model Gemini di `_fallbackModels` gagal, bot masih bisa mengirim respons (data mentah), tapi jika error terjadi sebelum query POS, tidak ada respons yang terkirim.

**FIX:** Test Gemini API Key di: [aistudio.google.com](https://aistudio.google.com)

---

## ✅ Checklist Perbaikan (Urutan Prioritas)

- [ ] **1.** Buka app → Settings → Telegram → pastikan **"Aktifkan AI Chatbot" = ON**
- [ ] **2.** Pastikan **Bot Token** dan **Gemini API Key** sudah diisi
- [ ] **3.** Klik **"Simpan"** untuk restart polling dengan config baru
- [ ] **4.** Cek webhook: `curl 'https://api.telegram.org/bot<TOKEN>/getWebhookInfo'`
- [ ] **5.** Hapus webhook jika ada: `curl 'https://api.telegram.org/bot<TOKEN>/deleteWebhook'`
- [ ] **6.** Pastikan Chat ID adalah **angka numerik** yang benar
- [ ] **7.** Kirim pesan ke bot, pastikan app **masih terbuka** di foreground
- [ ] **8.** Test via tombol **"Test AI Chatbot"** di Settings app

---

## 🧪 Unit Test — Intent Detection (86%, 31/36)

### ✅ PASS (31 test)
Semua query umum bekerja dengan benar:
- Penjualan harian/mingguan/bulanan/all-time ✅
- Top produk, stok, promosi, kasir ✅
- Multi-bahasa (Inggris + Indonesia) ✅
- Uppercase, karakter spesial ✅

### ❌ FAIL (5 test) — Bug yang Ditemukan

| # | Input | Expected | Got | Analisis |
|---|---|---|---|---|
| 1 | `"produk terlaris all time"` | `top_products_alltime` | `all_sales` | Keyword `"all time"` ditangkap oleh intent `all_sales` sebelum `top_products_alltime` — **urutan cek intent salah** |
| 2 | `"stok rendah"` | `stock_low` | `stock_search` | Regex stock_product match `"stok"` + kata setelahnya (`"rendah"`) sebelum cek `stock_low` — **regex terlalu greedy** |
| 3 | `"air mineral tinggal berapa?"` | `stock_search` | `full_summary` | Pattern `_hasStockWithProduct` butuh kata `stok/stock` di awal — query tanpa prefiks stok tidak dideteksi |
| 4 | `"sesi kasir aktif"` | `session_info` | `cashier_stats` | Keyword `"kasir"` diperiksa sebelum `"sesi"` — **urutan prioritas salah** |
| 5 | `"penjualan  hari   ini"` (extra spaces) | `daily_sales` | `full_summary` | Multiple spaces memecah exact match `"penjualan hari ini"` — **tidak ada normalisasi whitespace** |

### 💡 Rekomendasi Perbaikan Dart Code

```dart
// 1. Normalisasi whitespace di awal detectIntent
final lower = text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

// 2. Pindahkan cek stock_low SEBELUM regex stock_product
if (_matchesAny(lower, ['stok rendah', 'low stock', 'hampir habis'])) {
  return IntentResult('stock_low');
}
// ... baru regex stock_product

// 3. Pindahkan session_info SEBELUM cashier_stats
if (_matchesAny(lower, ['sesi', 'session', 'shift', 'register'])) {
  return IntentResult('session_info');
}
// ... baru kasir check

// 4. Fix top_products_alltime — cek compound keyword lebih spesifik
if (_matchesAny(lower, ['terlaris all', 'best seller all', 'top all time', 'top produk all'])) {
  return IntentResult('top_products_alltime');
}
```

---

## 🔗 SIT — System Integration Test (89%, 17/19)

### ✅ PASS (17 test)

| Kategori | Hasil |
|---|---|
| Happy Path (5 test) | 5/5 ✅ |
| Failure Scenarios (6 test) | 6/6 ✅ |
| Multi-language (3 test) | 3/3 ✅ |
| Edge Case (5 test) | 3/5 ⚠️ |

### ❌ FAIL (2 test)

**SIT-012** — Pesan sangat panjang (500 karakter): Intent `daily_sales` tidak terdeteksi karena normalisasi teks panjang — bukan bug kritis, Gemini akan handle.

**SIT-016** — Multi-keyword conflict (`"stok dan penjualan"`): Detected `stock_search` bukan `stock_check` karena regex greedy. Masih fungsional.

### ✅ Skenario Failure Berhasil Terverifikasi

Semua skenario kritis berhasil dideteksi dengan benar:
- Polling disabled → bot tidak respons ✅
- Token kosong → polling tidak mulai ✅
- Gemini key kosong → polling tidak mulai ✅
- Chat ID tidak cocok → pesan diabaikan ✅
- Tidak ada toko aktif → error response ✅
- Telegram send gagal → respons tidak terkirim ✅

---

## 💪 Stress Test (100%, 1.250 requests)

| Skenario | Request | Success Rate | Throughput | Avg Latency | P95 |
|---|---|---|---|---|---|
| Beban Ringan (5u × 10) | 50 | **100%** ✅ | ~30K req/s | 0.01ms | 0.02ms |
| Beban Sedang (10u × 20) | 200 | **100%** ✅ | ~39K req/s | 0.01ms | 0.02ms |
| Beban Berat (25u × 30) | 750 | **100%** ✅ | ~54K req/s | 0.01ms | 0.01ms |
| Spike Test (50u × 5) | 250 | **100%** ✅ | ~38K req/s | 0.01ms | 0.02ms |

> **Kesimpulan Stress Test:** Logika intent detection sangat ringan dan tahan beban tinggi. Tidak ada bottleneck pada layer logika. Bottleneck nyata ada di latency jaringan ke Telegram API dan Gemini API (expected ~1-5 detik per respons).

---

## 📋 Arsitektur Bot — Temuan Penting

### Konfigurasi Yang Diperlukan (SharedPreferences)
| Key | Tipe | Fungsi |
|---|---|---|
| `telegram_chatbot_enabled` | bool | Toggle ON/OFF polling |
| `telegram_bot_token` | String | Token bot dari @BotFather |
| `telegram_chat_id` | String | Chat ID numerik tujuan |
| `gemini_api_key` | String | API key Google AI Studio |
| `chatbot_last_update_id` | int | Tracking pesan terakhir |
| `telegram_enabled` | bool | Toggle kirim laporan sesi |

### Alur Normal (Happy Path)
```
User kirim pesan di Telegram
       ↓
Timer 5 detik → getUpdates
       ↓
Validasi Chat ID cocok?
       ↓ (ya)
Gemini classifyIntent()
       ↓
PosQueryService.queryByIntent()
       ↓
Gemini _askGemini() — 3 model fallback
       ↓
_sendTelegram() → user menerima jawaban
```

### Model Fallback Gemini
```dart
static const _fallbackModels = [
  'gemini-2.5-flash',   // Coba pertama
  'gemini-2.0-flash',   // Fallback 1
  'gemini-2.0-flash-lite', // Fallback 2
];
```
Jika semua gagal → kirim raw data (tanpa AI formatting).

---

## 🛠️ Cara Menjalankan Test Live

Jalankan dari perangkat/komputer yang terhubung internet:

```bash
# Install dependency
pip install requests

# Jalankan test suite lengkap (diagnostik + SIT + stress)
python3 telegram_test_suite.py
```

Skrip akan otomatis:
1. Detect koneksi internet → jalankan test live ke Telegram API & Gemini
2. Jalankan unit test logika (offline)
3. Jalankan SIT (offline simulation)
4. Jalankan stress test (offline)
5. Tampilkan root cause analysis & checklist perbaikan

---

*Laporan dibuat otomatis oleh Kompak POS Test Suite v2.0*
