import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/combo_groups_table.dart';
import '../tables/combo_group_items_table.dart';

part 'combo_dao.g.dart';

@DriftAccessor(tables: [ComboGroups, ComboGroupItems])
class ComboDao extends DatabaseAccessor<AppDatabase> with _$ComboDaoMixin {
  ComboDao(super.db);

  // ── Combo Groups ──

  Future<List<ComboGroup>> getGroupsByProduct(String productId) =>
      (select(comboGroups)
            ..where((g) => g.productId.equals(productId))
            ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
          .get();

  Stream<List<ComboGroup>> watchGroupsByProduct(String productId) =>
      (select(comboGroups)
            ..where((g) => g.productId.equals(productId))
            ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
          .watch();

  Future<ComboGroup?> getGroupById(String id) =>
      (select(comboGroups)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<int> insertGroup(ComboGroupsCompanion group) =>
      into(comboGroups).insert(group);

  Future<bool> updateGroup(ComboGroupsCompanion group) =>
      update(comboGroups).replace(group);

  Future<int> deleteGroup(String id) =>
      (delete(comboGroups)..where((g) => g.id.equals(id))).go();

  Future<int> deleteGroupsByProduct(String productId) =>
      (delete(comboGroups)..where((g) => g.productId.equals(productId))).go();

  // ── Combo Group Items ──

  Future<List<ComboGroupItem>> getItemsByGroup(String comboGroupId) =>
      (select(comboGroupItems)
            ..where((i) => i.comboGroupId.equals(comboGroupId))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .get();

  Stream<List<ComboGroupItem>> watchItemsByGroup(String comboGroupId) =>
      (select(comboGroupItems)
            ..where((i) => i.comboGroupId.equals(comboGroupId))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .watch();

  Future<int> insertItem(ComboGroupItemsCompanion item) =>
      into(comboGroupItems).insert(item);

  Future<bool> updateItem(ComboGroupItemsCompanion item) =>
      update(comboGroupItems).replace(item);

  Future<int> deleteItem(String id) =>
      (delete(comboGroupItems)..where((i) => i.id.equals(id))).go();

  Future<int> deleteItemsByGroup(String comboGroupId) =>
      (delete(comboGroupItems)
            ..where((i) => i.comboGroupId.equals(comboGroupId)))
          .go();

  Future<int> deleteItemsByProduct(String productId) async {
    final groups = await getGroupsByProduct(productId);
    int count = 0;
    for (final group in groups) {
      count += await deleteItemsByGroup(group.id);
    }
    return count;
  }
}
