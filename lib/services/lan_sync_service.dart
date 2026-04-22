import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../core/database/app_database.dart';

class LanSyncService {
  final AppDatabase _db;
  final _log = Logger(printer: SimplePrinter());
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  HttpServer? _server;
  bool get isRunning => _server != null;

  LanSyncService(this._db);

  // ─── SERVER ───────────────────────────────────────────────

  Future<void> startServer() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
    _log.i('LAN Sync server started on port 8080');
    _server!.listen(_handleRequest);
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    _log.i('LAN Sync server stopped');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // CORS headers for flexibility
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.contentType = ContentType.json;

    if (request.method == 'POST' && request.uri.path == '/sync') {
      await _handleSync(request);
    } else if (request.method == 'GET' && request.uri.path == '/ping') {
      request.response
        ..statusCode = 200
        ..write(jsonEncode({'status': 'ok', 'app': 'Kompak POS'}));
      await request.response.close();
    } else {
      request.response
        ..statusCode = 404
        ..write(jsonEncode({'error': 'Not found'}));
      await request.response.close();
    }
  }

  Future<void> _handleSync(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final sessionData = data['session'] as Map<String, dynamic>;
      final sessionId = sessionData['id'] as String;

      // Check for duplicate session
      final existing = await _db.posSessionDao.getSessionById(sessionId);
      if (existing != null) {
        request.response
          ..statusCode = 409
          ..write(jsonEncode({
            'error': 'Session sudah ada',
            'session_id': sessionId,
          }));
        await request.response.close();
        return;
      }

      // Insert all data in a transaction
      await _db.transaction(() async {
        // Upsert store if provided
        if (data.containsKey('store')) {
          await _upsertStore(data['store'] as Map<String, dynamic>);
        }

        // Upsert terminal if provided
        if (data.containsKey('terminal')) {
          await _upsertTerminal(data['terminal'] as Map<String, dynamic>);
        }

        // Upsert cashier user if provided
        if (data.containsKey('cashier')) {
          await _upsertUser(data['cashier'] as Map<String, dynamic>);
        }

        // Insert session
        await _insertSession(sessionData);

        // Insert orders with items and payments
        final ordersData = data['orders'] as List<dynamic>? ?? [];
        for (final orderWrapper in ordersData) {
          final orderMap = orderWrapper as Map<String, dynamic>;
          await _insertOrder(orderMap['order'] as Map<String, dynamic>);

          final items = orderMap['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            await _insertOrderItem(item as Map<String, dynamic>);
          }

          final payments = orderMap['payments'] as List<dynamic>? ?? [];
          for (final payment in payments) {
            await _insertPayment(payment as Map<String, dynamic>);
          }
        }
      });

      request.response
        ..statusCode = 200
        ..write(jsonEncode({'status': 'ok', 'session_id': sessionId}));
      await request.response.close();
      _log.i('Received session $sessionId via LAN sync');
    } catch (e) {
      _log.e('LAN sync error: $e');
      request.response
        ..statusCode = 500
        ..write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  // ─── CLIENT ───────────────────────────────────────────────

  /// Send a closed session to another device via LAN
  Future<void> sendSession(String targetIp, String sessionId) async {
    final payload = await _buildSessionPayload(sessionId);
    await _withRetry(() => _dio.post(
          'http://$targetIp:8080/sync',
          data: payload,
        ));
  }

  /// Ping target device to verify connectivity
  Future<bool> pingDevice(String targetIp) async {
    try {
      final response = await _dio.get('http://$targetIp:8080/ping');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get this device's local IP address
  static Future<String?> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── PAYLOAD BUILDER ─────────────────────────────────────

  Future<Map<String, dynamic>> _buildSessionPayload(String sessionId) async {
    final session = await _db.posSessionDao.getSessionById(sessionId);
    if (session == null) throw Exception('Session not found: $sessionId');

    final orders = await _db.posSessionDao.getOrdersForSession(sessionId);
    final ordersPayload = <Map<String, dynamic>>[];

    for (final order in orders) {
      // Get items for this order
      final items = await ((_db.select(_db.orderItems)
            ..where((oi) => oi.orderId.equals(order.id)))
          .get());

      // Get payments for this order
      final payments = await ((_db.select(_db.payments)
            ..where((p) => p.orderId.equals(order.id)))
          .get());

      ordersPayload.add({
        'order': _orderToMap(order),
        'items': items.map(_orderItemToMap).toList(),
        'payments': payments.map(_paymentToMap).toList(),
      });
    }

    // Get referenced entities
    final store =
        await (_db.select(_db.stores)..where((s) => s.id.equals(session.storeId)))
            .getSingleOrNull();
    final terminal = await (_db.select(_db.terminals)
          ..where((t) => t.id.equals(session.terminalId)))
        .getSingleOrNull();
    final cashier =
        await (_db.select(_db.users)..where((u) => u.id.equals(session.cashierId)))
            .getSingleOrNull();

    return {
      'session': _sessionToMap(session),
      'orders': ordersPayload,
      if (store != null) 'store': _storeToMap(store),
      if (terminal != null) 'terminal': _terminalToMap(terminal),
      if (cashier != null) 'cashier': _userToMap(cashier),
    };
  }

  // ─── SERIALIZATION ───────────────────────────────────────

  Map<String, dynamic> _sessionToMap(PosSession s) => {
        'id': s.id,
        'store_id': s.storeId,
        'terminal_id': s.terminalId,
        'cashier_id': s.cashierId,
        'status': s.status,
        'opening_cash': s.openingCash,
        'closing_cash': s.closingCash,
        'expected_cash': s.expectedCash,
        'opened_at': s.openedAt.toIso8601String(),
        'closed_at': s.closedAt?.toIso8601String(),
        'notes': s.notes,
      };

  Map<String, dynamic> _orderToMap(Order o) => {
        'id': o.id,
        'store_id': o.storeId,
        'terminal_id': o.terminalId,
        'cashier_id': o.cashierId,
        'customer_id': o.customerId,
        'order_number': o.orderNumber,
        'status': o.status,
        'subtotal': o.subtotal,
        'discount_amount': o.discountAmount,
        'discount_type': o.discountType,
        'tax_amount': o.taxAmount,
        'total': o.total,
        'charges_json': o.chargesJson,
        'promotions_json': o.promotionsJson,
        'session_id': o.sessionId,
        'notes': o.notes,
        'created_at': o.createdAt.toIso8601String(),
        'completed_at': o.completedAt?.toIso8601String(),
      };

  Map<String, dynamic> _orderItemToMap(OrderItem oi) => {
        'id': oi.id,
        'order_id': oi.orderId,
        'product_id': oi.productId,
        'product_name': oi.productName,
        'product_price': oi.productPrice,
        'quantity': oi.quantity,
        'extras_json': oi.extrasJson,
        'subtotal': oi.subtotal,
        'original_price': oi.originalPrice,
        'cost_price': oi.costPrice,
        'notes': oi.notes,
      };

  Map<String, dynamic> _paymentToMap(Payment p) => {
        'id': p.id,
        'order_id': p.orderId,
        'method': p.method,
        'amount': p.amount,
        'change_amount': p.changeAmount,
        'reference_number': p.referenceNumber,
      };

  Map<String, dynamic> _storeToMap(Store s) => {
        'id': s.id,
        'name': s.name,
        'address': s.address,
      };

  Map<String, dynamic> _terminalToMap(Terminal t) => {
        'id': t.id,
        'store_id': t.storeId,
        'name': t.name,
        'code': t.code,
      };

  Map<String, dynamic> _userToMap(User u) => {
        'id': u.id,
        'store_id': u.storeId,
        'name': u.name,
        'role': u.role,
      };

  // ─── DB INSERT HELPERS ───────────────────────────────────

  Future<void> _upsertStore(Map<String, dynamic> data) async {
    final existing = await (_db.select(_db.stores)
          ..where((s) => s.id.equals(data['id'] as String)))
        .getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.stores).insert(StoresCompanion.insert(
          id: data['id'] as String,
          name: data['name'] as String,
          address: Value(data['address'] as String?),
        ));
  }

  Future<void> _upsertTerminal(Map<String, dynamic> data) async {
    final existing = await (_db.select(_db.terminals)
          ..where((t) => t.id.equals(data['id'] as String)))
        .getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.terminals).insert(TerminalsCompanion.insert(
          id: data['id'] as String,
          storeId: data['store_id'] as String,
          name: data['name'] as String,
          code: data['code'] as String,
        ));
  }

  Future<void> _upsertUser(Map<String, dynamic> data) async {
    final existing = await (_db.select(_db.users)
          ..where((u) => u.id.equals(data['id'] as String)))
        .getSingleOrNull();
    if (existing != null) return;
    await _db.into(_db.users).insert(UsersCompanion.insert(
          id: data['id'] as String,
          storeId: Value(data['store_id'] as String?),
          name: data['name'] as String,
          role: Value(data['role'] as String),
          pin: '000000', // Placeholder - synced user can't login without real PIN
        ));
  }

  Future<void> _insertSession(Map<String, dynamic> data) async {
    await _db.into(_db.posSessions).insert(PosSessionsCompanion.insert(
          id: data['id'] as String,
          storeId: data['store_id'] as String,
          terminalId: data['terminal_id'] as String,
          cashierId: data['cashier_id'] as String,
          status: Value(data['status'] as String),
          openingCash: (data['opening_cash'] as num).toDouble(),
          closingCash: Value(data['closing_cash'] != null
              ? (data['closing_cash'] as num).toDouble()
              : null),
          expectedCash: Value(data['expected_cash'] != null
              ? (data['expected_cash'] as num).toDouble()
              : null),
          openedAt: Value(DateTime.parse(data['opened_at'] as String)),
          closedAt: Value(data['closed_at'] != null
              ? DateTime.parse(data['closed_at'] as String)
              : null),
          notes: Value(data['notes'] as String?),
        ));
  }

  Future<void> _insertOrder(Map<String, dynamic> data) async {
    await _db.into(_db.orders).insert(OrdersCompanion.insert(
          id: data['id'] as String,
          storeId: data['store_id'] as String,
          terminalId: data['terminal_id'] as String,
          cashierId: data['cashier_id'] as String,
          customerId: Value(data['customer_id'] as String?),
          orderNumber: data['order_number'] as String,
          status: Value(data['status'] as String),
          subtotal: (data['subtotal'] as num).toDouble(),
          discountAmount: Value((data['discount_amount'] as num?)?.toDouble() ?? 0),
          discountType: Value(data['discount_type'] as String?),
          taxAmount: Value((data['tax_amount'] as num?)?.toDouble() ?? 0),
          total: (data['total'] as num).toDouble(),
          chargesJson: Value(data['charges_json'] as String?),
          promotionsJson: Value(data['promotions_json'] as String?),
          sessionId: Value(data['session_id'] as String?),
          notes: Value(data['notes'] as String?),
          createdAt: Value(DateTime.parse(data['created_at'] as String)),
          completedAt: Value(data['completed_at'] != null
              ? DateTime.parse(data['completed_at'] as String)
              : null),
        ));
  }

  Future<void> _insertOrderItem(Map<String, dynamic> data) async {
    await _db.into(_db.orderItems).insert(OrderItemsCompanion.insert(
          id: data['id'] as String,
          orderId: data['order_id'] as String,
          productId: data['product_id'] as String,
          productName: data['product_name'] as String,
          productPrice: (data['product_price'] as num).toDouble(),
          quantity: (data['quantity'] as num).toInt(),
          extrasJson: Value(data['extras_json'] as String?),
          subtotal: (data['subtotal'] as num).toDouble(),
          originalPrice: Value((data['original_price'] as num?)?.toDouble()),
          costPrice: Value((data['cost_price'] as num?)?.toDouble()),
          notes: Value(data['notes'] as String?),
        ));
  }

  Future<void> _insertPayment(Map<String, dynamic> data) async {
    await _db.into(_db.payments).insert(PaymentsCompanion.insert(
          id: data['id'] as String,
          orderId: data['order_id'] as String,
          method: data['method'] as String,
          amount: (data['amount'] as num).toDouble(),
          changeAmount:
              Value((data['change_amount'] as num?)?.toDouble() ?? 0),
          referenceNumber: Value(data['reference_number'] as String?),
        ));
  }

  // ─── RETRY ───────────────────────────────────────────────

  Future<Response> _withRetry(Future<Response> Function() request) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await request();
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    throw Exception('Unreachable');
  }
}
