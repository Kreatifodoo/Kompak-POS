import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';
import '../utils/pin_hash.dart';

class SeedData {
  static const _uuid = Uuid();

  static Future<void> seedIfEmpty(AppDatabase db) async {
    final stores = await db.storeDao.getAllStores();
    if (stores.isNotEmpty) return;

    final storeId = _uuid.v4();
    final cashierId = _uuid.v4();

    // Seed store
    await db.storeDao.insertStore(StoresCompanion.insert(
      id: storeId,
      name: 'Kompak Store',
      address: const Value('Jl. Raya No. 1, Jakarta'),
      phone: const Value('021-12345678'),
    ));

    // Seed default terminal
    final terminalId = _uuid.v4();
    await db.terminalDao.insertTerminal(TerminalsCompanion.insert(
      id: terminalId,
      storeId: storeId,
      name: 'Kasir Utama',
      code: 'T1',
    ));

    // Seed admin user (PIN: 1234) assigned to default terminal
    await db.userDao.insertUser(UsersCompanion.insert(
      id: cashierId,
      name: 'Admin',
      pin: PinHash.hash('1234'),
      role: const Value('admin'),
      storeId: Value(storeId),
      terminalId: Value(terminalId),
    ));

    // Seed default payment methods (wajib ada agar transaksi bisa dilakukan)
    final paymentMethodsList = [
      {'name': 'Cash', 'type': 'cash', 'order': 1},
      {'name': 'Card', 'type': 'card', 'order': 2},
      {'name': 'QRIS', 'type': 'qris', 'order': 3},
      {'name': 'Transfer', 'type': 'transfer', 'order': 4},
    ];

    for (final pm in paymentMethodsList) {
      await db.paymentMethodDao.insertPaymentMethod(
        PaymentMethodsCompanion.insert(
          id: _uuid.v4(),
          storeId: storeId,
          name: pm['name'] as String,
          type: pm['type'] as String,
          sortOrder: Value(pm['order'] as int),
        ),
      );
    }
    // Tidak ada kategori, produk, promo, atau charges yang di-seed.
    // Pelanggan mengisi data master sendiri.
    // Gunakan "Muat Data Demo" di Settings untuk data contoh.
  }

  /// Seed default PPN charge for existing installs (called after migration)
  static Future<void> seedDefaultChargesIfEmpty(
    AppDatabase db,
    String storeId,
  ) async {
    final existing = await db.chargeDao.getActiveByStore(storeId);
    if (existing.isNotEmpty) return; // already has charges

    // Check if ANY charges exist (including inactive)
    final allCharges = await (db.select(db.charges)
          ..where((t) => t.storeId.equals(storeId)))
        .get();
    if (allCharges.isNotEmpty) return;

    // Seed default PPN 11%
    await db.chargeDao.insertCharge(ChargesCompanion.insert(
      id: _uuid.v4(),
      storeId: storeId,
      namaBiaya: 'PPN 11%',
      kategori: 'PAJAK',
      tipe: 'PERSENTASE',
      nilai: 11,
      urutan: const Value(1),
      includeBase: const Value('SUBTOTAL'),
    ));
  }
}
