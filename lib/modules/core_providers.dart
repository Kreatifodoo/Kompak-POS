import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/inventory_service.dart';
import '../services/auth_service.dart';
import '../services/printer_service.dart';
import '../services/receipt_service.dart';
import '../services/user_service.dart';
import '../services/customer_service.dart';
import '../services/payment_method_service.dart';
import '../services/pricelist_service.dart';
import '../services/charge_service.dart';
import '../services/promotion_service.dart';
import '../services/combo_service.dart';
import '../services/bom_service.dart';
import '../services/pos_session_service.dart';
import '../services/terminal_service.dart';
import '../services/store_service.dart';
import '../services/telegram_service.dart';
import '../services/csv_export_service.dart';
import '../services/pos_query_service.dart';
import '../services/telegram_chatbot_service.dart';
import '../services/attendance_service.dart';
import '../services/backup_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final cartServiceProvider = Provider<CartService>((ref) => CartService());

final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(ref.watch(databaseProvider));
});

final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService(ref.watch(databaseProvider));
});

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(ref.watch(databaseProvider));
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    db: ref.watch(databaseProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService(ref.watch(sharedPreferencesProvider));
});

final receiptServiceProvider = Provider<ReceiptService>((ref) {
  return ReceiptService();
});

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(databaseProvider));
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  return CustomerService(ref.watch(databaseProvider));
});

final paymentMethodServiceProvider = Provider<PaymentMethodService>((ref) {
  return PaymentMethodService(ref.watch(databaseProvider));
});

final pricelistServiceProvider = Provider<PricelistService>((ref) {
  return PricelistService(ref.watch(databaseProvider));
});

final chargeServiceProvider = Provider<ChargeService>((ref) {
  return ChargeService(ref.watch(databaseProvider));
});

final promotionServiceCoreProvider = Provider<PromotionService>((ref) {
  return PromotionService(ref.watch(databaseProvider));
});

final comboServiceProvider = Provider<ComboService>((ref) {
  return ComboService(ref.watch(databaseProvider));
});

final bomServiceProvider = Provider<BomService>((ref) {
  return BomService(ref.watch(databaseProvider));
});

final posSessionServiceProvider = Provider<PosSessionService>((ref) {
  return PosSessionService(ref.watch(databaseProvider));
});

final terminalServiceProvider = Provider<TerminalService>((ref) {
  return TerminalService(ref.watch(databaseProvider));
});

final storeServiceProvider = Provider<StoreService>((ref) {
  return StoreService(ref.watch(databaseProvider));
});

final telegramServiceProvider = Provider<TelegramService>((ref) {
  return TelegramService(
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  return CsvExportService(ref.watch(databaseProvider));
});

final posQueryServiceProvider = Provider<PosQueryService>((ref) {
  return PosQueryService(ref.watch(databaseProvider));
});

final telegramChatbotServiceProvider = Provider<TelegramChatbotService>((ref) {
  // Use ref.read() to avoid recreating service when dependencies rebuild.
  // This service holds a Timer for polling — must be a stable singleton.
  ref.keepAlive();
  final service = TelegramChatbotService(
    prefs: ref.read(sharedPreferencesProvider),
    db: ref.read(databaseProvider),
    queryService: ref.read(posQueryServiceProvider),
    csvService: ref.read(csvExportServiceProvider),
  );
  ref.onDispose(() => service.stopPolling());
  return service;
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    db: ref.watch(databaseProvider),
    telegram: ref.watch(telegramServiceProvider),
  );
});

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService(
    db: ref.watch(databaseProvider),
    telegram: ref.watch(telegramServiceProvider),
  );
});

// @deprecated — Use currentTerminalIdProvider instead.
// Legacy fallback for standalone mode (user not assigned to a terminal).
// Will be removed in a future version.
final terminalIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  const key = 'terminal_id';
  var terminalId = prefs.getString(key);
  if (terminalId == null) {
    terminalId = 'T-${const Uuid().v4().substring(0, 8)}';
    prefs.setString(key, terminalId);
  }
  return terminalId;
});

/// Current terminal ID for the active user session.
/// Set during login if user has a terminalId assigned.
/// Falls back to terminalIdProvider (legacy generated ID) if null.
final currentTerminalIdProvider = StateProvider<String?>((ref) => null);

/// Current terminal object for the active session.
final currentTerminalProvider = StateProvider<Terminal?>((ref) => null);

/// Selected terminal filter for report screens (null = all terminals).
/// Defined here (not in order_providers) to avoid circular imports when
/// auth_providers needs to clear it on logout.
final selectedTerminalFilterProvider = StateProvider<String?>((ref) => null);
