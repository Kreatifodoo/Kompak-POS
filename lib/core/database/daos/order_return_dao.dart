import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/order_returns_table.dart';

part 'order_return_dao.g.dart';

@DriftAccessor(tables: [OrderReturns])
class OrderReturnDao extends DatabaseAccessor<AppDatabase>
    with _$OrderReturnDaoMixin {
  OrderReturnDao(super.db);

  Future<int> insertReturn(OrderReturnsCompanion ret) =>
      into(orderReturns).insert(ret);

  Future<List<OrderReturn>> getReturnsByStore(String storeId) =>
      (select(orderReturns)
            ..where((r) => r.storeId.equals(storeId))
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
          .get();

  Future<OrderReturn?> getReturnByOrderId(String orderId) =>
      (select(orderReturns)..where((r) => r.orderId.equals(orderId)))
          .getSingleOrNull();

  Future<List<OrderReturn>> getReturnsByDateRange(
    String storeId,
    DateTime start,
    DateTime end,
  ) =>
      (select(orderReturns)
            ..where((r) =>
                r.storeId.equals(storeId) &
                r.createdAt.isBiggerOrEqualValue(start) &
                r.createdAt.isSmallerThanValue(end))
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
          .get();

  Future<double> getTotalReturnsByDateRange(
    String storeId,
    DateTime start,
    DateTime end,
  ) async {
    final returns = await getReturnsByDateRange(storeId, start, end);
    return returns.fold<double>(0, (sum, r) => sum + r.returnAmount);
  }

  Stream<List<OrderReturn>> watchReturnsByStore(String storeId) =>
      (select(orderReturns)
            ..where((r) => r.storeId.equals(storeId))
            ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
          .watch();
}
