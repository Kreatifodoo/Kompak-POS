import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';

class StoreService {
  final AppDatabase db;
  static const _uuid = Uuid();

  StoreService(this.db);

  // ── Query ──

  bool isHQ(Store store) => store.parentId == null;

  Future<Store?> getById(String id) => db.storeDao.getStoreById(id);

  Future<List<Store>> getBranches(String hqStoreId) =>
      db.storeDao.getBranches(hqStoreId);

  Stream<List<Store>> watchBranches(String hqStoreId) =>
      db.storeDao.watchBranches(hqStoreId);

  /// Returns HQ storeId + all branch storeIds (for aggregated queries)
  Future<List<String>> getAllStoreIds(String hqStoreId) =>
      db.storeDao.getAllBranchIds(hqStoreId);

  // ── CRUD ──

  Future<String> createBranch({
    required String parentId,
    required String name,
    String? address,
    String? phone,
    double taxRate = 0.11,
    String currencySymbol = 'Rp',
    String? receiptHeader,
    String? receiptFooter,
  }) async {
    final id = _uuid.v4();
    await db.storeDao.insertStore(StoresCompanion.insert(
      id: id,
      name: name,
      parentId: Value(parentId),
      address: Value(address),
      phone: Value(phone),
      taxRate: Value(taxRate),
      currencySymbol: Value(currencySymbol),
      receiptHeader: Value(receiptHeader),
      receiptFooter: Value(receiptFooter),
    ));

    // Auto-create default terminal for new branch
    final terminalId = _uuid.v4();
    await db.terminalDao.insertTerminal(TerminalsCompanion.insert(
      id: terminalId,
      storeId: id,
      name: 'Kasir 1',
      code: 'T1',
    ));

    // Auto-create default payment methods for new branch
    final paymentMethods = [
      {'name': 'Cash', 'type': 'cash', 'order': 1},
      {'name': 'Card', 'type': 'card', 'order': 2},
      {'name': 'QRIS', 'type': 'qris', 'order': 3},
      {'name': 'Transfer', 'type': 'transfer', 'order': 4},
    ];
    for (final pm in paymentMethods) {
      await db.paymentMethodDao.insertPaymentMethod(
        PaymentMethodsCompanion.insert(
          id: _uuid.v4(),
          storeId: id,
          name: pm['name'] as String,
          type: pm['type'] as String,
          sortOrder: Value(pm['order'] as int),
        ),
      );
    }

    return id;
  }

  Future<void> updateBranch({
    required String id,
    required String name,
    String? parentId,
    String? address,
    String? phone,
    double taxRate = 0.11,
    String currencySymbol = 'Rp',
    String? receiptHeader,
    String? receiptFooter,
  }) async {
    final existing = await db.storeDao.getStoreById(id);
    if (existing == null) return;

    await db.storeDao.updateStore(StoresCompanion(
      id: Value(id),
      name: Value(name),
      parentId: Value(parentId ?? existing.parentId),
      address: Value(address),
      phone: Value(phone),
      taxRate: Value(taxRate),
      currencySymbol: Value(currencySymbol),
      receiptHeader: Value(receiptHeader),
      receiptFooter: Value(receiptFooter),
      logoUrl: Value(existing.logoUrl),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Delete a branch and all its dependent data atomically.
  /// BUG-MULTI-004 FIX: Without cascade, deleting a branch leaves orphaned
  /// terminals, users, products, inventory, categories, etc.
  Future<void> deleteBranch(String id) async {
    await db.transaction(() async {
      // Delete inventory for products belonging to this store
      await db.customStatement(
        'DELETE FROM inventory WHERE product_id IN '
        '(SELECT id FROM products WHERE store_id = ?)',
        [id],
      );
      // Delete BOM items for products in this store
      await db.customStatement(
        'DELETE FROM bom_items WHERE product_id IN '
        '(SELECT id FROM products WHERE store_id = ?)',
        [id],
      );
      // Delete pricelist items for pricelists in this store
      await db.customStatement(
        'DELETE FROM pricelist_items WHERE pricelist_id IN '
        '(SELECT id FROM pricelists WHERE store_id = ?)',
        [id],
      );
      // Delete inventory movements for products in this store
      await db.customStatement(
        'DELETE FROM inventory_movements WHERE product_id IN '
        '(SELECT id FROM products WHERE store_id = ?)',
        [id],
      );
      // Delete all store-scoped entities
      await db.customStatement(
          'DELETE FROM product_extras WHERE product_id IN '
          '(SELECT id FROM products WHERE store_id = ?)',
          [id]);
      await db.customStatement(
          'DELETE FROM combo_groups WHERE product_id IN '
          '(SELECT id FROM products WHERE store_id = ?)',
          [id]);
      await db.customStatement('DELETE FROM products WHERE store_id = ?', [id]);
      await db.customStatement(
          'DELETE FROM categories WHERE store_id = ?', [id]);
      await db.customStatement('DELETE FROM terminals WHERE store_id = ?', [id]);
      await db.customStatement('DELETE FROM users WHERE store_id = ?', [id]);
      await db.customStatement(
          'DELETE FROM payment_methods WHERE store_id = ?', [id]);
      await db.customStatement('DELETE FROM charges WHERE store_id = ?', [id]);
      await db.customStatement(
          'DELETE FROM promotions WHERE store_id = ?', [id]);
      await db.customStatement(
          'DELETE FROM pricelists WHERE store_id = ?', [id]);
      // Delete the store record itself
      await db.storeDao.deleteStore(id);
    });
  }
}
