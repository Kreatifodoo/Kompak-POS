import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/core_providers.dart';
import '../../services/pricelist_service.dart';

final pricelistsProvider = StreamProvider<List<Pricelist>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  return db.pricelistDao.watchAllByStore(storeId);
});

final pricelistDetailProvider =
    FutureProvider.family<Pricelist?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.pricelistDao.getById(id);
});

final pricelistItemsProvider =
    FutureProvider.family<List<PricelistItem>, String>((ref, pricelistId) {
  final db = ref.watch(databaseProvider);
  return db.pricelistDao.getItemsByPricelist(pricelistId);
});

/// Resolve pricelist price for a product (qty=1) — used in catalog grid.
/// Returns PriceResolveResult or null if no active pricelist.
final catalogPriceProvider =
    FutureProvider.family<PriceResolveResult?, ({String productId, double price})>(
        (ref, params) {
  final plService = ref.watch(pricelistServiceProvider);
  return plService.resolvePrice(
    productId: params.productId,
    quantity: 1,
    originalPrice: params.price,
  );
});
