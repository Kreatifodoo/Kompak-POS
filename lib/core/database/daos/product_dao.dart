import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/products_table.dart';
import '../tables/product_extras_table.dart';

part 'product_dao.g.dart';

@DriftAccessor(tables: [Products, ProductExtras])
class ProductDao extends DatabaseAccessor<AppDatabase>
    with _$ProductDaoMixin {
  ProductDao(super.db);

  Future<List<Product>> getAllByStore(String storeId) =>
      (select(products)
            ..where((p) => p.storeId.equals(storeId) & p.isActive.equals(true))
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();

  Stream<List<Product>> watchAllByStore(String storeId) =>
      (select(products)
            ..where((p) => p.storeId.equals(storeId) & p.isActive.equals(true))
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .watch();

  Future<List<Product>> getByCategory(String storeId, String categoryId) =>
      (select(products)
            ..where((p) =>
                p.storeId.equals(storeId) &
                p.categoryId.equals(categoryId) &
                p.isActive.equals(true))
            ..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .get();

  Future<List<Product>> searchByName(String storeId, String query) =>
      (select(products)
            ..where((p) =>
                p.storeId.equals(storeId) &
                p.isActive.equals(true) &
                p.name.like('%$query%')))
          .get();

  Future<Product?> findByBarcode(String barcode) =>
      (select(products)
            ..where(
                (p) => p.barcode.equals(barcode) & p.isActive.equals(true)))
          .getSingleOrNull();

  Future<Product?> getById(String id) =>
      (select(products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<List<ProductExtra>> getExtrasForProduct(String productId) =>
      (select(productExtras)
            ..where((e) => e.productId.equals(productId))
            ..orderBy([(e) => OrderingTerm.asc(e.sortOrder)]))
          .get();

  Future<int> insertProduct(ProductsCompanion product) =>
      into(products).insert(product);

  Future<bool> updateProduct(ProductsCompanion product) =>
      update(products).replace(product);

  Future<int> insertExtra(ProductExtrasCompanion extra) =>
      into(productExtras).insert(extra);

  Future<int> deleteProduct(String id) =>
      (delete(products)..where((p) => p.id.equals(id))).go();

  Future<int> deleteExtrasForProduct(String productId) =>
      (delete(productExtras)..where((e) => e.productId.equals(productId))).go();
}
