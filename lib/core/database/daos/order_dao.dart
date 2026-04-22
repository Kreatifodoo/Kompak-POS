import 'package:drift/drift.dart';
import 'package:sqlite3/common.dart';
import '../app_database.dart';
import '../tables/orders_table.dart';
import '../tables/order_items_table.dart';

part 'order_dao.g.dart';

@DriftAccessor(tables: [Orders, OrderItems])
class OrderDao extends DatabaseAccessor<AppDatabase> with _$OrderDaoMixin {
  OrderDao(super.db);

  Future<List<Order>> getOrdersByStore(String storeId) =>
      (select(orders)
            ..where((o) => o.storeId.equals(storeId))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .get();

  Stream<List<Order>> watchOrdersByStore(String storeId) =>
      (select(orders)
            ..where((o) => o.storeId.equals(storeId))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .watch();

  Future<List<Order>> getOrdersByDate(String storeId, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(orders)
          ..where((o) =>
              o.storeId.equals(storeId) &
              o.status.equals('completed') &
              o.createdAt.isBiggerOrEqualValue(start) &
              o.createdAt.isSmallerThanValue(end))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .get();
  }

  Future<Order?> getOrderById(String id) =>
      (select(orders)..where((o) => o.id.equals(id))).getSingleOrNull();

  Future<List<OrderItem>> getItemsForOrder(String orderId) =>
      (select(orderItems)..where((i) => i.orderId.equals(orderId))).get();

  Future<List<Order>> getActiveOrders(String storeId) =>
      (select(orders)
            ..where((o) =>
                o.storeId.equals(storeId) &
                o.status.isIn(['confirmed', 'preparing', 'ready']))
            ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
          .get();

  /// Returns the next sequence number for today's orders.
  /// Uses MAX of existing order numbers with today's date prefix
  /// instead of COUNT — safe even if orders are deleted or there are gaps.
  Future<int> getNextOrderSequence(String datePrefix) async {
    // Find the highest sequence number for this date prefix
    // e.g. datePrefix = "KP240323", order numbers look like "KP240323-0005"
    final result = await customSelect(
      "SELECT MAX(CAST(SUBSTR(order_number, LENGTH(?) + 2) AS INTEGER)) AS max_seq "
      "FROM orders WHERE order_number LIKE ? || '-%'",
      variables: [Variable.withString(datePrefix), Variable.withString(datePrefix)],
      readsFrom: {orders},
    ).getSingleOrNull();

    final maxSeq = result?.read<int?>('max_seq') ?? 0;
    return maxSeq + 1;
  }

  Future<int> insertOrder(OrdersCompanion order, {int maxRetries = 5}) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await into(orders).insert(order);
      } on SqliteException catch (e) {
        // SQLITE_CONSTRAINT_UNIQUE = 2067
        if (e.extendedResultCode == 2067 && attempt < maxRetries - 1) {
          // Extract date prefix (everything before the last "-XXXX")
          final currentNumber = order.orderNumber.value;
          final lastDash = currentNumber.lastIndexOf('-');
          final datePrefix = currentNumber.substring(0, lastDash);
          final nextSequence = await getNextOrderSequence(datePrefix);
          final newNumber =
              '$datePrefix-${nextSequence.toString().padLeft(4, '0')}';
          order = order.copyWith(orderNumber: Value(newNumber));
          continue;
        }
        rethrow;
      }
    }
    return into(orders).insert(order);
  }

  Future<int> insertOrderItem(OrderItemsCompanion item) =>
      into(orderItems).insert(item);

  Future<void> updateOrderStatus(String id, String status) =>
      (update(orders)..where((o) => o.id.equals(id))).write(
        OrdersCompanion(
          status: Value(status),
          completedAt:
              status == 'completed' ? Value(DateTime.now()) : const Value.absent(),
        ),
      );

  // Statistics
  Future<int> getTodayOrderCount(String storeId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final result = await (select(orders)
          ..where((o) =>
              o.storeId.equals(storeId) &
              o.createdAt.isBiggerOrEqualValue(start) &
              o.status.equals('completed')))
        .get();
    return result.length;
  }

  Future<double> getTodayRevenue(String storeId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final result = await (select(orders)
          ..where((o) =>
              o.storeId.equals(storeId) &
              o.createdAt.isBiggerOrEqualValue(start) &
              o.status.equals('completed')))
        .get();
    double total = 0;
    for (final o in result) {
      total += o.total;
    }
    return total;
  }

  /// Get all completed orders for a specific customer
  Future<List<Order>> getOrdersByCustomer(String customerId) =>
      (select(orders)
            ..where((o) =>
                o.customerId.equals(customerId) &
                o.status.equals('completed'))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .get();

  Future<List<Order>> getOrdersByDateRange(
    String storeId,
    DateTime start,
    DateTime end,
  ) =>
      (select(orders)
            ..where((o) =>
                o.storeId.equals(storeId) &
                o.status.equals('completed') &
                o.createdAt.isBiggerOrEqualValue(start) &
                o.createdAt.isSmallerThanValue(end))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .get();

  /// Get completed + returned orders for analytics
  Future<List<Order>> getOrdersForAnalytics(
    String storeId,
    DateTime start,
    DateTime end,
  ) =>
      (select(orders)
            ..where((o) =>
                o.storeId.equals(storeId) &
                o.status.isIn(['completed', 'returned']) &
                o.createdAt.isBiggerOrEqualValue(start) &
                o.createdAt.isSmallerThanValue(end))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .get();

  // ── Filtered query methods (terminal + multi-branch) ──

  /// Helper to build store filter expression
  Expression<bool> _storeFilter(
    GeneratedColumn<String> col,
    String storeId, {
    List<String>? storeIds,
  }) {
    if (storeIds != null && storeIds.isNotEmpty) {
      return col.isIn(storeIds);
    }
    return col.equals(storeId);
  }

  /// Watch orders with optional terminal + multi-branch filter
  Stream<List<Order>> watchOrdersFiltered(
    String storeId, {
    String? terminalId,
    List<String>? storeIds,
  }) {
    return (select(orders)
          ..where((o) {
            var expr = _storeFilter(o.storeId, storeId, storeIds: storeIds);
            if (terminalId != null) {
              expr = expr & o.terminalId.equals(terminalId);
            }
            return expr;
          })
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  /// Analytics orders with optional terminal + multi-branch filter
  Future<List<Order>> getOrdersForAnalyticsFiltered(
    String storeId,
    DateTime start,
    DateTime end, {
    String? terminalId,
    List<String>? storeIds,
  }) {
    return (select(orders)
          ..where((o) {
            var expr = _storeFilter(o.storeId, storeId, storeIds: storeIds) &
                o.status.isIn(['completed', 'returned']) &
                o.createdAt.isBiggerOrEqualValue(start) &
                o.createdAt.isSmallerThanValue(end);
            if (terminalId != null) {
              expr = expr & o.terminalId.equals(terminalId);
            }
            return expr;
          })
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .get();
  }

  /// Today order count with optional terminal filter
  Future<int> getTodayOrderCountFiltered(
    String storeId, {
    String? terminalId,
    List<String>? storeIds,
  }) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final result = await (select(orders)
          ..where((o) {
            var expr = _storeFilter(o.storeId, storeId, storeIds: storeIds) &
                o.createdAt.isBiggerOrEqualValue(start) &
                o.status.equals('completed');
            if (terminalId != null) {
              expr = expr & o.terminalId.equals(terminalId);
            }
            return expr;
          }))
        .get();
    return result.length;
  }

  /// Today revenue with optional terminal filter
  Future<double> getTodayRevenueFiltered(
    String storeId, {
    String? terminalId,
    List<String>? storeIds,
  }) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final result = await (select(orders)
          ..where((o) {
            var expr = _storeFilter(o.storeId, storeId, storeIds: storeIds) &
                o.createdAt.isBiggerOrEqualValue(start) &
                o.status.equals('completed');
            if (terminalId != null) {
              expr = expr & o.terminalId.equals(terminalId);
            }
            return expr;
          }))
        .get();
    double total = 0;
    for (final o in result) {
      total += o.total;
    }
    return total;
  }

  /// Calculate total COGS (Cost of Goods Sold / HPP) for a list of order IDs.
  /// Uses costPrice stored in order_items. Falls back to product table costPrice
  /// for older orders that don't have costPrice in order_items.
  Future<double> calculateCOGS(List<String> orderIds) async {
    if (orderIds.isEmpty) return 0;

    // Use SQL for efficient batch calculation
    final placeholders = orderIds.map((_) => '?').join(',');
    final result = await customSelect(
      'SELECT COALESCE(SUM(COALESCE(oi.cost_price, p.cost_price, 0) * oi.quantity), 0) AS total_cogs '
      'FROM order_items oi '
      'LEFT JOIN products p ON oi.product_id = p.id '
      'WHERE oi.order_id IN ($placeholders)',
      variables: orderIds.map((id) => Variable.withString(id)).toList(),
      readsFrom: {orderItems},
    ).getSingleOrNull();

    return result?.read<double>('total_cogs') ?? 0;
  }
}
