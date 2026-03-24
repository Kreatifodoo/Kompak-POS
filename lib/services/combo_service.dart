import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';

class ComboService {
  final AppDatabase db;
  static const _uuid = Uuid();

  ComboService(this.db);

  // ── Combo Groups ──

  Future<List<ComboGroup>> getGroupsByProduct(String productId) =>
      db.comboDao.getGroupsByProduct(productId);

  Stream<List<ComboGroup>> watchGroupsByProduct(String productId) =>
      db.comboDao.watchGroupsByProduct(productId);

  Future<ComboGroup?> getGroupById(String id) =>
      db.comboDao.getGroupById(id);

  Future<String> createGroup({
    required String productId,
    required String name,
    int minSelect = 1,
    int maxSelect = 1,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    await db.comboDao.insertGroup(ComboGroupsCompanion.insert(
      id: id,
      productId: productId,
      name: name,
      minSelect: Value(minSelect),
      maxSelect: Value(maxSelect),
      sortOrder: Value(sortOrder),
    ));
    return id;
  }

  Future<void> updateGroup({
    required String id,
    required String productId,
    required String name,
    int minSelect = 1,
    int maxSelect = 1,
    int sortOrder = 0,
  }) async {
    await db.comboDao.updateGroup(ComboGroupsCompanion(
      id: Value(id),
      productId: Value(productId),
      name: Value(name),
      minSelect: Value(minSelect),
      maxSelect: Value(maxSelect),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> deleteGroup(String id) async {
    // Delete all items in the group first
    await db.comboDao.deleteItemsByGroup(id);
    await db.comboDao.deleteGroup(id);
  }

  // ── Combo Group Items ──

  Future<List<ComboGroupItem>> getItemsByGroup(String comboGroupId) =>
      db.comboDao.getItemsByGroup(comboGroupId);

  Stream<List<ComboGroupItem>> watchItemsByGroup(String comboGroupId) =>
      db.comboDao.watchItemsByGroup(comboGroupId);

  Future<String> addItemToGroup({
    required String comboGroupId,
    required String productId,
    double extraPrice = 0,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    await db.comboDao.insertItem(ComboGroupItemsCompanion.insert(
      id: id,
      comboGroupId: comboGroupId,
      productId: productId,
      extraPrice: Value(extraPrice),
      sortOrder: Value(sortOrder),
    ));
    return id;
  }

  Future<void> updateItem({
    required String id,
    required String comboGroupId,
    required String productId,
    double extraPrice = 0,
    int sortOrder = 0,
  }) async {
    await db.comboDao.updateItem(ComboGroupItemsCompanion(
      id: Value(id),
      comboGroupId: Value(comboGroupId),
      productId: Value(productId),
      extraPrice: Value(extraPrice),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> deleteItem(String id) async {
    await db.comboDao.deleteItem(id);
  }

  // ── Product Combo Status ──

  Future<void> setProductAsCombo(String productId, bool isCombo) async {
    final product = await db.productDao.getById(productId);
    if (product != null) {
      await db.productDao.updateProduct(ProductsCompanion(
        id: Value(product.id),
        storeId: Value(product.storeId),
        categoryId: Value(product.categoryId),
        name: Value(product.name),
        price: Value(product.price),
        isCombo: Value(isCombo),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  // ── Full combo data ──

  /// Get complete combo configuration: groups with their items & product info
  Future<List<ComboGroupWithItems>> getComboConfig(String productId) async {
    final groups = await db.comboDao.getGroupsByProduct(productId);
    final result = <ComboGroupWithItems>[];

    for (final group in groups) {
      final items = await db.comboDao.getItemsByGroup(group.id);
      final itemsWithProducts = <ComboItemWithProduct>[];

      for (final item in items) {
        final product = await db.productDao.getById(item.productId);
        if (product != null) {
          itemsWithProducts.add(ComboItemWithProduct(
            comboGroupItem: item,
            product: product,
          ));
        }
      }

      result.add(ComboGroupWithItems(
        group: group,
        items: itemsWithProducts,
      ));
    }

    return result;
  }

  /// Delete all combo configuration for a product
  Future<void> deleteComboConfig(String productId) async {
    await db.comboDao.deleteItemsByProduct(productId);
    await db.comboDao.deleteGroupsByProduct(productId);
  }
}

/// A combo group with its selectable items (products resolved)
class ComboGroupWithItems {
  final ComboGroup group;
  final List<ComboItemWithProduct> items;

  const ComboGroupWithItems({required this.group, required this.items});
}

/// A combo item with its associated product data
class ComboItemWithProduct {
  final ComboGroupItem comboGroupItem;
  final Product product;

  const ComboItemWithProduct({
    required this.comboGroupItem,
    required this.product,
  });
}
