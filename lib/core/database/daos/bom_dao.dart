import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/bom_items_table.dart';

part 'bom_dao.g.dart';

@DriftAccessor(tables: [BomItems])
class BomDao extends DatabaseAccessor<AppDatabase> with _$BomDaoMixin {
  BomDao(super.db);

  /// Get all BOM items for a finished product, ordered by sortOrder
  Future<List<BomItem>> getItemsByProduct(String productId) =>
      (select(bomItems)
            ..where((b) => b.productId.equals(productId))
            ..orderBy([(b) => OrderingTerm.asc(b.sortOrder)]))
          .get();

  /// Watch all BOM items for a finished product (reactive stream)
  Stream<List<BomItem>> watchItemsByProduct(String productId) =>
      (select(bomItems)
            ..where((b) => b.productId.equals(productId))
            ..orderBy([(b) => OrderingTerm.asc(b.sortOrder)]))
          .watch();

  Future<int> insertItem(BomItemsCompanion item) =>
      into(bomItems).insert(item);

  Future<bool> updateItem(BomItemsCompanion item) =>
      update(bomItems).replace(item);

  Future<int> deleteItem(String id) =>
      (delete(bomItems)..where((b) => b.id.equals(id))).go();

  Future<int> deleteItemsByProduct(String productId) =>
      (delete(bomItems)..where((b) => b.productId.equals(productId))).go();
}
