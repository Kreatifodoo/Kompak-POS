import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/stores_table.dart';

part 'store_dao.g.dart';

@DriftAccessor(tables: [Stores])
class StoreDao extends DatabaseAccessor<AppDatabase> with _$StoreDaoMixin {
  StoreDao(super.db);

  Future<List<Store>> getAllStores() => select(stores).get();

  Future<Store?> getStoreById(String id) =>
      (select(stores)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<int> insertStore(StoresCompanion store) =>
      into(stores).insert(store);

  Future<bool> updateStore(StoresCompanion store) =>
      update(stores).replace(store);

  Future<int> deleteStore(String id) =>
      (delete(stores)..where((s) => s.id.equals(id))).go();

  // ── Branch methods ──

  /// Get all branches for a given HQ store
  Future<List<Store>> getBranches(String parentId) =>
      (select(stores)
            ..where((s) => s.parentId.equals(parentId))
            ..orderBy([(s) => OrderingTerm.asc(s.name)]))
          .get();

  /// Watch all branches for a given HQ store (reactive)
  Stream<List<Store>> watchBranches(String parentId) =>
      (select(stores)
            ..where((s) => s.parentId.equals(parentId))
            ..orderBy([(s) => OrderingTerm.asc(s.name)]))
          .watch();

  /// Get HQ store ID + all branch store IDs (for aggregated queries)
  Future<List<String>> getAllBranchIds(String hqStoreId) async {
    final branches = await getBranches(hqStoreId);
    return [hqStoreId, ...branches.map((b) => b.id)];
  }
}
