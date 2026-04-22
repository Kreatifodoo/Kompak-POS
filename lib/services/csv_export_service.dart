import 'dart:io';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../core/database/app_database.dart';

class CsvExportService {
  final AppDatabase _db;
  final _dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

  CsvExportService(this._db);

  // ─── HELPERS ─────────────────────────────────────────────

  Future<File> _writeToFile(String prefix, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}/exports');
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }
    final datePart = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${exportDir.path}/${prefix}_$datePart.csv');
    await file.writeAsString(content);
    return file;
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Returns (filterSql, filterVars, label) for time period filtering.
  /// Uses the same date column pattern as PosQueryService.
  (String, List<Variable>, String) _periodFilter(String? timePeriod) {
    if (timePeriod == null || timePeriod.isEmpty || timePeriod == 'all_time') {
      return ('', [], 'Keseluruhan');
    }
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');
    final dateCol = "date(created_at, 'unixepoch', 'localtime')";

    String start, end, label;
    switch (timePeriod) {
      case 'today':
        start = end = fmt.format(now);
        label = 'Hari Ini';
      case 'yesterday':
        start = end = fmt.format(now.subtract(const Duration(days: 1)));
        label = 'Kemarin';
      case 'this_week':
        start = fmt.format(now.subtract(Duration(days: now.weekday - 1)));
        end = fmt.format(now);
        label = 'Minggu Ini';
      case 'last_week':
        start = fmt.format(now.subtract(Duration(days: now.weekday + 6)));
        end = fmt.format(now.subtract(Duration(days: now.weekday)));
        label = 'Minggu Lalu';
      case 'this_month':
        start = fmt.format(DateTime(now.year, now.month, 1));
        end = fmt.format(now);
        label = 'Bulan Ini';
      case 'last_month':
        start = fmt.format(DateTime(now.year, now.month - 1, 1));
        end = fmt.format(DateTime(now.year, now.month, 0));
        label = 'Bulan Lalu';
      case 'last_3_months':
        start = fmt.format(DateTime(now.year, now.month - 3, now.day));
        end = fmt.format(now);
        label = '3 Bulan Terakhir';
      case 'this_year':
        start = fmt.format(DateTime(now.year, 1, 1));
        end = fmt.format(now);
        label = 'Tahun Ini';
      default:
        return ('', [], 'Keseluruhan');
    }

    if (start == end) {
      return ('AND $dateCol = ?', [Variable.withString(start)], label);
    }
    return (
      'AND $dateCol >= ? AND $dateCol <= ?',
      [Variable.withString(start), Variable.withString(end)],
      label,
    );
  }

  // ─── SESSION CSV (existing) ──────────────────────────────

  /// Generate CSV file with session transactions.
  /// Returns the File object for sending via Telegram or sharing.
  Future<File> generateSessionCsv(String sessionId) async {
    final rows = await _db.posSessionDao.getOrdersForCsvExport(sessionId);

    final buffer = StringBuffer();
    buffer.writeln('transaction_id,datetime,total,payment_method');
    for (final row in rows) {
      buffer.writeln(
        '${row.orderId},'
        '${_dateFmt.format(row.dateTime)},'
        '${row.total.toStringAsFixed(0)},'
        '${row.paymentMethod}',
      );
    }

    return _writeToFile('session', buffer.toString());
  }

  // ─── SALES REPORT CSV ────────────────────────────────────

  /// Generate CSV with all completed orders for a store, optionally filtered by time period.
  Future<File> generateSalesReportCsv(String storeId, {String? timePeriod}) async {
    final (filterSql, filterVars, label) = _periodFilter(timePeriod);

    final rows = await _db.customSelect(
      '''SELECT
           o.order_number,
           datetime(o.created_at, 'unixepoch', 'localtime') as order_date,
           u.name as cashier_name,
           o.subtotal,
           o.discount_amount,
           o.tax_amount,
           o.total,
           p.method as payment_method,
           (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) as item_count
         FROM orders o
         LEFT JOIN users u ON u.id = o.cashier_id
         LEFT JOIN payments p ON p.order_id = o.id
         WHERE o.store_id = ? AND o.status = 'completed'
           $filterSql
         ORDER BY o.created_at DESC''',
      variables: [Variable.withString(storeId), ...filterVars],
      readsFrom: {_db.orders, _db.users, _db.payments, _db.orderItems},
    ).get();

    final buffer = StringBuffer();
    buffer.writeln('Laporan Penjualan - $label');
    buffer.writeln('order_number,tanggal,kasir,subtotal,diskon,pajak,total,metode_bayar,jumlah_item');

    double grandTotal = 0;
    for (final r in rows) {
      final total = r.read<double>('total');
      grandTotal += total;
      buffer.writeln(
        '${r.read<String>('order_number')},'
        '${r.read<String>('order_date')},'
        '${_escapeCsv(r.read<String?>('cashier_name') ?? '-')},'
        '${r.read<double>('subtotal').toStringAsFixed(0)},'
        '${r.read<double>('discount_amount').toStringAsFixed(0)},'
        '${r.read<double>('tax_amount').toStringAsFixed(0)},'
        '${total.toStringAsFixed(0)},'
        '${r.read<String?>('payment_method') ?? '-'},'
        '${r.read<int>('item_count')}',
      );
    }

    buffer.writeln();
    buffer.writeln('TOTAL,,,,,,${grandTotal.toStringAsFixed(0)},,${rows.length} transaksi');

    return _writeToFile('sales_report', buffer.toString());
  }

  // ─── INVENTORY REPORT CSV ────────────────────────────────

  /// Generate CSV with all products and their stock levels.
  Future<File> generateInventoryReportCsv(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT
           p.name as product_name,
           p.sku,
           c.name as category_name,
           COALESCE(i.quantity, 0) as stock,
           COALESCE(i.low_stock_threshold, 10) as threshold,
           i.unit,
           p.price as sell_price,
           COALESCE(p.cost_price, 0) as cost_price,
           p.is_active
         FROM products p
         LEFT JOIN categories c ON c.id = p.category_id
         LEFT JOIN inventory i ON i.product_id = p.id
         WHERE p.store_id = ?
         ORDER BY c.name, p.name''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.products, _db.categories, _db.inventory},
    ).get();

    final buffer = StringBuffer();
    buffer.writeln('Laporan Inventory');
    buffer.writeln('nama_produk,sku,kategori,stok,satuan,batas_rendah,status_stok,harga_jual,harga_modal,aktif');

    int lowStockCount = 0;
    for (final r in rows) {
      final stock = r.read<double>('stock');
      final threshold = r.read<double>('threshold');
      final isLow = stock <= threshold;
      if (isLow) lowStockCount++;

      buffer.writeln(
        '${_escapeCsv(r.read<String>('product_name'))},'
        '${r.read<String?>('sku') ?? '-'},'
        '${_escapeCsv(r.read<String?>('category_name') ?? '-')},'
        '${stock.toStringAsFixed(0)},'
        '${r.read<String?>('unit') ?? 'pcs'},'
        '${threshold.toStringAsFixed(0)},'
        '${isLow ? 'RENDAH' : 'OK'},'
        '${r.read<double>('sell_price').toStringAsFixed(0)},'
        '${r.read<double>('cost_price').toStringAsFixed(0)},'
        '${r.read<bool>('is_active') ? 'Ya' : 'Tidak'}',
      );
    }

    buffer.writeln();
    buffer.writeln('Total Produk: ${rows.length}');
    buffer.writeln('Stok Rendah: $lowStockCount produk');

    return _writeToFile('inventory_report', buffer.toString());
  }

  // ─── DASHBOARD CSV ───────────────────────────────────────

  /// Generate CSV with dashboard summary: sales, top products, payment breakdown, stock.
  Future<File> generateDashboardCsv(String storeId, {String? timePeriod}) async {
    final (filterSql, filterVars, label) = _periodFilter(timePeriod);

    final buffer = StringBuffer();
    buffer.writeln('Dashboard Ringkasan - $label');
    buffer.writeln();

    // ── Section 1: Sales Summary ──
    final sales = await _db.customSelect(
      '''SELECT
           COUNT(*) as total_trx,
           COALESCE(SUM(total), 0) as total_sales,
           COALESCE(SUM(discount_amount), 0) as total_discount,
           COALESCE(AVG(total), 0) as avg_order
         FROM orders
         WHERE store_id = ? AND status = 'completed'
           $filterSql''',
      variables: [Variable.withString(storeId), ...filterVars],
      readsFrom: {_db.orders},
    ).get();

    buffer.writeln('[RINGKASAN PENJUALAN]');
    buffer.writeln('metrik,nilai');
    if (sales.isNotEmpty) {
      final s = sales.first;
      buffer.writeln('Total Transaksi,${s.read<int>('total_trx')}');
      buffer.writeln('Total Penjualan,${s.read<double>('total_sales').toStringAsFixed(0)}');
      buffer.writeln('Total Diskon,${s.read<double>('total_discount').toStringAsFixed(0)}');
      buffer.writeln('Rata-rata/Order,${s.read<double>('avg_order').toStringAsFixed(0)}');
    }
    buffer.writeln();

    // ── Section 2: Top Products ──
    final topProducts = await _db.customSelect(
      '''SELECT p.name, SUM(oi.quantity) as qty, SUM(oi.subtotal) as revenue
         FROM order_items oi
         JOIN orders o ON o.id = oi.order_id
         JOIN products p ON p.id = oi.product_id
         WHERE o.store_id = ? AND o.status = 'completed'
           ${filterSql.replaceAll('created_at', 'o.created_at')}
         GROUP BY oi.product_id
         ORDER BY qty DESC
         LIMIT 20''',
      variables: [Variable.withString(storeId), ...filterVars],
      readsFrom: {_db.orderItems, _db.orders, _db.products},
    ).get();

    buffer.writeln('[TOP PRODUK]');
    buffer.writeln('no,nama_produk,qty_terjual,pendapatan');
    for (var i = 0; i < topProducts.length; i++) {
      final p = topProducts[i];
      buffer.writeln(
        '${i + 1},'
        '${_escapeCsv(p.read<String>('name'))},'
        '${p.read<double>('qty').toStringAsFixed(0)},'
        '${p.read<double>('revenue').toStringAsFixed(0)}',
      );
    }
    buffer.writeln();

    // ── Section 3: Payment Breakdown ──
    final payments = await _db.customSelect(
      '''SELECT p.method, COUNT(*) as count, SUM(p.amount - p.change_amount) as net
         FROM payments p
         JOIN orders o ON o.id = p.order_id
         WHERE o.store_id = ? AND o.status = 'completed'
           ${filterSql.replaceAll('created_at', 'o.created_at')}
         GROUP BY p.method
         ORDER BY net DESC''',
      variables: [Variable.withString(storeId), ...filterVars],
      readsFrom: {_db.payments, _db.orders},
    ).get();

    buffer.writeln('[PEMBAYARAN]');
    buffer.writeln('metode,jumlah_trx,total_netto');
    for (final p in payments) {
      buffer.writeln(
        '${p.read<String>('method')},'
        '${p.read<int>('count')},'
        '${p.read<double>('net').toStringAsFixed(0)}',
      );
    }
    buffer.writeln();

    // ── Section 4: Stock Summary ──
    final stock = await _db.customSelect(
      '''SELECT
           COUNT(*) as total_products,
           SUM(CASE WHEN i.quantity <= i.low_stock_threshold THEN 1 ELSE 0 END) as low_stock,
           SUM(CASE WHEN i.quantity = 0 THEN 1 ELSE 0 END) as out_of_stock
         FROM inventory i
         JOIN products p ON p.id = i.product_id
         WHERE p.store_id = ?''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.inventory, _db.products},
    ).get();

    buffer.writeln('[RINGKASAN STOK]');
    buffer.writeln('metrik,nilai');
    if (stock.isNotEmpty) {
      final st = stock.first;
      buffer.writeln('Total Produk,${st.read<int>('total_products')}');
      buffer.writeln('Stok Rendah,${st.read<int>('low_stock')}');
      buffer.writeln('Stok Habis,${st.read<int>('out_of_stock')}');
    }

    return _writeToFile('dashboard', buffer.toString());
  }
}
