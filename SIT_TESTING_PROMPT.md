# Kompak POS — Full Cycle SIT Testing Prompt

Kamu adalah QA Tester untuk aplikasi **Kompak POS** (Flutter POS app).
Lokasi project: `/Users/admin/Desktop/Kompak POS/`

## Tujuan
Lakukan full-cycle System Integration Testing (SIT) pada semua fitur Kompak POS.
Identifikasi semua bug, error, loophole, inkonsistensi UI, dan masalah kalkulasi.

## Cara Kerja
1. Baca source code setiap fitur yang akan ditest
2. Trace logic dari UI → Provider → Service → DAO → Database
3. Periksa edge cases, error handling, validasi input
4. Periksa konsistensi kalkulasi (subtotal, diskon, charges, total)
5. Periksa apakah data tersimpan dengan benar ke database
6. Catat semua temuan dalam format laporan di akhir

## Tech Stack
- Flutter 3.29.2 (Dart)
- Drift ORM v2.28.2 (SQLite)
- flutter_riverpod v2.6.1 (State Management)
- go_router v14.8.1 (Navigation)
- ESC/POS thermal printing 58mm

## Struktur Kode
- `lib/screens/` — UI screens
- `lib/services/` — Business logic
- `lib/modules/` — Riverpod providers
- `lib/models/` — Data models & enums
- `lib/core/database/` — Database (tables, DAOs, migrations, seed)
- `lib/core/config/router.dart` — All routes

## Daftar Fitur yang Harus Ditest

### PHASE 1: Authentication & Session
Test files:
- `lib/screens/auth/auth_screen.dart`
- `lib/services/auth_service.dart`
- `lib/modules/auth/auth_providers.dart`

Checklist:
- [ ] Login dengan PIN valid (demo: 1234) → masuk Dashboard
- [ ] Login PIN salah → error message tampil, tidak bisa masuk
- [ ] Login PIN kosong → validasi
- [ ] Session restore: setelah login, data user & store tersimpan di SharedPreferences
- [ ] Logout: session cleared, kembali ke auth screen
- [ ] Cek apakah PIN disimpan plain text (security issue?)

### PHASE 2: Dashboard
Test files:
- `lib/screens/dashboard/dashboard_screen.dart`

Checklist:
- [ ] Welcome card menampilkan nama user & store yang benar
- [ ] Session status card: tampil status kasir (aktif/tutup)
- [ ] Ringkasan hari ini: Total Transaksi, Total Penjualan, Rata-rata, Gross Profit, Item Terjual
- [ ] Grafik 7 hari: data konsisten dengan order yang ada
- [ ] Aksi cepat: Buka POS, List Order, Laporan → navigasi benar
- [ ] Jika tidak ada session aktif: "Buka POS" harus redirect ke open register

### PHASE 3: POS Session (Buka/Tutup Kasir)
Test files:
- `lib/screens/pos/session/open_register_screen.dart`
- `lib/screens/pos/session/close_register_dialog.dart`
- `lib/services/pos_session_service.dart`
- `lib/modules/pos_session/pos_session_providers.dart`
- `lib/core/database/tables/pos_sessions_table.dart`

Checklist:
- [ ] Buka kasir: input saldo awal → session created dengan status 'open'
- [ ] Saldo awal 0 → boleh atau tidak? Cek validasi
- [ ] Hanya 1 session aktif per store (tidak bisa buka 2x)
- [ ] Tutup kasir: input closing cash → session closed
- [ ] Expected cash dihitung benar (opening + cash received - cash change)
- [ ] Selisih (difference) = actual - expected → tampil benar
- [ ] Setelah tutup kasir → kembali ke Dashboard
- [ ] Session report: semua data lengkap (orders, sales, payment breakdown)
- [ ] Print session report → format thermal benar

### PHASE 4: Core POS Transaction Flow
Test files:
- `lib/screens/pos/catalog/catalog_screen.dart`
- `lib/screens/pos/catalog/product_detail_screen.dart`
- `lib/screens/pos/cart/cart_screen.dart`
- `lib/screens/pos/payment/payment_screen.dart`
- `lib/screens/pos/receipt/receipt_screen.dart`
- `lib/services/cart_service.dart`
- `lib/services/order_service.dart`
- `lib/modules/pos/cart_providers.dart`

Checklist:
- [ ] Katalog: semua produk aktif tampil di grid
- [ ] Filter kategori: hanya produk kategori terpilih yang tampil
- [ ] Search: hasil sesuai keyword
- [ ] Tap produk: masuk detail atau langsung add to cart
- [ ] Cart: item tampil dengan qty, harga, subtotal benar
- [ ] Ubah qty: subtotal & total recalculate
- [ ] Hapus item: item hilang, total update
- [ ] Clear cart: semua item terhapus
- [ ] Payment Cash: input nominal → kembalian dihitung benar
- [ ] Payment Cash kurang dari total → button bayar disabled
- [ ] Payment QRIS/Card/Transfer: langsung confirm tanpa input nominal
- [ ] Order tersimpan ke database dengan status 'completed'
- [ ] Order items tersimpan lengkap (productName, price, qty, extrasJson)
- [ ] Receipt digital: semua info tampil (items, charges, total, payment, change)
- [ ] Receipt thermal print: format benar, alignment rapi
- [ ] Order number auto-increment per hari
- [ ] Setelah order selesai → bisa langsung buat order baru

### PHASE 5: Combo Product
Test files:
- `lib/screens/pos/combo/combo_selection_sheet.dart`
- `lib/screens/master/combo_config_screen.dart`
- `lib/services/combo_service.dart`
- `lib/modules/combo/combo_providers.dart`
- `lib/models/cart_item_model.dart` (ComboSelection class)

Checklist:
- [ ] Produk combo tampil badge "COMBO" di katalog
- [ ] Tap combo → bottom sheet muncul dengan semua group
- [ ] Setiap group: pilihan sesuai min/max selection
- [ ] Single select group: radio button behavior
- [ ] Multi select group: checkbox behavior, max enforced
- [ ] Extra price tampil di samping item (+Rp 5.000)
- [ ] Total combo = base price + sum extra prices
- [ ] Confirm tanpa pilih semua required group → blocked
- [ ] Combo masuk cart sebagai line item terpisah (tidak merge)
- [ ] 2 combo sama tapi pilihan beda → 2 line items
- [ ] Cart menampilkan detail pilihan combo
- [ ] Receipt menampilkan combo selections
- [ ] Thermal print: format `* [product name]` untuk combo items
- [ ] extrasJson di order_items menyimpan isCombo + comboSelections

### PHASE 6: Pricelist / Harga Bertingkat
Test files:
- `lib/services/pricelist_service.dart`
- `lib/modules/pricelist/pricelist_providers.dart`
- `lib/screens/master/pricelist_list_screen.dart`
- `lib/screens/master/pricelist_form_screen.dart`

Checklist:
- [ ] Pricelist aktif dengan date range valid → harga berubah di katalog
- [ ] Tier 1: Noodles Ramen qty 1-5 → Rp 48.000
- [ ] Tier 2: Noodles Ramen qty 6+ → Rp 42.000
- [ ] Ubah qty di cart → harga per pcs update sesuai tier
- [ ] Savings tampil (harga asli vs harga pricelist)
- [ ] Pricelist expired → harga kembali ke harga normal
- [ ] Pricelist inactive → harga normal
- [ ] CRUD pricelist: create, edit, delete → data konsisten

### PHASE 7: Promotions
Test files:
- `lib/services/promotion_service.dart`
- `lib/modules/promotion/promotion_providers.dart`
- `lib/screens/master/promotion_list_screen.dart`
- `lib/screens/master/promotion_form_screen.dart`
- `lib/models/applied_promotion_model.dart`

Checklist:
- [ ] Promo otomatis: subtotal >= 50.000 → diskon 10% auto apply
- [ ] Promo otomatis: subtotal < 50.000 → tidak ada diskon
- [ ] Kode diskon: input valid code → diskon apply
- [ ] Kode diskon: input invalid → error message
- [ ] Max discount cap: diskon tidak melebihi batas
- [ ] Min qty: promo hanya berlaku jika qty >= minimum
- [ ] Min subtotal: promo hanya berlaku jika subtotal >= minimum
- [ ] Beli X Gratis Y: beli 3+ item → termurah free
- [ ] Date range: promo di luar tanggal → tidak berlaku
- [ ] Day of week: promo hanya hari tertentu
- [ ] Max usage: promo sudah mencapai limit → tidak berlaku
- [ ] Priority ordering: promo dengan priority lebih tinggi diproses duluan
- [ ] Promo inactive → tidak apply
- [ ] promotionsJson tersimpan di order
- [ ] CRUD promotion: validasi semua field

### PHASE 8: Charges (Biaya / Pajak)
Test files:
- `lib/services/charge_service.dart`
- `lib/modules/charge/charge_providers.dart`
- `lib/screens/master/charge_list_screen.dart`
- `lib/screens/master/charge_form_screen.dart`
- `lib/models/applied_charge_model.dart`

Checklist:
- [ ] PPN 11%: dihitung dari subtotal → amount benar
- [ ] Service 5%: persentase dari subtotal
- [ ] Potongan nominal: Rp 5.000 dikurangi dari total
- [ ] Charge cascading (afterPrevious): charge berikutnya dihitung dari running total
- [ ] Charge dari subtotal: selalu dari subtotal awal
- [ ] Multiple charges: urutan (sortOrder) benar
- [ ] Charge inactive → tidak dihitung
- [ ] chargesJson tersimpan di order
- [ ] KALKULASI KRITIS: subtotal - diskon - promo + charges = total → HARUS TEPAT
- [ ] Tampilan di cart, receipt digital, dan thermal print konsisten

### PHASE 9: Inventory
Test files:
- `lib/screens/inventory/inventory_screen.dart`
- `lib/screens/inventory/restock_screen.dart`
- `lib/screens/inventory/adjustment_screen.dart`
- `lib/screens/inventory/inventory_report_screen.dart`
- `lib/services/inventory_service.dart`

Checklist:
- [ ] Stok awal sesuai seed data
- [ ] Jual produk → stok berkurang sesuai qty
- [ ] Restock: tambah stok → stok bertambah
- [ ] Adjustment increase: stok bertambah
- [ ] Adjustment decrease: stok berkurang
- [ ] Stok tidak bisa negatif (atau bisa? cek business rule)
- [ ] Low stock threshold: warning tampil saat stok rendah
- [ ] Inventory report: data konsisten
- [ ] Riwayat pergerakan stok tercatat

### PHASE 10: Order Management
Test files:
- `lib/screens/orders/orders_screen.dart`
- `lib/screens/orders/order_detail_screen.dart`
- `lib/modules/orders/order_providers.dart`

Checklist:
- [ ] List order: semua order tampil (StreamProvider real-time)
- [ ] Order baru langsung muncul tanpa refresh
- [ ] Order detail: semua info lengkap (items, qty, prices, charges, promo, payment)
- [ ] Reprint receipt dari order detail
- [ ] Filter/sort order (jika ada)

### PHASE 11: Kitchen Display
Test files:
- `lib/screens/kitchen/kitchen_display_screen.dart`

Checklist:
- [ ] Order aktif tampil di grid
- [ ] Auto-refresh 30 detik
- [ ] Layout responsive (1/2/3 kolom)
- [ ] Order detail lengkap (items, notes, combo selections)
- [ ] Dark theme background

### PHASE 12: Master Data CRUD
Test files: `lib/screens/master/*.dart` dan `lib/services/*.dart`

Untuk setiap entity (Products, Categories, Users, Customers, Payment Methods, Charges, Promotions, Pricelists):
- [ ] CREATE: form validasi, data tersimpan
- [ ] READ: list tampil benar, search/filter
- [ ] UPDATE: perubahan tersimpan, reflected di POS
- [ ] DELETE/DEACTIVATE: data nonaktif/hilang dari POS

Khusus:
- [ ] Product form: isCombo toggle → "Atur Pilihan Combo" button muncul
- [ ] User form: PIN unik, role selection
- [ ] Payment method: type selection (cash/card/qris/transfer)

### PHASE 13: Settings & Printer
Test files:
- `lib/screens/settings/settings_screen.dart`
- `lib/screens/settings/store_settings_screen.dart`
- `lib/screens/settings/printer_settings_screen.dart`

Checklist:
- [ ] Store settings: ubah nama toko → update di receipt header
- [ ] Printer settings: discovery, connect, test print
- [ ] Semua menu settings navigasi ke screen yang benar
- [ ] Menu drawer: POS, Laporan (expandable), Inventory (expandable), Dashboard, Settings, Logout

### PHASE 14: Navigation & Routing
Test file: `lib/core/config/router.dart`

Checklist:
- [ ] Semua route bisa diakses tanpa error
- [ ] Deep link dengan parameter (:id) benar
- [ ] Back button behavior konsisten
- [ ] Drawer menu navigasi benar
- [ ] Redirect saat tidak ada session aktif

### PHASE 15: Edge Cases & Cross-Feature
Checklist:
- [ ] Combo + Promo + Pricelist + Charge → kalkulasi total benar
- [ ] Diskon manual + promo otomatis bersamaan → behavior benar
- [ ] Transaksi tanpa session aktif → di-block / redirect
- [ ] Double tap payment button → hanya 1 order
- [ ] Cart kosong → tidak bisa ke payment
- [ ] Produk dihapus tapi ada di order lama → order detail tetap OK
- [ ] Angka boundary: 0, negatif, sangat besar, desimal panjang
- [ ] String panjang di nama produk → layout tidak overflow
- [ ] Order number reset tiap hari
- [ ] Multiple payment methods: jika 1 dinonaktifkan → tidak muncul di payment

## Format Laporan Output

Setelah selesai review semua phase, buat laporan dengan format:

```
# KOMPAK POS — SIT Testing Report
Tanggal: [tanggal]

## Summary
- Total fitur ditest: X
- Total issue ditemukan: X
- Critical: X | Major: X | Minor: X | Suggestion: X

## Issues Found

### [CRITICAL] ISS-001: [Judul Issue]
- **File:** [path file]
- **Line:** [nomor baris]
- **Deskripsi:** [penjelasan bug]
- **Impact:** [dampak ke user]
- **Suggestion:** [saran perbaikan]

### [MAJOR] ISS-002: ...

### [MINOR] ISS-003: ...

### [SUGGESTION] ISS-004: ...

## Phase Results
| Phase | Status | Issues |
|-------|--------|--------|
| 1. Auth | PASS/FAIL | X issues |
| 2. Dashboard | PASS/FAIL | X issues |
| ... | ... | ... |
```

Severity levels:
- **CRITICAL**: App crash, data loss, wrong calculation, security hole
- **MAJOR**: Feature not working, bad UX flow, data inconsistency
- **MINOR**: UI glitch, typo, minor alignment issue
- **SUGGESTION**: Improvement idea, best practice recommendation

## Instruksi Penting
1. JANGAN edit file apapun — ini hanya READ & REVIEW
2. Baca setiap file secara teliti, trace logic end-to-end
3. Perhatikan khusus pada KALKULASI UANG — ini yang paling kritis untuk POS
4. Cek error handling: apa yang terjadi jika service throw exception?
5. Cek null safety: apakah ada potensi null pointer?
6. Cek state management: apakah provider di-dispose dengan benar?
7. Fokus pada REAL bugs, bukan nitpick style preference
8. Simpan laporan di: `/Users/admin/Desktop/Kompak POS/SIT_REPORT.md`
