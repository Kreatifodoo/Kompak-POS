#!/usr/bin/env python3
"""
=======================================================
  SCRIPT DIAGNOSTIK BOT TELEGRAM + GEMINI
  Jalankan: python3 telegram_bot_diagnostik.py
=======================================================
"""

import requests
import json
import sys
import time

# ── KONFIGURASI ─────────────────────────────────────
TELEGRAM_TOKEN = "8638560445:AAE4a5db5q0hGfs-aksuaVBn2MkkNHRIioo"
CHAT_ID        = "724591264"
GEMINI_API_KEY = "AIzaSyB_59C0YJEMxkGzb4OvD8Gt4iAu6Yq0mrA"

BASE_URL       = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}"
GEMINI_URL     = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    f"gemini-2.0-flash:generateContent?key={GEMINI_API_KEY}"
)

OK  = "✅"
ERR = "❌"
WRN = "⚠️ "

# ── HELPER ───────────────────────────────────────────
def header(title):
    print(f"\n{'='*55}")
    print(f"  {title}")
    print('='*55)

def ok(msg):   print(f"  {OK}  {msg}")
def err(msg):  print(f"  {ERR}  {msg}")
def warn(msg): print(f"  {WRN} {msg}")

# ═══════════════════════════════════════════════════
# TEST 1 – Info Bot
# ═══════════════════════════════════════════════════
header("TEST 1 : INFO BOT TELEGRAM")
try:
    r = requests.get(f"{BASE_URL}/getMe", timeout=10)
    data = r.json()
    if data.get("ok"):
        bot = data["result"]
        ok(f"Bot aktif  : @{bot.get('username')}")
        ok(f"Nama       : {bot.get('first_name')}")
        ok(f"Bot ID     : {bot.get('id')}")
        ok(f"Can Join Groups: {bot.get('can_join_groups')}")
    else:
        err(f"API Error : {data}")
except Exception as e:
    err(f"Koneksi gagal ke Telegram API: {e}")
    sys.exit(1)

# ═══════════════════════════════════════════════════
# TEST 2 – Cek Webhook vs Polling
# ═══════════════════════════════════════════════════
header("TEST 2 : CEK WEBHOOK / POLLING")
try:
    r = requests.get(f"{BASE_URL}/getWebhookInfo", timeout=10)
    wh = r.json().get("result", {})
    url = wh.get("url", "")
    if url:
        warn(f"Webhook AKTIF  : {url}")
        warn("Bot pakai webhook — getUpdates TIDAK akan bekerja bersamaan!")
        pending = wh.get("pending_update_count", 0)
        last_err = wh.get("last_error_message", "-")
        print(f"  Pending updates : {pending}")
        print(f"  Last error      : {last_err}")

        # Sarankan hapus webhook kalau mau pakai polling
        if last_err and last_err != "-":
            err(f"Webhook error terakhir: {last_err}")
            print("\n  💡 SOLUSI: Hapus webhook dengan perintah:")
            print(f"     curl 'https://api.telegram.org/bot{TELEGRAM_TOKEN}/deleteWebhook'")
    else:
        ok("Tidak ada webhook aktif (mode polling siap digunakan)")
except Exception as e:
    err(f"Gagal cek webhook: {e}")

# ═══════════════════════════════════════════════════
# TEST 3 – getUpdates (hanya kalau tidak ada webhook)
# ═══════════════════════════════════════════════════
header("TEST 3 : CEK UPDATE / PESAN MASUK")
try:
    r = requests.get(f"{BASE_URL}/getUpdates?limit=5", timeout=10)
    data = r.json()
    if not data.get("ok"):
        err(f"getUpdates gagal: {data.get('description','')}")
        if "webhook" in data.get("description","").lower():
            warn("Bot masih terpasang webhook — hapus dulu sebelum polling")
    else:
        updates = data.get("result", [])
        if updates:
            ok(f"Ada {len(updates)} update terakhir:")
            for u in updates:
                msg = u.get("message", {})
                text = msg.get("text","(bukan teks)")
                user = msg.get("from",{}).get("username","?")
                print(f"     [@{user}] {text}")
        else:
            warn("Tidak ada update baru. Coba kirim pesan ke bot dulu, lalu jalankan ulang.")
except Exception as e:
    err(f"Gagal getUpdates: {e}")

# ═══════════════════════════════════════════════════
# TEST 4 – Kirim pesan test ke Chat ID
# ═══════════════════════════════════════════════════
header("TEST 4 : KIRIM PESAN TEST KE CHAT")
try:
    payload = {
        "chat_id": CHAT_ID,
        "text": "🤖 *[SIT TEST]* Bot aktif dan sedang diuji!\n\nWaktu: " + time.strftime("%Y-%m-%d %H:%M:%S"),
        "parse_mode": "Markdown"
    }
    r = requests.post(f"{BASE_URL}/sendMessage", json=payload, timeout=10)
    data = r.json()
    if data.get("ok"):
        ok(f"Pesan berhasil dikirim ke chat {CHAT_ID}")
        ok(f"Message ID: {data['result']['message_id']}")
    else:
        err(f"Gagal kirim pesan: {data.get('description','')}")
        if "chat not found" in data.get("description","").lower():
            warn("Chat ID tidak ditemukan — pastikan user sudah pernah /start ke bot")
        if "blocked" in data.get("description","").lower():
            warn("User memblokir bot")
except Exception as e:
    err(f"Exception saat kirim pesan: {e}")

# ═══════════════════════════════════════════════════
# TEST 5 – Gemini API
# ═══════════════════════════════════════════════════
header("TEST 5 : GEMINI API")
try:
    body = {
        "contents": [{
            "parts": [{"text": "Jawab singkat: 2 + 2 = ?"}]
        }]
    }
    r = requests.post(GEMINI_URL, json=body, timeout=15)
    data = r.json()
    if r.status_code == 200:
        answer = (data.get("candidates", [{}])[0]
                      .get("content", {})
                      .get("parts", [{}])[0]
                      .get("text", ""))
        ok(f"Gemini API aktif")
        ok(f"Response test : {answer.strip()}")
    else:
        err(f"Gemini API error (HTTP {r.status_code})")
        print(f"  Detail: {json.dumps(data, indent=2)}")
        if r.status_code == 400:
            warn("API Key tidak valid atau model salah")
        elif r.status_code == 429:
            warn("Rate limit — terlalu banyak request")
except Exception as e:
    err(f"Gagal koneksi ke Gemini: {e}")

# ═══════════════════════════════════════════════════
# TEST 6 – Simulasi alur: User kirim pesan → Gemini → Balas ke Telegram
# ═══════════════════════════════════════════════════
header("TEST 6 : SIMULASI ALUR PENUH (Gemini → Telegram)")
try:
    pertanyaan = "Halo! Siapa kamu dan apa yang bisa kamu bantu?"

    # Langkah A: Kirim ke Gemini
    print(f"  📨 Pertanyaan  : {pertanyaan}")
    body = {"contents": [{"parts": [{"text": pertanyaan}]}]}
    r = requests.post(GEMINI_URL, json=body, timeout=15)
    if r.status_code != 200:
        err(f"Gemini gagal: {r.status_code} - {r.text[:200]}")
    else:
        jawaban = (r.json().get("candidates",[{}])[0]
                          .get("content",{})
                          .get("parts",[{}])[0]
                          .get("text","(kosong)"))
        print(f"  🤖 Jawaban Gemini: {jawaban[:150]}...")

        # Langkah B: Kirim jawaban ke Telegram
        payload = {
            "chat_id": CHAT_ID,
            "text": f"🧪 *[SIT TEST - Simulasi Penuh]*\n\n*Pertanyaan:*\n{pertanyaan}\n\n*Jawaban AI:*\n{jawaban[:500]}",
            "parse_mode": "Markdown"
        }
        r2 = requests.post(f"{BASE_URL}/sendMessage", json=payload, timeout=10)
        if r2.json().get("ok"):
            ok("Simulasi penuh BERHASIL — pesan Gemini terkirim ke Telegram!")
        else:
            err(f"Gagal kirim jawaban ke Telegram: {r2.json().get('description','')}")
except Exception as e:
    err(f"Exception pada simulasi penuh: {e}")

# ═══════════════════════════════════════════════════
# RINGKASAN
# ═══════════════════════════════════════════════════
header("SELESAI — Periksa hasil di atas untuk diagnosa")
print("""
  Masalah umum bot tidak bisa jawab:
  1. Webhook masih aktif → hapus dengan deleteWebhook
  2. Bot belum di-/start oleh user (chat not found)
  3. Loop polling tidak berjalan / proses bot mati
  4. Error di handler pesan (cek log server/bot)
  5. API Key Gemini expired atau rate limit
""")
