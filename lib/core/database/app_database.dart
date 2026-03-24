import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/stores_table.dart';
import 'tables/users_table.dart';
import 'tables/categories_table.dart';
import 'tables/products_table.dart';
import 'tables/product_extras_table.dart';
import 'tables/inventory_table.dart';
import 'tables/customers_table.dart';
import 'tables/orders_table.dart';
import 'tables/order_items_table.dart';
import 'tables/payments_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/payment_methods_table.dart';
import 'tables/pricelists_table.dart';
import 'tables/pricelist_items_table.dart';
import 'tables/charges_table.dart';
import 'tables/promotions_table.dart';
import 'tables/combo_groups_table.dart';
import 'tables/combo_group_items_table.dart';
import 'tables/pos_sessions_table.dart';
import 'tables/inventory_movements_table.dart';
import 'tables/order_returns_table.dart';
import 'tables/bom_items_table.dart';
import 'tables/terminals_table.dart';

import 'daos/store_dao.dart';
import 'daos/user_dao.dart';
import 'daos/category_dao.dart';
import 'daos/product_dao.dart';
import 'daos/inventory_dao.dart';
import 'daos/order_dao.dart';
import 'daos/payment_dao.dart';
import 'daos/customer_dao.dart';
import 'daos/sync_queue_dao.dart';
import 'daos/payment_method_dao.dart';
import 'daos/pricelist_dao.dart';
import 'daos/charge_dao.dart';
import 'daos/promotion_dao.dart';
import 'daos/combo_dao.dart';
import 'daos/pos_session_dao.dart';
import 'daos/inventory_movement_dao.dart';
import 'daos/order_return_dao.dart';
import 'daos/bom_dao.dart';
import 'daos/terminal_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Stores,
    Users,
    Categories,
    Products,
    ProductExtras,
    Inventory,
    Customers,
    Orders,
    OrderItems,
    Payments,
    SyncQueue,
    PaymentMethods,
    Pricelists,
    PricelistItems,
    Charges,
    Promotions,
    ComboGroups,
    ComboGroupItems,
    PosSessions,
    InventoryMovements,
    OrderReturns,
    BomItems,
    Terminals,
  ],
  daos: [
    StoreDao,
    UserDao,
    CategoryDao,
    ProductDao,
    InventoryDao,
    OrderDao,
    PaymentDao,
    CustomerDao,
    SyncQueueDao,
    PaymentMethodDao,
    PricelistDao,
    ChargeDao,
    PromotionDao,
    ComboDao,
    PosSessionDao,
    InventoryMovementDao,
    OrderReturnDao,
    BomDao,
    TerminalDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 16;

  static String _hashPin(String pin) {
    const salt = 'kompak_pos_pin_salt_v1';
    final bytes = utf8.encode('$salt:$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(paymentMethods);
          }
          if (from < 3) {
            await m.addColumn(stores, stores.logoUrl);
          }
          if (from < 4) {
            await m.createTable(pricelists);
            await m.createTable(pricelistItems);
            await m.addColumn(orderItems, orderItems.originalPrice);
          }
          if (from < 5) {
            await m.createTable(charges);
            await m.addColumn(orders, orders.chargesJson);
          }
          if (from < 6) {
            await m.createTable(promotions);
            await m.addColumn(orders, orders.promotionsJson);
          }
          if (from < 7) {
            await m.createTable(comboGroups);
            await m.createTable(comboGroupItems);
            await m.addColumn(products, products.isCombo);
          }
          if (from < 8) {
            await m.createTable(posSessions);
            await m.addColumn(orders, orders.sessionId);
          }
          if (from < 9) {
            await m.createTable(inventoryMovements);
            // Hash existing plain-text PINs
            final rows = await customSelect('SELECT id, pin FROM users').get();
            for (final row in rows) {
              final id = row.read<String>('id');
              final pin = row.read<String>('pin');
              // Only hash if not already hashed (SHA-256 = 64 hex chars)
              if (pin.length < 64) {
                final hashed = _hashPin(pin);
                await customStatement(
                  'UPDATE users SET pin = ? WHERE id = ?',
                  [hashed, id],
                );
              }
            }
          }
          if (from < 10) {
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_order_number ON orders (order_number)',
            );
          }
          if (from < 11) {
            await m.addColumn(orderItems, orderItems.costPrice);
          }
          if (from < 12) {
            await m.createTable(orderReturns);
          }
          if (from < 13) {
            await m.addColumn(stores, stores.receiptHeader);
            await m.addColumn(stores, stores.receiptFooter);
          }
          if (from < 14) {
            await m.createTable(bomItems);
            await m.addColumn(products, products.hasBom);
          }
          if (from < 15) {
            await m.createTable(terminals);
            await m.addColumn(users, users.terminalId);
            // Migrate existing terminalId strings from pos_sessions to Terminal rows
            final existing = await customSelect(
              'SELECT DISTINCT terminal_id, store_id FROM pos_sessions WHERE terminal_id IS NOT NULL',
            ).get();
            for (final row in existing) {
              final tid = row.read<String>('terminal_id');
              final sid = row.read<String>('store_id');
              final codeLen = tid.length < 8 ? tid.length : 8;
              await customStatement(
                'INSERT OR IGNORE INTO terminals (id, store_id, name, code, is_active, created_at) VALUES (?, ?, ?, ?, 1, ?)',
                [tid, sid, 'Kasir (Legacy)', tid.substring(0, codeLen), DateTime.now().toIso8601String()],
              );
            }
          }
          if (from < 16) {
            await m.addColumn(stores, stores.parentId);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'kompak_pos',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
