import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config/app_config.dart';
import '../core/database/app_database.dart';
import 'telegram_service.dart';

class BackupService {
  final AppDatabase _db;
  final TelegramService _telegram;

  BackupService({required AppDatabase db, required TelegramService telegram})
      : _db = db,
        _telegram = telegram;

  // All tables in parent→child order (for INSERT).
  // DELETE uses reversed order.
  static const _tableOrder = [
    'stores',
    'users',
    'roles',
    'terminals',
    'categories',
    'products',
    'product_extras',
    'customers',
    'payment_methods',
    'pricelists',
    'pricelist_items',
    'charges',
    'promotions',
    'inventory',
    'orders',
    'pos_sessions',
    'sync_queue',
    'order_items',
    'payments',
    'inventory_movements',
    'order_returns',
    'combo_groups',
    'combo_group_items',
    'bom_items',
    'attendances',
    'rbac_permissions',
    'role_permissions',
  ];

  // ─── Backup ──────────────────────────────────────────────

  Future<File> createBackup() async {
    final tables = <String, List<Map<String, dynamic>>>{};

    for (final table in _tableOrder) {
      final rows = await _db.customSelect('SELECT * FROM $table').get();
      tables[table] = rows.map((r) => r.data).toList();
    }

    // Get store name for metadata
    final stores = tables['stores'] ?? [];
    final storeName = stores.isNotEmpty
        ? (stores.first['name'] as String? ?? 'Unknown')
        : 'Unknown';

    final backup = {
      'meta': {
        'version': _db.schemaVersion,
        'app_version': AppConfig.appVersion,
        'created_at': DateTime.now().toIso8601String(),
        'store_name': storeName,
        'table_counts': {
          for (final entry in tables.entries) entry.key: entry.value.length,
        },
      },
      'tables': tables,
    };

    final json = jsonEncode(backup);

    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    if (!backupDir.existsSync()) {
      backupDir.createSync(recursive: true);
    }

    final datePart = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${backupDir.path}/kompak_backup_$datePart.kompak_backup');
    await file.writeAsString(json);

    return file;
  }

  // ─── Send to Telegram ────────────────────────────────────

  Future<void> sendBackupToTelegram(File backupFile) async {
    if (!_telegram.isEnabled) return;

    // Parse backup to build caption
    final content = await backupFile.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    final meta = data['meta'] as Map<String, dynamic>;
    final counts = meta['table_counts'] as Map<String, dynamic>;

    final storeName = meta['store_name'] ?? 'Unknown';
    final createdAt = DateTime.parse(meta['created_at'] as String);
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(createdAt);

    final productCount = counts['products'] ?? 0;
    final orderCount = counts['orders'] ?? 0;
    final userCount = counts['users'] ?? 0;
    final customerCount = counts['customers'] ?? 0;

    final caption = '📦 BACKUP DATA KOMPAK POS\n\n'
        '🏪 Toko: $storeName\n'
        '📅 Tanggal: $dateStr\n'
        '📊 Data:\n'
        '  • $productCount Produk\n'
        '  • $orderCount Transaksi\n'
        '  • $userCount User\n'
        '  • $customerCount Pelanggan\n'
        '💾 Versi: v${meta['version']}\n\n'
        'File backup terlampir.';

    await _sendDocument(backupFile, caption);
  }

  Future<void> _sendDocument(File file, String caption) async {
    final token = _telegram.tokenForBackup;
    final chatId = _telegram.chatIdForBackup;
    if (token.isEmpty || chatId.isEmpty) return;

    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));
    final formData = FormData.fromMap({
      'chat_id': chatId,
      'document': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
      'caption': caption,
    });

    await dio.post(
      'https://api.telegram.org/bot$token/sendDocument',
      data: formData,
    );
  }

  // ─── Validate ────────────────────────────────────────────

  Future<Map<String, dynamic>> validateBackupFile(File file) async {
    try {
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (!data.containsKey('meta') || !data.containsKey('tables')) {
        throw const FormatException('Format file backup tidak valid');
      }

      final meta = data['meta'] as Map<String, dynamic>;
      final version = meta['version'] as int? ?? 0;

      if (version > _db.schemaVersion) {
        throw FormatException(
          'Versi backup ($version) lebih baru dari aplikasi (${_db.schemaVersion}). '
          'Update aplikasi terlebih dahulu.',
        );
      }

      return meta;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Gagal membaca file backup: $e');
    }
  }

  // ─── Restore ─────────────────────────────────────────────

  Future<void> restoreFromFile(File backupFile) async {
    final content = await backupFile.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    final tables = data['tables'] as Map<String, dynamic>;

    await _db.transaction(() async {
      // 1. DELETE all tables (child → parent)
      for (final table in _tableOrder.reversed) {
        await _db.customStatement('DELETE FROM $table');
      }

      // 2. INSERT all tables (parent → child)
      for (final table in _tableOrder) {
        final rows = tables[table] as List<dynamic>?;
        if (rows == null || rows.isEmpty) continue;

        for (final row in rows) {
          final map = row as Map<String, dynamic>;
          final columns = map.keys.toList();
          final placeholders = columns.map((_) => '?').join(', ');
          final columnNames = columns.join(', ');
          final values = columns.map((c) => Variable(map[c])).toList();

          await _db.customStatement(
            'INSERT OR REPLACE INTO $table ($columnNames) VALUES ($placeholders)',
            values.map((v) => v.value).toList(),
          );
        }
      }
    });
  }
}
