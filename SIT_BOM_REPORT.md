# SIT Report — Fitur BOM / Resep (Bill of Materials)
**Tanggal:** 2026-03-24
**Versi:** Flutter 3.29.2 / Schema v14
**Tester:** Claude Code (Full Cycle Static Analysis)
**Status:** ✅ 4 issue ditemukan dan diperbaiki

---

## Executive Summary

| Kategori | Ditemukan | Diperbaiki |
|----------|-----------|-----------|
| 🔴 MAJOR | 3 | 3 ✅ |
| 🟡 MINOR | 1 | 1 ✅ |
| ✅ PASS | 18 | — |
| **Total** | **22** | **4** |

---

## Bugs Ditemukan & Diperbaiki

### BUG-BOM-001 🔴 MAJOR — `setProductHasBom()` Data Loss via `replace()`
**File:** `lib/services/bom_service.dart:62-75`

**Root Cause:**
```dart
// ❌ SEBELUM — replace() mereset field yang absent ke nilai default
await db.productDao.updateProduct(ProductsCompanion(
  id: Value(product.id),
  name: Value(product.name),
  hasBom: Value(hasBom),
  // costPrice, barcode, sku, imagePath, isActive, isCombo... → DIRESET ke NULL/default!
));
```

`product_dao.dart` menggunakan `update(products).replace(companion)`. Drift's `replace()` menulis SEMUA kolom — field yang absent (Value.absent()) di-reset ke nilai default tabel mereka:
- `costPrice` → null
- `barcode` → null
- `sku` → null
- `imageUrl` → null
- `isActive` → true (baik)
- `isCombo` → false ← **DATA LOSS jika produk adalah combo!**
- `discountPercent` → null

**Fix:** Preserve semua field existing dari produk yang sudah dibaca:
```dart
// ✅ SESUDAH — semua field di-preserve, hanya hasBom yang berubah
await db.productDao.updateProduct(ProductsCompanion(
  id: Value(product.id),
  storeId: Value(product.storeId),
  categoryId: Value(product.categoryId),
  name: Value(product.name),
  description: Value(product.description),
  price: Value(product.price),
  costPrice: Value(product.costPrice),      // ← preserved
  imageUrl: Value(product.imageUrl),        // ← preserved
  barcode: Value(product.barcode),          // ← preserved
  sku: Value(product.sku),                  // ← preserved
  isActive: Value(product.isActive),        // ← preserved
  hasExtras: Value(product.hasExtras),      // ← preserved
  isCombo: Value(product.isCombo),          // ← preserved
  hasBom: Value(hasBom),                    // ← hanya ini yang berubah
  kitchenPrinterId: Value(product.kitchenPrinterId), // ← preserved
  discountPercent: Value(product.discountPercent),   // ← preserved
  updatedAt: Value(DateTime.now()),
));
```

**Catatan:** Method ini saat ini tidak dipanggil dari screen manapun (product form handles BOM flag langsung), tapi tetap diperbaiki untuk mencegah bug latent.

---

### BUG-BOM-002 🔴 MAJOR — Empty BOM → Stok Tidak Terpotong (Silent Skip)
**Files:** `lib/services/order_service.dart:102` + `lib/screens/orders/orders_screen.dart:448`

**Root Cause:**
```dart
// ❌ SEBELUM — jika hasBom=true tapi belum ada resep, TIDAK ADA stok yang dipotong
if (product != null && product.hasBom) {
  final bomItems = await db.bomDao.getItemsByProduct(item.productId);
  for (final bom in bomItems) { // ← jika kosong, loop tidak jalan
    await db.inventoryDao.decrementStock(...);
  }
} else {
  await db.inventoryDao.decrementStock(...); // ← tidak dieksekusi karena hasBom=true
}
```

**Skenario:** User mengaktifkan toggle BOM pada produk tapi belum mengkonfigurasi resep (belum tap "Atur Resep BOM"). Saat produk dijual, `bomItems` kosong → loop tidak berjalan → stok produk sendiri juga tidak terpotong → **STOK HILANG TANPA JEJAK**.

**Fix:** Fallback ke pengurangan stok produk itu sendiri jika BOM belum dikonfigurasi:
```dart
// ✅ SESUDAH
if (product != null && product.hasBom) {
  final bomItems = await db.bomDao.getItemsByProduct(item.productId);
  if (bomItems.isNotEmpty) {
    for (final bom in bomItems) {
      await db.inventoryDao.decrementStock(bom.materialProductId, ...);
    }
  } else {
    // BOM belum dikonfigurasi → deduct produk sendiri
    await db.inventoryDao.decrementStock(item.productId, ...);
  }
}
```

**Fix yang sama diterapkan** di return logic (`orders_screen.dart`).

---

### BUG-BOM-003 🔴 MAJOR — Return Order Tidak dalam Transaction
**File:** `lib/screens/orders/orders_screen.dart:422`

**Root Cause:**
```dart
// ❌ SEBELUM — operasi tidak di-wrap transaction
await db.orderReturnDao.insertReturn(...);   // 1. Return record inserted
await db.orderDao.updateOrderStatus('returned'); // 2. Status changed
final items = await db.orderDao.getItemsForOrder(order.id);
for (final item in items) {
  await db.inventoryDao.restockProduct(...); // 3. Jika ini gagal di tengah...
}
// → Order sudah 'returned' tapi inventory hanya sebagian di-restore!
```

**Skenario failure:** Jika produk ke-2 dari 3 item dalam order gagal di-restock (misal karena ada constraint DB atau deadlock), maka:
- Order status sudah berubah ke `returned` ✓
- Return record sudah diinsert ✓
- Item ke-1 sudah di-restock ✓
- Item ke-2 dan ke-3 TIDAK di-restock ❌
- **Inkonsistensi data permanen**

**Fix:** Wrap seluruh operasi dalam `db.transaction()`:
```dart
// ✅ SESUDAH
await db.transaction(() async {
  await db.orderReturnDao.insertReturn(...);
  await db.orderDao.updateOrderStatus('returned');
  final items = await db.orderDao.getItemsForOrder(order.id);
  for (final item in items) {
    await db.inventoryDao.restockProduct(...);
  }
  // Jika ada yang gagal → semua di-rollback, order tetap 'completed'
});
```

---

### BUG-BOM-004 🟡 MINOR — Duplikat Material Bisa Ditambahkan ke BOM
**File:** `lib/screens/master/bom_config_screen.dart:215`

**Root Cause:**
```dart
// ❌ SEBELUM — dropdown menampilkan SEMUA produk kecuali dirinya sendiri
items: products
    .where((p) => p.id != productId) // hanya filter self
    .map(...)
    .toList(),
```

User bisa memilih produk yang SUDAH ada di BOM dan menambahkannya lagi. Hasilnya: 2 entry untuk bahan baku yang sama. Saat penjualan, stok bahan baku itu terpotong 2x lipat.

**Fix:** Filter keluar material yang sudah ada di BOM dari dropdown:
```dart
// ✅ SESUDAH
final existingMaterialIds = bomAsync.valueOrNull
    ?.map((e) => e.bomItem.materialProductId).toSet() ?? {};

items: products
    .where((p) =>
        p.id != productId &&               // exclude self
        !existingMaterialIds.contains(p.id)) // exclude yang sudah ada
    .map(...)
    .toList(),
```

---

## Full Cycle Test Results

### Layer 1: Database Schema
| Checklist | Status |
|-----------|--------|
| `bom_items_table.dart` — kolom lengkap (id, productId, materialProductId, quantity, unit, sortOrder, createdAt) | ✅ PASS |
| `products_table.dart` — kolom `hasBom` dengan default `false` | ✅ PASS |
| `app_database.dart` — BomItems terdaftar di `@DriftDatabase(tables: [...])` | ✅ PASS |
| `app_database.dart` — BomDao terdaftar di `@DriftDatabase(daos: [...])` | ✅ PASS |
| Migration v14 — `createTable(bomItems)` + `addColumn(products.hasBom)` | ✅ PASS |
| Schema version = 14 | ✅ PASS |
| Web-compatible: tidak ada `sqlite3/sqlite3.dart` import | ✅ PASS |

### Layer 2: DAO
| Checklist | Status |
|-----------|--------|
| `bom_dao.dart` — `getItemsByProduct()` dengan ORDER BY sortOrder | ✅ PASS |
| `bom_dao.dart` — `watchItemsByProduct()` reactive stream | ✅ PASS |
| `bom_dao.dart` — `insertItem()`, `updateItem()`, `deleteItem()` | ✅ PASS |
| `bom_dao.dart` — `deleteItemsByProduct()` untuk cleanup | ✅ PASS |

### Layer 3: Service
| Checklist | Status |
|-----------|--------|
| `bom_service.dart` — UUID generation untuk ID | ✅ PASS |
| `bom_service.dart` — `addItem()` parameter lengkap | ✅ PASS |
| `bom_service.dart` — `updateItem()` tanpa generate UUID baru | ✅ PASS |
| `bom_service.dart` — `getBomConfig()` resolve product info | ✅ PASS |
| `bom_service.dart` — `deleteBomConfig()` cascade delete items | ✅ PASS |
| `bom_service.dart` — `setProductHasBom()` data loss | ✅ FIXED (BUG-BOM-001) |

### Layer 4: Provider
| Checklist | Status |
|-----------|--------|
| `bomServiceProvider` terdaftar di `core_providers.dart` | ✅ PASS |
| `bomItemsProvider` — StreamProvider.family | ✅ PASS |
| `bomConfigProvider` — FutureProvider.family | ✅ PASS |
| Invalidate `bomConfigProvider` setelah add/edit/delete | ✅ PASS |

### Layer 5: UI / Screen
| Checklist | Status |
|-----------|--------|
| Route `/settings/products/:id/bom` terdaftar di router | ✅ PASS |
| `BomConfigScreen` accessible dari `product_form_screen.dart` | ✅ PASS |
| "Atur Resep BOM" button hanya tampil jika `isEditing=true` | ✅ PASS |
| Hint "Simpan produk dulu..." untuk produk baru | ✅ PASS |
| Empty state (belum ada bahan baku) | ✅ PASS |
| Total cost calculation (`costPrice × quantity`) | ✅ PASS |
| Add dialog — self-exclude dari dropdown | ✅ PASS |
| Add dialog — duplicate material check | ✅ FIXED (BUG-BOM-004) |
| Edit dialog — preserve materialProductId | ✅ PASS |
| Delete confirmation dialog | ✅ PASS |
| Unit dropdown (pcs, gram, kg, ml, liter) | ✅ PASS |
| `_formatQty()` — integer display (1.0 → "1") | ✅ PASS |

### Layer 6: Order Flow (BOM Integration)
| Checklist | Status |
|-----------|--------|
| `order_service.dart` — cek `product.hasBom` sebelum deduct | ✅ PASS |
| `order_service.dart` — BOM deduct: `bom.quantity × item.quantity` | ✅ PASS |
| `order_service.dart` — empty BOM fallback ke product sendiri | ✅ FIXED (BUG-BOM-002) |
| Dalam `db.transaction()` — BOM deduct atomic | ✅ PASS |
| Return: cek `product.hasBom` sebelum restock | ✅ PASS |
| Return: BOM restock: `bom.quantity × item.quantity` | ✅ PASS |
| Return: empty BOM fallback ke product sendiri | ✅ FIXED (BUG-BOM-002) |
| Return: wrapped dalam `db.transaction()` | ✅ FIXED (BUG-BOM-003) |

---

## Catatan Arsitektur

### Flow yang Benar (Setelah Fix)

```
User Toggle BOM (product_form_screen.dart)
  └─ _hasBom = true
  └─ Save → ProductService.updateProduct(hasBom: true) [ALL fields preserved]

User Konfigurasi Resep (bom_config_screen.dart)
  └─ Tambah bahan baku → BomService.addItem(productId, materialId, qty, unit)
  └─ Duplicate check → material yang sudah ada tidak muncul di dropdown

Penjualan (order_service.dart - dalam transaction)
  └─ product.hasBom == true
     └─ bomItems.isNotEmpty → deduct tiap bahan baku (qty × sold_qty)
     └─ bomItems.isEmpty   → fallback: deduct product sendiri [BUG-BOM-002 FIX]
  └─ product.hasBom == false → deduct product sendiri

Return (orders_screen.dart - dalam transaction [BUG-BOM-003 FIX])
  └─ product.hasBom == true
     └─ bomItems.isNotEmpty → restock tiap bahan baku
     └─ bomItems.isEmpty   → fallback: restock product sendiri
  └─ product.hasBom == false → restock product sendiri
```

### Potensi Improvement (Bukan Bug, Suggestion)
- **Circular BOM**: Tidak ada proteksi jika A → B → A (rare tapi possible)
- **userId di decrementStock**: BOM deduction tidak menyertakan `cashierId` ke inventory movement (tracking kurang detail)
- **`allProductsProvider` loading**: Dialog "tambah bahan baku" menampilkan error jika provider belum load saat FAB pertama ditekan

---

## Files yang Diubah

| File | Perubahan |
|------|-----------|
| `lib/services/bom_service.dart` | Fix data loss di `setProductHasBom()` — preserve all product fields |
| `lib/services/order_service.dart` | Fix empty BOM silent skip — tambah fallback ke product sendiri |
| `lib/screens/orders/orders_screen.dart` | Fix return: wrap transaction + empty BOM fallback |
| `lib/screens/master/bom_config_screen.dart` | Fix duplicate material — filter existing IDs dari dropdown |
