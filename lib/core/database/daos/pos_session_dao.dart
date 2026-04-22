import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/pos_sessions_table.dart';
import '../tables/orders_table.dart';
import '../tables/order_items_table.dart';
import '../tables/payments_table.dart';

part 'pos_session_dao.g.dart';

@DriftAccessor(tables: [PosSessions, Orders, OrderItems, Payments])
class PosSessionDao extends DatabaseAccessor<AppDatabase>
    with _$PosSessionDaoMixin {
  PosSessionDao(super.db);

  /// Get any one active session for a store.
  /// NOTE: With multi-terminal, a store may have multiple active sessions (one
  /// per terminal). Use [getActiveSessionForTerminal] for per-terminal lookups.
  /// This method returns the first match to avoid StateError crashes.
  Future<PosSession?> getActiveSession(String storeId) async {
    final results = await (select(posSessions)
          ..where(
              (s) => s.storeId.equals(storeId) & s.status.equals('open'))
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }

  /// Watch any one active session for a store.
  /// NOTE: With multi-terminal, prefer [watchActiveSessionForTerminal].
  Stream<PosSession?> watchActiveSession(String storeId) =>
      (select(posSessions)
            ..where(
                (s) => s.storeId.equals(storeId) & s.status.equals('open'))
            ..limit(1))
          .watchSingleOrNull();

  /// Get active session for a specific terminal (multi-terminal support)
  Future<PosSession?> getActiveSessionForTerminal(String terminalId) =>
      (select(posSessions)
            ..where((s) =>
                s.terminalId.equals(terminalId) & s.status.equals('open')))
          .getSingleOrNull();

  /// Watch active session for a specific terminal (multi-terminal support)
  Stream<PosSession?> watchActiveSessionForTerminal(String terminalId) =>
      (select(posSessions)
            ..where((s) =>
                s.terminalId.equals(terminalId) & s.status.equals('open')))
          .watchSingleOrNull();

  Future<void> insertSession(PosSessionsCompanion entry) =>
      into(posSessions).insert(entry);

  Future<void> closeSession({
    required String id,
    required double closingCash,
    required double expectedCash,
    String? notes,
  }) =>
      (update(posSessions)..where((s) => s.id.equals(id))).write(
        PosSessionsCompanion(
          status: const Value('closed'),
          closedAt: Value(DateTime.now()),
          closingCash: Value(closingCash),
          expectedCash: Value(expectedCash),
          notes: Value(notes),
        ),
      );

  Future<List<PosSession>> getSessionsByStore(String storeId) =>
      (select(posSessions)
            ..where((s) => s.storeId.equals(storeId))
            ..orderBy([(s) => OrderingTerm.desc(s.openedAt)]))
          .get();

  /// Filtered session history with optional terminal + multi-branch filter
  Future<List<PosSession>> getSessionsFiltered(
    String storeId, {
    String? terminalId,
    List<String>? storeIds,
  }) {
    return (select(posSessions)
          ..where((s) {
            var expr = (storeIds != null && storeIds.isNotEmpty)
                ? s.storeId.isIn(storeIds)
                : s.storeId.equals(storeId);
            if (terminalId != null) {
              expr = expr & s.terminalId.equals(terminalId);
            }
            return expr;
          })
          ..orderBy([(s) => OrderingTerm.desc(s.openedAt)]))
        .get();
  }

  Future<PosSession?> getSessionById(String id) =>
      (select(posSessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<List<Order>> getOrdersForSession(String sessionId) =>
      (select(orders)
            ..where((o) => o.sessionId.equals(sessionId))
            ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
          .get();

  Future<List<Payment>> getPaymentsForSessionOrders(String sessionId) async {
    final query = select(payments).join([
      innerJoin(orders, orders.id.equalsExp(payments.orderId)),
    ])
      ..where(orders.sessionId.equals(sessionId));
    final rows = await query.get();
    return rows.map((row) => row.readTable(payments)).toList();
  }

  /// Top products by quantity sold for a session (for Telegram report)
  Future<List<TopProductResult>> getTopProductsForSession(
    String sessionId, {
    int limit = 3,
  }) async {
    final query = customSelect(
      'SELECT oi.product_name, SUM(oi.quantity) AS total_qty '
      'FROM order_items oi '
      'INNER JOIN orders o ON o.id = oi.order_id '
      'WHERE o.session_id = ? AND o.status = \'completed\' '
      'GROUP BY oi.product_id '
      'ORDER BY total_qty DESC '
      'LIMIT ?',
      variables: [Variable.withString(sessionId), Variable.withInt(limit)],
      readsFrom: {orderItems, orders},
    );
    final rows = await query.get();
    return rows
        .map((row) => TopProductResult(
              productName: row.read<String>('product_name'),
              totalQty: row.read<int>('total_qty'),
            ))
        .toList();
  }

  /// Orders with payment method for CSV export
  Future<List<OrderCsvRow>> getOrdersForCsvExport(String sessionId) async {
    final query = select(orders).join([
      innerJoin(payments, payments.orderId.equalsExp(orders.id)),
    ])
      ..where(orders.sessionId.equals(sessionId) &
          orders.status.equals('completed'))
      ..orderBy([OrderingTerm.asc(orders.createdAt)]);
    final rows = await query.get();
    return rows
        .map((row) => OrderCsvRow(
              orderId: row.readTable(orders).id,
              dateTime: row.readTable(orders).createdAt,
              total: row.readTable(orders).total,
              paymentMethod: row.readTable(payments).method,
            ))
        .toList();
  }
}

class TopProductResult {
  final String productName;
  final int totalQty;
  const TopProductResult({required this.productName, required this.totalQty});
}

class OrderCsvRow {
  final String orderId;
  final DateTime dateTime;
  final double total;
  final String paymentMethod;
  const OrderCsvRow({
    required this.orderId,
    required this.dateTime,
    required this.total,
    required this.paymentMethod,
  });
}
