import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../tables/inventory_table.dart';
import '../tables/products_table.dart';

part 'inventory_dao.g.dart';

@DriftAccessor(tables: [Inventory, Products])
class InventoryDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryDaoMixin {
  static const _uuid = Uuid();
  InventoryDao(super.db);

  Future<List<InventoryData>> getAllByStore(String storeId) =>
      (select(inventory)..where((i) => i.storeId.equals(storeId))).get();

  Stream<List<InventoryData>> watchAllByStore(String storeId) =>
      (select(inventory)..where((i) => i.storeId.equals(storeId))).watch();

  Future<InventoryData?> getForProduct(String productId) =>
      (select(inventory)..where((i) => i.productId.equals(productId)))
          .getSingleOrNull();

  Future<void> decrementStock(String productId, double qty, {String? userId}) async {
    // BUG-SIT-002 FIX: Read first to capture previousQty for movement log,
    // then use atomic MAX(0, quantity - qty) UPDATE to prevent overselling
    // even if called outside a transaction.
    final inv = await getForProduct(productId);
    if (inv != null) {
      await customStatement(
        'UPDATE inventory SET quantity = MAX(0, quantity - ?), updated_at = ? WHERE product_id = ?',
        [qty, DateTime.now().toIso8601String(), productId],
      );
      final newQty = math.max(0.0, inv.quantity - qty);
      await attachedDatabase.inventoryMovementDao.insertMovement(
        InventoryMovementsCompanion.insert(
          id: _uuid.v4(),
          productId: productId,
          type: 'sale',
          quantity: qty,
          previousQty: inv.quantity,
          newQty: newQty,
          userId: Value(userId),
        ),
      );
    }
  }

  Future<void> restockProduct(String productId, double qty, {String? userId, String type = 'restock'}) async {
    final inv = await getForProduct(productId);
    if (inv != null) {
      final newQty = inv.quantity + qty;
      await (update(inventory)..where((i) => i.productId.equals(productId)))
          .write(InventoryCompanion(
        quantity: Value(newQty),
        lastRestockAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ));
      await attachedDatabase.inventoryMovementDao.insertMovement(
        InventoryMovementsCompanion.insert(
          id: _uuid.v4(),
          productId: productId,
          type: type,
          quantity: qty,
          previousQty: inv.quantity,
          newQty: newQty,
          userId: Value(userId),
        ),
      );
    }
  }

  Future<List<InventoryData>> getLowStock(String storeId) async {
    final all = await getAllByStore(storeId);
    return all.where((i) => i.quantity <= i.lowStockThreshold).toList();
  }

  Future<void> updateLowStockThreshold(
      String productId, double threshold) async {
    await (update(inventory)..where((i) => i.productId.equals(productId)))
        .write(InventoryCompanion(
      lowStockThreshold: Value(threshold),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<int> insertInventory(InventoryCompanion inv) =>
      into(inventory).insert(inv);
}
