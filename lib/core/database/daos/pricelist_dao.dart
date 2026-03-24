import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/pricelists_table.dart';
import '../tables/pricelist_items_table.dart';

part 'pricelist_dao.g.dart';

@DriftAccessor(tables: [Pricelists, PricelistItems])
class PricelistDao extends DatabaseAccessor<AppDatabase>
    with _$PricelistDaoMixin {
  PricelistDao(super.db);

  // ── Pricelists CRUD ──

  Future<List<Pricelist>> getAllByStore(String storeId) =>
      (select(pricelists)..where((t) => t.storeId.equals(storeId)))
          .get();

  Stream<List<Pricelist>> watchAllByStore(String storeId) =>
      (select(pricelists)
            ..where((t) => t.storeId.equals(storeId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<Pricelist?> getById(String id) =>
      (select(pricelists)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<void> insertPricelist(PricelistsCompanion entry) =>
      into(pricelists).insert(entry);

  Future<void> updatePricelist(PricelistsCompanion entry) =>
      (update(pricelists)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);

  Future<void> deletePricelist(String id) async {
    await (delete(pricelistItems)..where((t) => t.pricelistId.equals(id)))
        .go();
    await (delete(pricelists)..where((t) => t.id.equals(id))).go();
  }

  // ── Pricelist Items CRUD ──

  Future<List<PricelistItem>> getItemsByPricelist(String pricelistId) =>
      (select(pricelistItems)
            ..where((t) => t.pricelistId.equals(pricelistId)))
          .get();

  Future<void> insertItem(PricelistItemsCompanion entry) =>
      into(pricelistItems).insert(entry);

  Future<void> deleteItem(String id) =>
      (delete(pricelistItems)..where((t) => t.id.equals(id))).go();

  Future<void> deleteItemsByPricelist(String pricelistId) =>
      (delete(pricelistItems)
            ..where((t) => t.pricelistId.equals(pricelistId)))
          .go();

  // ── Price Resolution ──

  /// Get the best matching pricelist price for a product at a given quantity.
  /// Returns the PricelistItem with the highest minQty that matches,
  /// from any active pricelist whose date range covers [now].
  Future<PricelistItem?> getActivePrice(
    String productId,
    int quantity,
    DateTime now,
  ) async {
    final query = select(pricelistItems).join([
      innerJoin(
        pricelists,
        pricelists.id.equalsExp(pricelistItems.pricelistId),
      ),
    ]);

    query.where(
      pricelistItems.productId.equals(productId) &
          pricelists.isActive.equals(true) &
          pricelists.startDate.isSmallerOrEqualValue(now) &
          pricelists.endDate.isBiggerOrEqualValue(now) &
          pricelistItems.minQty.isSmallerOrEqualValue(quantity) &
          (pricelistItems.maxQty.isBiggerOrEqualValue(quantity) |
              pricelistItems.maxQty.equals(0)),
    );

    query.orderBy([OrderingTerm.desc(pricelistItems.minQty)]);
    query.limit(1);

    final rows = await query.get();
    if (rows.isEmpty) return null;
    return rows.first.readTable(pricelistItems);
  }
}
