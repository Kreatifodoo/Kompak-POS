import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';
import '../utils/pin_hash.dart';

class SeedData {
  static const _uuid = Uuid();

  static Future<void> seedIfEmpty(AppDatabase db) async {
    final stores = await db.storeDao.getAllStores();
    if (stores.isNotEmpty) return;

    final storeId = _uuid.v4();
    final cashierId = _uuid.v4();

    // Seed store
    await db.storeDao.insertStore(StoresCompanion.insert(
      id: storeId,
      name: 'Kompak Store',
      address: const Value('Jl. Raya No. 1, Jakarta'),
      phone: const Value('021-12345678'),
    ));

    // Seed cashier (PIN: 1234)
    await db.userDao.insertUser(UsersCompanion.insert(
      id: cashierId,
      name: 'Admin',
      pin: PinHash.hash('1234'),
      role: const Value('admin'),
      storeId: Value(storeId),
    ));

    // Seed default payment methods
    final paymentMethodsList = [
      {'name': 'Cash', 'type': 'cash', 'order': 1},
      {'name': 'Card', 'type': 'card', 'order': 2},
      {'name': 'QRIS', 'type': 'qris', 'order': 3},
      {'name': 'Transfer', 'type': 'transfer', 'order': 4},
    ];

    for (final pm in paymentMethodsList) {
      await db.paymentMethodDao.insertPaymentMethod(
        PaymentMethodsCompanion.insert(
          id: _uuid.v4(),
          storeId: storeId,
          name: pm['name'] as String,
          type: pm['type'] as String,
          sortOrder: Value(pm['order'] as int),
        ),
      );
    }

    // Seed categories
    final categories = [
      {'name': 'Snack', 'icon': 'cookie', 'order': 1},
      {'name': 'Food', 'icon': 'restaurant', 'order': 2},
      {'name': 'Drink', 'icon': 'local_cafe', 'order': 3},
      {'name': 'Fruits', 'icon': 'eco', 'order': 4},
    ];

    final categoryIds = <String, String>{};
    for (final cat in categories) {
      final catId = _uuid.v4();
      categoryIds[cat['name'] as String] = catId;
      await db.categoryDao.insertCategory(CategoriesCompanion.insert(
        id: catId,
        storeId: storeId,
        name: cat['name'] as String,
        iconName: Value(cat['icon'] as String),
        sortOrder: Value(cat['order'] as int),
      ));
    }

    // Seed products
    final products = [
      {'name': 'Noodles Ramen', 'desc': 'With Spicy Sauce', 'price': 53500.0, 'cat': 'Food', 'discount': 30.0, 'barcode': '8801234560001'},
      {'name': 'Dumplings', 'desc': 'Japanese Beef Filling', 'price': 32700.0, 'cat': 'Food', 'discount': 30.0, 'barcode': '8801234560002'},
      {'name': 'Beef Burger', 'desc': 'Selected Meat Specials', 'price': 42100.0, 'cat': 'Food', 'discount': 30.0, 'barcode': '8801234560003'},
      {'name': 'Pizza Sicilia', 'desc': 'Italian Classic', 'price': 65000.0, 'cat': 'Food', 'discount': 30.0, 'barcode': '8801234560004'},
      {'name': 'French Fries', 'desc': 'Crispy Golden', 'price': 25000.0, 'cat': 'Snack', 'discount': null, 'barcode': '8801234560005'},
      {'name': 'Chicken Wings', 'desc': 'Spicy BBQ', 'price': 35000.0, 'cat': 'Snack', 'discount': 20.0, 'barcode': '8801234560006'},
      {'name': 'Iced Tea', 'desc': 'Fresh Brewed', 'price': 15000.0, 'cat': 'Drink', 'discount': null, 'barcode': '8801234560007'},
      {'name': 'Coffee Latte', 'desc': 'Premium Arabica', 'price': 28000.0, 'cat': 'Drink', 'discount': null, 'barcode': '8801234560008'},
      {'name': 'Orange Juice', 'desc': 'Fresh Squeezed', 'price': 22000.0, 'cat': 'Drink', 'discount': 10.0, 'barcode': '8801234560009'},
      {'name': 'Fresh Apple', 'desc': 'Organic Green Apple', 'price': 12000.0, 'cat': 'Fruits', 'discount': null, 'barcode': '8801234560010'},
      {'name': 'Banana Split', 'desc': 'Premium Dessert', 'price': 30000.0, 'cat': 'Fruits', 'discount': 15.0, 'barcode': '8801234560011'},
      {'name': 'Mango Smoothie', 'desc': 'Tropical Blend', 'price': 25000.0, 'cat': 'Drink', 'discount': null, 'barcode': '8801234560012'},
    ];

    for (final prod in products) {
      final prodId = _uuid.v4();
      final catName = prod['cat'] as String;
      final catId = categoryIds[catName] ?? categoryIds['Food']!;

      await db.productDao.insertProduct(ProductsCompanion.insert(
        id: prodId,
        storeId: storeId,
        categoryId: catId,
        name: prod['name'] as String,
        description: Value(prod['desc'] as String),
        price: prod['price'] as double,
        barcode: Value(prod['barcode'] as String),
        sku: Value('SKU-${prod['barcode']}'),
        discountPercent: Value(prod['discount'] as double?),
      ));

      // Seed inventory for each product
      await db.inventoryDao.insertInventory(InventoryCompanion.insert(
        id: _uuid.v4(),
        productId: prodId,
        storeId: storeId,
        quantity: const Value(100),
        lowStockThreshold: const Value(10),
      ));

      productIds[prod['name'] as String] = prodId;
    }

    // Seed demo pricelist
    await _seedPricelist(db, storeId, productIds);

    // Seed default charges (biaya)
    await _seedCharges(db, storeId);

    // Seed demo promotions
    await _seedPromotions(db, storeId);

    // Seed demo combo product
    await _seedCombo(db, storeId, categoryIds, productIds);
  }

  static final Map<String, String> productIds = {};

  static Future<void> _seedPricelist(
    AppDatabase db,
    String storeId,
    Map<String, String> productIds,
  ) async {
    final plId = _uuid.v4();
    final now = DateTime.now();

    // Create a pricelist valid for 90 days
    await db.pricelistDao.insertPricelist(PricelistsCompanion.insert(
      id: plId,
      storeId: storeId,
      name: 'Promo Grand Opening',
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 90)),
    ));

    // Add tier pricing for select products
    final noodlesId = productIds['Noodles Ramen'];
    final burgerId = productIds['Beef Burger'];
    final coffeeId = productIds['Coffee Latte'];

    if (noodlesId != null) {
      // Noodles: qty 1-5 → 48000, qty 6+ → 42000
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(),
        pricelistId: plId,
        productId: noodlesId,
        minQty: const Value(1),
        maxQty: const Value(5),
        price: 48000,
      ));
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(),
        pricelistId: plId,
        productId: noodlesId,
        minQty: const Value(6),
        maxQty: const Value(0),
        price: 42000,
      ));
    }

    if (burgerId != null) {
      // Burger: qty 1-3 → 38000, qty 4+ → 35000
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(),
        pricelistId: plId,
        productId: burgerId,
        minQty: const Value(1),
        maxQty: const Value(3),
        price: 38000,
      ));
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(),
        pricelistId: plId,
        productId: burgerId,
        minQty: const Value(4),
        maxQty: const Value(0),
        price: 35000,
      ));
    }

    if (coffeeId != null) {
      // Coffee: qty 1+ → 24000
      await db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
        id: _uuid.v4(),
        pricelistId: plId,
        productId: coffeeId,
        minQty: const Value(1),
        maxQty: const Value(0),
        price: 24000,
      ));
    }
  }

  static Future<void> _seedCharges(
    AppDatabase db,
    String storeId,
  ) async {
    // PPN 11% — active by default
    await db.chargeDao.insertCharge(ChargesCompanion.insert(
      id: _uuid.v4(),
      storeId: storeId,
      namaBiaya: 'PPN 11%',
      kategori: 'PAJAK',
      tipe: 'PERSENTASE',
      nilai: 11,
      urutan: const Value(1),
      includeBase: const Value('SUBTOTAL'),
    ));

    // Service Charge 5% — inactive, demo
    await db.chargeDao.insertCharge(ChargesCompanion.insert(
      id: _uuid.v4(),
      storeId: storeId,
      namaBiaya: 'Service 5%',
      kategori: 'LAYANAN',
      tipe: 'PERSENTASE',
      nilai: 5,
      urutan: const Value(2),
      includeBase: const Value('SUBTOTAL'),
      isActive: const Value(false),
    ));

    // Potongan Member Rp 5.000 — inactive, demo
    await db.chargeDao.insertCharge(ChargesCompanion.insert(
      id: _uuid.v4(),
      storeId: storeId,
      namaBiaya: 'Potongan Member',
      kategori: 'POTONGAN',
      tipe: 'NOMINAL',
      nilai: 5000,
      urutan: const Value(3),
      includeBase: const Value('AFTER_PREVIOUS'),
      isActive: const Value(false),
    ));
  }

  static Future<void> _seedPromotions(
    AppDatabase db,
    String storeId,
  ) async {
    final now = DateTime.now();

    // Promo: Diskon 10% min 50rb — active
    await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
      id: _uuid.v4(),
      storeId: storeId,
      namaPromo: 'Diskon 10% Min 50rb',
      deskripsi: const Value('Diskon otomatis 10% untuk belanja minimal Rp 50.000'),
      tipeProgram: 'OTOMATIS',
      tipeReward: 'DISKON_PERSENTASE',
      nilaiReward: 10,
      startDate: now.subtract(const Duration(days: 1)),
      minSubtotal: const Value(50000),
      priority: const Value(10),
    ));

    // Promo: Kode Diskon HEMAT20 — inactive demo
    await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
      id: _uuid.v4(),
      storeId: storeId,
      namaPromo: 'Kode HEMAT20',
      deskripsi: const Value('Masukkan kode HEMAT20 untuk diskon 20%'),
      tipeProgram: 'KODE_DISKON',
      kodeDiskon: const Value('HEMAT20'),
      tipeReward: 'DISKON_PERSENTASE',
      nilaiReward: 20,
      startDate: now.subtract(const Duration(days: 1)),
      endDate: Value(now.add(const Duration(days: 90))),
      minSubtotal: const Value(100000),
      maxDiskon: const Value(50000),
      priority: const Value(5),
      isActive: const Value(false),
    ));

    // Promo: Beli 2 Gratis 1 — inactive demo
    await db.promotionDao.insertPromotion(PromotionsCompanion.insert(
      id: _uuid.v4(),
      storeId: storeId,
      namaPromo: 'Beli 2 Gratis 1',
      deskripsi: const Value('Beli 2 item, gratis 1 item termurah'),
      tipeProgram: 'BELI_X_GRATIS_Y',
      tipeReward: 'DISKON_PERSENTASE',
      nilaiReward: 100, // 100% off cheapest
      startDate: now.subtract(const Duration(days: 1)),
      applyTo: const Value('CHEAPEST'),
      minQty: const Value(3),
      priority: const Value(1),
      isActive: const Value(false),
    ));
  }

  static Future<void> _seedCombo(
    AppDatabase db,
    String storeId,
    Map<String, String> categoryIds,
    Map<String, String> productIds,
  ) async {
    // Create a combo product: "Paket Hemat"
    final comboId = _uuid.v4();
    final foodCatId = categoryIds['Food'] ?? categoryIds.values.first;

    await db.productDao.insertProduct(ProductsCompanion.insert(
      id: comboId,
      storeId: storeId,
      categoryId: foodCatId,
      name: 'Paket Hemat',
      description: const Value('1 Makanan + 1 Minuman + 1 Snack'),
      price: 55000,
      barcode: const Value('8801234560099'),
      sku: const Value('SKU-COMBO-001'),
      isCombo: const Value(true),
    ));

    // Seed inventory
    await db.inventoryDao.insertInventory(InventoryCompanion.insert(
      id: _uuid.v4(),
      productId: comboId,
      storeId: storeId,
      quantity: const Value(999),
      lowStockThreshold: const Value(10),
    ));

    // Group 1: Pilih Makanan
    final grpFood = _uuid.v4();
    await db.comboDao.insertGroup(ComboGroupsCompanion.insert(
      id: grpFood,
      productId: comboId,
      name: 'Pilih Makanan',
      minSelect: const Value(1),
      maxSelect: const Value(1),
      sortOrder: const Value(1),
    ));

    final foodProducts = ['Noodles Ramen', 'Dumplings', 'Beef Burger'];
    int sortIdx = 0;
    for (final name in foodProducts) {
      final pid = productIds[name];
      if (pid != null) {
        final extra = name == 'Noodles Ramen' ? 5000.0 : 0.0;
        await db.comboDao.insertItem(ComboGroupItemsCompanion.insert(
          id: _uuid.v4(),
          comboGroupId: grpFood,
          productId: pid,
          extraPrice: Value(extra),
          sortOrder: Value(sortIdx++),
        ));
      }
    }

    // Group 2: Pilih Minuman
    final grpDrink = _uuid.v4();
    await db.comboDao.insertGroup(ComboGroupsCompanion.insert(
      id: grpDrink,
      productId: comboId,
      name: 'Pilih Minuman',
      minSelect: const Value(1),
      maxSelect: const Value(1),
      sortOrder: const Value(2),
    ));

    final drinkProducts = ['Iced Tea', 'Coffee Latte', 'Orange Juice'];
    sortIdx = 0;
    for (final name in drinkProducts) {
      final pid = productIds[name];
      if (pid != null) {
        final extra = name == 'Coffee Latte' ? 3000.0 : 0.0;
        await db.comboDao.insertItem(ComboGroupItemsCompanion.insert(
          id: _uuid.v4(),
          comboGroupId: grpDrink,
          productId: pid,
          extraPrice: Value(extra),
          sortOrder: Value(sortIdx++),
        ));
      }
    }

    // Group 3: Pilih Snack
    final grpSnack = _uuid.v4();
    await db.comboDao.insertGroup(ComboGroupsCompanion.insert(
      id: grpSnack,
      productId: comboId,
      name: 'Pilih Snack',
      minSelect: const Value(1),
      maxSelect: const Value(1),
      sortOrder: const Value(3),
    ));

    final snackProducts = ['French Fries', 'Chicken Wings'];
    sortIdx = 0;
    for (final name in snackProducts) {
      final pid = productIds[name];
      if (pid != null) {
        await db.comboDao.insertItem(ComboGroupItemsCompanion.insert(
          id: _uuid.v4(),
          comboGroupId: grpSnack,
          productId: pid,
          sortOrder: Value(sortIdx++),
        ));
      }
    }
  }

  /// Seed default PPN charge for existing installs (called after migration)
  static Future<void> seedDefaultChargesIfEmpty(
    AppDatabase db,
    String storeId,
  ) async {
    final existing = await db.chargeDao.getActiveByStore(storeId);
    if (existing.isNotEmpty) return; // already has charges

    // Check if ANY charges exist (including inactive)
    final allCharges = await (db.select(db.charges)
          ..where((t) => t.storeId.equals(storeId)))
        .get();
    if (allCharges.isNotEmpty) return;

    // Seed default PPN 11%
    await db.chargeDao.insertCharge(ChargesCompanion.insert(
      id: _uuid.v4(),
      storeId: storeId,
      namaBiaya: 'PPN 11%',
      kategori: 'PAJAK',
      tipe: 'PERSENTASE',
      nilai: 11,
      urutan: const Value(1),
      includeBase: const Value('SUBTOTAL'),
    ));
  }
}
