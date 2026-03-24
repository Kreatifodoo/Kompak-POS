// ignore_for_file: avoid_print
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kompak_pos/core/database/app_database.dart' hide PaymentMethod;
import 'package:kompak_pos/models/cart_item_model.dart';
import 'package:kompak_pos/models/cart_state_model.dart';
import 'package:kompak_pos/models/enums.dart';
import 'package:kompak_pos/services/bom_service.dart';
import 'package:kompak_pos/services/order_service.dart';
import 'package:kompak_pos/services/pos_session_service.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────
// STRESS TEST CONFIG
// 5 sesi × 200 transaksi = 1.000 transaksi total
// ─────────────────────────────────────────────────────────────────
const int kSessions = 5;
const int kTransactionsPerSession = 200;
const int kTotalTransactions = kSessions * kTransactionsPerSession;
const double kInitialStock = 99999;
const double kProductPrice = 25000;
const double kCostPrice = 8000;

void main() {
  late AppDatabase db;
  late OrderService orderService;
  late PosSessionService sessionService;
  late BomService bomService;

  late String storeId;
  late String cashierId;
  late String terminalId;
  late String regularProductId;
  late String bomProductId;
  late String bomMaterialId;

  // ── Helpers ──────────────────────────────────────────────────

  CartState buildCart({
    required String productId,
    String productName = 'Produk Test',
    int qty = 1,
    double price = kProductPrice,
  }) {
    final item = CartItem(
      productId: productId,
      productName: productName,
      productPrice: price,
      quantity: qty,
      lineTotal: price * qty,
    );
    final subtotal = price * qty;
    return CartState(items: [item], subtotal: subtotal, total: subtotal);
  }

  PaymentMethod paymentMethodFor(int i) {
    const methods = [
      PaymentMethod.cash,
      PaymentMethod.qris,
      PaymentMethod.card,
      PaymentMethod.transfer,
    ];
    return methods[i % methods.length];
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    orderService = OrderService(db);
    sessionService = PosSessionService(db);
    bomService = BomService(db);
    const uuid = Uuid();

    storeId = uuid.v4();
    cashierId = uuid.v4();
    terminalId = 'T-STRESS01';
    regularProductId = uuid.v4();
    bomProductId = uuid.v4();
    bomMaterialId = uuid.v4();

    // Seed store
    await db.storeDao.insertStore(StoresCompanion.insert(
      id: storeId,
      name: 'Stress Test Store',
    ));

    // Seed category
    final categoryId = uuid.v4();
    await db.categoryDao.insertCategory(CategoriesCompanion.insert(
      id: categoryId,
      storeId: storeId,
      name: 'Test Category',
    ));

    // Seed cashier
    await db.userDao.insertUser(UsersCompanion.insert(
      id: cashierId,
      storeId: Value(storeId),
      name: 'Kasir Stress',
      pin: 'hashedpin',
    ));

    // Seed regular product + inventory
    await db.productDao.insertProduct(ProductsCompanion.insert(
      id: regularProductId,
      storeId: storeId,
      categoryId: categoryId,
      name: 'Regular Product',
      price: kProductPrice,
      costPrice: const Value(kCostPrice),
    ));
    await db.inventoryDao.insertInventory(InventoryCompanion.insert(
      id: uuid.v4(),
      storeId: storeId,
      productId: regularProductId,
      quantity: Value(kInitialStock),
    ));

    // Seed BOM material + inventory
    await db.productDao.insertProduct(ProductsCompanion.insert(
      id: bomMaterialId,
      storeId: storeId,
      categoryId: categoryId,
      name: 'Bahan Baku',
      price: 5000,
      costPrice: const Value(2000.0),
    ));
    await db.inventoryDao.insertInventory(InventoryCompanion.insert(
      id: uuid.v4(),
      storeId: storeId,
      productId: bomMaterialId,
      quantity: Value(kInitialStock),
    ));

    // Seed BOM finished product (no inventory record — uses BOM)
    await db.productDao.insertProduct(ProductsCompanion.insert(
      id: bomProductId,
      storeId: storeId,
      categoryId: categoryId,
      name: 'BOM Product',
      price: kProductPrice,
      costPrice: const Value(10000.0),
      hasBom: const Value(true),
    ));
    // 1 unit BOM product requires 2 units of material
    await bomService.addItem(
      productId: bomProductId,
      materialProductId: bomMaterialId,
      quantity: 2,
      unit: 'pcs',
    );
  });

  tearDown(() async => db.close());

  // ═══════════════════════════════════════════════════════════════
  // STRESS-001 — Order Number Uniqueness
  // ═══════════════════════════════════════════════════════════════
  test('STRESS-001: $kTotalTransactions order numbers harus semua unik', () async {
    print('\n═══ STRESS-001: Order Number Uniqueness ═══');
    final orderNumbers = <String>{};
    final sw = Stopwatch()..start();
    int errors = 0;

    for (int s = 0; s < kSessions; s++) {
      final sessionId = await sessionService.openSession(
        storeId: storeId,
        cashierId: cashierId,
        terminalId: terminalId,
        openingCash: 500000,
      );

      for (int t = 0; t < kTransactionsPerSession; t++) {
        try {
          final cart = buildCart(productId: regularProductId);
          final pm = paymentMethodFor(t);
          final orderId = await orderService.createOrder(
            cart: cart,
            paymentMethod: pm,
            amountTendered: cart.total,
            storeId: storeId,
            terminalId: terminalId,
            cashierId: cashierId,
            sessionId: sessionId,
          );
          final order = await db.orderDao.getOrderById(orderId);
          if (order != null) orderNumbers.add(order.orderNumber);
          else errors++;
        } catch (e) {
          errors++;
          print('  ✗ S$s T$t: $e');
        }
      }

      await sessionService.closeSession(sessionId, closingCash: 500000);
    }
    sw.stop();

    print('  Orders inserted  : ${orderNumbers.length}');
    print('  Errors           : $errors');
    print('  Durasi           : ${sw.elapsedMilliseconds}ms');
    print('  Throughput       : ${(kTotalTransactions * 1000 / max(sw.elapsedMilliseconds, 1)).toStringAsFixed(1)} tx/s');

    expect(errors, 0, reason: '$errors transaksi gagal');
    expect(orderNumbers.length, kTotalTransactions,
        reason: 'Duplikat order number ditemukan! '
            'Expected $kTotalTransactions unique, got ${orderNumbers.length}');
  });

  // ═══════════════════════════════════════════════════════════════
  // STRESS-002 — Inventory Accuracy (Regular Product)
  // ═══════════════════════════════════════════════════════════════
  test('STRESS-002: Stok reguler harus berkurang tepat setelah $kTotalTransactions transaksi', () async {
    print('\n═══ STRESS-002: Inventory Accuracy ═══');
    double totalQtySold = 0;

    for (int s = 0; s < kSessions; s++) {
      final sessionId = await sessionService.openSession(
        storeId: storeId,
        cashierId: cashierId,
        terminalId: terminalId,
        openingCash: 500000,
      );
      for (int t = 0; t < kTransactionsPerSession; t++) {
        final qty = (t % 3) + 1; // 1, 2, or 3 items
        totalQtySold += qty;
        final cart = buildCart(productId: regularProductId, qty: qty);
        await orderService.createOrder(
          cart: cart,
          paymentMethod: PaymentMethod.cash,
          amountTendered: cart.total,
          storeId: storeId,
          terminalId: terminalId,
          cashierId: cashierId,
          sessionId: sessionId,
        );
      }
      await sessionService.closeSession(sessionId, closingCash: 500000);
    }

    final inv = await db.inventoryDao.getForProduct(regularProductId);
    final expected = kInitialStock - totalQtySold;

    print('  Stok awal        : $kInitialStock');
    print('  Total qty terjual: $totalQtySold');
    print('  Expected stock   : $expected');
    print('  Actual stock     : ${inv?.quantity}');

    expect(inv, isNotNull);
    expect(inv!.quantity, closeTo(expected, 0.001));
  });

  // ═══════════════════════════════════════════════════════════════
  // STRESS-003 — BOM Inventory Accuracy
  // ═══════════════════════════════════════════════════════════════
  test('STRESS-003: BOM material harus berkurang 2x per unit terjual', () async {
    print('\n═══ STRESS-003: BOM Inventory Accuracy ═══');
    const bomRatio = 2.0;
    final totalSold = kTotalTransactions.toDouble();

    for (int s = 0; s < kSessions; s++) {
      final sessionId = await sessionService.openSession(
        storeId: storeId,
        cashierId: cashierId,
        terminalId: terminalId,
        openingCash: 500000,
      );
      for (int t = 0; t < kTransactionsPerSession; t++) {
        final cart = buildCart(productId: bomProductId);
        await orderService.createOrder(
          cart: cart,
          paymentMethod: PaymentMethod.qris,
          amountTendered: cart.total,
          storeId: storeId,
          terminalId: terminalId,
          cashierId: cashierId,
          sessionId: sessionId,
        );
      }
      await sessionService.closeSession(sessionId, closingCash: 500000);
    }

    final materialInv = await db.inventoryDao.getForProduct(bomMaterialId);
    final expectedMaterial = kInitialStock - (totalSold * bomRatio);

    print('  BOM products sold  : $totalSold');
    print('  BOM ratio          : $bomRatio');
    print('  Expected material  : $expectedMaterial');
    print('  Actual material    : ${materialInv?.quantity}');

    expect(materialInv, isNotNull);
    expect(materialInv!.quantity, closeTo(expectedMaterial, 0.001));
  });

  // ═══════════════════════════════════════════════════════════════
  // STRESS-004 — Session Report Accuracy
  // ═══════════════════════════════════════════════════════════════
  test('STRESS-004: Session report harus cocok dengan kalkulasi manual', () async {
    print('\n═══ STRESS-004: Session Report Accuracy ═══');

    for (int s = 0; s < kSessions; s++) {
      double expectedTotal = 0;
      final sessionId = await sessionService.openSession(
        storeId: storeId,
        cashierId: cashierId,
        terminalId: terminalId,
        openingCash: 500000,
      );
      for (int t = 0; t < kTransactionsPerSession; t++) {
        final qty = (t % 2) + 1;
        final cart = buildCart(productId: regularProductId, qty: qty);
        expectedTotal += cart.total;
        await orderService.createOrder(
          cart: cart,
          paymentMethod: paymentMethodFor(t),
          amountTendered: cart.total,
          storeId: storeId,
          terminalId: terminalId,
          cashierId: cashierId,
          sessionId: sessionId,
        );
      }
      await sessionService.closeSession(sessionId, closingCash: 500000);
      final report = await sessionService.generateReport(sessionId);

      print('  Session ${s + 1}: ${report.totalOrders} orders, '
          'Rp ${report.totalSales.toStringAsFixed(0)} '
          '(expected Rp ${expectedTotal.toStringAsFixed(0)})');

      expect(report.totalOrders, kTransactionsPerSession,
          reason: 'Session ${s + 1} order count mismatch');
      expect(report.totalSales, closeTo(expectedTotal, 0.01),
          reason: 'Session ${s + 1} total sales mismatch');
    }
  });

  // ═══════════════════════════════════════════════════════════════
  // STRESS-005 — COGS calculation dengan >999 order IDs (SQLite limit)
  // ═══════════════════════════════════════════════════════════════
  test('STRESS-005: calculateCOGS harus berhasil dengan $kTotalTransactions order IDs', () async {
    print('\n═══ STRESS-005: COGS Calculation ($kTotalTransactions IDs) ═══');
    final allOrderIds = <String>[];

    for (int s = 0; s < kSessions; s++) {
      final sessionId = await sessionService.openSession(
        storeId: storeId,
        cashierId: cashierId,
        terminalId: terminalId,
        openingCash: 500000,
      );
      for (int t = 0; t < kTransactionsPerSession; t++) {
        final cart = buildCart(productId: regularProductId);
        final orderId = await orderService.createOrder(
          cart: cart,
          paymentMethod: PaymentMethod.cash,
          amountTendered: cart.total,
          storeId: storeId,
          terminalId: terminalId,
          cashierId: cashierId,
          sessionId: sessionId,
        );
        allOrderIds.add(orderId);
      }
      await sessionService.closeSession(sessionId, closingCash: 500000);
    }

    print('  Order IDs to query: ${allOrderIds.length}');
    print('  SQLite LIMIT_VARIABLE_NUMBER: 999');

    double cogs = 0;
    Object? caughtError;
    try {
      cogs = await db.orderDao.calculateCOGS(allOrderIds);
      print('  COGS result: Rp ${cogs.toStringAsFixed(0)}');
    } catch (e) {
      caughtError = e;
      print('  ✗ FAIL: $e');
    }

    // costPrice 8000 × 1 qty × 1000 orders
    const expectedCogs = kTotalTransactions * kCostPrice;
    print('  Expected COGS: Rp ${expectedCogs.toStringAsFixed(0)}');

    expect(caughtError, isNull,
        reason: 'calculateCOGS GAGAL dengan ${allOrderIds.length} IDs.\n'
            'SQLite max variables = 999. Butuh chunking di calculateCOGS!');
    expect(cogs, closeTo(expectedCogs, 1.0));
  });

  // ═══════════════════════════════════════════════════════════════
  // STRESS-006 — Double Session Guard
  // ═══════════════════════════════════════════════════════════════
  test('STRESS-006: Tidak boleh ada 2 sesi aktif bersamaan', () async {
    print('\n═══ STRESS-006: Session Double-Open Guard ═══');

    final s1 = await sessionService.openSession(
      storeId: storeId, cashierId: cashierId,
      terminalId: terminalId, openingCash: 500000,
    );
    print('  Session 1 opened ✓');

    Object? error;
    try {
      await sessionService.openSession(
        storeId: storeId, cashierId: cashierId,
        terminalId: terminalId, openingCash: 100000,
      );
    } catch (e) {
      error = e;
      print('  Session 2 blocked ✓: $e');
    }

    await sessionService.closeSession(s1, closingCash: 500000);
    expect(error, isNotNull, reason: 'Harus throw ketika buka sesi kedua');
  });

  // ═══════════════════════════════════════════════════════════════
  // STRESS-007 — getTodayRevenue Performance
  // ═══════════════════════════════════════════════════════════════
  test('STRESS-007: getTodayRevenue akurasi & performance dengan $kTotalTransactions orders', () async {
    print('\n═══ STRESS-007: Revenue Query Performance ═══');

    for (int s = 0; s < kSessions; s++) {
      final sessionId = await sessionService.openSession(
        storeId: storeId, cashierId: cashierId,
        terminalId: terminalId, openingCash: 500000,
      );
      for (int t = 0; t < kTransactionsPerSession; t++) {
        final cart = buildCart(productId: regularProductId);
        await orderService.createOrder(
          cart: cart, paymentMethod: PaymentMethod.cash,
          amountTendered: cart.total, storeId: storeId,
          terminalId: terminalId, cashierId: cashierId,
          sessionId: sessionId,
        );
      }
      await sessionService.closeSession(sessionId, closingCash: 500000);
    }

    final sw = Stopwatch()..start();
    final revenue = await db.orderDao.getTodayRevenue(storeId);
    final count = await db.orderDao.getTodayOrderCount(storeId);
    sw.stop();

    const expectedRevenue = kTotalTransactions * kProductPrice;
    print('  Order count  : $count');
    print('  Revenue      : Rp ${revenue.toStringAsFixed(0)} (expected ${expectedRevenue.toStringAsFixed(0)})');
    print('  Query time   : ${sw.elapsedMilliseconds}ms');

    if (sw.elapsedMilliseconds > 500) {
      print('  ⚠ WARNING: getTodayRevenue lambat (${sw.elapsedMilliseconds}ms)!'
          ' Gunakan SQL SUM() bukan Dart-side aggregation.');
    }

    expect(count, kTotalTransactions);
    expect(revenue, closeTo(expectedRevenue, 1.0));
  });

  // ═══════════════════════════════════════════════════════════════
  // STRESS-008 — Inventory Movement Log Completeness
  // ═══════════════════════════════════════════════════════════════
  test('STRESS-008: Setiap transaksi harus membuat 1 inventory movement log', () async {
    print('\n═══ STRESS-008: Inventory Movement Log ═══');

    for (int s = 0; s < kSessions; s++) {
      final sessionId = await sessionService.openSession(
        storeId: storeId, cashierId: cashierId,
        terminalId: terminalId, openingCash: 500000,
      );
      for (int t = 0; t < kTransactionsPerSession; t++) {
        final cart = buildCart(productId: regularProductId);
        await orderService.createOrder(
          cart: cart, paymentMethod: PaymentMethod.cash,
          amountTendered: cart.total, storeId: storeId,
          terminalId: terminalId, cashierId: cashierId,
          sessionId: sessionId,
        );
      }
      await sessionService.closeSession(sessionId, closingCash: 500000);
    }

    final movements = await db.inventoryMovementDao.getByProduct(regularProductId);
    final saleMovements = movements.where((m) => m.type == 'sale').toList();

    print('  Total movements  : ${movements.length}');
    print('  Sale movements   : ${saleMovements.length}');
    print('  Expected         : $kTotalTransactions');

    expect(saleMovements.length, kTotalTransactions,
        reason: 'Setiap transaksi harus ada 1 inventory movement');
  });
}

int max(int a, int b) => a > b ? a : b;
