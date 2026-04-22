// ignore_for_file: avoid_print
// SIT: Multi-Branch, Multi-Terminal, Promotion, Pricelist, Charges — Full Cycle
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kompak_pos/core/database/app_database.dart' hide PaymentMethod;
import 'package:kompak_pos/models/cart_item_model.dart';
import 'package:kompak_pos/models/cart_state_model.dart';
import 'package:kompak_pos/models/enums.dart';
import 'package:kompak_pos/services/cart_service.dart';
import 'package:kompak_pos/services/charge_service.dart';
import 'package:kompak_pos/services/order_service.dart';
import 'package:kompak_pos/services/pos_session_service.dart';
import 'package:kompak_pos/services/pricelist_service.dart';
import 'package:kompak_pos/services/promotion_service.dart';
import 'package:kompak_pos/services/store_service.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ── Helpers ──────────────────────────────────────────────────────────────────

AppDatabase _openDb() => AppDatabase(NativeDatabase.memory());

Future<String> _insertStore(AppDatabase db,
    {String? name, String? parentId}) async {
  final id = _uuid.v4();
  await db.storeDao.insertStore(StoresCompanion.insert(
    id: id,
    name: name ?? 'Store ${id.substring(0, 6)}',
    parentId: Value(parentId),
  ));
  return id;
}

Future<String> _insertTerminal(AppDatabase db,
    {required String storeId, String? name, String code = 'T1'}) async {
  final id = _uuid.v4();
  await db.terminalDao.insertTerminal(TerminalsCompanion.insert(
    id: id,
    storeId: storeId,
    name: name ?? 'Terminal',
    code: code,
  ));
  return id;
}

Future<String> _insertUser(AppDatabase db,
    {required String storeId, required String terminalId}) async {
  final id = _uuid.v4();
  await db.userDao.insertUser(UsersCompanion.insert(
    id: id,
    storeId: Value(storeId),
    name: 'Cashier',
    pin: 'pin_hash',
    role: const Value('cashier'),
    terminalId: Value(terminalId),
  ));
  return id;
}

Future<String> _insertCategory(AppDatabase db,
    {required String storeId, String? name}) async {
  final id = _uuid.v4();
  await db.categoryDao.insertCategory(CategoriesCompanion.insert(
    id: id,
    storeId: storeId,
    name: name ?? 'Category',
  ));
  return id;
}

Future<String> _insertProduct(AppDatabase db,
    {required String storeId,
    required String categoryId,
    String? name,
    double price = 25000,
    double costPrice = 10000}) async {
  final id = _uuid.v4();
  await db.productDao.insertProduct(ProductsCompanion.insert(
    id: id,
    storeId: storeId,
    categoryId: categoryId,
    name: name ?? 'Product ${id.substring(0, 6)}',
    price: price,
    costPrice: Value(costPrice),
  ));
  await db.inventoryDao.insertInventory(InventoryCompanion.insert(
    id: _uuid.v4(),
    storeId: storeId,
    productId: id,
    quantity: Value(1000.0),
  ));
  return id;
}

Future<String> _openSession(AppDatabase db,
    {required String storeId,
    required String cashierId,
    required String terminalId,
    double openingCash = 0}) async {
  return PosSessionService(db).openSession(
    storeId: storeId,
    cashierId: cashierId,
    terminalId: terminalId,
    openingCash: openingCash,
  );
}

Future<String> _createOrder(AppDatabase db,
    {required String storeId,
    required String terminalId,
    required String cashierId,
    required String sessionId,
    required String productId,
    int quantity = 1,
    double price = 25000}) async {
  final item = CartItem(
    productId: productId,
    productName: 'Product',
    productPrice: price,
    quantity: quantity,
    lineTotal: price * quantity,
  );
  final cart = CartState(
    items: [item],
    subtotal: price * quantity,
    total: price * quantity,
  );
  return OrderService(db).createOrder(
    cart: cart,
    paymentMethod: PaymentMethod.cash,
    amountTendered: price * quantity,
    storeId: storeId,
    terminalId: terminalId,
    cashierId: cashierId,
    sessionId: sessionId,
  );
}

CartItem _mkItem(String id, String name, double price, {int qty = 1}) =>
    CartItem(
      productId: id,
      productName: name,
      productPrice: price,
      quantity: qty,
      lineTotal: price * qty,
    );

CartState _mkCart(List<CartItem> items) {
  final sub = items.fold(0.0, (s, i) => s + i.lineTotal);
  return CartState(items: items, subtotal: sub, total: sub);
}

// ── main ──────────────────────────────────────────────────────────────────────

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-001: Multiple Active Sessions Per Store
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-001: Multiple Active Sessions Per Store', () {
    test('2 terminals in same store can each have an open session', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db, name: 'HQ');
      final t1 = await _insertTerminal(db, storeId: storeId, code: 'T1');
      final t2 = await _insertTerminal(db, storeId: storeId, code: 'T2');
      final u1 = await _insertUser(db, storeId: storeId, terminalId: t1);
      final u2 = await _insertUser(db, storeId: storeId, terminalId: t2);

      final s1 = await _openSession(db, storeId: storeId, cashierId: u1, terminalId: t1);
      final s2 = await _openSession(db, storeId: storeId, cashierId: u2, terminalId: t2);

      expect(s1, isNotEmpty);
      expect(s2, isNotEmpty);
      expect(s1, isNot(equals(s2)));

      // BUG-MULTI-001: getActiveSession uses getSingleOrNull → throws with 2 sessions
      Object? err;
      PosSession? result;
      try {
        result = await db.posSessionDao.getActiveSession(storeId);
      } catch (e) {
        err = e;
      }
      expect(err, isNull,
          reason: 'BUG-MULTI-001: getActiveSession must NOT crash with 2 open terminals');
      expect(result, isNotNull);

      // Per-terminal queries still work correctly
      final s1Check = await db.posSessionDao.getActiveSessionForTerminal(t1);
      final s2Check = await db.posSessionDao.getActiveSessionForTerminal(t2);
      expect(s1Check?.id, equals(s1));
      expect(s2Check?.id, equals(s2));

      print('  T1=$s1, T2=$s2 — both open simultaneously ✓');
      print('  getActiveSession(store) returned without crash ✓');
    });

    test('Same terminal cannot open 2 sessions', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final t1 = await _insertTerminal(db, storeId: storeId, code: 'T1');
      final u1 = await _insertUser(db, storeId: storeId, terminalId: t1);

      await _openSession(db, storeId: storeId, cashierId: u1, terminalId: t1);
      expect(
        () => _openSession(db, storeId: storeId, cashierId: u1, terminalId: t1),
        throwsA(isA<Exception>()),
        reason: 'Same terminal cannot have 2 open sessions',
      );
      print('  Double-session guard on same terminal ✓');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-002: Session Report — Returned Orders
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-002: Session Report Excludes Returned Orders', () {
    test('Revenue only counts completed orders', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final catId = await _insertCategory(db, storeId: storeId);
      final t1 = await _insertTerminal(db, storeId: storeId, code: 'T1');
      final u1 = await _insertUser(db, storeId: storeId, terminalId: t1);
      final prodId = await _insertProduct(db,
          storeId: storeId, categoryId: catId, price: 50000);

      final sessionId = await _openSession(db,
          storeId: storeId, cashierId: u1, terminalId: t1);

      // 3 orders @ Rp 50,000
      await _createOrder(db,
          storeId: storeId, terminalId: t1, cashierId: u1,
          sessionId: sessionId, productId: prodId, price: 50000);
      await _createOrder(db,
          storeId: storeId, terminalId: t1, cashierId: u1,
          sessionId: sessionId, productId: prodId, price: 50000);
      final o3 = await _createOrder(db,
          storeId: storeId, terminalId: t1, cashierId: u1,
          sessionId: sessionId, productId: prodId, price: 50000);

      // Return order 3
      await db.orderDao.updateOrderStatus(o3, 'returned');

      await db.posSessionDao.closeSession(
          id: sessionId, closingCash: 100000, expectedCash: 100000);

      final report = await PosSessionService(db).generateReport(sessionId);

      print('  totalOrders=${report.totalOrders}, totalSales=Rp ${report.totalSales}');

      // BUG-MULTI-002: before fix → totalOrders=3, totalSales=150,000
      expect(report.totalOrders, equals(2),
          reason: 'BUG-MULTI-002: returned orders must NOT count in session revenue');
      expect(report.totalSales, equals(100000.0),
          reason: 'BUG-MULTI-002: returned order Rp 50k must be excluded');
      print('  Session report: 2 completed orders, Rp 100,000 ✓');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-003: Multi-Branch Data Isolation
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-003: Multi-Branch Data Isolation', () {
    test('Products isolated per branch', () async {
      final db = _openDb();
      

      final hqId = await _insertStore(db, name: 'HQ');
      final aId = await _insertStore(db, name: 'Branch A', parentId: hqId);
      final bId = await _insertStore(db, name: 'Branch B', parentId: hqId);
      final catA = await _insertCategory(db, storeId: aId);
      final catB = await _insertCategory(db, storeId: bId);

      final pA = await _insertProduct(db,
          storeId: aId, categoryId: catA, name: 'Noodles A');
      final pB = await _insertProduct(db,
          storeId: bId, categoryId: catB, name: 'Noodles B');

      final prodA = await db.productDao.getAllByStore(aId);
      final prodB = await db.productDao.getAllByStore(bId);

      expect(prodA.map((p) => p.id), contains(pA));
      expect(prodA.map((p) => p.id), isNot(contains(pB)));
      expect(prodB.map((p) => p.id), contains(pB));
      expect(prodB.map((p) => p.id), isNot(contains(pA)));
      print('  Product isolation: A sees only A, B sees only B ✓');
    });

    test('Inventory changes in branch A do not affect branch B', () async {
      final db = _openDb();
      

      final aId = await _insertStore(db, name: 'A');
      final bId = await _insertStore(db, name: 'B');
      final catA = await _insertCategory(db, storeId: aId);
      final catB = await _insertCategory(db, storeId: bId);

      final pA = await _insertProduct(db, storeId: aId, categoryId: catA);
      await _insertProduct(db, storeId: bId, categoryId: catB);

      await db.inventoryDao.decrementStock(pA, 10.0);

      final invA = await db.inventoryDao.getAllByStore(aId);
      final invB = await db.inventoryDao.getAllByStore(bId);

      expect(invA.first.quantity, equals(990.0));
      expect(invB.first.quantity, equals(1000.0));
      print('  A stock=990, B stock=1000 (unchanged) ✓');
    });

    test('Promotions isolated per store', () async {
      final db = _openDb();
      

      final aId = await _insertStore(db, name: 'A');
      final bId = await _insertStore(db, name: 'B');

      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(),
        storeId: aId,
        namaPromo: 'Promo A',
        tipeProgram: 'OTOMATIS',
        tipeReward: 'DISKON_PERSENTASE',
        nilaiReward: 10.0,
        applyTo: const Value('ORDER'),
        startDate: DateTime(2020),
      ));

      expect((await db.promotionDao.getActiveByStore(aId)).length, equals(1));
      expect((await db.promotionDao.getActiveByStore(bId)).length, equals(0));
      print('  Promotions isolated per store ✓');
    });

    test('Categories isolated per store', () async {
      final db = _openDb();
      

      final aId = await _insertStore(db, name: 'A');
      final bId = await _insertStore(db, name: 'B');

      await _insertCategory(db, storeId: aId, name: 'Food');
      await _insertCategory(db, storeId: aId, name: 'Drinks');
      await _insertCategory(db, storeId: bId, name: 'Snack');

      expect((await db.categoryDao.getAllByStore(aId)).length, equals(2));
      expect((await db.categoryDao.getAllByStore(bId)).length, equals(1));
      print('  Categories isolated per store ✓');
    });

    test('Charges isolated per store', () async {
      final db = _openDb();
      

      final aId = await _insertStore(db, name: 'A');
      final bId = await _insertStore(db, name: 'B');

      await db.chargeDao.insertCharge(ChargesCompanion.insert(
        id: _uuid.v4(),
        storeId: aId,
        namaBiaya: 'PPN',
        kategori: 'PAJAK',
        tipe: 'PERSENTASE',
        nilai: 11.0,
        urutan: const Value(1),
        includeBase: const Value('SUBTOTAL'),
      ));

      final chargesA = await ChargeService(db).getActiveByStore(aId);
      final chargesB = await ChargeService(db).getActiveByStore(bId);

      expect(chargesA.length, equals(1));
      expect(chargesB.length, equals(0));
      print('  Charges isolated per store ✓');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-004: Multi-Terminal Order Numbers
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-004: Multi-Terminal Order Numbers', () {
    test('10 orders from 2 terminals are all uniquely numbered', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final catId = await _insertCategory(db, storeId: storeId);
      final t1 = await _insertTerminal(db, storeId: storeId, code: 'T1');
      final t2 = await _insertTerminal(db, storeId: storeId, code: 'T2');
      final u1 = await _insertUser(db, storeId: storeId, terminalId: t1);
      final u2 = await _insertUser(db, storeId: storeId, terminalId: t2);
      final prod = await _insertProduct(db, storeId: storeId, categoryId: catId);

      final s1 = await _openSession(db, storeId: storeId, cashierId: u1, terminalId: t1);
      final s2 = await _openSession(db, storeId: storeId, cashierId: u2, terminalId: t2);

      for (var i = 0; i < 5; i++) {
        await _createOrder(db,
            storeId: storeId, terminalId: t1, cashierId: u1,
            sessionId: s1, productId: prod);
        await _createOrder(db,
            storeId: storeId, terminalId: t2, cashierId: u2,
            sessionId: s2, productId: prod);
      }

      final orders = await db.orderDao.getOrdersByStore(storeId);
      final nums = orders.map((o) => o.orderNumber).toList();
      expect(nums.toSet().length, equals(10),
          reason: 'All order numbers must be unique across 2 terminals');
      print('  10 orders, all unique: ${nums.take(4).join(", ")}... ✓');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-005: Pricelist Tier Resolution
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-005: Pricelist Tier Resolution', () {
    test('Tier 1 (qty 1-5) vs Tier 2 (qty 6+)', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final catId = await _insertCategory(db, storeId: storeId);
      final prodId = await _insertProduct(db,
          storeId: storeId, categoryId: catId, price: 50000);

      final now = DateTime.now();
      final plId = _uuid.v4();
      await db.pricelistDao.insertPricelist(PricelistsCompanion.insert(
        id: plId,
        storeId: storeId,
        name: 'Volume Pricing',
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 30)),
        isActive: const Value(true),
      ));
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(), pricelistId: plId, productId: prodId,
        minQty: const Value(1), maxQty: const Value(5), price: 45000,
      ));
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(), pricelistId: plId, productId: prodId,
        minQty: const Value(6), maxQty: const Value(0), price: 40000,
      ));

      final svc = PricelistService(db);
      final r1 = await svc.resolvePrice(productId: prodId, quantity: 3, originalPrice: 50000);
      final r2 = await svc.resolvePrice(productId: prodId, quantity: 10, originalPrice: 50000);

      expect(r1?.tierPrice, equals(45000.0));
      expect(r2?.tierPrice, equals(40000.0));
      print('  qty=3 → Rp ${r1?.tierPrice} ✓  qty=10 → Rp ${r2?.tierPrice} ✓');
    });

    test('Expired pricelist not applied', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final catId = await _insertCategory(db, storeId: storeId);
      final prodId = await _insertProduct(db, storeId: storeId, categoryId: catId, price: 50000);
      final now = DateTime.now();
      final plId = _uuid.v4();
      await db.pricelistDao.insertPricelist(PricelistsCompanion.insert(
        id: plId, storeId: storeId, name: 'Expired',
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.subtract(const Duration(days: 1)), // ended yesterday
        isActive: const Value(true),
      ));
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(), pricelistId: plId, productId: prodId,
        minQty: const Value(1), maxQty: const Value(0), price: 35000,
      ));

      final result = await PricelistService(db)
          .resolvePrice(productId: prodId, quantity: 1, originalPrice: 50000, now: now);
      expect(result, isNull, reason: 'Expired pricelist must not apply');
      print('  Expired pricelist returns null ✓');
    });

    test('Inactive pricelist not applied', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final catId = await _insertCategory(db, storeId: storeId);
      final prodId = await _insertProduct(db, storeId: storeId, categoryId: catId, price: 50000);
      final now = DateTime.now();
      final plId = _uuid.v4();
      await db.pricelistDao.insertPricelist(PricelistsCompanion.insert(
        id: plId, storeId: storeId, name: 'Inactive',
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 30)),
        isActive: const Value(false), // inactive
      ));
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(), pricelistId: plId, productId: prodId,
        minQty: const Value(1), maxQty: const Value(0), price: 35000,
      ));

      final result = await PricelistService(db)
          .resolvePrice(productId: prodId, quantity: 1, originalPrice: 50000);
      expect(result, isNull, reason: 'Inactive pricelist must not apply');
      print('  Inactive pricelist returns null ✓');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-006: Promotion Engine
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-006: Promotion Engine', () {
    test('OTOMATIS: 10% off on order ≥ Rp 50,000', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final now = DateTime.now();
      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaPromo: 'Diskon 10%',
        tipeProgram: 'OTOMATIS', tipeReward: 'DISKON_PERSENTASE',
        nilaiReward: 10.0, applyTo: const Value('ORDER'),
        minSubtotal: const Value(50000),
        startDate: now.subtract(const Duration(days: 1)),
      ));

      final promos = await db.promotionDao.getActiveByStore(storeId);
      final svc = PromotionService(db);

      final r1 = svc.evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([_mkItem('p1', 'A', 40000)]),
          now: now);
      expect(r1, isEmpty, reason: 'Rp 40k < min Rp 50k → no promo');

      final r2 = svc.evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([_mkItem('p1', 'A', 60000)]),
          now: now);
      expect(r2.length, equals(1));
      expect(r2.first.discountAmount, equals(6000.0));
      print('  Rp 40k → no promo ✓  Rp 60k → -Rp ${r2.first.discountAmount} ✓');
    });

    test('KODE_DISKON: 20% off with max cap Rp 50,000', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final now = DateTime.now();
      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaPromo: 'HEMAT20',
        tipeProgram: 'KODE_DISKON', kodeDiskon: const Value('HEMAT20'),
        tipeReward: 'DISKON_PERSENTASE', nilaiReward: 20.0, applyTo: const Value('ORDER'),
        maxDiskon: const Value(50000), minSubtotal: const Value(100000),
        startDate: now.subtract(const Duration(days: 1)),
      ));

      final promos = await db.promotionDao.getActiveByStore(storeId);
      final svc = PromotionService(db);

      // No code → not applied
      final r1 = svc.evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([_mkItem('p1', 'X', 200000)]),
          now: now);
      expect(r1, isEmpty);

      // With code, Rp 200k: 20% = 40k (below cap)
      final r2 = svc.evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([_mkItem('p1', 'X', 200000)]),
          now: now, enteredCode: 'HEMAT20');
      expect(r2.first.discountAmount, equals(40000.0));

      // With code, Rp 300k: 20% = 60k → capped at 50k
      final r3 = svc.evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([_mkItem('p1', 'X', 300000)]),
          now: now, enteredCode: 'HEMAT20');
      expect(r3.first.discountAmount, equals(50000.0),
          reason: 'maxDiskon cap must apply');

      print('  No code → blocked ✓  Rp200k → -40k ✓  Rp300k → capped -50k ✓');
    });

    test('BELI_X_GRATIS_Y: buy 3 get cheapest free', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final now = DateTime.now();
      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaPromo: 'Beli 2 Gratis 1',
        tipeProgram: 'BELI_X_GRATIS_Y', tipeReward: 'DISKON_PERSENTASE',
        nilaiReward: 100.0, applyTo: const Value('CHEAPEST'),
        minQty: const Value(3),
        startDate: now.subtract(const Duration(days: 1)),
      ));

      final promos = await db.promotionDao.getActiveByStore(storeId);
      final svc = PromotionService(db);

      // 2 items — minQty not met
      final r1 = svc.evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([_mkItem('p1', 'A', 30000), _mkItem('p2', 'B', 20000)]),
          now: now);
      expect(r1, isEmpty, reason: 'qty=2 < minQty=3');

      // 3 items — cheapest (15k) is free
      final r2 = svc.evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([
            _mkItem('p1', 'A', 30000),
            _mkItem('p2', 'B', 25000),
            _mkItem('p3', 'C', 15000),
          ]),
          now: now);
      expect(r2.length, equals(1));
      expect(r2.first.discountAmount, equals(15000.0));
      print('  qty=2 → blocked ✓  qty=3 → cheapest Rp 15k free ✓');
    });

    test('Promotion expired or future dates blocked', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final now = DateTime(2026, 3, 25, 12, 0);

      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaPromo: 'Future',
        tipeProgram: 'OTOMATIS', tipeReward: 'DISKON_PERSENTASE',
        nilaiReward: 10.0, applyTo: const Value('ORDER'),
        startDate: now.add(const Duration(days: 1)), // future
      ));
      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaPromo: 'Expired',
        tipeProgram: 'OTOMATIS', tipeReward: 'DISKON_PERSENTASE',
        nilaiReward: 10.0, applyTo: const Value('ORDER'),
        startDate: now.subtract(const Duration(days: 30)),
        endDate: Value(now.subtract(const Duration(days: 1))), // expired
      ));

      final promos = await db.promotionDao.getActiveByStore(storeId);
      final results = PromotionService(db).evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([_mkItem('p1', 'X', 100000)]),
          now: now);
      expect(results, isEmpty);
      print('  Future and expired promos blocked ✓');
    });

    test('Promotion maxUsage exhausted — blocked', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final now = DateTime.now();
      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaPromo: 'Limited 3x',
        tipeProgram: 'OTOMATIS', tipeReward: 'DISKON_PERSENTASE',
        nilaiReward: 10.0, applyTo: const Value('ORDER'),
        maxUsage: const Value(3), usageCount: const Value(3), // exhausted
        startDate: now.subtract(const Duration(days: 1)),
      ));

      final promos = await db.promotionDao.getActiveByStore(storeId);
      final results = PromotionService(db).evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([_mkItem('p1', 'X', 100000)]),
          now: now);
      expect(results, isEmpty, reason: 'Exhausted promo must be blocked');
      print('  Max usage exhausted (3/3) ✓');
    });

    test('Priority ordering: high-priority promo listed first', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final now = DateTime.now();

      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaPromo: 'P1-Low',
        tipeProgram: 'OTOMATIS', tipeReward: 'DISKON_PERSENTASE',
        nilaiReward: 10.0, applyTo: const Value('ORDER'),
        priority: const Value(1),
        startDate: now.subtract(const Duration(days: 1)),
      ));
      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaPromo: 'P2-High',
        tipeProgram: 'OTOMATIS', tipeReward: 'DISKON_PERSENTASE',
        nilaiReward: 20.0, applyTo: const Value('ORDER'),
        priority: const Value(2),
        startDate: now.subtract(const Duration(days: 1)),
      ));

      final promos = await db.promotionDao.getActiveByStore(storeId);
      // DAO returns sorted by priority DESC
      expect(promos.first.priority, equals(2));

      final results = PromotionService(db).evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([_mkItem('p1', 'X', 100000)]),
          now: now);

      expect(results.length, equals(2));
      expect(results.first.namaPromo, equals('P2-High'),
          reason: 'Highest priority promo must be evaluated first');
      expect(results.first.discountAmount, equals(20000.0));
      print('  P2-High (20%) listed first, P1-Low (10%) second ✓');
    });

    test('DISKON_NOMINAL: fixed amount discount', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final now = DateTime.now();
      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaPromo: 'Potongan 15rb',
        tipeProgram: 'OTOMATIS', tipeReward: 'DISKON_NOMINAL',
        nilaiReward: 15000.0, applyTo: const Value('ORDER'),
        startDate: now.subtract(const Duration(days: 1)),
      ));

      final promos = await db.promotionDao.getActiveByStore(storeId);
      final results = PromotionService(db).evaluatePromotions(
          activePromotions: promos,
          cart: _mkCart([_mkItem('p1', 'X', 80000)]),
          now: now);
      expect(results.first.discountAmount, equals(15000.0));
      print('  DISKON_NOMINAL Rp 15,000 applied ✓');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-007: Charge Calculation Engine
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-007: Charge Calculation Engine', () {
    test('PPN 11% on subtotal', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      await db.chargeDao.insertCharge(ChargesCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaBiaya: 'PPN',
        kategori: 'PAJAK', tipe: 'PERSENTASE', nilai: 11.0,
        urutan: const Value(1), includeBase: const Value('SUBTOTAL'),
      ));

      final charges = await ChargeService(db).getActiveByStore(storeId);
      final result = ChargeService(db).computeCharges(charges, 100000.0);

      expect(result.first.amount, closeTo(11000.0, 0.01));
      print('  PPN 11% on Rp 100k = Rp ${result.first.amount} ✓');
    });

    test('Chained charges: PPN then service fee AFTER_PREVIOUS', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      // PPN 10% on SUBTOTAL: 100k × 10% = 10k
      await db.chargeDao.insertCharge(ChargesCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaBiaya: 'PPN',
        kategori: 'PAJAK', tipe: 'PERSENTASE', nilai: 10.0,
        urutan: const Value(1), includeBase: const Value('SUBTOTAL'),
      ));
      // Service 5% AFTER_PREVIOUS: (100k + 10k) × 5% = 5,500
      await db.chargeDao.insertCharge(ChargesCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaBiaya: 'Service',
        kategori: 'LAYANAN', tipe: 'PERSENTASE', nilai: 5.0,
        urutan: const Value(2), includeBase: const Value('AFTER_PREVIOUS'),
      ));

      final charges = await ChargeService(db).getActiveByStore(storeId);
      final svc = ChargeService(db);
      final result = svc.computeCharges(charges, 100000.0);

      expect(result[0].amount, closeTo(10000.0, 0.01));
      expect(result[1].amount, closeTo(5500.0, 0.01));
      print('  PPN Rp ${result[0].amount} + Service Rp ${result[1].amount}'
          ' → total Rp ${100000 + result[0].amount + result[1].amount} ✓');
    });

    test('POTONGAN nominal: produces negative amount', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      await db.chargeDao.insertCharge(ChargesCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaBiaya: 'Diskon Member',
        kategori: 'POTONGAN', tipe: 'NOMINAL', nilai: 5000.0,
        urutan: const Value(1), includeBase: const Value('SUBTOTAL'),
      ));

      final charges = await ChargeService(db).getActiveByStore(storeId);
      final result = ChargeService(db).computeCharges(charges, 100000.0);

      expect(result.first.amount, equals(-5000.0));
      print('  POTONGAN Rp 5k → amount = Rp ${result.first.amount} ✓');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-008: Cart Full Cycle (Discount + Promo + Charge)
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-008: Cart Full Cycle', () {
    test('Subtotal → 10% manual discount → 5% promo → PPN 11%', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final now = DateTime.now();

      await db.chargeDao.insertCharge(ChargesCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaBiaya: 'PPN',
        kategori: 'PAJAK', tipe: 'PERSENTASE', nilai: 11.0,
        urutan: const Value(1), includeBase: const Value('SUBTOTAL'),
      ));
      await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaPromo: 'Flash 5%',
        tipeProgram: 'OTOMATIS', tipeReward: 'DISKON_PERSENTASE',
        nilaiReward: 5.0, applyTo: const Value('ORDER'),
        minSubtotal: const Value(50000),
        startDate: now.subtract(const Duration(days: 1)),
      ));

      final charges = await ChargeService(db).getActiveByStore(storeId);
      final promos = await db.promotionDao.getActiveByStore(storeId);
      final cartSvc = CartService();

      var cart = CartState(
        items: [CartItem(
          productId: 'p1', productName: 'Noodles',
          productPrice: 50000, quantity: 2, lineTotal: 100000,
        )],
        subtotal: 100000,
        total: 100000,
      );

      cart = cartSvc.applyDiscount(
        cart, DiscountType.percentage, 10.0,
        activeCharges: charges,
        chargeService: ChargeService(db),
        activePromotions: promos,
        promotionService: PromotionService(db),
      );

      // subtotal=100k, manual discount=10k, afterDiscount=90k
      // promo 5% on 90k = 4,500; afterPromo = 85,500
      // PPN 11% on SUBTOTAL base (85,500) = 9,405
      // total = 85,500 + 9,405 = 94,905
      expect(cart.subtotal, equals(100000.0));
      expect(cart.discountAmount, equals(10000.0));
      expect(cart.promotionsDiscount, closeTo(4500.0, 0.01));
      // PPN base = afterPromotions = 85,500
      expect(cart.chargesTotal, closeTo(85500.0 * 0.11, 0.01));
      final expectedTotal = 85500.0 + (85500.0 * 0.11);
      expect(cart.total, closeTo(expectedTotal, 0.01));

      print('  Subtotal: Rp ${cart.subtotal}');
      print('  -10% discount: Rp ${cart.discountAmount}');
      print('  -5% promo: Rp ${cart.promotionsDiscount}');
      print('  +PPN 11%: Rp ${cart.chargesTotal.toStringAsFixed(0)}');
      print('  Total: Rp ${cart.total.toStringAsFixed(0)} ✓');
    });

    test('Nominal discount > subtotal → total=0, charges NOT negative', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      await db.chargeDao.insertCharge(ChargesCompanion.insert(
        id: _uuid.v4(), storeId: storeId, namaBiaya: 'PPN',
        kategori: 'PAJAK', tipe: 'PERSENTASE', nilai: 11.0,
        urutan: const Value(1), includeBase: const Value('SUBTOTAL'),
      ));

      final charges = await ChargeService(db).getActiveByStore(storeId);
      final cartSvc = CartService();

      var cart = CartState(
        items: [CartItem(
          productId: 'p1', productName: 'Item',
          productPrice: 50000, quantity: 1, lineTotal: 50000,
        )],
        subtotal: 50000,
        total: 50000,
      );

      // Discount Rp 200,000 on Rp 50,000 cart (way over)
      cart = cartSvc.applyDiscount(
        cart, DiscountType.fixed, 200000.0,
        activeCharges: charges,
        chargeService: ChargeService(db),
      );

      // BUG-MULTI-005: before fix, chargesTotal = negative (PPN on negative base)
      expect(cart.total, equals(0.0),
          reason: 'BUG-MULTI-005: total must not go negative');
      expect(cart.chargesTotal, greaterThanOrEqualTo(0.0),
          reason: 'BUG-MULTI-005: charges must not be negative when discount exceeds subtotal');
      print('  Oversized discount: total=Rp ${cart.total} chargesTotal=Rp ${cart.chargesTotal} ✓');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-009: Multi-Terminal Session Report Isolation
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-009: Multi-Terminal Session Report', () {
    test('T1 and T2 session reports are isolated', () async {
      final db = _openDb();
      

      final storeId = await _insertStore(db);
      final catId = await _insertCategory(db, storeId: storeId);
      final t1 = await _insertTerminal(db, storeId: storeId, code: 'T1');
      final t2 = await _insertTerminal(db, storeId: storeId, code: 'T2');
      final u1 = await _insertUser(db, storeId: storeId, terminalId: t1);
      final u2 = await _insertUser(db, storeId: storeId, terminalId: t2);
      final prod = await _insertProduct(db, storeId: storeId, categoryId: catId, price: 30000);

      final s1 = await _openSession(db, storeId: storeId, cashierId: u1, terminalId: t1);
      final s2 = await _openSession(db, storeId: storeId, cashierId: u2, terminalId: t2);

      for (var i = 0; i < 3; i++) {
        await _createOrder(db, storeId: storeId, terminalId: t1, cashierId: u1,
            sessionId: s1, productId: prod, price: 30000);
      }
      for (var i = 0; i < 5; i++) {
        await _createOrder(db, storeId: storeId, terminalId: t2, cashierId: u2,
            sessionId: s2, productId: prod, price: 30000);
      }

      await db.posSessionDao
          .closeSession(id: s1, closingCash: 90000, expectedCash: 90000);
      await db.posSessionDao
          .closeSession(id: s2, closingCash: 150000, expectedCash: 150000);

      final r1 = await PosSessionService(db).generateReport(s1);
      final r2 = await PosSessionService(db).generateReport(s2);

      expect(r1.totalOrders, equals(3));
      expect(r1.totalSales, equals(90000.0));
      expect(r2.totalOrders, equals(5));
      expect(r2.totalSales, equals(150000.0));
      print('  T1: ${r1.totalOrders} orders Rp ${r1.totalSales} ✓');
      print('  T2: ${r2.totalOrders} orders Rp ${r2.totalSales} ✓');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-010: HQ Aggregated Branch Queries
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-010: HQ Aggregated Branch Queries', () {
    test('getAllBranchIds returns HQ + all branch IDs', () async {
      final db = _openDb();
      

      final hqId = await _insertStore(db, name: 'HQ');
      final b1 = await _insertStore(db, name: 'B1', parentId: hqId);
      final b2 = await _insertStore(db, name: 'B2', parentId: hqId);
      final b3 = await _insertStore(db, name: 'B3', parentId: hqId);

      final ids = await db.storeDao.getAllBranchIds(hqId);
      expect(ids, containsAll([hqId, b1, b2, b3]));
      expect(ids.length, equals(4));
      print('  getAllBranchIds: ${ids.length} stores (HQ + 3 branches) ✓');
    });

    test('getSessionsFiltered across all branches', () async {
      final db = _openDb();
      

      final hqId = await _insertStore(db, name: 'HQ');
      final b1 = await _insertStore(db, name: 'B1', parentId: hqId);
      final b2 = await _insertStore(db, name: 'B2', parentId: hqId);

      final t0 = await _insertTerminal(db, storeId: hqId, code: 'T0');
      final t1 = await _insertTerminal(db, storeId: b1, code: 'T1');
      final t2 = await _insertTerminal(db, storeId: b2, code: 'T2');
      final u0 = await _insertUser(db, storeId: hqId, terminalId: t0);
      final u1 = await _insertUser(db, storeId: b1, terminalId: t1);
      final u2 = await _insertUser(db, storeId: b2, terminalId: t2);

      await _openSession(db, storeId: hqId, cashierId: u0, terminalId: t0);
      await _openSession(db, storeId: b1, cashierId: u1, terminalId: t1);
      await _openSession(db, storeId: b2, cashierId: u2, terminalId: t2);

      final allIds = await db.storeDao.getAllBranchIds(hqId);
      final sessions = await db.posSessionDao.getSessionsFiltered(hqId, storeIds: allIds);
      expect(sessions.length, equals(3));
      print('  Aggregated sessions across HQ+2 branches: ${sessions.length} ✓');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // MULTI-011: Delete Branch Cascade
  // ═══════════════════════════════════════════════════════════════════════════
  group('MULTI-011: Delete Branch Cascade', () {
    test('Deleting branch removes terminals, products, categories', () async {
      final db = _openDb();
      

      final hqId = await _insertStore(db, name: 'HQ');
      final brId = await _insertStore(db, name: 'Branch X', parentId: hqId);

      final tId = await _insertTerminal(db, storeId: brId, code: 'TX1');
      await _insertUser(db, storeId: brId, terminalId: tId);
      final catId = await _insertCategory(db, storeId: brId, name: 'Cat X');
      await _insertProduct(db, storeId: brId, categoryId: catId, name: 'Prod X');

      expect((await db.terminalDao.getByStore(brId)).length, equals(1));
      expect((await db.productDao.getAllByStore(brId)).length, equals(1));
      expect((await db.categoryDao.getAllByStore(brId)).length, equals(1));
      expect((await db.inventoryDao.getAllByStore(brId)).length, equals(1));

      // Delete the branch via StoreService (cascade) — BUG-MULTI-004 FIX
      await StoreService(db).deleteBranch(brId);

      final termsAfter = await db.terminalDao.getByStore(brId);
      final prodsAfter = await db.productDao.getAllByStore(brId);
      final catsAfter = await db.categoryDao.getAllByStore(brId);
      final invAfter = await db.inventoryDao.getAllByStore(brId);

      print('  After delete: terminals=${termsAfter.length}'
          ' products=${prodsAfter.length}'
          ' categories=${catsAfter.length}'
          ' inventory=${invAfter.length}');

      // BUG-MULTI-004: before fix these will be non-zero (orphaned)
      expect(termsAfter, isEmpty,
          reason: 'BUG-MULTI-004: terminals must be deleted with branch');
      expect(prodsAfter, isEmpty,
          reason: 'BUG-MULTI-004: products must be deleted with branch');
      expect(catsAfter, isEmpty,
          reason: 'BUG-MULTI-004: categories must be deleted with branch');
      expect(invAfter, isEmpty,
          reason: 'BUG-MULTI-004: inventory must be deleted with branch');
    });
  });
}
