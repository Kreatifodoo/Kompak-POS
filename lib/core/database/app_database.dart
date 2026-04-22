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
import 'tables/roles_table.dart';
import 'tables/rbac_permissions_table.dart';
import 'tables/role_permissions_table.dart';
import 'tables/attendances_table.dart';

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
import 'daos/role_dao.dart';
import 'daos/rbac_permission_dao.dart';
import 'daos/attendance_dao.dart';

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
    Roles,
    RbacPermissions,
    RolePermissions,
    Attendances,
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
    RoleDao,
    RbacPermissionDao,
    AttendanceDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 21;

  static String _hashPin(String pin) {
    const salt = 'kompak_pos_pin_salt_v1';
    final bytes = utf8.encode('$salt:$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedRbacDefaults(customStatement);
          // Performance indexes for common query patterns
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_orders_store_date_status '
            'ON orders (store_id, created_at DESC, status)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_orders_session ON orders (session_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_inventory_product ON inventory (product_id)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sessions_terminal_status '
            'ON pos_sessions (terminal_id, status)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue (status, created_at)',
          );
        },
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
          if (from < 17) {
            await m.createTable(roles);
            await m.createTable(rbacPermissions);
            await m.createTable(rolePermissions);
            await _seedRbacDefaults(customStatement);
          }
          if (from < 18) {
            // BUG-SIT-PERF: Add composite indexes for common query patterns.
            // Prevents full table scan once orders/sessions grow past 10k rows.
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_orders_store_date_status '
              'ON orders (store_id, created_at DESC, status)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_orders_session '
              'ON orders (session_id)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_inventory_product '
              'ON inventory (product_id)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_sessions_terminal_status '
              'ON pos_sessions (terminal_id, status)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_sync_queue_status '
              'ON sync_queue (status, created_at)',
            );
          }
          if (from < 19) {
            await m.createTable(attendances);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_attendance_user_ts '
              'ON attendances (user_id, timestamp DESC)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_attendance_store_ts '
              'ON attendances (store_id, timestamp DESC)',
            );
          }
          if (from < 20) {
            // Add address column for reverse geocoding results
            try {
              await customStatement(
                "ALTER TABLE attendances ADD COLUMN address TEXT NOT NULL DEFAULT ''",
              );
            } catch (_) {
              // Column may already exist from fresh install on v19+
            }
          }
          if (from < 21) {
            // Multi-user attendance: add per-user access flag.
            // Existing users default to false; admins can opt them in via the
            // user form. Owner/admin/branch_manager are auto-granted at
            // runtime via UserDao.canAccessAttendance() helper.
            try {
              await customStatement(
                'ALTER TABLE users ADD COLUMN can_access_attendance INTEGER NOT NULL DEFAULT 0',
              );
            } catch (_) {
              // Column may already exist from fresh install on v21+
            }
          }
        },
      );

  /// Seed default RBAC roles, permissions, and role-permission mappings.
  /// Uses raw SQL via [exec] because DAOs may not be ready during migration.
  static Future<void> _seedRbacDefaults(
      Future<void> Function(String, [List<Object?>?]) exec) async {
    final now = DateTime.now().toIso8601String();

    // ── 1. System roles ──
    const rolesSql = '''
INSERT OR IGNORE INTO roles (id, store_id, name, description, is_system, created_at) VALUES
  ('owner', NULL, 'Owner', 'Full system access', 1, ?),
  ('admin', NULL, 'Admin', 'Administrative access', 1, ?),
  ('branch_manager', NULL, 'Branch Manager', 'Branch-level management', 1, ?),
  ('cashier', NULL, 'Cashier', 'POS operations', 1, ?),
  ('kitchen', NULL, 'Kitchen', 'Kitchen display only', 1, ?)
''';
    await exec(rolesSql, [now, now, now, now, now]);

    // ── 2. Permission definitions ──
    const permSql = '''
INSERT OR IGNORE INTO rbac_permissions (id, module, name, description) VALUES
  ('dashboard.view', 'dashboard', 'Lihat Dashboard', 'Akses halaman dashboard'),
  ('reports.view', 'reports', 'Lihat Laporan', 'Akses menu laporan'),
  ('reports.sales', 'reports', 'Laporan Penjualan', 'Lihat laporan penjualan'),
  ('reports.sessions', 'reports', 'Laporan Sesi', 'Lihat laporan sesi kasir'),
  ('master_data.manage', 'master_data', 'Kelola Master Data', 'Kelola produk, kategori, dll'),
  ('branches.manage', 'branches', 'Kelola Cabang', 'Buat dan edit cabang'),
  ('branches.view_all', 'branches', 'Lihat Semua Cabang', 'Lihat data semua cabang'),
  ('users.manage', 'users', 'Kelola Pengguna', 'Kelola user dan role'),
  ('pos.access', 'pos', 'Akses POS', 'Akses halaman kasir'),
  ('pos.returns', 'pos', 'Proses Retur', 'Memproses retur order'),
  ('pos.discount', 'pos', 'Beri Diskon', 'Memberikan diskon'),
  ('kitchen.view', 'kitchen', 'Lihat Kitchen Display', 'Akses kitchen display'),
  ('inventory.view', 'inventory', 'Lihat Inventory', 'Lihat stok barang'),
  ('inventory.restock', 'inventory', 'Restock Inventory', 'Restock barang masuk'),
  ('inventory.adjust', 'inventory', 'Adjustment Inventory', 'Adjustment stok'),
  ('inventory.report', 'inventory', 'Laporan Inventory', 'Lihat laporan inventory'),
  ('orders.view', 'orders', 'Lihat Order', 'Lihat daftar order'),
  ('settings.view', 'settings', 'Lihat Settings', 'Akses halaman settings')
''';
    await exec(permSql);

    // ── 3. Role → Permission mappings ──
    const allPerms = [
      'dashboard.view', 'reports.view', 'reports.sales', 'reports.sessions',
      'master_data.manage', 'branches.manage', 'branches.view_all',
      'users.manage', 'pos.access', 'pos.returns', 'pos.discount',
      'kitchen.view', 'inventory.view', 'inventory.restock',
      'inventory.adjust', 'inventory.report', 'orders.view', 'settings.view',
    ];

    // Owner gets ALL
    for (final p in allPerms) {
      await exec(
        'INSERT OR IGNORE INTO role_permissions (role_id, permission_id) VALUES (?, ?)',
        ['owner', p],
      );
    }

    // Admin gets all except branches.view_all
    for (final p in allPerms) {
      if (p == 'branches.view_all') continue;
      await exec(
        'INSERT OR IGNORE INTO role_permissions (role_id, permission_id) VALUES (?, ?)',
        ['admin', p],
      );
    }

    // Branch Manager
    const bmPerms = [
      'dashboard.view', 'reports.view', 'reports.sales', 'reports.sessions',
      'master_data.manage', 'pos.access', 'pos.returns', 'pos.discount',
      'kitchen.view', 'inventory.view', 'inventory.restock',
      'inventory.adjust', 'inventory.report', 'orders.view', 'settings.view',
    ];
    for (final p in bmPerms) {
      await exec(
        'INSERT OR IGNORE INTO role_permissions (role_id, permission_id) VALUES (?, ?)',
        ['branch_manager', p],
      );
    }

    // Cashier
    const cashierPerms = ['pos.access', 'pos.discount', 'orders.view'];
    for (final p in cashierPerms) {
      await exec(
        'INSERT OR IGNORE INTO role_permissions (role_id, permission_id) VALUES (?, ?)',
        ['cashier', p],
      );
    }

    // Kitchen
    await exec(
      'INSERT OR IGNORE INTO role_permissions (role_id, permission_id) VALUES (?, ?)',
      ['kitchen', 'kitchen.view'],
    );
  }

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
