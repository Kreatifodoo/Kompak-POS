import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../core_providers.dart';
import '../auth/auth_providers.dart';

/// Inventory item enriched with product name for display.
class InventoryWithProduct {
  final InventoryData inventory;
  final String productName;

  InventoryWithProduct({required this.inventory, required this.productName});
}

final inventoryProvider = FutureProvider<List<InventoryData>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final service = ref.watch(inventoryServiceProvider);
  return service.getAllInventory(storeId);
});

/// Inventory list enriched with product names.
final inventoryWithProductProvider =
    FutureProvider<List<InventoryWithProduct>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final db = ref.watch(databaseProvider);
  final inventoryList = await db.inventoryDao.getAllByStore(storeId);
  final products = await db.productDao.getAllByStore(storeId);

  // Build a map of productId → productName
  final nameMap = <String, String>{};
  for (final p in products) {
    nameMap[p.id] = p.name;
  }

  return inventoryList.map((inv) {
    return InventoryWithProduct(
      inventory: inv,
      productName: nameMap[inv.productId] ?? 'Unknown Product',
    );
  }).toList();
});

final lowStockProvider = FutureProvider<List<InventoryWithProduct>>((ref) async {
  final all = await ref.watch(inventoryWithProductProvider.future);
  return all
      .where((item) =>
          item.inventory.quantity <= item.inventory.lowStockThreshold)
      .toList();
});

final inventoryForProductProvider = FutureProvider.family<InventoryData?, String>((ref, productId) async {
  final service = ref.watch(inventoryServiceProvider);
  return service.getForProduct(productId);
});
