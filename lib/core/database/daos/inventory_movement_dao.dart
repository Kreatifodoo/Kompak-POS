import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/inventory_movements_table.dart';

part 'inventory_movement_dao.g.dart';

@DriftAccessor(tables: [InventoryMovements])
class InventoryMovementDao extends DatabaseAccessor<AppDatabase>
    with _$InventoryMovementDaoMixin {
  InventoryMovementDao(super.db);

  Future<void> insertMovement(InventoryMovementsCompanion entry) =>
      into(inventoryMovements).insert(entry);

  Future<List<InventoryMovement>> getByProduct(String productId) =>
      (select(inventoryMovements)
            ..where((m) => m.productId.equals(productId))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
          .get();

  Future<List<InventoryMovement>> getByDateRange(
    DateTime start,
    DateTime end,
  ) =>
      (select(inventoryMovements)
            ..where((m) =>
                m.createdAt.isBiggerOrEqualValue(start) &
                m.createdAt.isSmallerThanValue(end))
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
          .get();
}
