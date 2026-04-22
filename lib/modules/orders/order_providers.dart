import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../core_providers.dart';
import '../auth/auth_providers.dart';

// selectedTerminalFilterProvider was moved to core_providers.dart to break the
// circular import: auth_providers → order_providers → auth_providers.
// Re-exported here so existing import sites don't need to change.
export '../core_providers.dart' show selectedTerminalFilterProvider;

final ordersProvider = StreamProvider<List<Order>>((ref) {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  final terminalId = ref.watch(selectedTerminalFilterProvider);
  final storeIds = ref.watch(effectiveStoreIdsProvider).valueOrNull;
  return db.orderDao.watchOrdersFiltered(
    storeId,
    terminalId: terminalId,
    storeIds: storeIds,
  );
});

final todayOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final db = ref.watch(databaseProvider);
  return db.orderDao.getOrdersByDate(storeId, DateTime.now());
});

final orderDetailProvider = FutureProvider.family<Order?, String>((ref, id) async {
  final db = ref.watch(databaseProvider);
  return db.orderDao.getOrderById(id);
});

final orderItemsProvider = FutureProvider.family<List<OrderItem>, String>((ref, orderId) async {
  final db = ref.watch(databaseProvider);
  return db.orderDao.getItemsForOrder(orderId);
});

final orderPaymentProvider = FutureProvider.family<Payment?, String>((ref, orderId) async {
  final db = ref.watch(databaseProvider);
  return db.paymentDao.getPaymentForOrder(orderId);
});

final activeOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final db = ref.watch(databaseProvider);
  return db.orderDao.getActiveOrders(storeId);
});

final todayOrderCountProvider = FutureProvider<int>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return 0;
  final db = ref.watch(databaseProvider);
  final terminalId = ref.watch(selectedTerminalFilterProvider);
  final storeIds = ref.watch(effectiveStoreIdsProvider).valueOrNull;
  return db.orderDao.getTodayOrderCountFiltered(
    storeId,
    terminalId: terminalId,
    storeIds: storeIds,
  );
});

final todayRevenueProvider = FutureProvider<double>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return 0;
  final db = ref.watch(databaseProvider);
  final terminalId = ref.watch(selectedTerminalFilterProvider);
  final storeIds = ref.watch(effectiveStoreIdsProvider).valueOrNull;
  return db.orderDao.getTodayRevenueFiltered(
    storeId,
    terminalId: terminalId,
    storeIds: storeIds,
  );
});

/// Orders for a specific customer (transaction history)
final customerOrdersProvider =
    FutureProvider.family<List<Order>, String>((ref, customerId) async {
  final db = ref.watch(databaseProvider);
  return db.orderDao.getOrdersByCustomer(customerId);
});

/// COGS (Cost of Goods Sold / HPP) for today's completed orders.
/// Used in dashboard: Gross Profit = Net Sales - COGS
final todayCOGSProvider = FutureProvider<double>((ref) async {
  final orders = await ref.watch(todayOrdersProvider.future);
  if (orders.isEmpty) return 0;
  final db = ref.watch(databaseProvider);
  final orderIds = orders.map((o) => o.id).toList();
  return db.orderDao.calculateCOGS(orderIds);
});

// ISS-028: Efficient provider for last 7 days (instead of loading ALL orders)
final last7DaysOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final db = ref.watch(databaseProvider);
  final terminalId = ref.watch(selectedTerminalFilterProvider);
  final storeIds = ref.watch(effectiveStoreIdsProvider).valueOrNull;
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  return db.orderDao.getOrdersForAnalyticsFiltered(
    storeId,
    start,
    end,
    terminalId: terminalId,
    storeIds: storeIds,
  );
});
