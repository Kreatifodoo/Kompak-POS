import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';

class PaymentMethodService {
  final AppDatabase db;
  static const _uuid = Uuid();

  PaymentMethodService(this.db);

  Future<List<PaymentMethod>> getAllByStore(String storeId) =>
      db.paymentMethodDao.getAllByStore(storeId);

  Stream<List<PaymentMethod>> watchAllByStore(String storeId) =>
      db.paymentMethodDao.watchAllByStore(storeId);

  Future<PaymentMethod?> getById(String id) =>
      db.paymentMethodDao.getById(id);

  Future<String> createPaymentMethod({
    required String storeId,
    required String name,
    required String type,
    String? description,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    await db.paymentMethodDao.insertPaymentMethod(
      PaymentMethodsCompanion.insert(
        id: id,
        storeId: storeId,
        name: name,
        type: type,
        description: Value(description),
        sortOrder: Value(sortOrder),
      ),
    );
    return id;
  }

  Future<void> updatePaymentMethod({
    required String id,
    required String storeId,
    required String name,
    required String type,
    String? description,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    await db.paymentMethodDao.updatePaymentMethod(PaymentMethodsCompanion(
      id: Value(id),
      storeId: Value(storeId),
      name: Value(name),
      type: Value(type),
      description: Value(description),
      isActive: Value(isActive),
      sortOrder: Value(sortOrder),
    ));
  }

  Future<void> deletePaymentMethod(String id) async {
    await db.paymentMethodDao.deletePaymentMethod(id);
  }
}
