import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';
import '../models/session_report_model.dart';

class PosSessionService {
  final AppDatabase db;
  static const _uuid = Uuid();

  PosSessionService(this.db);

  Future<String> openSession({
    required String storeId,
    required String cashierId,
    required String terminalId,
    required double openingCash,
  }) async {
    // Multi-terminal: Enforce single active session per terminal (not per store)
    final existing = await db.posSessionDao.getActiveSessionForTerminal(terminalId);
    if (existing != null) {
      throw Exception('Terminal ini sudah memiliki sesi aktif. Tutup sesi sebelumnya terlebih dahulu.');
    }

    final id = _uuid.v4();
    await db.posSessionDao.insertSession(PosSessionsCompanion.insert(
      id: id,
      storeId: storeId,
      cashierId: cashierId,
      terminalId: terminalId,
      openingCash: openingCash,
    ));
    return id;
  }

  Future<PosSession?> getActiveSession(String storeId) =>
      db.posSessionDao.getActiveSession(storeId);

  Stream<PosSession?> watchActiveSession(String storeId) =>
      db.posSessionDao.watchActiveSession(storeId);

  /// Watch active session for a specific terminal (multi-terminal support)
  Stream<PosSession?> watchActiveSessionForTerminal(String terminalId) =>
      db.posSessionDao.watchActiveSessionForTerminal(terminalId);

  Future<SessionReport> generateReport(String sessionId) async {
    final session = await db.posSessionDao.getSessionById(sessionId);
    if (session == null) throw Exception('Session not found');

    // Get cashier name
    final cashier = await db.userDao.getUserById(session.cashierId);
    final cashierName = cashier?.name ?? 'Unknown';

    // Get orders and payments
    final orders = await db.posSessionDao.getOrdersForSession(sessionId);
    final payments =
        await db.posSessionDao.getPaymentsForSessionOrders(sessionId);

    // Aggregate totals
    final totalOrders = orders.length;
    double totalSales = 0;
    double totalSubtotal = 0;
    double totalDiscounts = 0;

    for (final order in orders) {
      totalSales += order.total;
      totalSubtotal += order.subtotal;
      totalDiscounts += order.discountAmount;
      // ISS-010: Include promotion discounts
      if (order.promotionsJson != null) {
        try {
          final promos = jsonDecode(order.promotionsJson!) as List;
          for (final p in promos) {
            if (p is Map<String, dynamic> && p['discountAmount'] != null) {
              totalDiscounts += (p['discountAmount'] as num).toDouble();
            }
          }
        } catch (_) {}
      }
    }

    // Breakdown by payment method
    int cashCount = 0, cardCount = 0, qrisCount = 0, transferCount = 0;
    double cashTotal = 0, cardTotal = 0, qrisTotal = 0, transferTotal = 0;
    double cashChange = 0;

    for (final payment in payments) {
      final method = payment.method.toLowerCase();
      switch (method) {
        case 'cash':
          cashCount++;
          cashTotal += payment.amount;
          cashChange += payment.changeAmount;
          break;
        case 'card':
          cardCount++;
          cardTotal += payment.amount;
          break;
        case 'qris':
          qrisCount++;
          qrisTotal += payment.amount;
          break;
        case 'transfer':
          transferCount++;
          transferTotal += payment.amount;
          break;
      }
    }

    final now = session.closedAt ?? DateTime.now();
    final duration = now.difference(session.openedAt);
    final expectedClosingCash =
        session.openingCash + cashTotal - cashChange;

    return SessionReport(
      sessionId: sessionId,
      openedAt: session.openedAt,
      closedAt: session.closedAt,
      cashierName: cashierName,
      duration: duration,
      totalOrders: totalOrders,
      totalSales: totalSales,
      totalSubtotal: totalSubtotal,
      totalDiscounts: totalDiscounts,
      cashBreakdown: PaymentMethodBreakdown(
        method: 'Cash',
        count: cashCount,
        totalAmount: cashTotal,
        totalChange: cashChange,
      ),
      cardBreakdown: PaymentMethodBreakdown(
        method: 'Card',
        count: cardCount,
        totalAmount: cardTotal,
      ),
      qrisBreakdown: PaymentMethodBreakdown(
        method: 'QRIS',
        count: qrisCount,
        totalAmount: qrisTotal,
      ),
      transferBreakdown: PaymentMethodBreakdown(
        method: 'Transfer',
        count: transferCount,
        totalAmount: transferTotal,
      ),
      openingCash: session.openingCash,
      cashReceived: cashTotal,
      cashChangeGiven: cashChange,
      expectedClosingCash: expectedClosingCash,
      actualClosingCash: session.closingCash,
      difference: session.closingCash != null
          ? session.closingCash! - expectedClosingCash
          : null,
    );
  }

  Future<void> closeSession(
    String sessionId, {
    required double closingCash,
    String? notes,
  }) async {
    // Compute expected cash
    final report = await generateReport(sessionId);
    await db.posSessionDao.closeSession(
      id: sessionId,
      closingCash: closingCash,
      expectedCash: report.expectedClosingCash,
      notes: notes,
    );
  }

  Future<List<PosSession>> getSessionHistory(String storeId) =>
      db.posSessionDao.getSessionsByStore(storeId);

  Future<PosSession?> getSessionById(String id) =>
      db.posSessionDao.getSessionById(id);
}
