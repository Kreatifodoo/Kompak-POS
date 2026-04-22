#!/usr/bin/env python3
"""
================================================================
  KOMPAK POS — TELEGRAM BOT TEST SUITE
  Mencakup: Diagnostik · SIT · Stress Test
  Mode: LIVE (butuh internet) + MOCK (offline analysis)
  Jalankan: python3 telegram_test_suite.py
================================================================
"""

import sys, time, json, re, asyncio, threading, random, traceback
from datetime import datetime
from unittest.mock import MagicMock, patch, AsyncMock
from concurrent.futures import ThreadPoolExecutor, as_completed

# ── CONFIG ──────────────────────────────────────────────────
TELEGRAM_TOKEN = "8638560445:AAE4a5db5q0hGfs-aksuaVBn2MkkNHRIioo"
CHAT_ID        = "724591264"
GEMINI_API_KEY = "AIzaSyB_59C0YJEMxkGzb4OvD8Gt4iAu6Yq0mrA"
BASE_URL       = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}"
GEMINI_URL     = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    f"gemini-2.0-flash:generateContent?key={GEMINI_API_KEY}"
)

# ── WARNA TERMINAL ──────────────────────────────────────────
class C:
    GREEN  = "\033[92m"; RED    = "\033[91m"; YELLOW = "\033[93m"
    CYAN   = "\033[96m"; BOLD   = "\033[1m";  RESET  = "\033[0m"
    BLUE   = "\033[94m"; MAGENTA= "\033[95m"

def ok(msg):   print(f"  {C.GREEN}✅{C.RESET}  {msg}")
def err(msg):  print(f"  {C.RED}❌{C.RESET}  {msg}")
def warn(msg): print(f"  {C.YELLOW}⚠️ {C.RESET} {msg}")
def info(msg): print(f"  {C.CYAN}ℹ️ {C.RESET} {msg}")
def section(t):
    print(f"\n{C.BOLD}{C.BLUE}{'═'*60}{C.RESET}")
    print(f"{C.BOLD}{C.BLUE}  {t}{C.RESET}")
    print(f"{C.BOLD}{C.BLUE}{'═'*60}{C.RESET}")

# ── HASIL GLOBAL ────────────────────────────────────────────
results = {"pass": 0, "fail": 0, "warn": 0, "skip": 0}
sit_results = []
stress_results = []

def record(status, name, detail=""):
    results[status] += 1
    icon = {"pass":"✅","fail":"❌","warn":"⚠️ ","skip":"⏭️ "}[status]
    sit_results.append({"status": status, "name": name, "detail": detail})
    print(f"  {icon} [{status.upper()}] {name}" + (f" → {detail}" if detail else ""))
    return status == "pass"

# ════════════════════════════════════════════════════════════
# BAGIAN A — DIAGNOSTIK LIVE (memerlukan koneksi internet)
# ════════════════════════════════════════════════════════════

def run_live_diagnostics():
    try:
        import requests
    except ImportError:
        warn("Package 'requests' tidak ada. Jalankan: pip install requests")
        return False

    section("DIAGNOSTIK LIVE — Koneksi & API")

    all_ok = True

    # ── A1: getMe ──
    print(f"\n{C.BOLD}▶ A1 · Info Bot{C.RESET}")
    try:
        r = requests.get(f"{BASE_URL}/getMe", timeout=10)
        d = r.json()
        if d.get("ok"):
            b = d["result"]
            ok(f"Bot aktif → @{b.get('username')} (ID: {b.get('id')})")
            ok(f"Nama: {b.get('first_name')}")
            record("pass", "A1 getMe", f"@{b.get('username')}")
        else:
            err(f"getMe gagal: {d}")
            record("fail", "A1 getMe", str(d))
            all_ok = False
    except Exception as e:
        err(f"Koneksi ke Telegram API gagal: {e}")
        record("fail", "A1 getMe", str(e))
        all_ok = False

    # ── A2: Webhook ──
    print(f"\n{C.BOLD}▶ A2 · Status Webhook{C.RESET}")
    try:
        r = requests.get(f"{BASE_URL}/getWebhookInfo", timeout=10)
        wh = r.json().get("result", {})
        url = wh.get("url", "")
        if url:
            warn(f"WEBHOOK AKTIF: {url}")
            warn("Bot pakai webhook — polling (getUpdates) TIDAK JALAN!")
            err(f"Pending: {wh.get('pending_update_count',0)} | Error: {wh.get('last_error_message','-')}")
            record("fail", "A2 Webhook Conflict",
                   f"URL={url}, pending={wh.get('pending_update_count',0)}")
            print(f"\n  {C.YELLOW}💡 FIX:{C.RESET} Hapus webhook:")
            print(f"     curl '{BASE_URL}/deleteWebhook'")
            all_ok = False
        else:
            ok("Tidak ada webhook → Mode polling aman")
            record("pass", "A2 Webhook", "Polling mode aktif")
    except Exception as e:
        record("fail", "A2 Webhook", str(e))
        all_ok = False

    # ── A3: getUpdates ──
    print(f"\n{C.BOLD}▶ A3 · Pesan Masuk (getUpdates){C.RESET}")
    try:
        r = requests.get(f"{BASE_URL}/getUpdates?limit=10", timeout=10)
        d = r.json()
        if not d.get("ok"):
            desc = d.get("description","")
            err(f"getUpdates error: {desc}")
            if "webhook" in desc.lower():
                warn("Masalah: webhook masih aktif → pakai deleteWebhook dulu")
            record("fail", "A3 getUpdates", desc)
            all_ok = False
        else:
            updates = d.get("result", [])
            if updates:
                ok(f"{len(updates)} update ditemukan")
                for u in updates[-3:]:
                    m = u.get("message",{})
                    info(f"[@{m.get('from',{}).get('username','?')}] {m.get('text','(non-text)')}")
                record("pass", "A3 getUpdates", f"{len(updates)} msgs")
            else:
                warn("Tidak ada update. Kirim pesan ke bot lalu coba lagi.")
                record("warn", "A3 getUpdates", "0 pesan — bot belum dikirim pesan")
    except Exception as e:
        record("fail", "A3 getUpdates", str(e))
        all_ok = False

    # ── A4: Kirim pesan test ──
    print(f"\n{C.BOLD}▶ A4 · Kirim Pesan Test{C.RESET}")
    try:
        ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        r = requests.post(f"{BASE_URL}/sendMessage", json={
            "chat_id": CHAT_ID,
            "text": f"🤖 *[SIT TEST]* Kompak POS Bot Test\nWaktu: {ts}",
            "parse_mode": "Markdown"
        }, timeout=10)
        d = r.json()
        if d.get("ok"):
            ok(f"Pesan terkirim! Message ID: {d['result']['message_id']}")
            record("pass", "A4 sendMessage", f"msg_id={d['result']['message_id']}")
        else:
            desc = d.get("description","")
            err(f"Gagal: {desc}")
            if "chat not found" in desc.lower():
                warn("FIX: User belum pernah /start ke bot")
            elif "blocked" in desc.lower():
                warn("FIX: User memblokir bot")
            record("fail", "A4 sendMessage", desc)
            all_ok = False
    except Exception as e:
        record("fail", "A4 sendMessage", str(e))
        all_ok = False

    # ── A5: Gemini API ──
    print(f"\n{C.BOLD}▶ A5 · Gemini API{C.RESET}")
    try:
        r = requests.post(GEMINI_URL, json={
            "contents": [{"parts": [{"text": "Jawab satu kata: OK"}]}]
        }, timeout=15)
        if r.status_code == 200:
            ans = (r.json().get("candidates",[{}])[0]
                          .get("content",{}).get("parts",[{}])[0].get("text",""))
            ok(f"Gemini aktif → response: {ans.strip()[:50]}")
            record("pass", "A5 Gemini API", f"HTTP 200, resp: {ans.strip()[:30]}")
        else:
            err(f"Gemini error HTTP {r.status_code}: {r.text[:200]}")
            if r.status_code == 400: warn("API Key tidak valid atau model salah")
            elif r.status_code == 429: warn("Rate limit — terlalu banyak request")
            record("fail", "A5 Gemini API", f"HTTP {r.status_code}")
            all_ok = False
    except Exception as e:
        record("fail", "A5 Gemini API", str(e))
        all_ok = False

    # ── A6: Simulasi alur penuh ──
    print(f"\n{C.BOLD}▶ A6 · Simulasi Alur Penuh (Gemini → Telegram){C.RESET}")
    try:
        q = "Halo! Apa yang bisa kamu bantu?"
        r = requests.post(GEMINI_URL, json={
            "contents": [{"parts": [{"text": q}]}]
        }, timeout=15)
        if r.status_code == 200:
            jawaban = (r.json().get("candidates",[{}])[0]
                              .get("content",{}).get("parts",[{}])[0].get("text",""))
            print(f"  🤖 Gemini: {jawaban[:100]}...")
            r2 = requests.post(f"{BASE_URL}/sendMessage", json={
                "chat_id": CHAT_ID,
                "text": f"🧪 *[SIT Full Pipeline]*\n*Q:* {q}\n*A:* {jawaban[:400]}",
                "parse_mode": "Markdown"
            }, timeout=10)
            if r2.json().get("ok"):
                ok("Alur penuh BERHASIL — Gemini → Telegram ✓")
                record("pass", "A6 Full Pipeline", "Gemini+Telegram OK")
            else:
                err(f"Kirim ke Telegram gagal: {r2.json().get('description')}")
                record("fail", "A6 Full Pipeline", r2.json().get('description',''))
                all_ok = False
        else:
            err(f"Gemini gagal: HTTP {r.status_code}")
            record("fail", "A6 Full Pipeline", f"Gemini HTTP {r.status_code}")
            all_ok = False
    except Exception as e:
        record("fail", "A6 Full Pipeline", str(e))
        all_ok = False

    return all_ok


# ════════════════════════════════════════════════════════════
# BAGIAN B — UNIT TEST LOGIKA (offline / mock)
# ════════════════════════════════════════════════════════════

# Replika Python dari detectIntent Dart
def detect_intent(text: str) -> dict:
    lower = text.lower().strip()

    def matches_any(keywords):
        return any(k in lower for k in keywords)

    # Stock + product name
    stock_product = re.search(
        r'(?:stok|stock|sisa|tinggal berapa)\s+(.+?)(?:\s+(?:tinggal|berapa|sisa|ada).*)?$', lower)
    has_stock_with_product = (
        re.search(r'(.+?)\s+(?:tinggal|sisa|berapa|ada berapa)', lower) and
        matches_any(['stok', 'stock', 'tinggal', 'sisa'])
    )
    if stock_product or has_stock_with_product:
        extracted = (stock_product.group(1) if stock_product else "").strip()
        if extracted:
            return {"intent": "stock_search", "product": extracted}

    # Sales + product name
    if matches_any(['penjualan', 'sales', 'jual', 'omset', 'laku']):
        pass  # simplified

    # Standard intents
    if matches_any(['total penjualan', 'all time', 'keseluruhan', 'dari awal', 'semua penjualan']):
        return {"intent": "all_sales"}
    if matches_any(['penjualan hari ini', 'sales today', 'omset hari ini']):
        return {"intent": "daily_sales"}
    if matches_any(['penjualan minggu', 'sales week', 'mingguan']):
        return {"intent": "weekly_sales"}
    if matches_any(['penjualan bulan', 'sales month', 'bulanan']):
        return {"intent": "monthly_sales"}
    if matches_any(['tren penjualan', 'sales trend', 'grafik']):
        return {"intent": "sales_trend"}
    if matches_any(['per kategori', 'kategori penjualan']):
        return {"intent": "sales_by_category"}
    if matches_any(['top produk all', 'terlaris semua', 'best seller all']):
        return {"intent": "top_products_alltime"}
    if matches_any(['top produk', 'produk terlaris', 'best seller', 'paling laku', 'terlaris']):
        return {"intent": "top_products"}
    if matches_any(['combo', 'paket', 'bundling']):
        return {"intent": "combo_info"}
    if matches_any(['pricelist', 'harga khusus', 'daftar harga']):
        return {"intent": "pricelist_info"}
    if matches_any(['promosi', 'promo', 'diskon']):
        return {"intent": "promotion_info"}
    if matches_any(['stok rendah', 'low stock', 'hampir habis']):
        return {"intent": "stock_low"}
    if matches_any(['pergerakan stok', 'mutasi stok']):
        return {"intent": "stock_movements"}
    if matches_any(['resep', 'bahan baku', 'bill of material']):
        return {"intent": "bom_info"}
    if matches_any(['stok', 'stock', 'inventori', 'persediaan']):
        return {"intent": "stock_check"}
    if matches_any(['biaya', 'pajak', 'tax', 'ppn']):
        return {"intent": "charges_info"}
    if matches_any(['profit', 'laba', 'margin', 'keuntungan']):
        return {"intent": "profit_report"}
    if matches_any(['retur', 'return', 'refund']):
        return {"intent": "returns_info"}
    if matches_any(['pembayaran semua', 'total pembayaran', 'payment all']):
        return {"intent": "payment_alltime"}
    if matches_any(['pembayaran', 'payment', 'qris']):
        return {"intent": "payment_breakdown"}
    if matches_any(['transaksi terakhir', 'order terakhir', 'transaksi terbaru']):
        return {"intent": "recent_orders"}
    if matches_any(['performa kasir all', 'kasir all', 'semua kasir']):
        return {"intent": "cashier_alltime"}
    if matches_any(['kasir', 'cashier', 'kinerja kasir']):
        return {"intent": "cashier_stats"}
    if matches_any(['sesi', 'session', 'shift', 'register']):
        return {"intent": "session_info"}
    if matches_any(['terminal', 'mesin kasir']):
        return {"intent": "terminal_info"}
    if matches_any(['cabang', 'branch', 'toko', 'outlet']):
        return {"intent": "branch_info"}
    if matches_any(['customer', 'pelanggan', 'member', 'loyalty']):
        return {"intent": "customer_info"}
    if matches_any(['ringkasan', 'summary', 'laporan', 'report', 'rekap']):
        return {"intent": "full_summary"}
    return {"intent": "full_summary"}


def run_unit_tests():
    section("UNIT TEST — Logika Intent Detection (Offline Mock)")

    tests = [
        # Format: (input, expected_intent, keterangan)
        ("penjualan hari ini", "daily_sales", "Query penjualan hari ini"),
        ("berapa omset hari ini?", "daily_sales", "Sinonim omset"),
        ("penjualan minggu ini", "weekly_sales", "Query mingguan"),
        ("penjualan bulan ini", "monthly_sales", "Query bulanan"),
        ("total penjualan dari awal", "all_sales", "All time sales"),
        ("top produk terlaris", "top_products", "Top produk"),
        ("produk terlaris all time", "top_products_alltime", "All time top produk"),
        ("cek stok", "stock_check", "Cek stok general"),
        ("stok rendah", "stock_low", "Stok hampir habis"),
        ("stok air mineral", "stock_search", "Cek stok produk spesifik"),
        ("air mineral tinggal berapa?", "stock_search", "Stok spesifik v2"),
        ("info promosi", "promotion_info", "Query promo"),
        ("info diskon", "promotion_info", "Sinonim diskon"),
        ("laporan kasir", "cashier_stats", "Kinerja kasir"),
        ("semua kasir", "cashier_alltime", "Kasir all time"),
        ("info cabang", "branch_info", "Info toko/branch"),
        ("data pelanggan", "customer_info", "CRM pelanggan"),
        ("profit bulan ini", "profit_report", "Laporan laba"),
        ("payment hari ini", "payment_breakdown", "Rincian pembayaran"),
        ("total pembayaran semua", "payment_alltime", "Payment all time"),
        ("transaksi terbaru", "recent_orders", "Order terakhir"),
        ("rekap harian", "full_summary", "Summary request"),
        ("grafik penjualan", "sales_trend", "Trend/grafik"),
        ("info paket combo", "combo_info", "Paket/bundling"),
        ("daftar harga", "pricelist_info", "Pricelist"),
        ("resep produk", "bom_info", "Bill of material"),
        ("mutasi stok", "stock_movements", "Pergerakan stok"),
        ("info pajak", "charges_info", "Charges/pajak"),
        ("retur barang", "returns_info", "Return/refund"),
        ("sesi kasir aktif", "session_info", "Info shift"),
        ("info terminal", "terminal_info", "Info mesin POS"),
        # Edge cases
        ("?", "full_summary", "Edge: pesan kosong/simbol"),
        ("halo", "full_summary", "Edge: salam tanpa konteks"),
        ("PENJUALAN HARI INI", "daily_sales", "Edge: uppercase"),
        ("pnjualan hri ini", "full_summary", "Edge: typo berat (fallback OK)"),
        ("penjualan  hari   ini", "daily_sales", "Edge: extra spaces"),
    ]

    pass_count = 0
    for text, expected, desc in tests:
        result = detect_intent(text)
        got = result.get("intent")
        passed = got == expected
        status_str = f"{C.GREEN}PASS{C.RESET}" if passed else f"{C.RED}FAIL{C.RESET}"
        indicator = "✅" if passed else "❌"
        print(f"  {indicator} [{status_str}] {desc}")
        if not passed:
            print(f"       Input   : \"{text}\"")
            print(f"       Expected: {expected}")
            print(f"       Got     : {got}")
        if passed:
            pass_count += 1
            results["pass"] += 1
        else:
            results["fail"] += 1

    total = len(tests)
    pct = pass_count / total * 100
    color = C.GREEN if pct >= 80 else C.YELLOW if pct >= 60 else C.RED
    print(f"\n  {color}{C.BOLD}Score: {pass_count}/{total} ({pct:.0f}%){C.RESET}")
    return pass_count, total


# ════════════════════════════════════════════════════════════
# BAGIAN C — SIT (System Integration Test)
# ════════════════════════════════════════════════════════════

def simulate_bot_pipeline(message_text, chat_id_matches=True, store_exists=True,
                           gemini_works=True, telegram_works=True,
                           polling_enabled=True, token_set=True, gemini_key_set=True):
    """
    Simulasi alur penuh bot tanpa koneksi nyata.
    Mengembalikan dict: {success, stage_failed, response}
    """
    stages = []

    # Stage 1: Polling aktif?
    if not polling_enabled:
        return {"success": False, "stage_failed": "polling_disabled",
                "response": None, "stages": stages}
    stages.append("polling_active")

    # Stage 2: Config ada?
    if not token_set or not gemini_key_set:
        return {"success": False, "stage_failed": "config_missing",
                "response": None, "stages": stages}
    stages.append("config_ok")

    # Stage 3: getUpdates
    mock_update = {
        "update_id": random.randint(100000, 999999),
        "message": {
            "text": message_text,
            "chat": {"id": chat_id_matches and "724591264" or "999999"},
            "from": {"username": "testuser"}
        }
    }
    stages.append("getUpdates_ok")

    # Stage 4: Chat ID match
    if not chat_id_matches:
        return {"success": False, "stage_failed": "chat_id_mismatch",
                "response": None, "stages": stages}
    stages.append("chat_id_matched")

    # Stage 5: Intent classification
    intent = detect_intent(message_text)
    stages.append(f"intent={intent['intent']}")

    # Stage 6: Store lookup
    if not store_exists:
        return {"success": False, "stage_failed": "no_active_store",
                "response": "Tidak ada toko aktif di device ini.", "stages": stages}
    stages.append("store_found")

    # Stage 7: Gemini response
    if not gemini_works:
        mock_response = f"[DATA RAW] Hasil query untuk intent {intent['intent']}"
    else:
        mock_response = f"📊 Simulasi jawaban Kompak AI untuk: {message_text}\nIntent: {intent['intent']}"
    stages.append("gemini_response_ok" if gemini_works else "gemini_fallback_rawdata")

    # Stage 8: Kirim ke Telegram
    if not telegram_works:
        return {"success": False, "stage_failed": "telegram_send_failed",
                "response": mock_response, "stages": stages}
    stages.append("telegram_sent")

    return {"success": True, "stage_failed": None,
            "response": mock_response, "stages": stages}


def run_sit():
    section("SIT — System Integration Testing")

    sit_cases = [
        # ── Happy path ──
        {
            "id": "SIT-001", "category": "Happy Path",
            "desc": "Pesan normal — alur penuh OK",
            "msg": "penjualan hari ini", "expected_intent": "daily_sales",
            "params": {}
        },
        {
            "id": "SIT-002", "category": "Happy Path",
            "desc": "Query stok produk spesifik",
            "msg": "stok air mineral tinggal berapa",
            "expected_intent": "stock_search", "params": {}
        },
        {
            "id": "SIT-003", "category": "Happy Path",
            "desc": "Top produk terlaris",
            "msg": "top produk terlaris bulan ini",
            "expected_intent": "top_products", "params": {}
        },
        {
            "id": "SIT-004", "category": "Happy Path",
            "desc": "Laporan laba rugi",
            "msg": "profit bulan ini berapa",
            "expected_intent": "profit_report", "params": {}
        },
        {
            "id": "SIT-005", "category": "Happy Path",
            "desc": "Gemini fallback ke raw data saat model gagal",
            "msg": "cek stok",
            "expected_intent": "stock_check",
            "params": {"gemini_works": False}
        },
        # ── Failure scenarios ──
        {
            "id": "SIT-006", "category": "Failure",
            "desc": "KRITIS: Polling dinonaktifkan → bot tidak respons",
            "msg": "penjualan hari ini",
            "expected_intent": None,
            "params": {"polling_enabled": False},
            "expected_success": False,
            "expected_stage_failed": "polling_disabled"
        },
        {
            "id": "SIT-007", "category": "Failure",
            "desc": "KRITIS: Token kosong → polling tidak mulai",
            "msg": "berapa omset?",
            "expected_intent": None,
            "params": {"polling_enabled": True, "token_set": False},
            "expected_success": False,
            "expected_stage_failed": "config_missing"
        },
        {
            "id": "SIT-008", "category": "Failure",
            "desc": "KRITIS: Gemini key kosong → polling tidak mulai",
            "msg": "cek stok",
            "expected_intent": None,
            "params": {"polling_enabled": True, "gemini_key_set": False},
            "expected_success": False,
            "expected_stage_failed": "config_missing"
        },
        {
            "id": "SIT-009", "category": "Failure",
            "desc": "Chat ID tidak cocok → pesan diabaikan",
            "msg": "penjualan hari ini",
            "expected_intent": None,
            "params": {"chat_id_matches": False},
            "expected_success": False,
            "expected_stage_failed": "chat_id_mismatch"
        },
        {
            "id": "SIT-010", "category": "Failure",
            "desc": "Tidak ada toko aktif → error response",
            "msg": "penjualan hari ini",
            "expected_intent": None,
            "params": {"store_exists": False},
            "expected_success": False,
            "expected_stage_failed": "no_active_store"
        },
        {
            "id": "SIT-011", "category": "Failure",
            "desc": "Telegram send gagal → respons tidak terkirim",
            "msg": "top produk",
            "expected_intent": None,
            "params": {"telegram_works": False},
            "expected_success": False,
            "expected_stage_failed": "telegram_send_failed"
        },
        # ── Edge cases ──
        {
            "id": "SIT-012", "category": "Edge Case",
            "desc": "Pesan sangat panjang (500 karakter)",
            "msg": "penjualan " * 50,
            "expected_intent": "daily_sales", "params": {}
        },
        {
            "id": "SIT-013", "category": "Edge Case",
            "desc": "Pesan dengan karakter spesial",
            "msg": "penjualan hari ini? 🤔 & total=100",
            "expected_intent": "daily_sales", "params": {}
        },
        {
            "id": "SIT-014", "category": "Edge Case",
            "desc": "Pesan hanya emoji",
            "msg": "😀🎉",
            "expected_intent": "full_summary", "params": {}
        },
        {
            "id": "SIT-015", "category": "Edge Case",
            "desc": "Pesan uppercase penuh",
            "msg": "CEK STOK",
            "expected_intent": "stock_check", "params": {}
        },
        {
            "id": "SIT-016", "category": "Edge Case",
            "desc": "Multiple intent keywords — prioritas pertama menang",
            "msg": "stok dan penjualan",
            "expected_intent": "stock_check", "params": {}
        },
        # ── Multi-language / bahasa campuran ──
        {
            "id": "SIT-017", "category": "Multi-language",
            "desc": "Campuran Inggris-Indonesia",
            "msg": "how much sales today?",
            "expected_intent": "daily_sales", "params": {}
        },
        {
            "id": "SIT-018", "category": "Multi-language",
            "desc": "Bahasa Inggris murni",
            "msg": "check stock",
            "expected_intent": "stock_check", "params": {}
        },
        {
            "id": "SIT-019", "category": "Multi-language",
            "desc": "Query top products in English",
            "msg": "best seller this week",
            "expected_intent": "top_products", "params": {}
        },
    ]

    categories = {}
    pass_count = 0

    for case in sit_cases:
        cat = case["category"]
        if cat not in categories:
            categories[cat] = []
            print(f"\n  {C.MAGENTA}{C.BOLD}── {cat} ──{C.RESET}")

        params = case.get("params", {})
        expected_success = case.get("expected_success", True)
        expected_stage = case.get("expected_stage_failed")

        result = simulate_bot_pipeline(case["msg"], **params)

        # Evaluate
        success_ok = result["success"] == expected_success
        stage_ok = (expected_stage is None) or (result["stage_failed"] == expected_stage)
        intent_ok = True
        if case.get("expected_intent") and result["success"]:
            intent_got = detect_intent(case["msg"]).get("intent")
            intent_ok = intent_got == case["expected_intent"]

        passed = success_ok and stage_ok and intent_ok
        status = "pass" if passed else "fail"
        results[status] += 1

        icon = "✅" if passed else "❌"
        stages_str = " → ".join(result["stages"][-3:])  # last 3 stages
        detail = f"stage={result['stage_failed'] or 'success'}, path=[{stages_str}]"

        print(f"    {icon} [{case['id']}] {case['desc']}")
        if not passed:
            print(f"         Expected success={expected_success}, got={result['success']}")
            if expected_stage:
                print(f"         Expected stage_failed={expected_stage}, got={result['stage_failed']}")
            if not intent_ok:
                print(f"         Intent: expected={case['expected_intent']}, got={detect_intent(case['msg']).get('intent')}")
        if passed:
            pass_count += 1

        categories[cat].append(passed)

    total = len(sit_cases)
    pct = pass_count / total * 100
    color = C.GREEN if pct >= 90 else C.YELLOW if pct >= 70 else C.RED

    print(f"\n  {color}{C.BOLD}SIT Score: {pass_count}/{total} ({pct:.0f}%){C.RESET}")

    # Per-category summary
    print(f"\n  {C.BOLD}Per Kategori:{C.RESET}")
    for cat, res in categories.items():
        p = sum(res); t = len(res)
        c = C.GREEN if p == t else C.YELLOW if p >= t*0.7 else C.RED
        print(f"    {c}• {cat}: {p}/{t}{C.RESET}")

    return pass_count, total


# ════════════════════════════════════════════════════════════
# BAGIAN D — STRESS TEST
# ════════════════════════════════════════════════════════════

def stress_worker(worker_id: int, messages: list, iterations: int):
    """Worker untuk stress test — simulasi concurrent users"""
    local_results = []
    for i in range(iterations):
        msg = random.choice(messages)
        start = time.perf_counter()
        try:
            result = simulate_bot_pipeline(msg)
            elapsed = (time.perf_counter() - start) * 1000  # ms
            local_results.append({
                "worker": worker_id, "iter": i, "msg": msg[:30],
                "success": result["success"],
                "latency_ms": elapsed,
                "intent": detect_intent(msg).get("intent")
            })
        except Exception as e:
            local_results.append({
                "worker": worker_id, "iter": i, "msg": msg[:30],
                "success": False, "latency_ms": 9999,
                "error": str(e)
            })
    return local_results


def run_stress_test():
    section("STRESS TEST — Concurrency & Ketahanan")

    test_messages = [
        "penjualan hari ini",
        "cek stok",
        "top produk terlaris",
        "berapa omset bulan ini?",
        "profit laporan",
        "kasir performance",
        "info promosi",
        "total penjualan all time",
        "stok air mineral",
        "transaksi terakhir",
        "payment breakdown",
        "ringkasan laporan",
        "info cabang",
        "data customer",
        "sesi kasir aktif",
    ]

    scenarios = [
        {"label": "Beban Ringan  (5 users × 10 msg)", "workers": 5, "iters": 10},
        {"label": "Beban Sedang (10 users × 20 msg)", "workers": 10, "iters": 20},
        {"label": "Beban Berat  (25 users × 30 msg)", "workers": 25, "iters": 30},
        {"label": "Spike Test   (50 users × 5 msg)",  "workers": 50, "iters": 5},
    ]

    global stress_results

    for scenario in scenarios:
        print(f"\n  {C.CYAN}▶ {scenario['label']}{C.RESET}")
        workers = scenario["workers"]
        iters = scenario["iters"]
        total_requests = workers * iters

        start_time = time.perf_counter()

        all_results = []
        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = {
                executor.submit(stress_worker, wid, test_messages, iters): wid
                for wid in range(workers)
            }
            for f in as_completed(futures):
                try:
                    all_results.extend(f.result())
                except Exception as e:
                    err(f"Worker error: {e}")

        elapsed = time.perf_counter() - start_time

        success_count = sum(1 for r in all_results if r.get("success"))
        fail_count = total_requests - success_count
        latencies = [r["latency_ms"] for r in all_results if "latency_ms" in r]

        avg_lat = sum(latencies) / len(latencies) if latencies else 0
        max_lat = max(latencies) if latencies else 0
        min_lat = min(latencies) if latencies else 0
        p95 = sorted(latencies)[int(len(latencies)*0.95)] if latencies else 0
        rps = total_requests / elapsed if elapsed > 0 else 0
        success_rate = success_count / total_requests * 100 if total_requests > 0 else 0

        # Intent distribution
        intents = {}
        for r in all_results:
            i = r.get("intent","?")
            intents[i] = intents.get(i, 0) + 1

        color = C.GREEN if success_rate >= 99 else C.YELLOW if success_rate >= 95 else C.RED
        ok_str = f"{C.GREEN}✅ OK{C.RESET}" if success_rate == 100 else f"{C.YELLOW}⚠️ {C.RESET}"

        print(f"     {ok_str} Requests  : {success_count}/{total_requests} sukses ({color}{success_rate:.1f}%{C.RESET})")
        print(f"     ⏱️  Waktu total : {elapsed:.2f}s | {rps:.0f} req/s")
        print(f"     📊 Latensi    : avg={avg_lat:.2f}ms | min={min_lat:.2f}ms | max={max_lat:.2f}ms | p95={p95:.2f}ms")
        if fail_count > 0:
            print(f"     ❌ Gagal      : {fail_count}")

        # Top 3 intents
        top_intents = sorted(intents.items(), key=lambda x: x[1], reverse=True)[:3]
        print(f"     🎯 Top intents: {', '.join(f'{i}({c})' for i,c in top_intents)}")

        stress_results.append({
            "scenario": scenario["label"],
            "total": total_requests,
            "success": success_count,
            "success_rate": success_rate,
            "rps": rps,
            "avg_latency_ms": avg_lat,
            "p95_latency_ms": p95,
            "max_latency_ms": max_lat,
            "elapsed_s": elapsed
        })

        results["pass" if success_rate >= 99 else "fail"] += 1

    return stress_results


# ════════════════════════════════════════════════════════════
# BAGIAN E — ROOT CAUSE ANALYSIS
# ════════════════════════════════════════════════════════════

def run_root_cause_analysis():
    section("ROOT CAUSE ANALYSIS — Kenapa Bot Tidak Merespons?")

    print(f"""
  {C.BOLD}Berdasarkan analisis kode TelegramChatbotService.dart:{C.RESET}

  {C.RED}{C.BOLD}❌ PENYEBAB #1 — telegram_chatbot_enabled = false (PALING MUNGKIN){C.RESET}
  ─────────────────────────────────────────────────────────
  Di kode (baris 78):
    if (!isEnabled || _botToken.isEmpty || _geminiKey.isEmpty) {{
        return;  // ← polling tidak start!
    }}

  isEnabled membaca: prefs.getBool('telegram_chatbot_enabled')
  Jika toggle "Aktifkan AI Chatbot" di Settings belum di-ON,
  startPolling() langsung return tanpa mulai polling.

  {C.YELLOW}{C.BOLD}FIX:{C.RESET} Buka Settings → Telegram → toggle "Aktifkan AI Chatbot" → ON → Simpan

  ─────────────────────────────────────────────────────────
  {C.RED}{C.BOLD}❌ PENYEBAB #2 — Webhook Aktif Konflik dengan Polling{C.RESET}
  ─────────────────────────────────────────────────────────
  Telegram TIDAK memperbolehkan webhook + polling bersamaan.
  Jika ada webhook aktif, getUpdates akan error 409 Conflict.

  {C.YELLOW}{C.BOLD}FIX:{C.RESET} curl '{BASE_URL}/deleteWebhook'

  ─────────────────────────────────────────────────────────
  {C.RED}{C.BOLD}❌ PENYEBAB #3 — Chat ID Tidak Cocok{C.RESET}
  ─────────────────────────────────────────────────────────
  Di kode (baris 169):
    if (chatId != _chatId) {{
        continue;  // pesan diabaikan!
    }}

  chatId dari pesan dibandingkan dengan _chatId dari prefs.
  Jika Chat ID yang disimpan salah (misal pakai username bukan angka),
  semua pesan akan di-ignore tanpa error.

  {C.YELLOW}{C.BOLD}FIX:{C.RESET} Pastikan Chat ID adalah angka numerik (cek via getUpdates)
        Cara: kirim pesan ke bot → buka: {BASE_URL}/getUpdates

  ─────────────────────────────────────────────────────────
  {C.RED}{C.BOLD}❌ PENYEBAB #4 — App Tidak Aktif / Background Kill{C.RESET}
  ─────────────────────────────────────────────────────────
  Bot Kompak POS berjalan sebagai Timer di dalam aplikasi Flutter.
  Polling hanya aktif selama aplikasi HIDUP dan DI FOREGROUND.

  Android agresif mematikan proses background untuk hemat baterai.
  Jika aplikasi di-minimize lama atau RAM habis, timer berhenti.

  {C.YELLOW}{C.BOLD}FIX:{C.RESET} Pastikan aplikasi tetap terbuka (jangan minimize)
        Atau gunakan mode "Keep Awake" di Android Developer Options

  ─────────────────────────────────────────────────────────
  {C.RED}{C.BOLD}❌ PENYEBAB #5 — Gemini API Key Tidak Valid{C.RESET}
  ─────────────────────────────────────────────────────────
  Meski bot bisa menerima pesan, jika Gemini API gagal (quota habis,
  key expired), semua model di _fallbackModels akan dicoba lalu gagal.
  Bot masih akan kirim respons (data mentah) tapi lambat/error.

  {C.YELLOW}{C.BOLD}FIX:{C.RESET} Test Gemini API Key di: aistudio.google.com
        Atau cek quota di: console.cloud.google.com

  ─────────────────────────────────────────────────────────
  {C.CYAN}{C.BOLD}⚙️  POTENTIAL BUG: _isProcessing flag tidak direset jika crash{C.RESET}
  ─────────────────────────────────────────────────────────
  Di kode (baris 131-183), ada try/finally yang reset _isProcessing.
  Namun jika DioException terjadi pada timeout yang sangat lama,
  polling bisa "macet" sampai request selesai.

  connectTimeout dan receiveTimeout sudah set 15 detik (baris 52-54),
  jadi seharusnya tidak macet lebih dari 15 detik.

  ─────────────────────────────────────────────────────────
  {C.CYAN}{C.BOLD}⚙️  POTENTIAL BUG: last_update_id tidak sync saat restart{C.RESET}
  ─────────────────────────────────────────────────────────
  _lastUpdateId disimpan ke SharedPreferences setiap update.
  Jika ada pesan saat app off, setelah restart pesan tersebut
  akan diproses (karena offset = lastUpdateId + 1).
  Ini perilaku YANG DIINGINKAN, sudah benar.
""")

    print(f"  {C.GREEN}{C.BOLD}✅ CHECKLIST PERBAIKAN (urutan prioritas):{C.RESET}")
    checklist = [
        "1. Buka app → Settings → Telegram → pastikan 'Aktifkan AI Chatbot' = ON",
        "2. Pastikan Bot Token dan Gemini API Key sudah diisi",
        "3. Klik 'Simpan' untuk restart polling",
        "4. Cek tidak ada webhook aktif: curl '" + BASE_URL + "/getWebhookInfo'",
        "5. Hapus webhook jika ada: curl '" + BASE_URL + "/deleteWebhook'",
        "6. Pastikan Chat ID numerik yang benar",
        "7. Kirim pesan ke bot, pastikan app masih terbuka",
        "8. Test via tombol 'Test AI Chatbot' di Settings",
    ]
    for item in checklist:
        print(f"  {C.YELLOW}  {item}{C.RESET}")


# ════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════

def print_final_summary():
    section("RINGKASAN HASIL TEST")

    total = results["pass"] + results["fail"] + results["warn"] + results["skip"]
    pct = results["pass"] / total * 100 if total > 0 else 0
    color = C.GREEN if pct >= 90 else C.YELLOW if pct >= 70 else C.RED

    print(f"""
  {C.BOLD}Total Test Dijalankan: {total}{C.RESET}
  {C.GREEN}✅ PASS : {results['pass']}{C.RESET}
  {C.RED}❌ FAIL : {results['fail']}{C.RESET}
  {C.YELLOW}⚠️  WARN : {results['warn']}{C.RESET}
  {C.CYAN}⏭️  SKIP : {results['skip']}{C.RESET}

  {color}{C.BOLD}Overall Score: {pct:.0f}%{C.RESET}
""")

    if stress_results:
        print(f"  {C.BOLD}Stress Test Summary:{C.RESET}")
        for s in stress_results:
            c = C.GREEN if s["success_rate"] >= 99 else C.YELLOW
            print(f"  {c}  • {s['scenario']}: {s['success_rate']:.1f}% success | {s['rps']:.0f} req/s | p95={s['p95_latency_ms']:.2f}ms{C.RESET}")

    print(f"""
  {C.BOLD}Langkah Selanjutnya:{C.RESET}
  1. Jalankan skrip ini di perangkat yang punya koneksi internet
     untuk test LIVE ke Telegram API & Gemini
  2. Perbaiki sesuai checklist di bagian Root Cause Analysis
  3. Setelah perbaikan, jalankan ulang untuk verifikasi
""")


if __name__ == "__main__":
    print(f"""
{C.BOLD}{C.CYAN}
╔═══════════════════════════════════════════════════════════╗
║       KOMPAK POS — TELEGRAM BOT TEST SUITE v2.0          ║
║   Diagnostik · Unit Test · SIT · Stress · RCA             ║
╚═══════════════════════════════════════════════════════════╝
{C.RESET}""")

    # Try live diagnostics
    section("MODE DETEKSI — Cek Koneksi Internet")
    try:
        import requests
        try:
            test_r = requests.get("https://www.google.com", timeout=5)
            if test_r.status_code == 200:
                ok("Koneksi internet tersedia → menjalankan Diagnostik LIVE")
                run_live_diagnostics()
            else:
                warn("Koneksi internet terbatas → skip Diagnostik Live, jalankan Mock Test")
        except:
            warn("Tidak ada koneksi internet → skip Diagnostik Live, jalankan Mock Test")
            info("Jalankan skrip ini di perangkat dengan internet untuk test live")
    except ImportError:
        warn("requests tidak tersedia")

    # Always run these (offline)
    run_unit_tests()
    run_sit()
    run_stress_test()
    run_root_cause_analysis()
    print_final_summary()
