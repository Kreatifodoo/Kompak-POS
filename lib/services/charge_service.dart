import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';
import '../models/applied_charge_model.dart';
import '../models/enums.dart';

class ChargeService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  ChargeService(this._db);

  // ── CRUD ──

  Stream<List<Charge>> watchAllByStore(String storeId) =>
      _db.chargeDao.watchAllByStore(storeId);

  Future<Charge?> getById(String id) => _db.chargeDao.getById(id);

  Future<List<Charge>> getActiveByStore(String storeId) =>
      _db.chargeDao.getActiveByStore(storeId);

  Future<String> createCharge({
    required String storeId,
    required String namaBiaya,
    required String kategori,
    required String tipe,
    required double nilai,
    required int urutan,
    required String includeBase,
  }) async {
    final id = _uuid.v4();
    await _db.chargeDao.insertCharge(ChargesCompanion.insert(
      id: id,
      storeId: storeId,
      namaBiaya: namaBiaya,
      kategori: kategori,
      tipe: tipe,
      nilai: nilai,
      urutan: Value(urutan),
      includeBase: Value(includeBase),
    ));
    return id;
  }

  Future<void> updateCharge({
    required String id,
    required String namaBiaya,
    required String kategori,
    required String tipe,
    required double nilai,
    required int urutan,
    required bool isActive,
    required String includeBase,
  }) async {
    await _db.chargeDao.updateCharge(ChargesCompanion(
      id: Value(id),
      namaBiaya: Value(namaBiaya),
      kategori: Value(kategori),
      tipe: Value(tipe),
      nilai: Value(nilai),
      urutan: Value(urutan),
      isActive: Value(isActive),
      includeBase: Value(includeBase),
    ));
  }

  Future<void> deleteCharge(String id) => _db.chargeDao.deleteCharge(id);

  Future<void> toggleActive(String id, bool isActive) =>
      _db.chargeDao.toggleActive(id, isActive);

  // ── Calculation Engine ──

  /// Compute all charges against [afterDiscountSubtotal].
  /// [activeCharges] must be sorted by urutan.
  /// Returns list of AppliedCharge with computed amounts.
  List<AppliedCharge> computeCharges(
    List<Charge> activeCharges,
    double afterDiscountSubtotal,
  ) {
    final results = <AppliedCharge>[];
    double runningTotal = afterDiscountSubtotal;

    for (final charge in activeCharges) {
      if (charge.nilai == 0) continue; // skip zero-value charges

      final kategori = ChargeKategori.fromDb(charge.kategori);
      final tipe = ChargeTipe.fromDb(charge.tipe);
      final includeBase = ChargeIncludeBase.fromDb(charge.includeBase);

      final base = includeBase == ChargeIncludeBase.subtotal
          ? afterDiscountSubtotal
          : runningTotal;

      double amount;
      if (tipe == ChargeTipe.persentase) {
        amount = base * (charge.nilai / 100);
      } else {
        amount = charge.nilai;
      }

      // POTONGAN = negative
      if (kategori == ChargeKategori.potongan) {
        amount = -amount.abs();
      }

      results.add(AppliedCharge(
        chargeId: charge.id,
        namaBiaya: charge.namaBiaya,
        kategori: kategori,
        tipe: tipe,
        nilai: charge.nilai,
        includeBase: includeBase,
        amount: amount,
      ));

      runningTotal += amount;
    }

    return results;
  }
}
