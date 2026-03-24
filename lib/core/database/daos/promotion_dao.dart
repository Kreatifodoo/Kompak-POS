import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/promotions_table.dart';

part 'promotion_dao.g.dart';

@DriftAccessor(tables: [Promotions])
class PromotionDao extends DatabaseAccessor<AppDatabase>
    with _$PromotionDaoMixin {
  PromotionDao(super.db);

  Stream<List<Promotion>> watchAllByStore(String storeId) =>
      (select(promotions)
            ..where((t) => t.storeId.equals(storeId))
            ..orderBy([(t) => OrderingTerm.desc(t.priority)]))
          .watch();

  Future<List<Promotion>> getActiveByStore(String storeId) =>
      (select(promotions)
            ..where((t) =>
                t.storeId.equals(storeId) & t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.priority)]))
          .get();

  Future<Promotion?> getById(String id) =>
      (select(promotions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Promotion?> getByCode(String storeId, String code) =>
      (select(promotions)
            ..where((t) =>
                t.storeId.equals(storeId) &
                t.kodeDiskon.equals(code) &
                t.isActive.equals(true) &
                t.tipeProgram.equals('KODE_DISKON')))
          .getSingleOrNull();

  Future<void> insertPromotion(PromotionsCompanion entry) =>
      into(promotions).insert(entry);

  Future<void> updatePromotion(PromotionsCompanion entry) =>
      (update(promotions)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);

  Future<void> deletePromotion(String id) =>
      (delete(promotions)..where((t) => t.id.equals(id))).go();

  Future<void> toggleActive(String id, bool isActive) =>
      (update(promotions)..where((t) => t.id.equals(id)))
          .write(PromotionsCompanion(isActive: Value(isActive)));

  Future<void> incrementUsage(String id) async {
    await customStatement(
      'UPDATE promotions SET usage_count = usage_count + 1 WHERE id = ?',
      [id],
    );
  }
}
