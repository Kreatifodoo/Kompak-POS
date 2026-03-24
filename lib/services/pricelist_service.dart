import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../core/database/app_database.dart';

class PriceResolveResult {
  final double tierPrice;
  final double originalPrice;
  final double savingsPerUnit;

  const PriceResolveResult({
    required this.tierPrice,
    required this.originalPrice,
    required this.savingsPerUnit,
  });
}

class PricelistService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  PricelistService(this._db);

  // ── Pricelists CRUD ──

  Stream<List<Pricelist>> watchAllByStore(String storeId) =>
      _db.pricelistDao.watchAllByStore(storeId);

  Future<Pricelist?> getById(String id) =>
      _db.pricelistDao.getById(id);

  Future<String> createPricelist({
    required String storeId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final id = _uuid.v4();
    await _db.pricelistDao.insertPricelist(PricelistsCompanion.insert(
      id: id,
      storeId: storeId,
      name: name,
      startDate: startDate,
      endDate: endDate,
    ));
    return id;
  }

  Future<void> updatePricelist({
    required String id,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required bool isActive,
  }) async {
    await _db.pricelistDao.updatePricelist(PricelistsCompanion(
      id: Value(id),
      name: Value(name),
      startDate: Value(startDate),
      endDate: Value(endDate),
      isActive: Value(isActive),
    ));
  }

  Future<void> deletePricelist(String id) =>
      _db.pricelistDao.deletePricelist(id);

  // ── Pricelist Items ──

  Future<List<PricelistItem>> getItems(String pricelistId) =>
      _db.pricelistDao.getItemsByPricelist(pricelistId);

  Future<void> addItem({
    required String pricelistId,
    required String productId,
    required int minQty,
    required int maxQty,
    required double price,
  }) async {
    await _db.pricelistDao.insertItem(PricelistItemsCompanion.insert(
      id: _uuid.v4(),
      pricelistId: pricelistId,
      productId: productId,
      minQty: Value(minQty),
      maxQty: Value(maxQty),
      price: price,
    ));
  }

  Future<void> deleteItem(String id) =>
      _db.pricelistDao.deleteItem(id);

  Future<void> replaceItems(
    String pricelistId,
    List<PricelistItemsCompanion> items,
  ) async {
    await _db.pricelistDao.deleteItemsByPricelist(pricelistId);
    for (final item in items) {
      await _db.pricelistDao.insertItem(item);
    }
  }

  // ── Price Resolution ──

  /// Resolve the best price for a product given the quantity and current time.
  /// Returns null if no active pricelist matches.
  Future<PriceResolveResult?> resolvePrice({
    required String productId,
    required int quantity,
    required double originalPrice,
    DateTime? now,
  }) async {
    final dateNow = now ?? DateTime.now();
    final item = await _db.pricelistDao.getActivePrice(
      productId,
      quantity,
      dateNow,
    );
    if (item == null) return null;
    if (item.price >= originalPrice) return null; // no savings

    return PriceResolveResult(
      tierPrice: item.price,
      originalPrice: originalPrice,
      savingsPerUnit: originalPrice - item.price,
    );
  }
}
