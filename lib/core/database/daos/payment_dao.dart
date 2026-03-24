import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/payments_table.dart';

part 'payment_dao.g.dart';

@DriftAccessor(tables: [Payments])
class PaymentDao extends DatabaseAccessor<AppDatabase>
    with _$PaymentDaoMixin {
  PaymentDao(super.db);

  Future<Payment?> getPaymentForOrder(String orderId) =>
      (select(payments)..where((p) => p.orderId.equals(orderId)))
          .getSingleOrNull();

  Future<int> insertPayment(PaymentsCompanion payment) =>
      into(payments).insert(payment);

  /// Get all payments for a list of order IDs
  Future<List<Payment>> getPaymentsForOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return [];
    final result = <Payment>[];
    // Process in batches to avoid SQL variable limits
    for (var i = 0; i < orderIds.length; i += 500) {
      final batch = orderIds.sublist(
          i, i + 500 > orderIds.length ? orderIds.length : i + 500);
      final rows = await (select(payments)
            ..where((p) => p.orderId.isIn(batch)))
          .get();
      result.addAll(rows);
    }
    return result;
  }
}
