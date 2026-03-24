import '../core/database/app_database.dart';

class InventoryService {
  final AppDatabase db;

  InventoryService(this.db);

  Future<List<InventoryData>> getAllInventory(String storeId) =>
      db.inventoryDao.getAllByStore(storeId);

  Stream<List<InventoryData>> watchInventory(String storeId) =>
      db.inventoryDao.watchAllByStore(storeId);

  Future<List<InventoryData>> getLowStock(String storeId) =>
      db.inventoryDao.getLowStock(storeId);

  Future<InventoryData?> getForProduct(String productId) =>
      db.inventoryDao.getForProduct(productId);

  Future<void> restockProduct(String productId, double quantity, {String? userId, String type = 'restock'}) =>
      db.inventoryDao.restockProduct(productId, quantity, userId: userId, type: type);
}
