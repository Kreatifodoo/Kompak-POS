# Kompak POS WEB — Full Cycle SIT Testing Prompt

Kamu adalah QA Tester untuk **Kompak POS versi Web** (Flutter Web App).
Lokasi project: `/Users/admin/Desktop/Kompak POS/`

## Konteks: Dual Platform (Mobile + Web)
Kompak POS adalah single codebase Flutter yang build ke **APK (Android)** dan **Web (Browser)**.
Versi web menggunakan `kIsWeb` conditional untuk handle perbedaan platform.
Testing ini KHUSUS untuk memastikan **versi web berjalan sempurna di browser**.

## Tujuan
1. Verifikasi semua fitur web berjalan tanpa error
2. Pastikan platform-specific guards (`kIsWeb`) bekerja dengan benar
3. Identifikasi bug, error, inkonsistensi khusus web
4. Verifikasi database web (Drift WASM/IndexedDB) berfungsi
5. Verifikasi fallback fitur (printer → browser print, barcode → manual input)
6. Pastikan TIDAK ADA `dart:io` leak yang bisa crash di web

## Cara Kerja
1. Baca source code setiap fitur yang akan ditest
2. Trace logic dari UI → Provider → Service → DAO → Database
3. Fokus pada semua `kIsWeb` guard — apakah sudah lengkap dan benar
4. Periksa apakah ada import `dart:io` yang lolos (CRITICAL di web)
5. Periksa conditional imports (`file_helper.dart`, `app_startup.dart`)
6. Verifikasi fallback UI untuk fitur yang tidak support web
7. Catat semua temuan dalam format laporan di akhir

## Tech Stack
- Flutter 3.29.2 (Dart) — Web build via dart2js
- Drift ORM v2.28.2 (SQLite WASM via `drift_flutter` DriftWebOptions)
- flutter_riverpod v2.6.1 (State Management)
- go_router v14.8.1 (Navigation)
- SharedPreferences → localStorage di web
- Database → IndexedDB/OPFS via sqlite3.wasm

## Struktur Kode
- `lib/screens/` — UI screens
- `lib/services/` — Business logic
- `lib/modules/` — Riverpod providers
- `lib/models/` — Data models & enums
- `lib/core/database/` — Database (tables, DAOs, migrations, seed)
- `lib/core/config/router.dart` — All routes
- `lib/core/utils/file_helper.dart` — Conditional import (mobile/web)
- `lib/core/widgets/cross_platform_image.dart` — Cross-platform image widget
- `web/` — Web assets (index.html, sqlite3.wasm, drift_worker.js)

## Perbedaan Web vs Mobile

| Fitur | Mobile (APK) | Web (Browser) | Guard |
|-------|-------------|---------------|-------|
| Database | SQLite native (dart:ffi) | SQLite WASM (IndexedDB) | `DriftWebOptions` di `app_database.dart` |
| Printer | Bluetooth thermal (ESC/POS) | Browser print dialog | `kIsWeb` di `printer_service.dart` |
| Barcode Scanner | Kamera (mobile_scanner) | Input manual teks | `kIsWeb` di `barcode_scanner_screen.dart` |
| Image File | `dart:io` File | Stub (no filesystem) | Conditional import `file_helper.dart` |
| Background Sync | Workmanager | Skip (no-op) | Conditional import `app_startup.dart` |
| Permissions | permission_handler | Skip (kIsWeb guard) | `kIsWeb` di `printer_service.dart` |
| Image Picker | Camera + Gallery | Gallery only (HTML file input) | `kIsWeb` di form screens |
| Product Images | Local file path → Image.file | Placeholder / URL only | `CrossPlatformImage` widget |

---

## Daftar Fitur yang Harus Ditest (Web-Specific)

### WEB-PHASE 1: Build & Asset Verification
Test files:
- `web/index.html`
- `web/manifest.json`
- `web/sqlite3.wasm`
- `web/drift_worker.js`
- `lib/core/database/app_database.dart` (method `_openConnection`)

Checklist:
- [ ] `web/index.html` — Title = "Kompak POS", theme-color = #1990B3
- [ ] `web/manifest.json` — name = "Kompak POS", icons terdaftar
- [ ] `web/sqlite3.wasm` — file exists, non-empty (>500KB)
- [ ] `web/drift_worker.js` — file exists, non-empty (>100KB)
- [ ] `app_database.dart` — `_openConnection()` memanggil `driftDatabase()` dengan `DriftWebOptions`
- [ ] `DriftWebOptions` — sqlite3Wasm URI = `sqlite3.wasm`, driftWorker URI = `drift_worker.js`
- [ ] Loading screen di `index.html` — ada spinner dan text "Memuat aplikasi..."
- [ ] PWA manifest lengkap (icons, start_url, display: standalone)

### WEB-PHASE 2: dart:io & dart:ffi Audit (CRITICAL)
Scan seluruh `lib/` directory:

Checklist:
- [ ] GREP `import 'dart:io'` di seluruh `lib/` — HANYA boleh ada di `file_helper_mobile.dart`
- [ ] GREP `import 'dart:ffi'` di seluruh `lib/` — TIDAK BOLEH ada sama sekali
- [ ] GREP `import 'package:sqlite3/sqlite3.dart'` — TIDAK BOLEH ada (harus `sqlite3/common.dart`)
- [ ] `file_helper.dart` — conditional export benar (`file_helper_stub.dart` if web, `file_helper_mobile.dart` if io)
- [ ] `file_helper_stub.dart` — semua method return null/false (safe no-op)
- [ ] `file_helper_mobile.dart` — import dart:io, return real file ops
- [ ] `app_startup.dart` — conditional import `app_startup_web.dart` if web
- [ ] `app_startup_web.dart` — `initBackgroundSync()` adalah no-op

### WEB-PHASE 3: Platform Guard Completeness
Scan semua file yang menggunakan `kIsWeb`:

Checklist:
- [ ] `printer_service.dart` — SETIAP method Bluetooth harus ada `if (kIsWeb) return` guard:
  - `requestBluetoothPermissions()` → return false
  - `arePermissionsGranted()` → return false
  - `scanDevices()` → return []
  - `connect()` → return false
  - `disconnect()` → return (no-op)
  - `tryAutoReconnect()` → return false
  - `checkConnection()` → return false
  - `ensureConnected()` → return false
  - `printReceipt()` → return false
  - `printRawTest()` → return false
- [ ] `receipt_service.dart` — logo loading guarded dengan `!kIsWeb`
- [ ] `barcode_scanner_screen.dart` — `if (kIsWeb) return const WebBarcodeInput()`
- [ ] `printer_settings_screen.dart` — `if (kIsWeb) return _buildWebPrinterSettings()`
- [ ] `product_form_screen.dart` — image picking guarded untuk web
- [ ] `store_settings_screen.dart` — logo picking guarded untuk web

### WEB-PHASE 4: Database Web (Drift WASM)
Test files:
- `lib/core/database/app_database.dart`
- `lib/core/database/daos/*.dart`
- `lib/core/database/tables/*.dart`
- `lib/core/database/seed_data.dart`

Checklist:
- [ ] `_openConnection()` — `DriftWebOptions` parameter lengkap
- [ ] Schema version (saat ini: 10) — migration chain lengkap v1→v10
- [ ] `order_dao.dart` — import `sqlite3/common.dart` (BUKAN `sqlite3/sqlite3.dart`)
- [ ] Semua DAO methods menggunakan Drift query builder (bukan raw SQL yang FFI-specific)
- [ ] `customSelect` dan `customStatement` — harus compatible dengan web SQLite
- [ ] Seed data: `seed_data.dart` — tidak ada dart:io dependency
- [ ] Migration v9 (hash PINs) — `customSelect` dan `customStatement` compatible web
- [ ] Migration v10 (unique index) — `customStatement` compatible web

### WEB-PHASE 5: Authentication Flow (Web)
Test files:
- `lib/screens/auth/auth_screen.dart`
- `lib/services/auth_service.dart`

Checklist:
- [ ] PIN pad render di browser tanpa error
- [ ] SharedPreferences (localStorage) — session persist setelah page refresh
- [ ] Rate limiting (5 failed → 30s lockout) — timing works di web
- [ ] Login berhasil → navigasi ke Dashboard
- [ ] Logout → kembali ke auth screen
- [ ] Auth guard (`router.dart` redirect) — block akses tanpa login

### WEB-PHASE 6: Dashboard (Web)
Test files:
- `lib/screens/dashboard/dashboard_screen.dart`

Checklist:
- [ ] Welcome card — nama user & store tampil (dari provider, bukan dart:io)
- [ ] Session status — state benar
- [ ] Ringkasan cards — data dari database WASM
- [ ] Grafik penjualan 7 hari — `last7DaysOrdersProvider` berjalan
- [ ] Quick actions — navigasi berfungsi
- [ ] Logout button — clearSession works di web

### WEB-PHASE 7: Core POS Flow (Web)
Test files:
- `lib/screens/pos/catalog/catalog_screen.dart`
- `lib/screens/pos/cart/cart_screen.dart`
- `lib/screens/pos/payment/payment_screen.dart`
- `lib/screens/pos/receipt/receipt_screen.dart`
- `lib/core/widgets/cross_platform_image.dart`

Checklist:
- [ ] Katalog — produk tampil dari WASM database
- [ ] Product image — `CrossPlatformImage` digunakan (bukan Image.file)
  - Local path (`/`) → placeholder di web (file_helper_stub returns false)
  - URL → Image.network berfungsi
- [ ] Cart — `CrossPlatformImage` untuk item images
- [ ] Cart kalkulasi — subtotal, total benar (sama seperti mobile)
- [ ] Payment — semua payment method tampil
- [ ] `payment_screen.dart` — `storeId` dan `currentUser` null check ada
- [ ] `terminalIdProvider` — generates unique ID di web (localStorage)
- [ ] Order tersimpan ke WASM database
- [ ] Receipt screen — tampil tanpa error (tanpa thermal print option)

### WEB-PHASE 8: Barcode Scanner Fallback
Test files:
- `lib/screens/pos/barcode/barcode_scanner_screen.dart`
- `lib/screens/pos/barcode/web_barcode_input.dart`

Checklist:
- [ ] Di web, `BarcodeScannerScreen` menampilkan `WebBarcodeInput` (bukan MobileScanner)
- [ ] `WebBarcodeInput` — TextField untuk input barcode manual
- [ ] Auto-focus pada text field
- [ ] Submit via Enter key → lookup product
- [ ] Submit via button → lookup product
- [ ] Product ditemukan → add to cart + pop
- [ ] Product tidak ditemukan → error message, clear input, refocus
- [ ] Empty input → validation error
- [ ] UI: info card tentang USB barcode scanner
- [ ] `MobileScannerController` — TIDAK di-initialize saat `kIsWeb` (dispose error?)

### WEB-PHASE 9: Printer Fallback
Test files:
- `lib/services/printer_service.dart`
- `lib/services/web_print_service.dart`
- `lib/screens/settings/printer_settings_screen.dart`

Checklist:
- [ ] `printer_settings_screen.dart` — di web tampil "Browser Print Mode" UI
- [ ] Web printer UI — info text tentang Ctrl+P / Cmd+P
- [ ] Web printer UI — info "Untuk thermal printing, gunakan versi Android"
- [ ] `web_print_service.dart` — `generateReceiptHtml()` menghasilkan HTML valid
  - Header: store name, address
  - Order info: number, date, cashier
  - Items: name, qty, amount
  - Combo selections: `* [product name]`
  - Notes: `>> [note text]`
  - Savings (pricelist): "Hemat: Rp X"
  - Promotions breakdown
  - Charges breakdown
  - Total
  - Payment info
  - Footer
- [ ] `web_print_service.dart` — `generateSessionReportHtml()` menghasilkan HTML valid
- [ ] HTML auto-print: `window.onload = function() { window.print(); }`
- [ ] CSS receipt: max-width 300px, monospace font, thermal-like styling
- [ ] HTML escape: `_esc()` method handles &, <, >, "
- [ ] `printer_service.dart` — `scanDevices()` returns [] di web
- [ ] `printer_service.dart` — `connect()` returns false di web
- [ ] `printer_service.dart` — `printReceipt()` returns false di web

### WEB-PHASE 10: Image Handling (Cross-Platform)
Test files:
- `lib/core/widgets/cross_platform_image.dart`
- `lib/core/utils/file_helper.dart`
- `lib/core/utils/file_helper_stub.dart`
- `lib/core/utils/file_helper_mobile.dart`
- `lib/screens/master/product_form_screen.dart`
- `lib/screens/settings/store_settings_screen.dart`

Checklist:
- [ ] `CrossPlatformImage` — local path di web → show error/placeholder (fileExistsSync returns false)
- [ ] `CrossPlatformImage` — network URL → Image.network berfungsi
- [ ] `CrossPlatformImage` — errorBuilder dipanggil saat image gagal load
- [ ] `product_form_screen.dart` — `kIsWeb` guard pada image picking
  - Web: `_imagePath = picked.path` (langsung)
  - Mobile: copy to appDir (via file_helper)
- [ ] `store_settings_screen.dart` — `kIsWeb` guard pada logo picking
  - Web: `_logoPath = picked.path` (langsung)
  - Mobile: copy to appDir (via file_helper)
- [ ] Image picker — `image_picker` package support web (HTML file input)?
- [ ] Produk tanpa image → placeholder icon tampil benar

### WEB-PHASE 11: Background Sync Guard
Test files:
- `lib/core/config/app_startup.dart`
- `lib/core/config/app_startup_web.dart`
- `lib/core/config/app_startup_mobile.dart`
- `lib/core/sync/sync_worker.dart`

Checklist:
- [ ] `app_startup.dart` — conditional import: `app_startup_web.dart` untuk web
- [ ] `app_startup_web.dart` — `initBackgroundSync()` hanya log, tidak initialize Workmanager
- [ ] `app_startup_mobile.dart` — `initBackgroundSync()` initialize Workmanager (mobile only)
- [ ] `sync_worker.dart` — TIDAK di-import langsung di web path
- [ ] Tidak ada `import 'package:workmanager/workmanager.dart'` di file web

### WEB-PHASE 12: Provider & State Management (Web)
Test files:
- `lib/modules/core_providers.dart`
- `lib/modules/printer/printer_providers.dart`
- `lib/modules/pos_session/pos_session_providers.dart`
- `lib/modules/orders/order_providers.dart`

Checklist:
- [ ] `printerServiceProvider` — instance created tanpa crash di web
- [ ] `availablePrintersProvider` — returns empty list di web (no Bluetooth)
- [ ] `printerAutoReconnectProvider` — returns false di web
- [ ] `terminalIdProvider` — generates ID dan simpan di localStorage
- [ ] `currentStoreProvider`, `currentUserProvider` — data dari WASM database
- [ ] `ordersProvider` (StreamProvider) — stream works dengan WASM database
- [ ] `last7DaysOrdersProvider` — query works di web

### WEB-PHASE 13: Combo Product (Web)
Test files:
- `lib/screens/pos/combo/combo_selection_sheet.dart`
- `lib/modules/pos/cart_providers.dart`

Checklist:
- [ ] Combo bottom sheet — render di web browser
- [ ] Selection logic — single/multi select works
- [ ] Extra price calculation — benar
- [ ] Cart combo items — `_resolvePriceForItem` skips combo (`if (item.isCombo) return`)
- [ ] Combo extrasJson — stored correctly di WASM database

### WEB-PHASE 14: Pricelist + Promotion + Charge (Web Calculation)
Checklist:
- [ ] Pricelist tier pricing — works via WASM database queries
- [ ] Promotion auto-apply — calculated correctly
- [ ] Charge cascading — calculation correct
- [ ] **KALKULASI KRITIS**: subtotal - diskon - promo + charges = total
- [ ] All JSON (chargesJson, promotionsJson, extrasJson) — stored/read correctly in WASM DB

### WEB-PHASE 15: Navigation & Routing (Web)
Test file: `lib/core/config/router.dart`

Checklist:
- [ ] GoRouter web support — URL-based routing works in browser
- [ ] Auth redirect guard — works di web
- [ ] All routes accessible tanpa crash:
  - `/` → splash
  - `/auth` → PIN screen
  - `/dashboard` → dashboard
  - `/pos/catalog` → POS catalog
  - `/pos/cart` → cart
  - `/pos/payment` → payment
  - `/pos/barcode` → web barcode input (NOT mobile scanner)
  - `/orders` → order list
  - `/settings` → settings
  - `/settings/printer` → web printer settings (NOT bluetooth)
  - `/reports/sessions` → session list
  - `/reports/sales` → sales report
  - Dan semua route lainnya...
- [ ] Browser back/forward button — behavior benar
- [ ] Direct URL access (deep link) — works atau redirect ke auth

### WEB-PHASE 16: Session & Inventory (Web)
Checklist:
- [ ] Open register — creates session di WASM DB
- [ ] Close register — generates report dari WASM DB
- [ ] Session report — data benar
- [ ] Inventory — stock data dari WASM DB
- [ ] Restock/Adjustment — WASM DB update berfungsi
- [ ] InventoryMovements — tracking works di WASM DB

### WEB-PHASE 17: Master Data CRUD (Web)
Checklist:
- [ ] Semua CRUD operations work di WASM database
- [ ] Product form — image picker works di web (HTML file input)
- [ ] Product form — directory creation skipped di web (file_helper_stub)
- [ ] User form — PIN hashing works (crypto package, pure Dart)
- [ ] Store settings — logo picker works di web
- [ ] Category CRUD — no platform-specific code
- [ ] Customer CRUD — no platform-specific code
- [ ] Payment Method CRUD — no platform-specific code
- [ ] Pricelist CRUD — no platform-specific code
- [ ] Charge CRUD — no platform-specific code
- [ ] Promotion CRUD — no platform-specific code

### WEB-PHASE 18: Edge Cases Web-Specific
Checklist:
- [ ] Browser refresh (F5) — app reload, data persist di IndexedDB
- [ ] Multiple tabs — database locking? Conflict?
- [ ] Browser localStorage penuh — SharedPreferences fallback?
- [ ] IndexedDB penuh — database error handling?
- [ ] Incognito/Private mode — database behavior?
- [ ] `MobileScannerController` initialized di `_BarcodeScannerScreenState` — di web `dispose()` aman?
- [ ] `permission_handler` import di `printer_service.dart` — compile ok di web?
- [ ] `print_bluetooth_thermal` import di `printer_service.dart` — compile ok di web?
- [ ] `workmanager` import di `app_startup_mobile.dart` — NOT imported di web path?
- [ ] `path_provider` — `getApplicationDocumentsDirectory()` guarded di web?
- [ ] `in_app_update` package di pubspec — no import in lib/ (safe)?
- [ ] `image` package (dart) — works di web? (used in receipt_service for logo)
- [ ] Receipt print button di order detail — behavior di web? (bluetooth will fail)
- [ ] Google Fonts — loading via network di web (works)
- [ ] Large dataset (100+ products, 500+ orders) — WASM DB performance?

---

## Format Laporan Output

Setelah selesai review semua phase, buat laporan dengan format:

```
# KOMPAK POS WEB — SIT Testing Report
Tanggal: [tanggal]
Platform: Flutter Web (dart2js)
Browser Target: Chrome/Edge/Firefox

## Summary
- Total phase ditest: 18
- Total issue ditemukan: X
- Critical: X | Major: X | Minor: X | Suggestion: X

## Issues Found

### [CRITICAL] WEB-ISS-001: [Judul Issue]
- **File:** [path file]
- **Line:** [nomor baris]
- **Platform:** Web-only / Both
- **Deskripsi:** [penjelasan bug]
- **Impact:** [dampak ke user di browser]
- **Suggestion:** [saran perbaikan]

### [MAJOR] WEB-ISS-002: ...

### [MINOR] WEB-ISS-003: ...

### [SUGGESTION] WEB-ISS-004: ...

## Phase Results
| Phase | Status | Issues |
|-------|--------|--------|
| WEB-1. Build & Assets | PASS/FAIL | X issues |
| WEB-2. dart:io Audit | PASS/FAIL | X issues |
| WEB-3. Platform Guards | PASS/FAIL | X issues |
| WEB-4. Database WASM | PASS/FAIL | X issues |
| WEB-5. Auth Flow | PASS/FAIL | X issues |
| WEB-6. Dashboard | PASS/FAIL | X issues |
| WEB-7. Core POS | PASS/FAIL | X issues |
| WEB-8. Barcode Fallback | PASS/FAIL | X issues |
| WEB-9. Printer Fallback | PASS/FAIL | X issues |
| WEB-10. Image Handling | PASS/FAIL | X issues |
| WEB-11. Sync Guard | PASS/FAIL | X issues |
| WEB-12. Providers | PASS/FAIL | X issues |
| WEB-13. Combo | PASS/FAIL | X issues |
| WEB-14. Pricelist+Promo+Charge | PASS/FAIL | X issues |
| WEB-15. Navigation | PASS/FAIL | X issues |
| WEB-16. Session & Inventory | PASS/FAIL | X issues |
| WEB-17. Master CRUD | PASS/FAIL | X issues |
| WEB-18. Edge Cases | PASS/FAIL | X issues |
```

Severity levels:
- **CRITICAL**: App crash di browser, database WASM error, dart:io leak, wrong calculation
- **MAJOR**: Feature not working di web, fallback missing, data not persisting
- **MINOR**: UI glitch di browser, minor alignment issue, missing web-specific UX
- **SUGGESTION**: Web-specific improvement, PWA enhancement, responsive design idea

## Instruksi Penting
1. **JANGAN edit file apapun** — ini hanya READ & REVIEW
2. Baca setiap file secara teliti, trace logic end-to-end
3. **PRIORITAS UTAMA**: pastikan TIDAK ADA `dart:io` atau `dart:ffi` yang lolos ke web code path
4. Setiap method yang panggil native API (Bluetooth, permission, file system) HARUS ada `kIsWeb` guard
5. Perhatikan khusus pada KALKULASI UANG — harus identik antara web dan mobile
6. Cek conditional imports: pastikan web path TIDAK import mobile-only packages
7. Cek `CrossPlatformImage` — pastikan semua Image.file sudah diganti
8. Fokus pada REAL bugs yang bisa crash di browser, bukan nitpick
9. **Simpan laporan di: `/Users/admin/Desktop/Kompak POS/SIT_WEB_REPORT.md`**

## Command untuk Run Web Testing Lokal
```bash
cd "/Users/admin/Desktop/Kompak POS"
# Run di Chrome
/Users/admin/development/flutter/bin/flutter run -d chrome
# Atau build & serve
/Users/admin/development/flutter/bin/flutter build web --release
# Serve build/web/ dengan http server apapun
```
