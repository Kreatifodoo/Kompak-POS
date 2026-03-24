import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/payment_methods_table.dart';

part 'payment_method_dao.g.dart';

@DriftAccessor(tables: [PaymentMethods])
class PaymentMethodDao extends DatabaseAccessor<AppDatabase>
    with _$PaymentMethodDaoMixin {
  PaymentMethodDao(super.db);

  Future<List<PaymentMethod>> getAllByStore(String storeId) =>
      (select(paymentMethods)
            ..where((p) => p.storeId.equals(storeId) & p.isActive.equals(true))
            ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
          .get();

  Stream<List<PaymentMethod>> watchAllByStore(String storeId) =>
      (select(paymentMethods)
            ..where((p) => p.storeId.equals(storeId) & p.isActive.equals(true))
            ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
          .watch();

  Future<PaymentMethod?> getById(String id) =>
      (select(paymentMethods)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> insertPaymentMethod(PaymentMethodsCompanion method) =>
      into(paymentMethods).insert(method);

  Future<bool> updatePaymentMethod(PaymentMethodsCompanion method) =>
      update(paymentMethods).replace(method);

  Future<int> deletePaymentMethod(String id) =>
      (delete(paymentMethods)..where((p) => p.id.equals(id))).go();
}
