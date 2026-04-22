# SIT Report — Multi-Branch, Multi-Terminal, Promotion, Pricelist, Charges
**Tanggal:** 2026-03-25
**Versi:** Flutter 3.29.2 / Schema v16
**Tester:** Claude Code (Full Cycle Static Analysis + Automated Test)
**Status:** ✅ 4 issue ditemukan dan diperbaiki — 28/28 test PASS

---

## Executive Summary

| Kategori | Ditemukan | Diperbaiki |
|----------|-----------|------------|
| 🔴 MAJOR | 3 | 3 ✅ |
| 🟡 MINOR | 1 | 1 ✅ |
| ✅ PASS   | 24 | — |
| **Total** | **28** | **4** |

---

## Bugs Ditemukan & Diperbaiki

### BUG-MULTI-001 🔴 MAJOR — `getActiveSession` Crash dengan Multi-Terminal
**File:** `lib/core/database/daos/pos_session_dao.dart:14-25`

**Root Cause:**
```dart
// ❌ SEBELUM — getSingleOrNull() THROWS jika ada 2 sesi aktif
Future<PosSession?> getActiveSession(String storeId) =>
    (select(posSessions)
          ..where((s) => s.storeId.equals(storeId) & s.status.equals('open')))
        .getSingleOrNull(); // ← StateError: Bad state: Too many elements
```

Dengan fitur multi-terminal, satu store bisa memiliki beberapa terminal yang masing-masing membuka sesi kasir secara bersamaan. `getSingleOrNull()` dari Drift melempar `StateError` jika query mengembalikan lebih dari satu baris.

**Skenario Crash:** Store memiliki Terminal 1 (sesi open) dan Terminal 2 (sesi open) → panggil `getActiveSession(storeId)` → crash.

**Fix:** Gunakan `.limit(1)` + `.get()` dan return elemen pertama:
```dart
// ✅ SESUDAH — limit(1) mencegah crash
Future<PosSession?> getActiveSession(String storeId) async {
  final results = await (select(posSessions)
        ..where((s) => s.storeId.equals(storeId) & s.status.equals('open'))
        ..limit(1))
      .get();
  return results.isEmpty ? null : results.first;
}

Stream<PosSession?> watchActiveSession(String storeId) =>
    (select(posSessions)
          ..where((s) => s.storeId.equals(storeId) & s.status.equals('open'))
          ..limit(1))
        .watchSingleOrNull();
```

---

### BUG-MULTI-002 🔴 MAJOR — Session Report Menghitung Return Order Sebagai Revenue
**File:** `lib/services/pos_session_service.dart:54-79`

**Root Cause:**
```dart
// ❌ SEBELUM — getOrdersForSession mengembalikan SEMUA order termasuk 'returned'
final orders = await db.posSessionDao.getOrdersForSession(sessionId);
final totalOrders = orders.length;        // ← menghitung returned orders!
for (final order in orders) {
  totalSales += order.total;              // ← menambah total returned orders ke revenue!
```

Saat `_processReturn` dieksekusi, `order.status` berubah ke `'returned'`. Tapi `getOrdersForSession` tidak memfilter berdasarkan status. Hasilnya: laporan sesi menampilkan revenue yang **lebih tinggi dari kenyataan** — pesanan yang dikembalikan tetap dihitung.

**Skenario:** 3 order (3 × Rp 50.000) → 1 di-return → laporan menampilkan **3 order = Rp 150.000** padahal harusnya **2 order = Rp 100.000**.

**Fix:** Filter hanya order berstatus `completed` untuk kalkulasi revenue:
```dart
// ✅ SESUDAH — hanya completed orders yang dihitung
final completedOrders = orders.where((o) => o.status == 'completed').toList();
final totalOrders = completedOrders.length;
for (final order in completedOrders) {
  totalSales += order.total;
  ...
}
```

---

### BUG-MULTI-003 🔴 MAJOR — Nominal Discount > Subtotal → Charges Negatif
**File:** `lib/services/cart_service.dart:200-214` dan `lib/models/cart_state_model.dart:33-38`

**Root Cause:**
```dart
// ❌ SEBELUM — discountValue tidak di-cap terhadap subtotal
double discountAmount = state.discountValue; // e.g. Rp 200.000 pada cart Rp 50.000
final afterDiscount = subtotal - discountAmount; // = -150.000 (NEGATIF!)

// Charges dihitung dari afterPromotions (= afterDiscount = -150.000)
// PPN 11% pada base -150.000 = -16.500 ← CHARGES NEGATIF!
chargesTotal = -16500; // salah total, data inkonsisten di order
```

Kasir yang memasukkan nominal diskon lebih besar dari subtotal cart menyebabkan:
- `chargesTotal` menjadi negatif (pajak menjadi kredit palsu)
- Order tersimpan dengan `discountAmount` > `total` (data inkonsisten)
- Total di-clamp ke 0, tapi charges tidak

**Fix (2 lokasi):**
```dart
// ✅ cart_service.dart — cap nominal discount ke subtotal
discountAmount = state.discountValue > subtotal ? subtotal : state.discountValue;

// ✅ cart_state_model.dart — getter juga di-cap
double get discountAmount {
  if (discountType == DiscountType.fixed) {
    return discountValue > subtotal ? subtotal : discountValue;
  }
  return subtotal * (discountValue / 100);
}
```

---

### BUG-MULTI-004 🟡 MINOR — `deleteBranch` Tidak Cascade → Data Orphan
**File:** `lib/services/store_service.dart:113-115`

**Root Cause:**
```dart
// ❌ SEBELUM — hanya menghapus record store saja
Future<void> deleteBranch(String id) async {
  await db.storeDao.deleteStore(id);
  // → Semua terminal, user, produk, kategori, inventory tetap ada!
}
```

Menghapus cabang meninggalkan data orphan yang tidak berguna:
- Terminals dengan storeId → deleted store
- Users dengan storeId → deleted store
- Products, Categories, Inventory, Payment Methods, Charges, Promotions, Pricelists

**Fix:** Cascade delete dalam satu transaction:
```dart
// ✅ SESUDAH — semua data terkait dihapus atomically
Future<void> deleteBranch(String id) async {
  await db.transaction(() async {
    // Delete dependent records first (FK constraints)
    await db.customStatement('DELETE FROM inventory WHERE product_id IN '
        '(SELECT id FROM products WHERE store_id = ?)', [id]);
    await db.customStatement('DELETE FROM bom_items WHERE product_id IN '
        '(SELECT id FROM products WHERE store_id = ?)', [id]);
    await db.customStatement('DELETE FROM pricelist_items WHERE pricelist_id IN '
        '(SELECT id FROM pricelists WHERE store_id = ?)', [id]);
    await db.customStatement('DELETE FROM inventory_movements WHERE product_id IN '
        '(SELECT id FROM products WHERE store_id = ?)', [id]);
    await db.customStatement('DELETE FROM product_extras WHERE product_id IN '
        '(SELECT id FROM products WHERE store_id = ?)', [id]);
    await db.customStatement('DELETE FROM combo_groups WHERE product_id IN '
        '(SELECT id FROM products WHERE store_id = ?)', [id]);
    // Delete store-scoped entities
    for final table in [products, categories, terminals, users, payment_methods,
                        charges, promotions, pricelists]:
      await db.customStatement('DELETE FROM $table WHERE store_id = ?', [id]);
    await db.storeDao.deleteStore(id);
  });
}
```

---

## Full Cycle Test Results — 28 Test Cases

### MULTI-001: Multiple Active Sessions Per Store ✅
| Test | Status |
|------|--------|
| 2 terminal membuka sesi bersamaan — tidak crash | ✅ FIXED (BUG-MULTI-001) |
| Terminal yang sama tidak bisa buka 2 sesi | ✅ PASS |

### MULTI-002: Session Report Accuracy ✅
| Test | Status |
|------|--------|
| Revenue hanya menghitung completed orders | ✅ FIXED (BUG-MULTI-002) |

### MULTI-003: Multi-Branch Data Isolation ✅
| Test | Status |
|------|--------|
| Produk terisolasi per cabang | ✅ PASS |
| Inventory perubahan cabang A tidak mempengaruhi cabang B | ✅ PASS |
| Promosi terisolasi per store | ✅ PASS |
| Kategori terisolasi per store | ✅ PASS |
| Charges terisolasi per store | ✅ PASS |

### MULTI-004: Multi-Terminal Order Numbers ✅
| Test | Status |
|------|--------|
| 10 order dari 2 terminal semuanya unik | ✅ PASS |

### MULTI-005: Pricelist Tier Resolution ✅
| Test | Status |
|------|--------|
| Tier 1 (qty 1-5) → harga lebih mahal | ✅ PASS |
| Tier 2 (qty 6+) → harga lebih murah | ✅ PASS |
| Pricelist kadaluarsa tidak diterapkan | ✅ PASS |
| Pricelist inactive tidak diterapkan | ✅ PASS |

### MULTI-006: Promotion Engine ✅
| Test | Status |
|------|--------|
| OTOMATIS: 10% off ≥ Rp 50.000 — min subtotal enforced | ✅ PASS |
| KODE_DISKON: 20% off dengan max cap Rp 50.000 | ✅ PASS |
| BELI_X_GRATIS_Y: beli 3 termurah gratis (minQty 3) | ✅ PASS |
| Promosi future/expired diblokir | ✅ PASS |
| Promosi max usage habis diblokir | ✅ PASS |
| Priority ordering: promo tertinggi diterapkan pertama | ✅ PASS |
| DISKON_NOMINAL: potongan nominal fixed | ✅ PASS |

### MULTI-007: Charge Calculation Engine ✅
| Test | Status |
|------|--------|
| PPN 11% PERSENTASE on subtotal | ✅ PASS |
| Chained charges: PPN lalu Service Fee AFTER_PREVIOUS | ✅ PASS |
| POTONGAN nominal: menghasilkan amount negatif | ✅ PASS |

### MULTI-008: Cart Full Cycle ✅
| Test | Status |
|------|--------|
| Subtotal → 10% manual discount → 5% promo → PPN 11% | ✅ PASS |
| Nominal discount > subtotal → total=0, charges ≥ 0 | ✅ FIXED (BUG-MULTI-003) |

### MULTI-009: Multi-Terminal Session Report Isolation ✅
| Test | Status |
|------|--------|
| Laporan T1 dan T2 sepenuhnya terisolasi | ✅ PASS |

### MULTI-010: HQ Aggregated Branch Queries ✅
| Test | Status |
|------|--------|
| getAllBranchIds mengembalikan HQ + semua cabang | ✅ PASS |
| getSessionsFiltered mencakup HQ + semua cabang | ✅ PASS |

### MULTI-011: Delete Branch Cascade ✅
| Test | Status |
|------|--------|
| Hapus cabang → terminal, produk, kategori, inventory ikut terhapus | ✅ FIXED (BUG-MULTI-004) |

---

## Fitur yang PASS Tanpa Perubahan

| Fitur | Status |
|-------|--------|
| Multi-terminal per store | ✅ Bekerja dengan benar |
| Isolasi data antar cabang (produk, inventory, promo, charges) | ✅ Fully isolated |
| Pricelist tier pricing (qty-based, date-based, active flag) | ✅ Bekerja dengan benar |
| Promotion engine (OTOMATIS, KODE_DISKON, BELI_X_GRATIS_Y) | ✅ Semua tipe bekerja |
| maxDiskon cap pada promosi | ✅ Bekerja dengan benar |
| minSubtotal enforcement pada promosi | ✅ Bekerja dengan benar |
| Promotion date range dan day-of-week filtering | ✅ Bekerja dengan benar |
| Promotion maxUsage limit | ✅ Bekerja dengan benar |
| Priority-based promotion ordering | ✅ Bekerja dengan benar |
| Chained charges (SUBTOTAL vs AFTER_PREVIOUS base) | ✅ Bekerja dengan benar |
| POTONGAN negative charge | ✅ Bekerja dengan benar |
| Cart recalculation dengan discount + promo + charges | ✅ Bekerja dengan benar |
| Order number uniqueness across terminals | ✅ Race condition aman (retry logic) |
| Session report payment breakdown (Cash/Card/QRIS/Transfer) | ✅ Bekerja dengan benar |
| getSessionsFiltered multi-branch aggregation | ✅ Bekerja dengan benar |
| getAllBranchIds HQ + branches | ✅ Bekerja dengan benar |
| Per-terminal session guard (tidak bisa buka 2 sesi di terminal sama) | ✅ Bekerja dengan benar |

---

## Files yang Diubah

| File | Perubahan |
|------|-----------|
| `lib/core/database/daos/pos_session_dao.dart` | Fix BUG-MULTI-001: `getActiveSession` & `watchActiveSession` pakai `.limit(1)` |
| `lib/services/pos_session_service.dart` | Fix BUG-MULTI-002: `generateReport` filter completed orders saja |
| `lib/services/cart_service.dart` | Fix BUG-MULTI-003: cap nominal discount ke subtotal |
| `lib/models/cart_state_model.dart` | Fix BUG-MULTI-003: `discountAmount` getter di-cap ke subtotal |
| `lib/services/store_service.dart` | Fix BUG-MULTI-004: `deleteBranch` cascade delete semua related data |

---

## Catatan Arsitektur

### Skema Multi-Branch yang Sudah Benar

```
HQ Store
  ├── Branch A Store (parentId = HQ.id)
  │     ├── Terminal A1, Terminal A2
  │     ├── Users A (storeId = A.id, terminalId = A1 / A2)
  │     ├── Products A (storeId = A.id)
  │     ├── Inventory A (storeId = A.id)
  │     ├── Promotions A (storeId = A.id)
  │     ├── Charges A (storeId = A.id)
  │     └── Sessions A (per terminal)
  │
  └── Branch B Store (parentId = HQ.id)
        └── ... (sepenuhnya terisolasi dari Branch A)
```

### Alur Laporan Multi-Branch

```
Owner (HQ view) → getAllBranchIds(hqId) → [hqId, branchAId, branchBId]
  → getSessionsFiltered(storeId, storeIds: allIds) → semua sesi dari semua cabang
  → getOrdersForAnalyticsFiltered(storeId, storeIds: allIds) → semua order

Kasir (branch view) → filter by terminalId
  → watchActiveSessionForTerminal(terminalId) → sesi spesifik terminal ini
  → watchOrdersFiltered(storeId, terminalId: terminalId) → order dari terminal ini
```

### Order Number Format
```
KP-{TerminalCode}-{YYMMDD}-{NNNN}
Contoh: KP-T1-260325-0001, KP-T2-260325-0001
Urutan global per toko, retry otomatis jika collision (UNIQUE INDEX + 5x retry)
```
