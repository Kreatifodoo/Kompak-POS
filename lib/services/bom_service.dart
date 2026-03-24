import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';

class BomService {
  final AppDatabase db;
  static const _uuid = Uuid();

  BomService(this.db);

  // ── BOM Items ──

  Future<List<BomItem>> getItemsByProduct(String productId) =>
      db.bomDao.getItemsByProduct(productId);

  Stream<List<BomItem>> watchItemsByProduct(String productId) =>
      db.bomDao.watchItemsByProduct(productId);

  Future<String> addItem({
    required String productId,
    required String materialProductId,
    required double quantity,
    String unit = 'pcs',
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    await db.bomDao.insertItem(BomItemsCompanion.insert(
      id: id,
      productId: productId,
      materialProductId: materialProductId,
      quantity: quantity,
      unit: Value(unit),
      sortOrder: Value(sortOrder),
    ));
    return id;
  }

  Future<void> updateItem({
    required String id,
    required String productId,
    required String materialProductId,
    required double quantity,
    String unit = 'pcs',
    int sortOrder = 0,
  }) async {
    await db.bomDao.updateItem(BomItemsCompanion(
      id: Value(id),
      productId: Value(productId),
      materialProductId: Value(materialProductId),
      quantity: Value(quantity),
      unit: Value(unit),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> deleteItem(String id) async {
    await db.bomDao.deleteItem(id);
  }

  // ── Product BOM Status ──

  Future<void> setProductHasBom(String productId, bool hasBom) async {
    final product = await db.productDao.getById(productId);
    if (product != null) {
      // Preserve ALL existing fields — only change hasBom.
      // Using replace() with partial companion would reset absent fields to
      // their column defaults (e.g. costPrice → null, barcode → null).
      await db.productDao.updateProduct(ProductsCompanion(
        id: Value(product.id),
        storeId: Value(product.storeId),
        categoryId: Value(product.categoryId),
        name: Value(product.name),
        description: Value(product.description),
        price: Value(product.price),
        costPrice: Value(product.costPrice),
        imageUrl: Value(product.imageUrl),
        barcode: Value(product.barcode),
        sku: Value(product.sku),
        isActive: Value(product.isActive),
        hasExtras: Value(product.hasExtras),
        isCombo: Value(product.isCombo),
        hasBom: Value(hasBom),
        kitchenPrinterId: Value(product.kitchenPrinterId),
        discountPercent: Value(product.discountPercent),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  // ── Full BOM data ──

  /// Get complete BOM configuration: items with their material product info
  Future<List<BomItemWithProduct>> getBomConfig(String productId) async {
    final items = await db.bomDao.getItemsByProduct(productId);
    final result = <BomItemWithProduct>[];

    for (final item in items) {
      final product = await db.productDao.getById(item.materialProductId);
      if (product != null) {
        result.add(BomItemWithProduct(
          bomItem: item,
          material: product,
        ));
      }
    }

    return result;
  }

  /// Delete entire BOM for a product
  Future<void> deleteBomConfig(String productId) async {
    await db.bomDao.deleteItemsByProduct(productId);
  }
}

/// A BOM item with its associated raw material product data
class BomItemWithProduct {
  final BomItem bomItem;
  final Product material;

  const BomItemWithProduct({required this.bomItem, required this.material});
}
