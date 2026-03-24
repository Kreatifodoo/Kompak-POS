import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/charges_table.dart';

part 'charge_dao.g.dart';

@DriftAccessor(tables: [Charges])
class ChargeDao extends DatabaseAccessor<AppDatabase> with _$ChargeDaoMixin {
  ChargeDao(super.db);

  Stream<List<Charge>> watchAllByStore(String storeId) =>
      (select(charges)
            ..where((t) => t.storeId.equals(storeId))
            ..orderBy([(t) => OrderingTerm.asc(t.urutan)]))
          .watch();

  Future<List<Charge>> getActiveByStore(String storeId) =>
      (select(charges)
            ..where((t) =>
                t.storeId.equals(storeId) & t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.urutan)]))
          .get();

  Future<Charge?> getById(String id) =>
      (select(charges)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertCharge(ChargesCompanion entry) =>
      into(charges).insert(entry);

  Future<void> updateCharge(ChargesCompanion entry) =>
      (update(charges)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);

  Future<void> deleteCharge(String id) =>
      (delete(charges)..where((t) => t.id.equals(id))).go();

  Future<void> toggleActive(String id, bool isActive) =>
      (update(charges)..where((t) => t.id.equals(id)))
          .write(ChargesCompanion(isActive: Value(isActive)));
}
