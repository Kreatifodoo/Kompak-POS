import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';

class ProductService {
  final AppDatabase db;
  static const _uuid = Uuid();

  ProductService(this.db);

  Future<List<Product>> getAllProducts(String storeId) =>
      db.productDao.getAllByStore(storeId);

  Stream<List<Product>> watchProducts(String storeId) =>
      db.productDao.watchAllByStore(storeId);

  Future<List<Product>> getByCategory(String storeId, String categoryId) =>
      db.productDao.getByCategory(storeId, categoryId);

  Future<List<Product>> searchProducts(String storeId, String query) =>
      db.productDao.searchByName(storeId, query);

  Future<Product?> findByBarcode(String barcode) =>
      db.productDao.findByBarcode(barcode);

  Future<Product?> getProductById(String id) =>
      db.productDao.getById(id);

  Future<List<ProductExtra>> getExtras(String productId) =>
      db.productDao.getExtrasForProduct(productId);

  Future<List<Category>> getCategories(String storeId) =>
      db.categoryDao.getAllByStore(storeId);

  Stream<List<Category>> watchCategories(String storeId) =>
      db.categoryDao.watchAllByStore(storeId);

  // ── Product CRUD ──

  Future<String> createProduct({
    required String storeId,
    required String categoryId,
    required String name,
    required double price,
    String? description,
    double? costPrice,
    String? barcode,
    String? sku,
    double? discountPercent,
    String? kitchenPrinterId,
    String? imageUrl,
    bool isCombo = false,
    bool hasBom = false,
  }) async {
    final id = _uuid.v4();
    await db.productDao.insertProduct(ProductsCompanion.insert(
      id: id,
      storeId: storeId,
      categoryId: categoryId,
      name: name,
      price: price,
      description: Value(description),
      costPrice: Value(costPrice),
      barcode: Value(barcode),
      sku: Value(sku),
      discountPercent: Value(discountPercent),
      kitchenPrinterId: Value(kitchenPrinterId),
      imageUrl: Value(imageUrl),
      isCombo: Value(isCombo),
      hasBom: Value(hasBom),
    ));
    return id;
  }

  Future<void> updateProduct({
    required String id,
    required String storeId,
    required String categoryId,
    required String name,
    required double price,
    String? description,
    double? costPrice,
    String? barcode,
    String? sku,
    bool isActive = true,
    double? discountPercent,
    String? kitchenPrinterId,
    String? imageUrl,
    bool isCombo = false,
    bool hasBom = false,
  }) async {
    await db.productDao.updateProduct(ProductsCompanion(
      id: Value(id),
      storeId: Value(storeId),
      categoryId: Value(categoryId),
      name: Value(name),
      price: Value(price),
      description: Value(description),
      costPrice: Value(costPrice),
      barcode: Value(barcode),
      sku: Value(sku),
      isActive: Value(isActive),
      discountPercent: Value(discountPercent),
      kitchenPrinterId: Value(kitchenPrinterId),
      imageUrl: Value(imageUrl),
      isCombo: Value(isCombo),
      hasBom: Value(hasBom),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deactivateProduct(String id) async {
    final product = await db.productDao.getById(id);
    if (product != null) {
      await db.productDao.updateProduct(ProductsCompanion(
        id: Value(product.id),
        storeId: Value(product.storeId),
        categoryId: Value(product.categoryId),
        name: Value(product.name),
        price: Value(product.price),
        isActive: const Value(false),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  // ── Category CRUD ──

  Future<Category?> getCategoryById(String id) =>
      db.categoryDao.getById(id);

  Future<String> createCategory({
    required String storeId,
    required String name,
    String iconName = 'restaurant',
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    await db.categoryDao.insertCategory(CategoriesCompanion.insert(
      id: id,
      storeId: storeId,
      name: name,
      iconName: Value(iconName),
      sortOrder: Value(sortOrder),
    ));
    return id;
  }

  Future<void> updateCategory({
    required String id,
    required String storeId,
    required String name,
    String iconName = 'restaurant',
    int sortOrder = 0,
    bool isActive = true,
  }) async {
    await db.categoryDao.updateCategory(CategoriesCompanion(
      id: Value(id),
      storeId: Value(storeId),
      name: Value(name),
      iconName: Value(iconName),
      sortOrder: Value(sortOrder),
      isActive: Value(isActive),
    ));
  }

  Future<void> deactivateCategory(String id) async {
    final cat = await db.categoryDao.getById(id);
    if (cat != null) {
      await db.categoryDao.updateCategory(CategoriesCompanion(
        id: Value(cat.id),
        storeId: Value(cat.storeId),
        name: Value(cat.name),
        isActive: const Value(false),
      ));
    }
  }
}
