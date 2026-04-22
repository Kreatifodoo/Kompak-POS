import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../core/database/app_database.dart';

/// Comprehensive POS data query service for AI chatbot.
///
/// Queries ALL historical data across orders, inventory, products, promotions,
/// pricelists, charges, combos, BOM recipes, terminals, branches, users, and customers.
///
/// IMPORTANT: Drift stores DateTime as unix epoch SECONDS (integers).
/// All date functions must use: date/datetime(column, 'unixepoch', 'localtime')
class PosQueryService {
  final AppDatabase _db;
  final _fmt = NumberFormat('#,##0', 'id_ID');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  PosQueryService(this._db);

  // ═══════════════════════════════════════════════════════════
  // MAIN ENTRY POINT
  // ═══════════════════════════════════════════════════════════

  Future<String> queryByIntent(
    String intent,
    String storeId, {
    String? productName,
    String? timePeriod,
  }) async {
    // Default to all_time when no timePeriod specified — bot reads ALL historical data
    final period = timePeriod ?? 'all_time';

    switch (intent) {
      // ── Sales ──
      case 'daily_sales':
        return _getSalesByPeriod(storeId, timePeriod ?? 'today');
      case 'weekly_sales':
        return _getSalesByPeriod(storeId, timePeriod ?? 'this_week');
      case 'monthly_sales':
        return _getSalesByPeriod(storeId, timePeriod ?? 'this_month');
      case 'all_sales':
        return _getSalesByPeriod(storeId, 'all_time');
      case 'sales_by_category':
        return _getSalesByCategory(storeId, timePeriod: period);
      case 'sales_trend':
        return _getSalesTrend(storeId);

      // ── Products ──
      case 'top_products':
        return _getTopProducts(storeId, timePeriod: period);
      case 'top_products_alltime':
        return _getTopProducts(storeId, timePeriod: 'all_time');
      case 'product_sales':
        return _getProductSales(storeId, productName ?? '', timePeriod: period);
      case 'combo_info':
        return _getComboInfo(storeId);
      case 'pricelist_info':
        return _getPricelistInfo(storeId);
      case 'promotion_info':
        return _getPromotionInfo(storeId);

      // ── Inventory ──
      case 'stock_check':
        return _getStockStatus(storeId);
      case 'stock_search':
        return _searchStock(storeId, productName ?? '');
      case 'stock_low':
        return _getLowStock(storeId);
      case 'stock_movements':
        return _getStockMovements(storeId);
      case 'bom_info':
        return _getBomInfo(storeId);

      // ── Financial ──
      case 'payment_breakdown':
        return _getPaymentByPeriod(storeId, period);
      case 'payment_alltime':
        return _getPaymentByPeriod(storeId, 'all_time');
      case 'charges_info':
        return _getChargesInfo(storeId);
      case 'profit_report':
        return _getProfitReport(storeId);
      case 'returns_info':
        return _getReturnsInfo(storeId);

      // ── Operational ──
      case 'recent_orders':
        return _getRecentOrders(storeId);
      case 'cashier_stats':
        return _getCashierByPeriod(storeId, period);
      case 'cashier_alltime':
        return _getCashierByPeriod(storeId, 'all_time');
      case 'session_info':
        return _getSessionInfo(storeId);
      case 'terminal_info':
        return _getTerminalInfo(storeId);
      case 'branch_info':
        return _getBranchInfo(storeId);

      // ── CRM ──
      case 'customer_info':
        return _getCustomerInfo(storeId);

      // ── Default ──
      case 'full_summary':
      default:
        return _getFullSummary(storeId);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SALES QUERIES
  // ═══════════════════════════════════════════════════════════

  /// Unified sales query — works for any time period.
  Future<String> _getSalesByPeriod(String storeId, String timePeriod) async {
    final dateCol = "date(created_at, 'unixepoch', 'localtime')";
    final (filterSql, filterVars) = _timePeriodFilter(timePeriod, dateCol);
    final label = _periodLabel(timePeriod, 'KESELURUHAN');

    final rows = await _db.customSelect(
      '''SELECT
           COUNT(*) as total_trx,
           COALESCE(SUM(total), 0) as total_sales,
           COALESCE(SUM(discount_amount), 0) as total_discount,
           COALESCE(SUM(tax_amount), 0) as total_tax,
           COALESCE(AVG(total), 0) as avg_order,
           MIN($dateCol) as first_date,
           MAX($dateCol) as last_date,
           COUNT(DISTINCT $dateCol) as active_days
         FROM orders
         WHERE store_id = ? AND status = 'completed'
           $filterSql''',
      variables: [Variable.withString(storeId), ...filterVars],
      readsFrom: {_db.orders},
    ).get();

    final r = rows.first;
    final trx = r.read<int>('total_trx');
    if (trx == 0) return 'PENJUALAN ($label):\nBelum ada transaksi.';

    final totalSales = r.read<double>('total_sales');
    final activeDays = r.read<int>('active_days');
    final avgPerDay = activeDays > 0 ? totalSales / activeDays : 0.0;

    final buf = StringBuffer('''PENJUALAN ($label):
- Total Transaksi: $trx
- Total Penjualan: Rp ${_f(totalSales)}
- Total Diskon: Rp ${_f(r.read<double>('total_discount'))}
- Total Pajak: Rp ${_f(r.read<double>('total_tax'))}
- Rata-rata/Order: Rp ${_f(r.read<double>('avg_order'))}
- Hari Aktif: $activeDays
- Rata-rata/Hari: Rp ${_f(avgPerDay)}
''');

    // Daily breakdown (for periods spanning multiple days, show per-day)
    if (activeDays > 1 && activeDays <= 31) {
      final daily = await _db.customSelect(
        '''SELECT $dateCol as sale_date,
             COUNT(*) as trx, SUM(total) as sales
           FROM orders
           WHERE store_id = ? AND status = 'completed' $filterSql
           GROUP BY sale_date ORDER BY sale_date DESC LIMIT 14''',
        variables: [Variable.withString(storeId), ...filterVars],
        readsFrom: {_db.orders},
      ).get();
      if (daily.isNotEmpty) {
        buf.writeln('Per Hari:');
        for (final d in daily) {
          buf.writeln('- ${d.read<String>('sale_date')}: ${d.read<int>('trx')} trx, '
              'Rp ${_f(d.read<double>('sales'))}');
        }
      }
    }

    // Monthly breakdown for longer periods
    if (activeDays > 31) {
      final monthly = await _db.customSelect(
        '''SELECT
             strftime('%Y-%m', created_at, 'unixepoch', 'localtime') as month,
             COUNT(*) as trx, SUM(total) as sales
           FROM orders
           WHERE store_id = ? AND status = 'completed' $filterSql
           GROUP BY month ORDER BY month DESC LIMIT 6''',
        variables: [Variable.withString(storeId), ...filterVars],
        readsFrom: {_db.orders},
      ).get();
      if (monthly.isNotEmpty) {
        buf.writeln('Per Bulan:');
        for (final m in monthly) {
          buf.writeln('- ${m.read<String>('month')}: ${m.read<int>('trx')} trx, '
              'Rp ${_f(m.read<double>('sales'))}');
        }
      }
    }

    return buf.toString();
  }

  Future<String> _getSalesByCategory(String storeId, {String? timePeriod}) async {
    final dateCol = "date(o.created_at, 'unixepoch', 'localtime')";
    final (filterSql, filterVars) = _timePeriodFilter(timePeriod, dateCol);
    final label = _periodLabel(timePeriod, 'all-time');

    final rows = await _db.customSelect(
      '''SELECT
           c.name as category_name,
           COUNT(DISTINCT o.id) as total_orders,
           SUM(oi.quantity) as total_qty,
           SUM(oi.subtotal) as total_revenue
         FROM order_items oi
         JOIN orders o ON o.id = oi.order_id
         JOIN products p ON p.id = oi.product_id
         JOIN categories c ON c.id = p.category_id
         WHERE o.store_id = ? AND o.status = 'completed'
           $filterSql
         GROUP BY c.id ORDER BY total_revenue DESC''',
      variables: [Variable.withString(storeId), ...filterVars],
      readsFrom: {_db.orderItems, _db.orders, _db.products, _db.categories},
    ).get();

    if (rows.isEmpty) return 'PENJUALAN PER KATEGORI ($label): Belum ada data.';

    final buf = StringBuffer('PENJUALAN PER KATEGORI ($label):\n');
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      buf.writeln('${i + 1}. ${r.read<String>('category_name')} — '
          '${r.read<int>('total_qty')}x terjual, '
          'Rp ${_f(r.read<double>('total_revenue'))}');
    }
    return buf.toString();
  }

  Future<String> _getSalesTrend(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT
           date(created_at, 'unixepoch', 'localtime') as sale_date,
           COUNT(*) as trx, SUM(total) as sales
         FROM orders
         WHERE store_id = ? AND status = 'completed'
         GROUP BY sale_date ORDER BY sale_date DESC LIMIT 14''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.orders},
    ).get();

    if (rows.isEmpty) return 'TREN PENJUALAN: Belum ada data.';

    final buf = StringBuffer('TREN PENJUALAN (14 hari terakhir):\n');
    for (final r in rows.reversed) {
      buf.writeln('- ${r.read<String>('sale_date')}: ${r.read<int>('trx')} trx, '
          'Rp ${_f(r.read<double>('sales'))}');
    }
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // PRODUCT QUERIES
  // ═══════════════════════════════════════════════════════════

  Future<String> _getTopProducts(String storeId, {String? timePeriod}) async {
    final dateCol = "date(o.created_at, 'unixepoch', 'localtime')";
    // Default to all_time — bot reads ALL historical data
    final effectivePeriod = timePeriod ?? 'all_time';
    final (filterSql, filterVars) = _timePeriodFilter(effectivePeriod, dateCol);
    final label = _periodLabel(effectivePeriod, 'ALL-TIME');

    final rows = await _db.customSelect(
      '''SELECT
           oi.product_name, SUM(oi.quantity) as total_qty,
           SUM(oi.subtotal) as total_revenue,
           COUNT(DISTINCT o.id) as total_orders
         FROM order_items oi
         JOIN orders o ON o.id = oi.order_id
         WHERE o.store_id = ? AND o.status = 'completed'
           $filterSql
         GROUP BY oi.product_id ORDER BY total_qty DESC LIMIT 15''',
      variables: [Variable.withString(storeId), ...filterVars],
      readsFrom: {_db.orderItems, _db.orders},
    ).get();

    if (rows.isEmpty) return 'TOP PRODUK ($label): Belum ada data.';

    final buf = StringBuffer('TOP PRODUK TERLARIS ($label):\n');
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      buf.writeln('${i + 1}. ${r.read<String>('product_name')} — '
          '${r.read<int>('total_qty')}x terjual, '
          'Rp ${_f(r.read<double>('total_revenue'))}, '
          '${r.read<int>('total_orders')} order');
    }
    return buf.toString();
  }

  Future<String> _getProductSales(String storeId, String productName, {String? timePeriod}) async {
    if (productName.isEmpty) {
      return _getTopProducts(storeId, timePeriod: timePeriod ?? 'all_time');
    }

    final dateCol = "date(o.created_at, 'unixepoch', 'localtime')";
    final (filterSql, filterVars) = _timePeriodFilter(timePeriod, dateCol);
    final label = _periodLabel(timePeriod, 'all-time');

    // Build LIKE conditions for each word (fuzzy match)
    final words = productName.toLowerCase().split(RegExp(r'\s+'));
    final likeClauses = words.map((_) => 'LOWER(oi.product_name) LIKE ?').join(' AND ');
    final likeVars = words.map((w) => Variable.withString('%$w%')).toList();

    final rows = await _db.customSelect(
      '''SELECT
           oi.product_name,
           COALESCE(SUM(oi.quantity), 0) as total_qty,
           COALESCE(SUM(oi.subtotal), 0) as total_revenue,
           COUNT(DISTINCT o.id) as total_orders,
           COALESCE(AVG(oi.product_price), 0) as avg_price,
           MIN($dateCol) as first_sold,
           MAX($dateCol) as last_sold
         FROM order_items oi
         JOIN orders o ON o.id = oi.order_id
         WHERE o.store_id = ? AND o.status = 'completed'
           AND $likeClauses
           $filterSql
         GROUP BY oi.product_id''',
      variables: [Variable.withString(storeId), ...likeVars, ...filterVars],
      readsFrom: {_db.orderItems, _db.orders},
    ).get();

    if (rows.isEmpty) {
      // Try to find product in master data to give better message
      final products = await _db.customSelect(
        '''SELECT name, price FROM products
           WHERE store_id = ? AND is_active = 1
           AND (${words.map((_) => 'LOWER(name) LIKE ?').join(' OR ')})
           LIMIT 5''',
        variables: [Variable.withString(storeId), ...likeVars],
        readsFrom: {_db.products},
      ).get();

      if (products.isNotEmpty) {
        final buf = StringBuffer('Produk "$productName" belum terjual ($label).\n');
        buf.writeln('Produk serupa yang terdaftar:');
        for (final p in products) {
          buf.writeln('- ${p.read<String>('name')} (Rp ${_f(p.read<double>('price'))})');
        }
        return buf.toString();
      }
      return 'Produk "$productName" tidak ditemukan di database.';
    }

    final buf = StringBuffer('DATA PENJUALAN PRODUK ($label):\n');
    for (final r in rows) {
      buf.writeln('📦 ${r.read<String>('product_name')}');
      buf.writeln('- Total Terjual: ${r.read<int>('total_qty')}x');
      buf.writeln('- Total Revenue: Rp ${_f(r.read<double>('total_revenue'))}');
      buf.writeln('- Jumlah Order: ${r.read<int>('total_orders')}');
      buf.writeln('- Harga Rata-rata: Rp ${_f(r.read<double>('avg_price'))}');
      buf.writeln('- Pertama Terjual: ${r.readNullable<String>('first_sold') ?? '-'}');
      buf.writeln('- Terakhir Terjual: ${r.readNullable<String>('last_sold') ?? '-'}');

      // Monthly breakdown (only for all-time or long periods)
      if (timePeriod == null || timePeriod == 'all_time') {
        final monthly = await _db.customSelect(
          '''SELECT
               strftime('%Y-%m', o.created_at, 'unixepoch', 'localtime') as month,
               COALESCE(SUM(oi.quantity), 0) as qty,
               COALESCE(SUM(oi.subtotal), 0) as rev
             FROM order_items oi JOIN orders o ON o.id = oi.order_id
             WHERE o.store_id = ? AND o.status = 'completed'
               AND $likeClauses
             GROUP BY month ORDER BY month DESC LIMIT 6''',
          variables: [Variable.withString(storeId), ...likeVars],
          readsFrom: {_db.orderItems, _db.orders},
        ).get();

        if (monthly.isNotEmpty) {
          buf.writeln('Per Bulan:');
          for (final m in monthly) {
            buf.writeln('  ${m.read<String>('month')}: ${m.read<int>('qty')}x, '
                'Rp ${_f(m.read<double>('rev'))}');
          }
        }
      }
    }
    return buf.toString();
  }

  /// Search stock for a specific product by name (fuzzy matching)
  Future<String> _searchStock(String storeId, String productName) async {
    if (productName.isEmpty) return _getStockStatus(storeId);

    // Split into words for fuzzy matching
    final words = productName.toLowerCase().split(RegExp(r'\s+'));
    final likeClauses = words.map((_) => 'LOWER(p.name) LIKE ?').join(' OR ');
    final likeVars = words.map((w) => Variable.withString('%$w%')).toList();

    final rows = await _db.customSelect(
      '''SELECT p.name, i.quantity as stock, i.low_stock_threshold as threshold,
           i.unit, c.name as category,
           datetime(i.last_restock_at, 'unixepoch', 'localtime') as last_restock
         FROM inventory i
         JOIN products p ON p.id = i.product_id
         LEFT JOIN categories c ON c.id = p.category_id
         WHERE i.store_id = ? AND ($likeClauses)
         ORDER BY p.name''',
      variables: [Variable.withString(storeId), ...likeVars],
      readsFrom: {_db.inventory, _db.products, _db.categories},
    ).get();

    if (rows.isEmpty) {
      return 'STOK "$productName": Produk tidak ditemukan di inventori.\n'
          'Pastikan nama produk sudah benar.';
    }

    final buf = StringBuffer('STOK PRODUK (pencarian: "$productName"):\n');
    for (final r in rows) {
      final stock = r.read<double>('stock');
      final threshold = r.read<double>('threshold');
      final warn = stock <= threshold ? ' ⚠️ RENDAH' : ' ✅';
      final restock = r.readNullable<String>('last_restock') ?? '-';
      final cat = r.readNullable<String>('category') ?? '-';
      buf.writeln('\n📦 ${r.read<String>('name')} [$cat]');
      buf.writeln('  Stok: ${stock.toStringAsFixed(0)} ${r.read<String>('unit')}$warn');
      buf.writeln('  Batas Min: ${threshold.toStringAsFixed(0)} ${r.read<String>('unit')}');
      buf.writeln('  Restock Terakhir: $restock');
    }
    return buf.toString();
  }

  Future<String> _getComboInfo(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT p.id, p.name, p.price,
           (SELECT COUNT(*) FROM combo_groups cg WHERE cg.product_id = p.id) as group_count
         FROM products p
         WHERE p.store_id = ? AND p.is_combo = 1 AND p.is_active = 1''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.products, _db.comboGroups},
    ).get();

    if (rows.isEmpty) return 'DATA COMBO: Tidak ada produk combo aktif.';

    final buf = StringBuffer('PRODUK COMBO AKTIF:\n');
    for (final r in rows) {
      final productId = r.read<String>('id');
      buf.writeln('\n🍱 ${r.read<String>('name')} — Rp ${_f(r.read<double>('price'))}');

      // Get groups and items
      final groups = await _db.customSelect(
        '''SELECT cg.name, cg.min_select, cg.max_select,
             GROUP_CONCAT(p.name, ', ') as items
           FROM combo_groups cg
           JOIN combo_group_items cgi ON cgi.combo_group_id = cg.id
           JOIN products p ON p.id = cgi.product_id
           WHERE cg.product_id = ?
           GROUP BY cg.id ORDER BY cg.sort_order''',
        variables: [Variable.withString(productId)],
        readsFrom: {_db.comboGroups, _db.comboGroupItems, _db.products},
      ).get();

      for (final g in groups) {
        buf.writeln('  • ${g.read<String>('name')} '
            '(pilih ${g.read<int>('min_select')}-${g.read<int>('max_select')}): '
            '${g.read<String>('items')}');
      }

      // Sales data for this combo
      final sales = await _db.customSelect(
        '''SELECT COALESCE(SUM(oi.quantity), 0) as qty
           FROM order_items oi JOIN orders o ON o.id = oi.order_id
           WHERE o.store_id = ? AND o.status = 'completed' AND oi.product_id = ?''',
        variables: [Variable.withString(storeId), Variable.withString(productId)],
        readsFrom: {_db.orderItems, _db.orders},
      ).get();
      buf.writeln('  📊 Total terjual: ${sales.first.read<int>('qty')}x');
    }
    return buf.toString();
  }

  Future<String> _getPricelistInfo(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT pl.id, pl.name, pl.is_active,
           datetime(pl.start_date, 'unixepoch', 'localtime') as start_dt,
           datetime(pl.end_date, 'unixepoch', 'localtime') as end_dt,
           COUNT(pli.id) as item_count
         FROM pricelists pl
         LEFT JOIN pricelist_items pli ON pli.pricelist_id = pl.id
         WHERE pl.store_id = ?
         GROUP BY pl.id ORDER BY pl.is_active DESC, pl.start_date DESC''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.pricelists, _db.pricelistItems},
    ).get();

    if (rows.isEmpty) return 'DATA PRICELIST: Tidak ada pricelist.';

    final buf = StringBuffer('DAFTAR PRICELIST:\n');
    for (final r in rows) {
      final active = r.read<bool>('is_active') ? '✅ Aktif' : '❌ Nonaktif';
      buf.writeln('\n📋 ${r.read<String>('name')} ($active)');
      buf.writeln('  Periode: ${r.read<String>('start_dt')} s/d ${r.read<String>('end_dt')}');
      buf.writeln('  Jumlah Item: ${r.read<int>('item_count')} produk');

      // Show items
      final items = await _db.customSelect(
        '''SELECT p.name, pli.min_qty, pli.max_qty, pli.price, p.price as base_price
           FROM pricelist_items pli
           JOIN products p ON p.id = pli.product_id
           WHERE pli.pricelist_id = ?
           ORDER BY p.name LIMIT 10''',
        variables: [Variable.withString(r.read<String>('id'))],
        readsFrom: {_db.pricelistItems, _db.products},
      ).get();

      for (final item in items) {
        final maxQty = item.read<int>('max_qty');
        final qtyRange = maxQty == 0
            ? '≥${item.read<int>('min_qty')}'
            : '${item.read<int>('min_qty')}-$maxQty';
        buf.writeln('  • ${item.read<String>('name')}: '
            'Rp ${_f(item.read<double>('base_price'))} → '
            'Rp ${_f(item.read<double>('price'))} (qty $qtyRange)');
      }
    }
    return buf.toString();
  }

  Future<String> _getPromotionInfo(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT id, nama_promo, deskripsi, tipe_program, tipe_reward,
           nilai_reward, max_diskon, min_qty, min_subtotal,
           usage_count, max_usage, is_active,
           datetime(start_date, 'unixepoch', 'localtime') as start_dt,
           datetime(end_date, 'unixepoch', 'localtime') as end_dt
         FROM promotions WHERE store_id = ?
         ORDER BY is_active DESC, priority DESC''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.promotions},
    ).get();

    if (rows.isEmpty) return 'DATA PROMOSI: Tidak ada promosi.';

    final buf = StringBuffer('DAFTAR PROMOSI:\n');
    for (final r in rows) {
      final active = r.read<bool>('is_active') ? '✅' : '❌';
      buf.writeln('\n$active ${r.read<String>('nama_promo')}');
      final desc = r.readNullable<String>('deskripsi');
      if (desc != null && desc.isNotEmpty) buf.writeln('  $desc');
      buf.writeln('  Tipe: ${r.read<String>('tipe_program')} → ${r.read<String>('tipe_reward')}');
      buf.writeln('  Nilai: ${r.read<double>('nilai_reward')}');
      final maxDiskon = r.readNullable<double>('max_diskon');
      if (maxDiskon != null) buf.writeln('  Maks Diskon: Rp ${_f(maxDiskon)}');
      final maxUsage = r.read<int>('max_usage');
      buf.writeln('  Penggunaan: ${r.read<int>('usage_count')}x'
          '${maxUsage > 0 ? ' / $maxUsage' : ' (unlimited)'}');
      buf.writeln('  Periode: ${r.read<String>('start_dt')} s/d '
          '${r.readNullable<String>('end_dt') ?? 'Tanpa batas'}');
    }
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // INVENTORY QUERIES
  // ═══════════════════════════════════════════════════════════

  Future<String> _getStockStatus(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT p.name, i.quantity as stock, i.low_stock_threshold as threshold,
           i.unit, c.name as category,
           datetime(i.last_restock_at, 'unixepoch', 'localtime') as last_restock
         FROM inventory i
         JOIN products p ON p.id = i.product_id
         LEFT JOIN categories c ON c.id = p.category_id
         WHERE i.store_id = ?
         ORDER BY i.quantity ASC LIMIT 20''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.inventory, _db.products, _db.categories},
    ).get();

    if (rows.isEmpty) return 'DATA STOK: Belum ada data inventori.';

    final buf = StringBuffer('DATA STOK KESELURUHAN (urut terendah):\n');
    for (final r in rows) {
      final stock = r.read<double>('stock');
      final threshold = r.read<double>('threshold');
      final warn = stock <= threshold ? ' ⚠️ RENDAH' : '';
      final restock = r.readNullable<String>('last_restock') ?? '-';
      buf.writeln('- ${r.read<String>('name')} [${r.readNullable<String>('category') ?? '-'}]: '
          '${stock.toStringAsFixed(0)} ${r.read<String>('unit')}$warn '
          '(restock: $restock)');
    }
    return buf.toString();
  }

  Future<String> _getLowStock(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT p.name, i.quantity as stock, i.low_stock_threshold as threshold, i.unit
         FROM inventory i
         JOIN products p ON p.id = i.product_id
         WHERE i.store_id = ? AND i.quantity <= i.low_stock_threshold
         ORDER BY (i.quantity / NULLIF(i.low_stock_threshold, 0)) ASC''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.inventory, _db.products},
    ).get();

    if (rows.isEmpty) return 'STOK RENDAH: Tidak ada produk yang stoknya rendah! ✅';

    final buf = StringBuffer('⚠️ PERINGATAN STOK RENDAH (${rows.length} produk):\n');
    for (final r in rows) {
      buf.writeln('- ${r.read<String>('name')}: ${r.read<double>('stock').toStringAsFixed(0)} '
          '${r.read<String>('unit')} (min: ${r.read<double>('threshold').toStringAsFixed(0)})');
    }
    return buf.toString();
  }

  Future<String> _getStockMovements(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT p.name as product_name, im.type, im.quantity as change_qty,
           im.previous_qty, im.new_qty, im.reason,
           datetime(im.created_at, 'unixepoch', 'localtime') as moved_at,
           u.name as user_name
         FROM inventory_movements im
         JOIN products p ON p.id = im.product_id
         LEFT JOIN users u ON u.id = im.user_id
         WHERE p.store_id = ?
         ORDER BY im.created_at DESC LIMIT 20''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.inventoryMovements, _db.products, _db.users},
    ).get();

    if (rows.isEmpty) return 'PERGERAKAN STOK: Belum ada data pergerakan.';

    final buf = StringBuffer('PERGERAKAN STOK TERAKHIR:\n');
    for (final r in rows) {
      final type = r.read<String>('type');
      final icon = type == 'sale' ? '🔻' : type == 'restock' ? '🔺' : '🔄';
      final reason = r.readNullable<String>('reason') ?? '';
      final user = r.readNullable<String>('user_name') ?? '-';
      buf.writeln('$icon ${r.read<String>('product_name')} '
          '[${r.read<String>('moved_at')}]');
      buf.writeln('  $type: ${r.read<double>('previous_qty').toStringAsFixed(0)} → '
          '${r.read<double>('new_qty').toStringAsFixed(0)} '
          '(${r.read<double>('change_qty') >= 0 ? '+' : ''}${r.read<double>('change_qty').toStringAsFixed(0)}) '
          'oleh: $user${reason.isNotEmpty ? ' ($reason)' : ''}');
    }
    return buf.toString();
  }

  Future<String> _getBomInfo(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT p.id, p.name, p.price
         FROM products p
         WHERE p.store_id = ? AND p.has_bom = 1 AND p.is_active = 1''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.products},
    ).get();

    if (rows.isEmpty) return 'DATA RESEP (BOM): Tidak ada produk dengan resep.';

    final buf = StringBuffer('RESEP PRODUK (Bill of Materials):\n');
    for (final r in rows) {
      buf.writeln('\n🧾 ${r.read<String>('name')} (Rp ${_f(r.read<double>('price'))})');

      final items = await _db.customSelect(
        '''SELECT mp.name as material, b.quantity, b.unit
           FROM bom_items b
           JOIN products mp ON mp.id = b.material_product_id
           WHERE b.product_id = ?
           ORDER BY b.sort_order''',
        variables: [Variable.withString(r.read<String>('id'))],
        readsFrom: {_db.bomItems, _db.products},
      ).get();

      for (final item in items) {
        buf.writeln('  • ${item.read<String>('material')}: '
            '${item.read<double>('quantity').toStringAsFixed(1)} ${item.read<String>('unit')}');
      }
    }
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // FINANCIAL QUERIES
  // ═══════════════════════════════════════════════════════════

  /// Unified payment breakdown — works for any time period.
  Future<String> _getPaymentByPeriod(String storeId, String timePeriod) async {
    final dateCol = "date(o.created_at, 'unixepoch', 'localtime')";
    final (filterSql, filterVars) = _timePeriodFilter(timePeriod, dateCol);
    final label = _periodLabel(timePeriod, 'KESELURUHAN');

    final rows = await _db.customSelect(
      '''SELECT p.method, COUNT(*) as cnt,
           SUM(p.amount) as total_amount, SUM(p.change_amount) as total_change
         FROM payments p
         JOIN orders o ON o.id = p.order_id
         WHERE o.store_id = ? AND o.status = 'completed'
           $filterSql
         GROUP BY p.method ORDER BY total_amount DESC''',
      variables: [Variable.withString(storeId), ...filterVars],
      readsFrom: {_db.payments, _db.orders},
    ).get();

    if (rows.isEmpty) return 'PEMBAYARAN ($label): Belum ada data.';

    var grandTotal = 0.0;
    final buf = StringBuffer('RINCIAN PEMBAYARAN ($label):\n');
    for (final r in rows) {
      final net = r.read<double>('total_amount') - r.read<double>('total_change');
      grandTotal += net;
      buf.writeln('- ${r.read<String>('method')}: ${r.read<int>('cnt')}x, Rp ${_f(net)}');
    }
    buf.writeln('TOTAL: Rp ${_f(grandTotal)}');
    return buf.toString();
  }

  Future<String> _getChargesInfo(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT nama_biaya, kategori, tipe, nilai, is_active, urutan
         FROM charges WHERE store_id = ?
         ORDER BY urutan''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.charges},
    ).get();

    if (rows.isEmpty) return 'DATA BIAYA: Tidak ada biaya/pajak terdaftar.';

    final buf = StringBuffer('DAFTAR BIAYA & PAJAK:\n');
    for (final r in rows) {
      final active = r.read<bool>('is_active') ? '✅' : '❌';
      final tipe = r.read<String>('tipe');
      final nilai = r.read<double>('nilai');
      final formatted = tipe == 'PERSENTASE' ? '${nilai.toStringAsFixed(1)}%' : 'Rp ${_f(nilai)}';
      buf.writeln('$active ${r.read<String>('nama_biaya')} '
          '[${r.read<String>('kategori')}]: $formatted');
    }

    // Total charges collected
    final orderCharges = await _db.customSelect(
      '''SELECT
           COUNT(*) as orders_with_charges,
           SUM(tax_amount) as total_tax
         FROM orders
         WHERE store_id = ? AND status = 'completed' AND tax_amount > 0''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.orders},
    ).get();

    if (orderCharges.isNotEmpty) {
      final oc = orderCharges.first;
      buf.writeln('\nTotal Pajak Terkumpul: Rp ${_f(oc.read<double>('total_tax'))} '
          '(dari ${oc.read<int>('orders_with_charges')} order)');
    }
    return buf.toString();
  }

  Future<String> _getProfitReport(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT
           SUM(oi.subtotal) as total_revenue,
           SUM(COALESCE(oi.cost_price, 0) * oi.quantity) as total_cost,
           SUM(oi.subtotal) - SUM(COALESCE(oi.cost_price, 0) * oi.quantity) as gross_profit,
           COUNT(DISTINCT o.id) as total_orders
         FROM order_items oi
         JOIN orders o ON o.id = oi.order_id
         WHERE o.store_id = ? AND o.status = 'completed' ''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.orderItems, _db.orders},
    ).get();

    final r = rows.first;
    final revenue = r.read<double>('total_revenue');
    final cost = r.read<double>('total_cost');
    final profit = r.read<double>('gross_profit');
    final margin = revenue > 0 ? (profit / revenue * 100) : 0.0;

    // Top profit products
    final topProfit = await _db.customSelect(
      '''SELECT oi.product_name,
           SUM(oi.subtotal) as rev,
           SUM(COALESCE(oi.cost_price, 0) * oi.quantity) as cost,
           SUM(oi.subtotal) - SUM(COALESCE(oi.cost_price, 0) * oi.quantity) as profit
         FROM order_items oi JOIN orders o ON o.id = oi.order_id
         WHERE o.store_id = ? AND o.status = 'completed'
         GROUP BY oi.product_id
         HAVING cost > 0
         ORDER BY profit DESC LIMIT 5''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.orderItems, _db.orders},
    ).get();

    final buf = StringBuffer('''LAPORAN PROFIT (all-time):
- Total Revenue: Rp ${_f(revenue)}
- Total HPP (Cost): Rp ${_f(cost)}
- Gross Profit: Rp ${_f(profit)}
- Margin: ${margin.toStringAsFixed(1)}%
- Total Orders: ${r.read<int>('total_orders')}
${cost == 0 ? '\n⚠️ Harga pokok (cost price) belum diisi di beberapa produk.' : ''}
''');

    if (topProfit.isNotEmpty) {
      buf.writeln('Top Profit Produk:');
      for (final p in topProfit) {
        buf.writeln('- ${p.read<String>('product_name')}: '
            'Profit Rp ${_f(p.read<double>('profit'))}');
      }
    }
    return buf.toString();
  }

  Future<String> _getReturnsInfo(String storeId) async {
    // Summary
    final summary = await _db.customSelect(
      '''SELECT COUNT(*) as cnt, COALESCE(SUM(return_amount), 0) as total
         FROM order_returns WHERE store_id = ?''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.orderReturns},
    ).get();

    final s = summary.first;
    if (s.read<int>('cnt') == 0) return 'DATA RETUR: Belum ada retur/refund.';

    // Detail list
    final rows = await _db.customSelect(
      '''SELECT
           or2.return_amount,
           or2.reason,
           u.name as cashier_name,
           datetime(or2.created_at, 'unixepoch', 'localtime') as return_date
         FROM order_returns or2
         LEFT JOIN users u ON u.id = or2.cashier_id
         WHERE or2.store_id = ?
         ORDER BY or2.created_at DESC LIMIT 15''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.orderReturns, _db.users},
    ).get();

    final buf = StringBuffer('DATA RETUR/REFUND:\n');
    buf.writeln('Total Retur: ${s.read<int>('cnt')}x');
    buf.writeln('Total Refund: Rp ${_f(s.read<double>('total'))}\n');

    buf.writeln('Retur Terakhir:');
    for (final r in rows) {
      buf.writeln('- ${r.readNullable<String>('return_date') ?? '-'} — '
          'Rp ${_f(r.read<double>('return_amount'))} '
          '(${r.read<String>('reason')}) oleh ${r.readNullable<String>('cashier_name') ?? '-'}');
    }
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // OPERATIONAL QUERIES
  // ═══════════════════════════════════════════════════════════

  Future<String> _getRecentOrders(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT o.order_number, o.total, o.status, o.created_at,
           o.discount_amount, o.tax_amount,
           p.method as payment_method,
           u.name as cashier_name,
           c.name as customer_name,
           t.name as terminal_name
         FROM orders o
         LEFT JOIN payments p ON p.order_id = o.id
         LEFT JOIN users u ON u.id = o.cashier_id
         LEFT JOIN customers c ON c.id = o.customer_id
         LEFT JOIN terminals t ON t.id = o.terminal_id
         WHERE o.store_id = ?
         ORDER BY o.created_at DESC LIMIT 15''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.orders, _db.payments, _db.users, _db.customers, _db.terminals},
    ).get();

    if (rows.isEmpty) return 'TRANSAKSI TERAKHIR: Belum ada transaksi.';

    final buf = StringBuffer('15 TRANSAKSI TERAKHIR:\n');
    for (final r in rows) {
      final epochSec = r.read<int>('created_at');
      final dt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
      final payment = r.readNullable<String>('payment_method') ?? '-';
      final customer = r.readNullable<String>('customer_name') ?? '-';
      final terminal = r.readNullable<String>('terminal_name') ?? '-';
      buf.writeln('- ${r.read<String>('order_number')} | ${_dateFmt.format(dt)} | '
          'Rp ${_f(r.read<double>('total'))} | $payment | '
          '${r.read<String>('status')} | $terminal');
      if (customer != '-') buf.writeln('  Customer: $customer');
    }
    return buf.toString();
  }

  /// Unified cashier stats — works for any time period.
  Future<String> _getCashierByPeriod(String storeId, String timePeriod) async {
    final dateCol = "date(o.created_at, 'unixepoch', 'localtime')";
    final (filterSql, filterVars) = _timePeriodFilter(timePeriod, dateCol);
    final label = _periodLabel(timePeriod, 'KESELURUHAN');

    final rows = await _db.customSelect(
      '''SELECT u.name, u.role, COUNT(o.id) as total_trx,
           COALESCE(SUM(o.total), 0) as total_sales,
           COALESCE(AVG(o.total), 0) as avg_order,
           COUNT(DISTINCT $dateCol) as active_days,
           MAX($dateCol) as last_active
         FROM orders o
         JOIN users u ON u.id = o.cashier_id
         WHERE o.store_id = ? AND o.status = 'completed'
           $filterSql
         GROUP BY o.cashier_id ORDER BY total_sales DESC''',
      variables: [Variable.withString(storeId), ...filterVars],
      readsFrom: {_db.orders, _db.users},
    ).get();

    if (rows.isEmpty) return 'STATISTIK KASIR ($label): Belum ada data.';

    final buf = StringBuffer('STATISTIK KASIR ($label):\n');
    for (final r in rows) {
      buf.writeln('\n👤 ${r.read<String>('name')} [${r.read<String>('role')}]');
      buf.writeln('  Total: ${r.read<int>('total_trx')} trx, '
          'Rp ${_f(r.read<double>('total_sales'))}');
      buf.writeln('  Avg/Order: Rp ${_f(r.read<double>('avg_order'))}');
      buf.writeln('  Hari Aktif: ${r.read<int>('active_days')} hari');
      buf.writeln('  Terakhir Aktif: ${r.read<String>('last_active')}');
    }
    return buf.toString();
  }

  Future<String> _getSessionInfo(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT s.id, s.status, s.opening_cash, s.closing_cash,
           s.expected_cash, s.opened_at, s.closed_at, s.notes,
           u.name as cashier_name, t.name as terminal_name,
           (SELECT COUNT(*) FROM orders o WHERE o.session_id = s.id AND o.status = 'completed') as order_count,
           (SELECT COALESCE(SUM(o.total), 0) FROM orders o WHERE o.session_id = s.id AND o.status = 'completed') as total_sales
         FROM pos_sessions s
         JOIN users u ON u.id = s.cashier_id
         JOIN terminals t ON t.id = s.terminal_id
         WHERE s.store_id = ?
         ORDER BY s.opened_at DESC LIMIT 5''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.posSessions, _db.users, _db.terminals, _db.orders},
    ).get();

    if (rows.isEmpty) return 'DATA SESI: Belum ada data sesi kasir.';

    final buf = StringBuffer('5 SESI KASIR TERAKHIR:\n');
    for (final r in rows) {
      final epochSec = r.read<int>('opened_at');
      final openedAt = DateTime.fromMillisecondsSinceEpoch(epochSec * 1000);
      final status = r.read<String>('status');
      final closingCash = r.readNullable<double>('closing_cash');
      final expectedCash = r.readNullable<double>('expected_cash');

      buf.writeln('\n📋 ${r.read<String>('cashier_name')} @ ${r.read<String>('terminal_name')}');
      buf.writeln('  Status: $status | Dibuka: ${_dateFmt.format(openedAt)}');
      buf.writeln('  Kas Awal: Rp ${_f(r.read<double>('opening_cash'))}');
      if (closingCash != null) {
        buf.writeln('  Kas Akhir: Rp ${_f(closingCash)}');
      }
      if (expectedCash != null && closingCash != null) {
        final diff = closingCash - expectedCash;
        buf.writeln('  Selisih: Rp ${_f(diff)} ${diff >= 0 ? '✅' : '⚠️'}');
      }
      buf.writeln('  Orders: ${r.read<int>('order_count')} trx, '
          'Rp ${_f(r.read<double>('total_sales'))}');
    }
    return buf.toString();
  }

  Future<String> _getTerminalInfo(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT t.id, t.name, t.code, t.is_active,
           (SELECT COUNT(*) FROM orders o WHERE o.terminal_id = t.id AND o.status = 'completed') as total_orders,
           (SELECT COALESCE(SUM(o.total), 0) FROM orders o WHERE o.terminal_id = t.id AND o.status = 'completed') as total_sales,
           (SELECT COUNT(DISTINCT date(o.created_at, 'unixepoch', 'localtime'))
            FROM orders o WHERE o.terminal_id = t.id AND o.status = 'completed') as active_days,
           (SELECT COUNT(*) FROM pos_sessions s WHERE s.terminal_id = t.id) as total_sessions
         FROM terminals t
         WHERE t.store_id = ?
         ORDER BY total_sales DESC''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.terminals, _db.orders, _db.posSessions},
    ).get();

    if (rows.isEmpty) return 'DATA TERMINAL: Tidak ada terminal.';

    final buf = StringBuffer('PERFORMA TERMINAL POS:\n');
    for (final r in rows) {
      final active = r.read<bool>('is_active') ? '🟢' : '🔴';
      buf.writeln('\n$active ${r.read<String>('name')} (${r.read<String>('code')})');
      buf.writeln('  Total Orders: ${r.read<int>('total_orders')}');
      buf.writeln('  Total Sales: Rp ${_f(r.read<double>('total_sales'))}');
      buf.writeln('  Hari Aktif: ${r.read<int>('active_days')}');
      buf.writeln('  Total Sesi: ${r.read<int>('total_sessions')}');
    }
    return buf.toString();
  }

  Future<String> _getBranchInfo(String storeId) async {
    final rows = await _db.customSelect(
      '''SELECT s.id, s.name, s.address, s.phone, s.tax_rate,
           (SELECT COUNT(*) FROM orders o WHERE o.store_id = s.id AND o.status = 'completed') as total_orders,
           (SELECT COALESCE(SUM(o.total), 0) FROM orders o WHERE o.store_id = s.id AND o.status = 'completed') as total_sales,
           (SELECT COUNT(*) FROM users u WHERE u.store_id = s.id) as staff_count,
           (SELECT COUNT(*) FROM terminals t WHERE t.store_id = s.id) as terminal_count,
           (SELECT COUNT(*) FROM products p WHERE p.store_id = s.id AND p.is_active = 1) as product_count
         FROM stores s
         ORDER BY s.parent_id NULLS FIRST, total_sales DESC''',
      variables: [],
      readsFrom: {_db.stores, _db.orders, _db.users, _db.terminals, _db.products},
    ).get();

    if (rows.isEmpty) return 'DATA CABANG: Tidak ada data toko.';

    final buf = StringBuffer('DATA TOKO & CABANG:\n');
    for (final r in rows) {
      buf.writeln('\n🏪 ${r.read<String>('name')}');
      final addr = r.readNullable<String>('address');
      if (addr != null && addr.isNotEmpty) buf.writeln('  Alamat: $addr');
      buf.writeln('  Staff: ${r.read<int>('staff_count')} orang');
      buf.writeln('  Terminal: ${r.read<int>('terminal_count')}');
      buf.writeln('  Produk Aktif: ${r.read<int>('product_count')}');
      buf.writeln('  Total Orders: ${r.read<int>('total_orders')}');
      buf.writeln('  Total Sales: Rp ${_f(r.read<double>('total_sales'))}');
      buf.writeln('  Pajak: ${(r.read<double>('tax_rate') * 100).toStringAsFixed(0)}%');
    }
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // CRM QUERIES
  // ═══════════════════════════════════════════════════════════

  Future<String> _getCustomerInfo(String storeId) async {
    // Summary
    final summary = await _db.customSelect(
      '''SELECT COUNT(*) as total_customers,
           SUM(points) as total_points
         FROM customers WHERE store_id = ?''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.customers},
    ).get();

    final s = summary.first;
    final totalCust = s.read<int>('total_customers');
    if (totalCust == 0) return 'DATA PELANGGAN: Belum ada data customer.';

    // Top customers by orders
    final topCustomers = await _db.customSelect(
      '''SELECT c.name, c.phone, c.points,
           COUNT(o.id) as total_orders,
           COALESCE(SUM(o.total), 0) as total_spent
         FROM customers c
         LEFT JOIN orders o ON o.customer_id = c.id AND o.status = 'completed'
         WHERE c.store_id = ?
         GROUP BY c.id ORDER BY total_spent DESC LIMIT 10''',
      variables: [Variable.withString(storeId)],
      readsFrom: {_db.customers, _db.orders},
    ).get();

    final buf = StringBuffer('DATA PELANGGAN:\n');
    buf.writeln('Total Customer Terdaftar: $totalCust');
    buf.writeln('Total Loyalty Points: ${s.read<int>('total_points')}\n');

    buf.writeln('Top 10 Pelanggan:');
    for (var i = 0; i < topCustomers.length; i++) {
      final c = topCustomers[i];
      final phone = c.readNullable<String>('phone') ?? '-';
      buf.writeln('${i + 1}. ${c.read<String>('name')} ($phone)');
      buf.writeln('   Orders: ${c.read<int>('total_orders')}x, '
          'Spent: Rp ${_f(c.read<double>('total_spent'))}, '
          'Points: ${c.read<int>('points')}');
    }
    return buf.toString();
  }

  // ═══════════════════════════════════════════════════════════
  // FULL SUMMARY
  // ═══════════════════════════════════════════════════════════

  Future<String> _getFullSummary(String storeId) async {
    final allTime = await _getSalesByPeriod(storeId, 'all_time');
    final daily = await _getSalesByPeriod(storeId, 'today');
    final top = await _getTopProducts(storeId, timePeriod: 'all_time');
    final payment = await _getPaymentByPeriod(storeId, 'all_time');
    final lowStock = await _getLowStock(storeId);
    return '$allTime\n\n$daily\n\n$top\n\n$payment\n\n$lowStock';
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  String _f(double v) => _fmt.format(v);

  /// Returns a (startDate, endDate) pair for the given time period string.
  /// Both dates are in 'yyyy-MM-dd' format. Returns null for 'all_time' or unknown.
  ({String start, String end, String label})? _dateRangeFromTimePeriod(String? timePeriod) {
    if (timePeriod == null || timePeriod.isEmpty || timePeriod == 'all_time') {
      return null;
    }
    final now = DateTime.now();
    final fmt = DateFormat('yyyy-MM-dd');

    switch (timePeriod) {
      case 'today':
        final d = fmt.format(now);
        return (start: d, end: d, label: 'Hari Ini');
      case 'yesterday':
        final d = fmt.format(now.subtract(const Duration(days: 1)));
        return (start: d, end: d, label: 'Kemarin');
      case 'this_week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (start: fmt.format(monday), end: fmt.format(now), label: 'Minggu Ini');
      case 'last_week':
        final lastMonday = now.subtract(Duration(days: now.weekday + 6));
        final lastSunday = now.subtract(Duration(days: now.weekday));
        return (start: fmt.format(lastMonday), end: fmt.format(lastSunday), label: 'Minggu Lalu');
      case 'this_month':
        final firstDay = DateTime(now.year, now.month, 1);
        return (start: fmt.format(firstDay), end: fmt.format(now), label: 'Bulan Ini');
      case 'last_month':
        final firstDay = DateTime(now.year, now.month - 1, 1);
        final lastDay = DateTime(now.year, now.month, 0);
        return (start: fmt.format(firstDay), end: fmt.format(lastDay), label: 'Bulan Lalu');
      case 'last_3_months':
        final firstDay = DateTime(now.year, now.month - 3, now.day);
        return (start: fmt.format(firstDay), end: fmt.format(now), label: '3 Bulan Terakhir');
      case 'this_year':
        final firstDay = DateTime(now.year, 1, 1);
        return (start: fmt.format(firstDay), end: fmt.format(now), label: 'Tahun Ini');
      default:
        return null;
    }
  }

  /// Returns a SQL WHERE clause fragment + variables for filtering by time period.
  /// [dateCol] is the column expression, e.g., "date(created_at, 'unixepoch', 'localtime')".
  /// Returns empty string + empty list if no filter needed.
  (String sql, List<Variable> vars) _timePeriodFilter(
    String? timePeriod,
    String dateCol,
  ) {
    final range = _dateRangeFromTimePeriod(timePeriod);
    if (range == null) return ('', []);

    if (range.start == range.end) {
      return (
        'AND $dateCol = ?',
        [Variable.withString(range.start)],
      );
    }
    return (
      'AND $dateCol >= ? AND $dateCol <= ?',
      [Variable.withString(range.start), Variable.withString(range.end)],
    );
  }

  /// Human-readable label for the time period, or default if null.
  String _periodLabel(String? timePeriod, [String fallback = 'KESELURUHAN']) {
    final range = _dateRangeFromTimePeriod(timePeriod);
    if (range == null) return fallback;
    return '${range.label} (${range.start} s/d ${range.end})';
  }
}
