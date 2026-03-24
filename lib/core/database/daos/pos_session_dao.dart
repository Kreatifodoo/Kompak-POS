import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/pos_sessions_table.dart';
import '../tables/orders_table.dart';
import '../tables/payments_table.dart';

part 'pos_session_dao.g.dart';

@DriftAccessor(tables: [PosSessions, Orders, Payments])
class PosSessionDao extends DatabaseAccessor<AppDatabase>
    with _$PosSessionDaoMixin {
  PosSessionDao(super.db);

  Future<PosSession?> getActiveSession(String storeId) =>
      (select(posSessions)
            ..where(
                (s) => s.storeId.equals(storeId) & s.status.equals('open')))
          .getSingleOrNull();

  Stream<PosSession?> watchActiveSession(String storeId) =>
      (select(posSessions)
            ..where(
                (s) => s.storeId.equals(storeId) & s.status.equals('open')))
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
}
