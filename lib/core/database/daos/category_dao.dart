import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Future<List<Category>> getAllByStore(String storeId) =>
      (select(categories)
            ..where((c) => c.storeId.equals(storeId) & c.isActive.equals(true))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  Stream<List<Category>> watchAllByStore(String storeId) =>
      (select(categories)
            ..where((c) => c.storeId.equals(storeId) & c.isActive.equals(true))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .watch();

  Future<Category?> getById(String id) =>
      (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertCategory(CategoriesCompanion cat) =>
      into(categories).insert(cat);

  Future<bool> updateCategory(CategoriesCompanion cat) =>
      update(categories).replace(cat);

  Future<int> deleteCategory(String id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();
}
