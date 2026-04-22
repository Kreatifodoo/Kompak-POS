// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';
import '../utils/pin_hash.dart';

/// Comprehensive demo seeder for multi-branch / multi-terminal testing.
///
/// Creates:
///   • 3 stores (1 HQ + 2 branches)
///   • 6 terminals (1 HQ, 2 per branch)
///   • 8 users (owner, admin, 3 cashiers per branch)
///   • Full product catalog per store (15 items incl. 2 combos, BOM/resep)
///   • Pricelist with tier pricing
///   • 5 promotion programs (all types / reward types)
///   • 3 charge types (pajak, layanan, potongan)
///   • 5 customers per store
///   • ~19 demo transactions across branches & terminals
///
/// PIN summary printed on completion.
class DemoSeeder {
  static const _uuid = Uuid();

  // ─────────────────────────────────────────────────────────────────────────
  // Entry point
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> seedDemoData(AppDatabase db) async {
    // Guard: don't seed twice
    final existing = await db.storeDao.getAllStores();
    for (final s in existing) {
      if (s.name == 'Warung Kompak HQ') {
        print('[DemoSeeder] Already seeded – skipping.');
        return;
      }
    }

    print('[DemoSeeder] Seeding demo data...');

    // ── 1. Stores ──────────────────────────────────────────────────────────
    final hqId = _uuid.v4();
    await db.storeDao.insertStore(StoresCompanion.insert(
      id: hqId,
      name: 'Warung Kompak HQ',
      address: const Value('Jl. Sudirman No. 1, Jakarta Pusat'),
      phone: const Value('021-55551234'),
      receiptHeader: const Value('Terima kasih telah berkunjung!'),
      receiptFooter: const Value('Follow IG @warungkompak'),
    ));

    final selId = _uuid.v4();
    await db.storeDao.insertStore(StoresCompanion.insert(
      id: selId,
      name: 'Cabang Selatan',
      parentId: Value(hqId),
      address: const Value('Jl. Fatmawati No. 22, Jakarta Selatan'),
      phone: const Value('021-55552222'),
      receiptHeader: const Value('Selamat menikmati!'),
    ));

    final timId = _uuid.v4();
    await db.storeDao.insertStore(StoresCompanion.insert(
      id: timId,
      name: 'Cabang Timur',
      parentId: Value(hqId),
      address: const Value('Jl. Bekasi Raya No. 88, Jakarta Timur'),
      phone: const Value('021-55553333'),
      receiptHeader: const Value('Selamat menikmati!'),
    ));

    // ── 2. Terminals ──────────────────────────────────────────────────────
    final tHQ = _uuid.v4();
    await db.terminalDao.insertTerminal(TerminalsCompanion.insert(
      id: tHQ, storeId: hqId, name: 'Kasir HQ', code: 'HQ',
    ));

    final tS1 = _uuid.v4();
    await db.terminalDao.insertTerminal(TerminalsCompanion.insert(
      id: tS1, storeId: selId, name: 'Kasir Selatan 1', code: 'S1',
    ));

    final tS2 = _uuid.v4();
    await db.terminalDao.insertTerminal(TerminalsCompanion.insert(
      id: tS2, storeId: selId, name: 'Kasir Selatan 2', code: 'S2',
    ));

    final tT1 = _uuid.v4();
    await db.terminalDao.insertTerminal(TerminalsCompanion.insert(
      id: tT1, storeId: timId, name: 'Kasir Timur 1', code: 'T1',
    ));

    final tT2 = _uuid.v4();
    await db.terminalDao.insertTerminal(TerminalsCompanion.insert(
      id: tT2, storeId: timId, name: 'Kasir Timur 2', code: 'T2',
    ));

    // ── 3. Users ──────────────────────────────────────────────────────────
    // HQ
    await _user(db, name: 'Owner Kompak', pin: '9999', role: 'owner',
        storeId: hqId, terminalId: tHQ);
    await _user(db, name: 'Admin HQ', pin: '1111', role: 'admin',
        storeId: hqId, terminalId: tHQ);
    // Branch Selatan
    await _user(db, name: 'Budi Santoso', pin: '2222', role: 'cashier',
        storeId: selId, terminalId: tS1);
    await _user(db, name: 'Sari Indah', pin: '3333', role: 'cashier',
        storeId: selId, terminalId: tS2);
    // Branch Timur
    await _user(db, name: 'Andi Wijaya', pin: '4444', role: 'cashier',
        storeId: timId, terminalId: tT1);
    await _user(db, name: 'Dewi Lestari', pin: '5555', role: 'cashier',
        storeId: timId, terminalId: tT2);

    // ── 4. Payment methods (per store) ────────────────────────────────────
    for (final sid in [hqId, selId, timId]) {
      await _seedPaymentMethods(db, sid);
    }

    // ── 5. Products & inventory (per store) ───────────────────────────────
    final hqProds = await _seedProducts(db, hqId);
    final selProds = await _seedProducts(db, selId);
    final timProds = await _seedProducts(db, timId);

    // ── 6. Pricelist (per store) ──────────────────────────────────────────
    for (final e in [(hqId, hqProds), (selId, selProds), (timId, timProds)]) {
      await _seedPricelist(db, e.$1, e.$2);
    }

    // ── 7. Promotions (per store) ─────────────────────────────────────────
    final hqPromos = await _seedPromotions(db, hqId);
    final selPromos = await _seedPromotions(db, selId);
    final timPromos = await _seedPromotions(db, timId);

    // ── 8. Charges (per store) ────────────────────────────────────────────
    final hqCharges = await _seedCharges(db, hqId);
    final selCharges = await _seedCharges(db, selId);
    final timCharges = await _seedCharges(db, timId);

    // ── 9. Customers (per store) ──────────────────────────────────────────
    final hqCustomers = await _seedCustomers(db, hqId);
    final selCustomers = await _seedCustomers(db, selId);
    final timCustomers = await _seedCustomers(db, timId);

    // ── 10. Sessions & Transactions ───────────────────────────────────────
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yday = today.subtract(const Duration(days: 1));
    final dby = today.subtract(const Duration(days: 2));

    // ▸ HQ – 1 closed session (yesterday) + 1 open session (today)
    final sesHQYday = await _openSession(db,
        storeId: hqId, terminalId: tHQ, cashierId: await _getCashierId(db, tHQ),
        openingCash: 500000, openedAt: yday.add(const Duration(hours: 8)));
    await _seedOrders(db, sesHQYday, hqId, tHQ, await _getCashierId(db, tHQ),
        hqProds, hqPromos, hqCharges, hqCustomers, yday, 'HQ');
    await _closeSession(db, sesHQYday, yday.add(const Duration(hours: 21)));

    final sesHQToday = await _openSession(db,
        storeId: hqId, terminalId: tHQ, cashierId: await _getCashierId(db, tHQ),
        openingCash: 500000, openedAt: today.add(const Duration(hours: 8)));
    await _seedOrdersToday(db, sesHQToday, hqId, tHQ, await _getCashierId(db, tHQ),
        hqProds, hqPromos, hqCharges, hqCustomers, today, 'HQ');

    // ▸ Cabang Selatan T-S1 – closed (dby + yday) + open today
    final sesS1Dby = await _openSession(db,
        storeId: selId, terminalId: tS1, cashierId: await _getCashierId(db, tS1),
        openingCash: 300000, openedAt: dby.add(const Duration(hours: 9)));
    await _seedOrders(db, sesS1Dby, selId, tS1, await _getCashierId(db, tS1),
        selProds, selPromos, selCharges, selCustomers, dby, 'S1');
    await _closeSession(db, sesS1Dby, dby.add(const Duration(hours: 20)));

    final sesS1Yday = await _openSession(db,
        storeId: selId, terminalId: tS1, cashierId: await _getCashierId(db, tS1),
        openingCash: 300000, openedAt: yday.add(const Duration(hours: 9)));
    await _seedOrders(db, sesS1Yday, selId, tS1, await _getCashierId(db, tS1),
        selProds, selPromos, selCharges, selCustomers, yday, 'S1');
    await _closeSession(db, sesS1Yday, yday.add(const Duration(hours: 21, minutes: 30)));

    final sesS1Today = await _openSession(db,
        storeId: selId, terminalId: tS1, cashierId: await _getCashierId(db, tS1),
        openingCash: 300000, openedAt: today.add(const Duration(hours: 9)));
    await _seedOrdersToday(db, sesS1Today, selId, tS1, await _getCashierId(db, tS1),
        selProds, selPromos, selCharges, selCustomers, today, 'S1');

    // ▸ Cabang Selatan T-S2 – closed yesterday + open today
    final sesS2Yday = await _openSession(db,
        storeId: selId, terminalId: tS2, cashierId: await _getCashierId(db, tS2),
        openingCash: 200000, openedAt: yday.add(const Duration(hours: 10)));
    await _seedOrders(db, sesS2Yday, selId, tS2, await _getCashierId(db, tS2),
        selProds, selPromos, selCharges, selCustomers, yday, 'S2');
    await _closeSession(db, sesS2Yday, yday.add(const Duration(hours: 22)));

    final sesS2Today = await _openSession(db,
        storeId: selId, terminalId: tS2, cashierId: await _getCashierId(db, tS2),
        openingCash: 200000, openedAt: today.add(const Duration(hours: 10)));
    await _seedOrdersToday(db, sesS2Today, selId, tS2, await _getCashierId(db, tS2),
        selProds, selPromos, selCharges, selCustomers, today, 'S2');

    // ▸ Cabang Timur T-T1 – closed (dby + yday) + open today
    final sesT1Dby = await _openSession(db,
        storeId: timId, terminalId: tT1, cashierId: await _getCashierId(db, tT1),
        openingCash: 300000, openedAt: dby.add(const Duration(hours: 8, minutes: 30)));
    await _seedOrders(db, sesT1Dby, timId, tT1, await _getCashierId(db, tT1),
        timProds, timPromos, timCharges, timCustomers, dby, 'T1');
    await _closeSession(db, sesT1Dby, dby.add(const Duration(hours: 21)));

    final sesT1Yday = await _openSession(db,
        storeId: timId, terminalId: tT1, cashierId: await _getCashierId(db, tT1),
        openingCash: 300000, openedAt: yday.add(const Duration(hours: 8, minutes: 30)));
    await _seedOrders(db, sesT1Yday, timId, tT1, await _getCashierId(db, tT1),
        timProds, timPromos, timCharges, timCustomers, yday, 'T1');
    await _closeSession(db, sesT1Yday, yday.add(const Duration(hours: 21)));

    final sesT1Today = await _openSession(db,
        storeId: timId, terminalId: tT1, cashierId: await _getCashierId(db, tT1),
        openingCash: 300000, openedAt: today.add(const Duration(hours: 8, minutes: 30)));
    await _seedOrdersToday(db, sesT1Today, timId, tT1, await _getCashierId(db, tT1),
        timProds, timPromos, timCharges, timCustomers, today, 'T1');

    // ▸ Cabang Timur T-T2 – closed yesterday + open today
    final sesT2Yday = await _openSession(db,
        storeId: timId, terminalId: tT2, cashierId: await _getCashierId(db, tT2),
        openingCash: 250000, openedAt: yday.add(const Duration(hours: 11)));
    await _seedOrders(db, sesT2Yday, timId, tT2, await _getCashierId(db, tT2),
        timProds, timPromos, timCharges, timCustomers, yday, 'T2');
    await _closeSession(db, sesT2Yday, yday.add(const Duration(hours: 22, minutes: 30)));

    final sesT2Today = await _openSession(db,
        storeId: timId, terminalId: tT2, cashierId: await _getCashierId(db, tT2),
        openingCash: 250000, openedAt: today.add(const Duration(hours: 11)));
    await _seedOrdersToday(db, sesT2Today, timId, tT2, await _getCashierId(db, tT2),
        timProds, timPromos, timCharges, timCustomers, today, 'T2');

    print('[DemoSeeder] ✓ Done! Login dengan PIN berikut:');
    print('  9999 → Owner Kompak (HQ)');
    print('  1111 → Admin HQ');
    print('  2222 → Budi / Kasir Selatan 1');
    print('  3333 → Sari / Kasir Selatan 2');
    print('  4444 → Andi / Kasir Timur 1');
    print('  5555 → Dewi / Kasir Timur 2');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers: user, payment methods, customers
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String> _user(AppDatabase db, {
    required String name,
    required String pin,
    required String role,
    required String storeId,
    required String terminalId,
  }) async {
    final id = _uuid.v4();
    await db.userDao.insertUser(UsersCompanion.insert(
      id: id, name: name, pin: PinHash.hash(pin),
      role: Value(role), storeId: Value(storeId), terminalId: Value(terminalId),
    ));
    return id;
  }

  static Future<String> _getCashierId(AppDatabase db, String terminalId) async {
    final result = await (db.select(db.users)
      ..where((u) => u.terminalId.equals(terminalId))).get();
    return result.first.id;
  }

  static Future<void> _seedPaymentMethods(AppDatabase db, String storeId) async {
    for (final (name, type, order) in [
      ('Cash', 'cash', 1), ('QRIS', 'qris', 2),
      ('Transfer Bank', 'transfer', 3), ('Kartu Debit/Kredit', 'card', 4),
    ]) {
      await db.paymentMethodDao.insertPaymentMethod(
        PaymentMethodsCompanion.insert(
          id: _uuid.v4(), storeId: storeId, name: name, type: type,
          sortOrder: Value(order),
        ),
      );
    }
  }

  static Future<List<String>> _seedCustomers(AppDatabase db, String storeId) async {
    final ids = <String>[];
    for (final (name, phone, points) in [
      ('Budi Santoso', '0812-1111-2222', 150),
      ('Siti Rahayu', '0813-3333-4444', 80),
      ('Ahmad Fauzi', '0814-5555-6666', 230),
      ('Dewi Kusuma', '0815-7777-8888', 45),
      ('Rizky Pratama', '0816-9999-0000', 320),
    ]) {
      final id = _uuid.v4();
      ids.add(id);
      await db.customerDao.insertCustomer(CustomersCompanion.insert(
        id: id, storeId: storeId, name: name,
        phone: Value(phone), points: Value(points),
      ));
    }
    return ids;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Products & inventory
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _seedProducts(
    AppDatabase db, String storeId,
  ) async {
    final pids = <String, String>{};

    // Categories
    final cats = <String, String>{};
    for (final (name, icon, order) in [
      ('Makanan Berat', 'restaurant', 1),
      ('Minuman', 'local_cafe', 2),
      ('Snack & Gorengan', 'cookie', 3),
      ('Dessert', 'icecream', 4),
      ('Bahan Baku', 'inventory_2', 5),
    ]) {
      final id = _uuid.v4();
      cats[name] = id;
      await db.categoryDao.insertCategory(CategoriesCompanion.insert(
        id: id, storeId: storeId, name: name,
        iconName: Value(icon), sortOrder: Value(order),
      ));
    }

    // Regular products
    final specs = [
      // (name, desc, price, costPrice, cat, sku, hasBom)
      ('Nasi Goreng Spesial', 'Nasi goreng dengan telur & ayam', 28000.0, 10000.0, 'Makanan Berat', 'NGS-001', true),
      ('Mie Ayam Bakso', 'Mie ayam dengan bakso sapi', 25000.0, 9000.0, 'Makanan Berat', 'MAB-001', false),
      ('Ayam Penyet', 'Ayam goreng tepung sambal korek', 35000.0, 13000.0, 'Makanan Berat', 'APY-001', false),
      ('Soto Ayam', 'Soto ayam bening rempah pilihan', 30000.0, 11000.0, 'Makanan Berat', 'SAY-001', false),
      ('Gado-Gado', 'Sayuran segar + bumbu kacang spesial', 27000.0, 9000.0, 'Makanan Berat', 'GGD-001', false),
      ('Es Teh Manis', 'Teh celup gula asli', 8000.0, 2000.0, 'Minuman', 'ETM-001', false),
      ('Kopi Susu Kekinian', 'Kopi robusta + susu segar', 18000.0, 5000.0, 'Minuman', 'KSK-001', false),
      ('Jus Alpukat', 'Alpukat segar + susu kental', 22000.0, 7000.0, 'Minuman', 'JAL-001', false),
      ('Es Jeruk Peras', 'Jeruk lokal segar diperas', 15000.0, 4000.0, 'Minuman', 'EJP-001', false),
      ('Air Mineral', 'Aqua 600ml', 5000.0, 2000.0, 'Minuman', 'AMN-001', false),
      ('Pisang Goreng (5pcs)', 'Pisang kepok goreng tepung renyah', 12000.0, 4000.0, 'Snack & Gorengan', 'PGR-001', true),
      ('Bakwan Sayur (3pcs)', 'Bakwan sayur gurih renyah', 10000.0, 3000.0, 'Snack & Gorengan', 'BSY-001', false),
      ('Cireng Isi (6pcs)', 'Cireng isi daging ayam + sambal', 10000.0, 3500.0, 'Snack & Gorengan', 'CRG-001', false),
      ('Es Campur Spesial', 'Serutan es + kolang-kaling + cincau', 18000.0, 6000.0, 'Dessert', 'ECS-001', false),
      ('Pudding Coklat', 'Pudding susu coklat premium', 15000.0, 5000.0, 'Dessert', 'PDC-001', false),
    ];

    for (final (name, desc, price, cost, cat, sku, hasBom) in specs) {
      final id = _uuid.v4();
      pids[name] = id;
      await db.productDao.insertProduct(ProductsCompanion.insert(
        id: id, storeId: storeId, categoryId: cats[cat]!,
        name: name, description: Value(desc),
        price: price, costPrice: Value(cost),
        sku: Value(sku), hasBom: Value(hasBom),
      ));
      await db.inventoryDao.insertInventory(InventoryCompanion.insert(
        id: _uuid.v4(), productId: id, storeId: storeId,
        quantity: const Value(200), lowStockThreshold: const Value(20),
      ));
    }

    // Raw materials (for BOM)
    for (final (name, price, sku) in [
      ('Beras Premium', 12000.0, 'BRS-001'),
      ('Tepung Terigu', 5000.0, 'TPG-001'),
      ('Minyak Goreng', 15000.0, 'MYG-001'),
      ('Bumbu Rempah', 8000.0, 'BRP-001'),
      ('Pisang Kepok', 3000.0, 'PSK-001'),
    ]) {
      final id = _uuid.v4();
      pids[name] = id;
      await db.productDao.insertProduct(ProductsCompanion.insert(
        id: id, storeId: storeId, categoryId: cats['Bahan Baku']!,
        name: name, price: price, sku: Value(sku),
        isActive: const Value(false), // raw materials not sold directly
      ));
      await db.inventoryDao.insertInventory(InventoryCompanion.insert(
        id: _uuid.v4(), productId: id, storeId: storeId,
        quantity: const Value(500), lowStockThreshold: const Value(50),
      ));
    }

    // BOM: Nasi Goreng Spesial
    final ngsId = pids['Nasi Goreng Spesial']!;
    for (final (matName, qty, unit) in [
      ('Beras Premium', 0.15, 'kg'),
      ('Minyak Goreng', 0.02, 'liter'),
      ('Bumbu Rempah', 1.0, 'pcs'),
    ]) {
      await db.bomDao.insertItem(BomItemsCompanion.insert(
        id: _uuid.v4(), productId: ngsId,
        materialProductId: pids[matName]!,
        quantity: qty, unit: Value(unit),
      ));
    }

    // BOM: Pisang Goreng
    final pgrId = pids['Pisang Goreng (5pcs)']!;
    for (final (matName, qty, unit) in [
      ('Tepung Terigu', 0.1, 'kg'),
      ('Minyak Goreng', 0.05, 'liter'),
      ('Pisang Kepok', 5.0, 'pcs'),
    ]) {
      await db.bomDao.insertItem(BomItemsCompanion.insert(
        id: _uuid.v4(), productId: pgrId,
        materialProductId: pids[matName]!,
        quantity: qty, unit: Value(unit),
      ));
    }

    // Combo 1: Paket Makan Siang (55,000)
    final combo1Id = _uuid.v4();
    pids['Paket Makan Siang'] = combo1Id;
    await db.productDao.insertProduct(ProductsCompanion.insert(
      id: combo1Id, storeId: storeId, categoryId: cats['Makanan Berat']!,
      name: 'Paket Makan Siang',
      description: const Value('1 Makanan + 1 Minuman + 1 Snack'),
      price: 55000, costPrice: const Value(20000),
      sku: const Value('PKT-SIANG-001'), isCombo: const Value(true),
    ));
    await db.inventoryDao.insertInventory(InventoryCompanion.insert(
      id: _uuid.v4(), productId: combo1Id, storeId: storeId,
      quantity: const Value(999), lowStockThreshold: const Value(5),
    ));

    // Combo 1 groups
    final cg1Food = _uuid.v4();
    await db.comboDao.insertGroup(ComboGroupsCompanion.insert(
      id: cg1Food, productId: combo1Id, name: 'Pilih Makanan',
      minSelect: const Value(1), maxSelect: const Value(1), sortOrder: const Value(1),
    ));
    for (final (pName, extra) in [
      ('Nasi Goreng Spesial', 5000.0), ('Mie Ayam Bakso', 0.0),
      ('Ayam Penyet', 10000.0), ('Soto Ayam', 3000.0),
    ]) {
      if (pids[pName] != null) {
        await db.comboDao.insertItem(ComboGroupItemsCompanion.insert(
          id: _uuid.v4(), comboGroupId: cg1Food, productId: pids[pName]!,
          extraPrice: Value(extra),
        ));
      }
    }

    final cg1Drink = _uuid.v4();
    await db.comboDao.insertGroup(ComboGroupsCompanion.insert(
      id: cg1Drink, productId: combo1Id, name: 'Pilih Minuman',
      minSelect: const Value(1), maxSelect: const Value(1), sortOrder: const Value(2),
    ));
    for (final (pName, extra) in [
      ('Es Teh Manis', 0.0), ('Kopi Susu Kekinian', 5000.0),
      ('Jus Alpukat', 8000.0), ('Es Jeruk Peras', 3000.0),
    ]) {
      if (pids[pName] != null) {
        await db.comboDao.insertItem(ComboGroupItemsCompanion.insert(
          id: _uuid.v4(), comboGroupId: cg1Drink, productId: pids[pName]!,
          extraPrice: Value(extra),
        ));
      }
    }

    final cg1Snack = _uuid.v4();
    await db.comboDao.insertGroup(ComboGroupsCompanion.insert(
      id: cg1Snack, productId: combo1Id, name: 'Pilih Snack',
      minSelect: const Value(1), maxSelect: const Value(1), sortOrder: const Value(3),
    ));
    for (final pName in ['Pisang Goreng (5pcs)', 'Bakwan Sayur (3pcs)', 'Cireng Isi (6pcs)']) {
      if (pids[pName] != null) {
        await db.comboDao.insertItem(ComboGroupItemsCompanion.insert(
          id: _uuid.v4(), comboGroupId: cg1Snack, productId: pids[pName]!,
          extraPrice: const Value(0.0),
        ));
      }
    }

    // Combo 2: Paket Berdua (80,000)
    final combo2Id = _uuid.v4();
    pids['Paket Berdua'] = combo2Id;
    await db.productDao.insertProduct(ProductsCompanion.insert(
      id: combo2Id, storeId: storeId, categoryId: cats['Makanan Berat']!,
      name: 'Paket Berdua Hemat',
      description: const Value('2 Makanan pilihan + 2 Minuman pilihan'),
      price: 80000, costPrice: const Value(30000),
      sku: const Value('PKT-DUA-001'), isCombo: const Value(true),
    ));
    await db.inventoryDao.insertInventory(InventoryCompanion.insert(
      id: _uuid.v4(), productId: combo2Id, storeId: storeId,
      quantity: const Value(999), lowStockThreshold: const Value(5),
    ));

    final cg2Food = _uuid.v4();
    await db.comboDao.insertGroup(ComboGroupsCompanion.insert(
      id: cg2Food, productId: combo2Id, name: 'Pilih 2 Makanan',
      minSelect: const Value(2), maxSelect: const Value(2), sortOrder: const Value(1),
    ));
    for (final pName in ['Nasi Goreng Spesial', 'Mie Ayam Bakso', 'Soto Ayam', 'Gado-Gado']) {
      if (pids[pName] != null) {
        await db.comboDao.insertItem(ComboGroupItemsCompanion.insert(
          id: _uuid.v4(), comboGroupId: cg2Food, productId: pids[pName]!,
          extraPrice: const Value(0.0),
        ));
      }
    }

    final cg2Drink = _uuid.v4();
    await db.comboDao.insertGroup(ComboGroupsCompanion.insert(
      id: cg2Drink, productId: combo2Id, name: 'Pilih 2 Minuman',
      minSelect: const Value(2), maxSelect: const Value(2), sortOrder: const Value(2),
    ));
    for (final pName in ['Es Teh Manis', 'Air Mineral', 'Kopi Susu Kekinian', 'Es Jeruk Peras']) {
      if (pids[pName] != null) {
        await db.comboDao.insertItem(ComboGroupItemsCompanion.insert(
          id: _uuid.v4(), comboGroupId: cg2Drink, productId: pids[pName]!,
          extraPrice: const Value(0.0),
        ));
      }
    }

    return pids;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pricelist – tier pricing
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _seedPricelist(
    AppDatabase db, String storeId, Map<String, String> pids,
  ) async {
    final plId = _uuid.v4();
    final now = DateTime.now();
    await db.pricelistDao.insertPricelist(PricelistsCompanion.insert(
      id: plId, storeId: storeId,
      name: 'Promo Member Loyal',
      startDate: now.subtract(const Duration(days: 7)),
      endDate: now.add(const Duration(days: 90)),
    ));

    // Nasi Goreng: qty 1-4 → 25k, qty 5+ → 22k
    if (pids['Nasi Goreng Spesial'] != null) {
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(), pricelistId: plId, productId: pids['Nasi Goreng Spesial']!,
        minQty: const Value(1), maxQty: const Value(4), price: 25000,
      ));
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(), pricelistId: plId, productId: pids['Nasi Goreng Spesial']!,
        minQty: const Value(5), maxQty: const Value(0), price: 22000,
      ));
    }

    // Kopi Susu Kekinian: qty 1+ → 15k
    if (pids['Kopi Susu Kekinian'] != null) {
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(), pricelistId: plId, productId: pids['Kopi Susu Kekinian']!,
        minQty: const Value(1), maxQty: const Value(0), price: 15000,
      ));
    }

    // Ayam Penyet: qty 1-2 → 32k, qty 3+ → 28k
    if (pids['Ayam Penyet'] != null) {
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(), pricelistId: plId, productId: pids['Ayam Penyet']!,
        minQty: const Value(1), maxQty: const Value(2), price: 32000,
      ));
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(), pricelistId: plId, productId: pids['Ayam Penyet']!,
        minQty: const Value(3), maxQty: const Value(0), price: 28000,
      ));
    }

    // Es Teh Manis: qty 3+ → 6k (bulk discount)
    if (pids['Es Teh Manis'] != null) {
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(), pricelistId: plId, productId: pids['Es Teh Manis']!,
        minQty: const Value(3), maxQty: const Value(0), price: 6000,
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Promotions – all 5 types/combos
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns map: promoName → promoId
  static Future<Map<String, String>> _seedPromotions(
    AppDatabase db, String storeId,
  ) async {
    final ids = <String, String>{};
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));

    // 1. OTOMATIS + DISKON_PERSENTASE: Happy Hour 15%
    final p1 = _uuid.v4();
    ids['happy_hour'] = p1;
    await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
      id: p1, storeId: storeId,
      namaPromo: 'Happy Hour 15%',
      deskripsi: const Value('Diskon otomatis 15% untuk transaksi min. Rp 50.000'),
      tipeProgram: 'OTOMATIS',
      tipeReward: 'DISKON_PERSENTASE',
      nilaiReward: 15,
      minSubtotal: const Value(50000),
      startDate: start,
      daysOfWeek: const Value('[1,2,3,4,5]'), // Mon-Fri
      priority: const Value(10),
    ));

    // 2. OTOMATIS + DISKON_NOMINAL: Promo Berdua
    final p2 = _uuid.v4();
    ids['berdua'] = p2;
    await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
      id: p2, storeId: storeId,
      namaPromo: 'Promo Berdua Hemat',
      deskripsi: const Value('Potongan Rp 20.000 untuk belanja min. Rp 100.000'),
      tipeProgram: 'OTOMATIS',
      tipeReward: 'DISKON_NOMINAL',
      nilaiReward: 20000,
      minSubtotal: const Value(100000),
      startDate: start,
      priority: const Value(5),
    ));

    // 3. KODE_DISKON + DISKON_PERSENTASE: VIP30 (30% off, max 75rb)
    final p3 = _uuid.v4();
    ids['vip30'] = p3;
    await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
      id: p3, storeId: storeId,
      namaPromo: 'Kode VIP30',
      deskripsi: const Value('Masukkan kode VIP30 untuk diskon 30% (maks. Rp 75.000)'),
      tipeProgram: 'KODE_DISKON',
      kodeDiskon: const Value('VIP30'),
      tipeReward: 'DISKON_PERSENTASE',
      nilaiReward: 30,
      maxDiskon: const Value(75000),
      minSubtotal: const Value(80000),
      startDate: start,
      endDate: Value(now.add(const Duration(days: 90))),
      priority: const Value(8),
    ));

    // 4. KODE_DISKON + DISKON_NOMINAL: FLAT25K
    final p4 = _uuid.v4();
    ids['flat25k'] = p4;
    await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
      id: p4, storeId: storeId,
      namaPromo: 'Kode FLAT25K',
      deskripsi: const Value('Masukkan kode FLAT25K untuk potongan Rp 25.000'),
      tipeProgram: 'KODE_DISKON',
      kodeDiskon: const Value('FLAT25K'),
      tipeReward: 'DISKON_NOMINAL',
      nilaiReward: 25000,
      minSubtotal: const Value(150000),
      startDate: start,
      priority: const Value(6),
    ));

    // 5. BELI_X_GRATIS_Y: Beli 3 Gratis 1 Termurah
    final p5 = _uuid.v4();
    ids['buy3get1'] = p5;
    await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
      id: p5, storeId: storeId,
      namaPromo: 'Beli 3 Gratis 1 Termurah',
      deskripsi: const Value('Beli 3 item atau lebih, gratis 1 item termurah'),
      tipeProgram: 'BELI_X_GRATIS_Y',
      tipeReward: 'DISKON_PERSENTASE',
      nilaiReward: 100,
      applyTo: const Value('CHEAPEST'),
      minQty: const Value(3),
      startDate: start,
      priority: const Value(3),
    ));

    return ids;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Charges – all 3 kategori (all active for demo)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns list of charge records as maps (id, name, kategori, tipe, nilai, includeBase)
  static Future<List<Map<String, dynamic>>> _seedCharges(
    AppDatabase db, String storeId,
  ) async {
    final result = <Map<String, dynamic>>[];

    // PPN 11%
    final ppnId = _uuid.v4();
    await db.chargeDao.insertCharge(ChargesCompanion.insert(
      id: ppnId, storeId: storeId,
      namaBiaya: 'PPN 11%', kategori: 'PAJAK',
      tipe: 'PERSENTASE', nilai: 11,
      urutan: const Value(1), includeBase: const Value('SUBTOTAL'),
    ));
    result.add({'id': ppnId, 'name': 'PPN 11%', 'kategori': 'PAJAK',
      'tipe': 'PERSENTASE', 'nilai': 11.0, 'includeBase': 'SUBTOTAL'});

    // Service Charge 5%
    final scId = _uuid.v4();
    await db.chargeDao.insertCharge(ChargesCompanion.insert(
      id: scId, storeId: storeId,
      namaBiaya: 'Service Charge 5%', kategori: 'LAYANAN',
      tipe: 'PERSENTASE', nilai: 5,
      urutan: const Value(2), includeBase: const Value('SUBTOTAL'),
    ));
    result.add({'id': scId, 'name': 'Service Charge 5%', 'kategori': 'LAYANAN',
      'tipe': 'PERSENTASE', 'nilai': 5.0, 'includeBase': 'SUBTOTAL'});

    // Potongan Member Loyal Rp 5.000
    final potId = _uuid.v4();
    await db.chargeDao.insertCharge(ChargesCompanion.insert(
      id: potId, storeId: storeId,
      namaBiaya: 'Potongan Loyal Member', kategori: 'POTONGAN',
      tipe: 'NOMINAL', nilai: 5000,
      urutan: const Value(3), includeBase: const Value('AFTER_PREVIOUS'),
    ));
    result.add({'id': potId, 'name': 'Potongan Loyal Member', 'kategori': 'POTONGAN',
      'tipe': 'NOMINAL', 'nilai': 5000.0, 'includeBase': 'AFTER_PREVIOUS'});

    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sessions
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String> _openSession(AppDatabase db, {
    required String storeId,
    required String terminalId,
    required String cashierId,
    required double openingCash,
    required DateTime openedAt,
  }) async {
    final id = _uuid.v4();
    await db.posSessionDao.insertSession(PosSessionsCompanion.insert(
      id: id, storeId: storeId, cashierId: cashierId,
      terminalId: terminalId, openingCash: openingCash,
      openedAt: Value(openedAt),
    ));
    return id;
  }

  static Future<void> _closeSession(AppDatabase db, String sessionId, DateTime closedAt) async {
    await (db.update(db.posSessions)..where((s) => s.id.equals(sessionId))).write(
      PosSessionsCompanion(
        status: const Value('closed'),
        closedAt: Value(closedAt),
        closingCash: const Value(750000),
        expectedCash: const Value(700000),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Order factory
  // ─────────────────────────────────────────────────────────────────────────

  /// Build chargesJson string for an order given subtotal
  static String _chargesJson(
    List<Map<String, dynamic>> charges, double subtotal,
  ) {
    final applied = <Map<String, dynamic>>[];
    for (final c in charges) {
      final nilai = c['nilai'] as double;
      double amount;
      if (c['tipe'] == 'PERSENTASE') {
        amount = subtotal * nilai / 100;
        if (c['kategori'] == 'POTONGAN') amount = -amount;
      } else {
        amount = nilai;
        if (c['kategori'] == 'POTONGAN') amount = -amount;
      }
      applied.add({
        'chargeId': c['id'],
        'namaBiaya': c['name'],
        'kategori': c['kategori'],
        'tipe': c['tipe'],
        'nilai': nilai,
        'includeBase': c['includeBase'],
        'amount': amount,
      });
    }
    return jsonEncode(applied);
  }

  /// Compute total charges amount for subtotal
  static double _chargesTotal(List<Map<String, dynamic>> charges, double subtotal) {
    double total = 0;
    for (final c in charges) {
      final nilai = c['nilai'] as double;
      double amount;
      if (c['tipe'] == 'PERSENTASE') {
        amount = subtotal * nilai / 100;
      } else {
        amount = nilai;
      }
      if (c['kategori'] == 'POTONGAN') {
        total -= amount;
      } else {
        total += amount;
      }
    }
    return total;
  }

  static int _orderSeq = 0;

  static Future<void> _insertOrder({
    required AppDatabase db,
    required String sessionId,
    required String storeId,
    required String terminalId,
    required String cashierId,
    required Map<String, String> pids,
    required List<Map<String, dynamic>> charges,
    required DateTime createdAt,
    required String terminalCode,
    String? customerId,
    String? promoJson,
    double promoDiscount = 0,
    required List<Map<String, dynamic>> items, // {name, price, qty, notes?, extras?}
    required String paymentMethod,
    double? amountTendered,
  }) async {
    _orderSeq++;
    final orderId = _uuid.v4();
    final paymentId = _uuid.v4();

    // Compute subtotal
    double subtotal = 0;
    for (final item in items) {
      subtotal += (item['price'] as double) * (item['qty'] as int);
    }

    final chargesAmount = _chargesTotal(charges, subtotal);
    final total = subtotal + chargesAmount - promoDiscount;

    // Order number: KP-T1-260325-0001
    final d = createdAt;
    final dp = '${d.year.toString().substring(2)}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final orderNumber = 'KP-$terminalCode-$dp-${_orderSeq.toString().padLeft(4, '0')}';

    final cjson = _chargesJson(charges, subtotal);

    await db.orderDao.insertOrder(OrdersCompanion.insert(
      id: orderId, storeId: storeId,
      terminalId: terminalId, cashierId: cashierId,
      customerId: Value(customerId),
      sessionId: Value(sessionId),
      orderNumber: orderNumber,
      status: const Value('completed'),
      subtotal: subtotal,
      discountAmount: Value(promoDiscount),
      taxAmount: Value(subtotal * 0.11),
      chargesJson: Value(cjson),
      promotionsJson: Value(promoJson),
      total: total < 0 ? 0 : total,
      createdAt: Value(createdAt),
      completedAt: Value(createdAt.add(const Duration(minutes: 3))),
    ));

    for (final item in items) {
      final pid = pids[item['name'] as String];
      if (pid == null) continue;
      final price = item['price'] as double;
      final qty = item['qty'] as int;
      final extras = item['extras'] as Map<String, dynamic>?;
      await db.orderDao.insertOrderItem(OrderItemsCompanion.insert(
        id: _uuid.v4(), orderId: orderId,
        productId: pid,
        productName: item['name'] as String,
        productPrice: price,
        quantity: qty,
        extrasJson: Value(extras != null ? jsonEncode(extras) : null),
        subtotal: price * qty,
        originalPrice: Value(item['originalPrice'] as double?),
        notes: Value(item['notes'] as String?),
      ));
    }

    final tendered = amountTendered ?? total;
    final change = tendered - total;
    await db.paymentDao.insertPayment(PaymentsCompanion.insert(
      id: paymentId, orderId: orderId,
      method: paymentMethod,
      amount: tendered,
      changeAmount: Value(change > 0 ? change : 0),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Seed orders for a CLOSED session (past date)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _seedOrders(
    AppDatabase db, String sessionId,
    String storeId, String terminalId, String cashierId,
    Map<String, String> pids,
    Map<String, String> promos,
    List<Map<String, dynamic>> charges,
    List<String> customers,
    DateTime date, String code,
  ) async {
    final promoId = promos['happy_hour']!;

    // Order A: 2x Nasi Goreng + 1x Es Teh — cash, promo Happy Hour
    final subtotalA = 28000.0 * 2 + 8000.0;
    final discA = subtotalA * 0.15;
    await _insertOrder(
      db: db, sessionId: sessionId, storeId: storeId,
      terminalId: terminalId, cashierId: cashierId, pids: pids,
      charges: charges,
      createdAt: date.add(const Duration(hours: 10, minutes: 15)),
      terminalCode: code,
      customerId: customers[0],
      promoJson: jsonEncode([{
        'promotionId': promoId, 'namaPromo': 'Happy Hour 15%',
        'tipeProgram': 'OTOMATIS', 'tipeReward': 'DISKON_PERSENTASE',
        'nilaiReward': 15, 'applyTo': 'ORDER',
        'discountAmount': discA, 'freeProductId': null,
        'freeProductName': null, 'freeProductQty': 0,
      }]),
      promoDiscount: discA,
      items: [
        {'name': 'Nasi Goreng Spesial', 'price': 25000.0, 'qty': 2,
          'originalPrice': 28000.0, 'notes': 'Pedas level 2'},
        {'name': 'Es Teh Manis', 'price': 8000.0, 'qty': 1},
      ],
      paymentMethod: 'cash', amountTendered: 100000,
    );

    // Order B: Paket Makan Siang combo + Pudding — QRIS, no promo, with customer
    await _insertOrder(
      db: db, sessionId: sessionId, storeId: storeId,
      terminalId: terminalId, cashierId: cashierId, pids: pids,
      charges: charges,
      createdAt: date.add(const Duration(hours: 12, minutes: 30)),
      terminalCode: code, customerId: customers[1],
      items: [
        {'name': 'Paket Makan Siang', 'price': 65000.0, 'qty': 1,
          'extras': {
            'isCombo': true,
            'comboSelections': [
              {'groupId': 'g1', 'groupName': 'Pilih Makanan',
                'productId': pids['Ayam Penyet'] ?? '', 'productName': 'Ayam Penyet',
                'extraPrice': 10000},
              {'groupId': 'g2', 'groupName': 'Pilih Minuman',
                'productId': pids['Kopi Susu Kekinian'] ?? '', 'productName': 'Kopi Susu Kekinian',
                'extraPrice': 5000},
              {'groupId': 'g3', 'groupName': 'Pilih Snack',
                'productId': pids['Pisang Goreng (5pcs)'] ?? '', 'productName': 'Pisang Goreng (5pcs)',
                'extraPrice': 0},
            ]
          },
          'notes': 'Ayam tidak terlalu pedas'},
        {'name': 'Pudding Coklat', 'price': 15000.0, 'qty': 2},
      ],
      paymentMethod: 'qris',
    );

    // Order C: Ayam Penyet x3 (pricelist) + Jus Alpukat x2 — card, promo Beli 3 Gratis 1
    final promoB3G1 = promos['buy3get1']!;
    // Cheapest item = Jus Alpukat (22k) → 100% off = 22k
    await _insertOrder(
      db: db, sessionId: sessionId, storeId: storeId,
      terminalId: terminalId, cashierId: cashierId, pids: pids,
      charges: charges,
      createdAt: date.add(const Duration(hours: 14, minutes: 45)),
      terminalCode: code, customerId: customers[2],
      promoJson: jsonEncode([{
        'promotionId': promoB3G1, 'namaPromo': 'Beli 3 Gratis 1 Termurah',
        'tipeProgram': 'BELI_X_GRATIS_Y', 'tipeReward': 'DISKON_PERSENTASE',
        'nilaiReward': 100, 'applyTo': 'CHEAPEST',
        'discountAmount': 22000.0, 'freeProductId': null,
        'freeProductName': null, 'freeProductQty': 0,
      }]),
      promoDiscount: 22000,
      items: [
        {'name': 'Ayam Penyet', 'price': 28000.0, 'qty': 3,
          'originalPrice': 35000.0},
        {'name': 'Jus Alpukat', 'price': 22000.0, 'qty': 2},
        {'name': 'Bakwan Sayur (3pcs)', 'price': 10000.0, 'qty': 1},
      ],
      paymentMethod: 'card',
    );

    // Order D: Paket Berdua + Dessert — transfer, no promo
    await _insertOrder(
      db: db, sessionId: sessionId, storeId: storeId,
      terminalId: terminalId, cashierId: cashierId, pids: pids,
      charges: charges,
      createdAt: date.add(const Duration(hours: 18, minutes: 20)),
      terminalCode: code, customerId: customers[3],
      items: [
        {'name': 'Paket Berdua Hemat', 'price': 80000.0, 'qty': 1,
          'extras': {
            'isCombo': true,
            'comboSelections': [
              {'groupId': 'g1', 'groupName': 'Pilih 2 Makanan',
                'productId': pids['Nasi Goreng Spesial'] ?? '', 'productName': 'Nasi Goreng Spesial', 'extraPrice': 0},
              {'groupId': 'g1', 'groupName': 'Pilih 2 Makanan',
                'productId': pids['Mie Ayam Bakso'] ?? '', 'productName': 'Mie Ayam Bakso', 'extraPrice': 0},
              {'groupId': 'g2', 'groupName': 'Pilih 2 Minuman',
                'productId': pids['Es Teh Manis'] ?? '', 'productName': 'Es Teh Manis', 'extraPrice': 0},
              {'groupId': 'g2', 'groupName': 'Pilih 2 Minuman',
                'productId': pids['Air Mineral'] ?? '', 'productName': 'Air Mineral', 'extraPrice': 0},
            ]
          }},
        {'name': 'Es Campur Spesial', 'price': 18000.0, 'qty': 2,
          'notes': 'Extra cincau'},
      ],
      paymentMethod: 'transfer',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Seed orders for TODAY's open session
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _seedOrdersToday(
    AppDatabase db, String sessionId,
    String storeId, String terminalId, String cashierId,
    Map<String, String> pids,
    Map<String, String> promos,
    List<Map<String, dynamic>> charges,
    List<String> customers,
    DateTime today, String code,
  ) async {
    // Order E: Mie Ayam + Kopi Susu (pricelist) — cash, promo Berdua
    final subtotalE = 25000.0 + 15000.0 * 2; // 55k (Kopi Susu pricelist 15k)
    final promoId2 = promos['berdua']!;
    await _insertOrder(
      db: db, sessionId: sessionId, storeId: storeId,
      terminalId: terminalId, cashierId: cashierId, pids: pids,
      charges: charges,
      createdAt: today.add(const Duration(hours: 9, minutes: 30)),
      terminalCode: code, customerId: customers[4],
      promoJson: jsonEncode([{
        'promotionId': promoId2, 'namaPromo': 'Promo Berdua Hemat',
        'tipeProgram': 'OTOMATIS', 'tipeReward': 'DISKON_NOMINAL',
        'nilaiReward': 20000, 'applyTo': 'ORDER',
        'discountAmount': 20000.0, 'freeProductId': null,
        'freeProductName': null, 'freeProductQty': 0,
      }]),
      promoDiscount: 20000,
      items: [
        {'name': 'Mie Ayam Bakso', 'price': 25000.0, 'qty': 1},
        {'name': 'Kopi Susu Kekinian', 'price': 15000.0, 'qty': 2,
          'originalPrice': 18000.0},
      ],
      paymentMethod: 'cash',
      amountTendered: (subtotalE + _chargesTotal(charges, subtotalE) - 20000).ceilToDouble() + 5000,
    );

    // Order F: Cireng + Bakwan + Es Teh x3 (pricelist bulk) — QRIS, no promo
    await _insertOrder(
      db: db, sessionId: sessionId, storeId: storeId,
      terminalId: terminalId, cashierId: cashierId, pids: pids,
      charges: charges,
      createdAt: today.add(const Duration(hours: 11, minutes: 15)),
      terminalCode: code,
      items: [
        {'name': 'Cireng Isi (6pcs)', 'price': 10000.0, 'qty': 2,
          'notes': 'Extra sambal'},
        {'name': 'Bakwan Sayur (3pcs)', 'price': 10000.0, 'qty': 2},
        {'name': 'Es Teh Manis', 'price': 6000.0, 'qty': 3,
          'originalPrice': 8000.0}, // pricelist bulk
      ],
      paymentMethod: 'qris',
    );
  }
}
