import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/core_providers.dart';
import '../../modules/orders/order_providers.dart';
import '../../modules/inventory/inventory_providers.dart';
import '../../modules/pos_session/pos_session_providers.dart';
import '../../core/database/app_database.dart';
import '../../screens/pos/session/close_register_dialog.dart';
import '../../core/utils/permissions.dart';
import '../../widgets/common/terminal_filter_dropdown.dart';
import '../../widgets/common/branch_filter_dropdown.dart';
import '../attendance/attendance_pin_dialog.dart';

// ──────────────────────────────────────────────
// Dashboard data model – computed once per build
// ──────────────────────────────────────────────
class _DashboardData {
  final List<Order> thisMonthOrders;
  final List<Order> lastMonthOrders;
  final List<Order> last30DaysOrders;
  final List<Order> last7DaysOrders;

  _DashboardData({
    required this.thisMonthOrders,
    required this.lastMonthOrders,
    required this.last30DaysOrders,
    required this.last7DaysOrders,
  });

  List<Order> get thisMonthCompleted =>
      thisMonthOrders.where((o) => o.status == 'completed').toList();
  List<Order> get lastMonthCompleted =>
      lastMonthOrders.where((o) => o.status == 'completed').toList();
  List<Order> get thisMonthReturned =>
      thisMonthOrders.where((o) => o.status == 'returned').toList();
}

/// Provider for dashboard monthly analytics (filtered by terminal + branch)
final _dashboardDataProvider = FutureProvider<_DashboardData>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) {
    return _DashboardData(
      thisMonthOrders: [],
      lastMonthOrders: [],
      last30DaysOrders: [],
      last7DaysOrders: [],
    );
  }
  final db = ref.watch(databaseProvider);
  final terminalId = ref.watch(selectedTerminalFilterProvider);
  final storeIds = ref.watch(effectiveStoreIdsProvider).valueOrNull;
  final now = DateTime.now();

  final thisMonthStart = DateTime(now.year, now.month, 1);
  final thisMonthEnd =
      DateTime(now.year, now.month + 1, 1);
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);
  final lastMonthEnd = thisMonthStart;
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final sevenDaysAgo =
      DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final tomorrow = DateTime(now.year, now.month, now.day + 1);

  final results = await Future.wait([
    db.orderDao.getOrdersForAnalyticsFiltered(storeId, thisMonthStart, thisMonthEnd, terminalId: terminalId, storeIds: storeIds),
    db.orderDao.getOrdersForAnalyticsFiltered(storeId, lastMonthStart, lastMonthEnd, terminalId: terminalId, storeIds: storeIds),
    db.orderDao.getOrdersForAnalyticsFiltered(storeId, thirtyDaysAgo, tomorrow, terminalId: terminalId, storeIds: storeIds),
    db.orderDao.getOrdersForAnalyticsFiltered(storeId, sevenDaysAgo, tomorrow, terminalId: terminalId, storeIds: storeIds),
  ]);

  return _DashboardData(
    thisMonthOrders: results[0],
    lastMonthOrders: results[1],
    last30DaysOrders: results[2],
    last7DaysOrders: results[3],
  );
});

// ──────────────────────────────────────────────
// Chart type enum
// ──────────────────────────────────────────────
enum ChartType { bar, line, pie }

// ──────────────────────────────────────────────
// Performance view modes (table, bar, line, pie)
// ──────────────────────────────────────────────
enum _PerfViewMode { table, bar, line, pie }

class _EntityPerformance {
  final String id;
  final String name;
  final double revenue;
  final int transactionCount;
  final double avo;

  _EntityPerformance({
    required this.id,
    required this.name,
    required this.revenue,
    required this.transactionCount,
    required this.avo,
  });
}

const _perfColors = [
  Color(0xFF0F80A6), // primary
  Color(0xFF10B981), // green
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red
  Color(0xFF8B5CF6), // purple
  Color(0xFF3B82F6), // blue
  Color(0xFFEC4899), // pink
  Color(0xFF6366F1), // indigo
];

/// Per-branch performance data (HQ only)
final _branchPerformanceProvider =
    FutureProvider<List<_EntityPerformance>>((ref) async {
  final isHQ = ref.watch(isHQUserProvider);
  if (!isHQ) return [];
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final db = ref.watch(databaseProvider);
  final hqStore = await db.storeDao.getStoreById(storeId);
  final branches = await db.storeDao.getBranches(storeId);
  final allStores = [if (hqStore != null) hqStore, ...branches];

  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = now;

  final result = <_EntityPerformance>[];
  for (final store in allStores) {
    final orders = await db.orderDao.getOrdersForAnalyticsFiltered(
      store.id, start, end,
      storeIds: [store.id],
    );
    final completed = orders.where((o) => o.status == 'completed').toList();
    final revenue = completed.fold<double>(0, (s, o) => s + o.total);
    final count = completed.length;
    result.add(_EntityPerformance(
      id: store.id,
      name: store.parentId == null ? '${store.name} (HQ)' : store.name,
      revenue: revenue,
      transactionCount: count,
      avo: count > 0 ? revenue / count : 0,
    ));
  }
  result.sort((a, b) => b.revenue.compareTo(a.revenue));
  return result;
});

/// Per-terminal performance data (responsive to branch filter)
final _terminalPerformanceProvider =
    FutureProvider<List<_EntityPerformance>>((ref) async {
  final storeId = ref.watch(currentStoreIdProvider);
  if (storeId == null) return [];
  final db = ref.watch(databaseProvider);
  final storeIds = ref.watch(effectiveStoreIdsProvider).valueOrNull;
  final selectedBranch = ref.watch(selectedBranchIdProvider);

  List<Terminal> terminals;
  if (storeIds != null && storeIds.length > 1 && selectedBranch == null) {
    terminals = await db.terminalDao.getActiveByStoreIds(storeIds);
  } else {
    final sid = selectedBranch ?? storeId;
    terminals = await db.terminalDao.getActiveByStore(sid);
  }

  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = now;

  final result = <_EntityPerformance>[];
  for (final terminal in terminals) {
    final orders = await db.orderDao.getOrdersForAnalyticsFiltered(
      terminal.storeId, start, end,
      terminalId: terminal.id,
      storeIds: [terminal.storeId],
    );
    final completed = orders.where((o) => o.status == 'completed').toList();
    final revenue = completed.fold<double>(0, (s, o) => s + o.total);
    final count = completed.length;
    result.add(_EntityPerformance(
      id: terminal.id,
      name: terminal.name,
      revenue: revenue,
      transactionCount: count,
      avo: count > 0 ? revenue / count : 0,
    ));
  }
  result.sort((a, b) => b.revenue.compareTo(a.revenue));
  return result;
});

// ──────────────────────────────────────────────
// Main dashboard
// ──────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  ChartType _chartType = ChartType.bar;
  _PerfViewMode _branchViewMode = _PerfViewMode.table;
  _PerfViewMode _terminalViewMode = _PerfViewMode.table;

  @override
  Widget build(BuildContext context) {
    final currentStore = ref.watch(currentStoreProvider);
    final currentUser = ref.watch(currentUserProvider);
    final activeSession = ref.watch(activeSessionProvider);
    final dashAsync = ref.watch(_dashboardDataProvider);
    final inventoryAsync = ref.watch(inventoryWithProductProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text('Dashboard',
            style: AppTextStyles.heading3.copyWith(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.fingerprint_rounded, color: Colors.white),
            tooltip: 'Absensi (PIN)',
            onPressed: () => _openAttendancePinDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              ref.invalidate(_dashboardDataProvider);
              ref.invalidate(todayOrdersProvider);
              ref.invalidate(inventoryWithProductProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.85),
            ),
            child: Row(
              children: [
                _buildHeaderAction(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS',
                  onTap: () => context.push('/pos/catalog'),
                ),
                const SizedBox(width: AppSpacing.xs),
                _buildHeaderAction(
                  icon: Icons.list_alt_rounded,
                  label: 'Order',
                  onTap: () => context.push('/orders'),
                ),
                const SizedBox(width: AppSpacing.xs),
                _buildHeaderAction(
                  icon: Icons.assessment_rounded,
                  label: 'Laporan',
                  onTap: () => context.push('/reports/sessions'),
                ),
                const SizedBox(width: AppSpacing.xs),
                _buildHeaderAction(
                  icon: Icons.fingerprint_rounded,
                  label: 'Absensi',
                  onTap: () => _openAttendancePinDialog(context),
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: _buildDrawer(context, ref),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_dashboardDataProvider);
          ref.invalidate(todayOrdersProvider);
          ref.invalidate(inventoryWithProductProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              _buildWelcomeHeader(currentUser, currentStore),
              const SizedBox(height: AppSpacing.sm),

              // Terminal & branch filter dropdowns
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  BranchFilterDropdown(),
                  TerminalFilterDropdown(),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Session status
              activeSession.when(
                data: (session) {
                  if (session == null) {
                    return _buildSessionCard(context,
                        isOpen: false,
                        onAction: () => context.push('/pos/catalog'));
                  }
                  return _buildSessionCard(context,
                      isOpen: true,
                      session: session,
                      onAction: () => context.push('/pos/catalog'),
                      onClose: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          CloseRegisterDialog(sessionId: session.id),
                    );
                  });
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ═══════════════════════════════════════
              // 1. PANEL ATAS: Ringkasan Kinerja (KPI)
              // ═══════════════════════════════════════
              dashAsync.when(
                data: (d) => _buildKPIPanel(d),
                loading: () => _buildLoadingCard(120),
                error: (_, __) => const Text('Gagal memuat data'),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ═══════════════════════════════════════
              // 2. PANEL TENGAH KIRI: Tren Penjualan
              // ═══════════════════════════════════════
              dashAsync.when(
                data: (d) => _buildTrendPanel(d),
                loading: () => _buildLoadingCard(260),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ═══════════════════════════════════════
              // 2a. KINERJA CABANG (HQ only)
              // ═══════════════════════════════════════
              if (ref.watch(isHQUserProvider))
                ref.watch(_branchPerformanceProvider).when(
                  data: (data) => data.isEmpty
                      ? const SizedBox.shrink()
                      : _buildPerformancePanel(
                          title: 'Kinerja Cabang',
                          icon: Icons.store_rounded,
                          iconColor: AppColors.infoBlue,
                          data: data,
                          viewMode: _branchViewMode,
                          onViewModeChanged: (m) =>
                              setState(() => _branchViewMode = m),
                        ),
                  loading: () => _buildLoadingCard(200),
                  error: (_, __) => const SizedBox.shrink(),
                ),

              if (ref.watch(isHQUserProvider))
                const SizedBox(height: AppSpacing.lg),

              // ═══════════════════════════════════════
              // 2b. KINERJA TERMINAL POS
              // ═══════════════════════════════════════
              ref.watch(_terminalPerformanceProvider).when(
                data: (data) => data.length < 2
                    ? const SizedBox.shrink()
                    : _buildPerformancePanel(
                        title: 'Kinerja Terminal POS',
                        icon: Icons.point_of_sale_rounded,
                        iconColor: AppColors.successGreen,
                        data: data,
                        viewMode: _terminalViewMode,
                        onViewModeChanged: (m) =>
                            setState(() => _terminalViewMode = m),
                      ),
                loading: () => _buildLoadingCard(200),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ═══════════════════════════════════════
              // 3. PANEL TENGAH KANAN: Komposisi Produk
              // ═══════════════════════════════════════
              dashAsync.when(
                data: (d) => _ProductCompositionPanel(orders: d.thisMonthCompleted),
                loading: () => _buildLoadingCard(200),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ═══════════════════════════════════════
              // 4. PANEL BAWAH KIRI: Staf & Pembayaran
              // ═══════════════════════════════════════
              dashAsync.when(
                data: (d) =>
                    _StaffPaymentPanel(orders: d.thisMonthCompleted),
                loading: () => _buildLoadingCard(200),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ═══════════════════════════════════════
              // 5. Summary Inventory
              // ═══════════════════════════════════════
              inventoryAsync.when(
                data: (items) => dashAsync.when(
                  data: (d) =>
                      _InventorySummaryPanel(items: items, orders: d.thisMonthCompleted),
                  loading: () => _buildLoadingCard(140),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                loading: () => _buildLoadingCard(140),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ═══════════════════════════════════════
              // 6. PANEL REKOMENDASI EKSEKUTIF
              // ═══════════════════════════════════════
              dashAsync.when(
                data: (d) => inventoryAsync.when(
                  data: (inv) => _RecommendationsPanel(data: d, inventory: inv),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                loading: () => _buildLoadingCard(200),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // 1. KPI Panel
  // ──────────────────────────────────────────
  Widget _buildKPIPanel(_DashboardData d) {
    final current = d.thisMonthCompleted;
    final prev = d.lastMonthCompleted;
    final returned = d.thisMonthReturned;

    final totalRevenue =
        current.fold<double>(0, (s, o) => s + o.total);
    final prevRevenue =
        prev.fold<double>(0, (s, o) => s + o.total);
    final totalReturns =
        returned.fold<double>(0, (s, o) => s + o.total);
    final netRevenue = totalRevenue - totalReturns;

    final trxCount = current.length;
    final prevTrxCount = prev.length;

    final avo = trxCount > 0 ? totalRevenue / trxCount : 0.0;
    final prevAvo = prevTrxCount > 0 ? prevRevenue / prevTrxCount : 0.0;

    final totalDiscount = _calcDiscount(current);
    final discountPct =
        totalRevenue > 0 ? (totalDiscount / totalRevenue * 100) : 0.0;

    // Gross Profit
    final cogsAsync = ref.watch(todayCOGSProvider);
    final todayOrders = ref.watch(todayOrdersProvider).valueOrNull ?? [];
    final todaySales = todayOrders.fold<double>(0, (s, o) => s + o.total);
    final todaySubtotal = todayOrders.fold<double>(0, (s, o) => s + o.subtotal);
    final todayDiscount = _calcDiscount(todayOrders);
    final todayNetSales = todaySubtotal - todayDiscount;
    final grossProfit = cogsAsync.when(
      data: (cogs) => todayNetSales - cogs,
      loading: () => todayNetSales,
      error: (_, __) => todayNetSales,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ringkasan Kinerja Bulan Ini', style: AppTextStyles.heading3),
        const SizedBox(height: AppSpacing.sm),

        // Row 1: Revenue + Transactions
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                icon: Icons.attach_money_rounded,
                iconColor: AppColors.successGreen,
                label: 'Total Pendapatan',
                value: Formatters.currency(totalRevenue),
                change: _pctChange(totalRevenue, prevRevenue),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildKPICard(
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.infoBlue,
                label: 'Jumlah Transaksi',
                value: '$trxCount',
                change: _pctChange(trxCount.toDouble(), prevTrxCount.toDouble()),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Row 2: AVO + Returns
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                icon: Icons.shopping_cart_rounded,
                iconColor: AppColors.warningAmber,
                label: 'Rata-rata Transaksi',
                value: Formatters.currency(avo),
                change: _pctChange(avo, prevAvo),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildKPICard(
                icon: Icons.assignment_return_rounded,
                iconColor: Colors.deepPurple,
                label: 'Return',
                value: Formatters.currency(totalReturns),
                subtitle: '${returned.length} order',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Row 3: Discount + Gross Profit
        Row(
          children: [
            Expanded(
              child: _buildKPICard(
                icon: Icons.discount_rounded,
                iconColor: AppColors.errorRed,
                label: 'Total Diskon',
                value: Formatters.currency(totalDiscount),
                subtitle: '${discountPct.toStringAsFixed(1)}% dari pendapatan',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildKPICard(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: Colors.teal,
                label: 'Gross Profit (Hari Ini)',
                value: Formatters.currency(grossProfit),
                subtitle: 'Net Sales - HPP',
              ),
            ),
          ],
        ),
      ],
    );
  }

  double _calcDiscount(List<Order> orders) {
    double total = 0;
    for (final o in orders) {
      total += o.discountAmount;
      if (o.promotionsJson != null) {
        try {
          final promos = jsonDecode(o.promotionsJson!) as List;
          for (final p in promos) {
            if (p is Map<String, dynamic> && p['discountAmount'] != null) {
              total += (p['discountAmount'] as num).toDouble();
            }
          }
        } catch (_) {}
      }
    }
    return total;
  }

  String? _pctChange(double current, double previous) {
    if (previous == 0 && current == 0) return null;
    if (previous == 0) return '+100%';
    final pct = ((current - previous) / previous * 100);
    final prefix = pct >= 0 ? '+' : '';
    return '$prefix${pct.toStringAsFixed(1)}%';
  }

  Widget _buildKPICard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? change,
    String? subtitle,
  }) {
    final isPositive = change != null && change.startsWith('+');
    final isNeutral = change == null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const Spacer(),
              if (change != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? AppColors.successGreen.withOpacity(0.1)
                        : AppColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    change,
                    style: AppTextStyles.caption.copyWith(
                      color: isPositive
                          ? AppColors.successGreen
                          : AppColors.errorRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              style: AppTextStyles.heading3.copyWith(fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textHint, fontSize: 10)),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // 2. Trend Panel with chart type toggle
  // ──────────────────────────────────────────
  Widget _buildTrendPanel(_DashboardData d) {
    final orders = d.last7DaysOrders
        .where((o) => o.status == 'completed')
        .toList();
    final now = DateTime.now();

    // Build 7-day data
    final List<_DayData> dayData = [];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day - i);
      final dayOrders = orders.where((o) =>
          o.createdAt.year == day.year &&
          o.createdAt.month == day.month &&
          o.createdAt.day == day.day);
      final total = dayOrders.fold<double>(0, (s, o) => s + o.total);
      final count = dayOrders.length;
      const dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      dayData.add(_DayData(
        label: dayNames[day.weekday - 1],
        total: total,
        count: count,
        isToday: i == 0,
      ));
    }

    // Peak hours from 30-day data
    final allCompleted = d.last30DaysOrders
        .where((o) => o.status == 'completed')
        .toList();
    final Map<int, int> hourlyCount = {};
    for (final o in allCompleted) {
      final h = o.createdAt.hour;
      hourlyCount[h] = (hourlyCount[h] ?? 0) + 1;
    }
    final peakHours = hourlyCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final peakHourStr = peakHours.isNotEmpty
        ? '${peakHours.first.key.toString().padLeft(2, '0')}:00 - ${(peakHours.first.key + 1).toString().padLeft(2, '0')}:00'
        : '-';

    // Weekend vs weekday analysis
    double weekendRevenue = 0, weekdayRevenue = 0;
    int weekendDays = 0, weekdayDays = 0;
    for (final dd in dayData) {
      // Sab=5, Min=6 in our list (index from Mon)
    }
    for (final o in allCompleted) {
      if (o.createdAt.weekday >= 6) {
        weekendRevenue += o.total;
      } else {
        weekdayRevenue += o.total;
      }
    }

    return _buildSectionCard(
      title: 'Tren Penjualan (7 Hari Terakhir)',
      icon: Icons.trending_up_rounded,
      iconColor: AppColors.primaryOrange,
      trailing: _buildChartTypeToggle(),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _chartType == ChartType.bar
                  ? _buildBarChart(dayData)
                  : _chartType == ChartType.line
                      ? _buildLineChart(dayData)
                      : _buildPieChart(dayData),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _buildInsightRow(Icons.access_time_filled_rounded,
                    'Jam Tersibuk', peakHourStr),
                if (peakHours.length > 1)
                  _buildInsightRow(
                      Icons.access_time_rounded,
                      'Jam Tersibuk #2',
                      '${peakHours[1].key.toString().padLeft(2, '0')}:00 (${peakHours[1].value} trx)'),
                _buildInsightRow(
                    Icons.weekend_rounded,
                    'Weekend Revenue',
                    Formatters.currency(weekendRevenue)),
                _buildInsightRow(
                    Icons.work_rounded,
                    'Weekday Revenue',
                    Formatters.currency(weekdayRevenue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chartToggleButton(ChartType.bar, Icons.bar_chart_rounded),
          _chartToggleButton(ChartType.line, Icons.show_chart_rounded),
          _chartToggleButton(ChartType.pie, Icons.pie_chart_rounded),
        ],
      ),
    );
  }

  Widget _chartToggleButton(ChartType type, IconData icon) {
    final isSelected = _chartType == type;
    return GestureDetector(
      onTap: () => setState(() => _chartType = type),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 18, color: isSelected ? Colors.white : AppColors.textHint),
      ),
    );
  }

  // ── Bar Chart ──
  Widget _buildBarChart(List<_DayData> data) {
    final maxVal =
        data.fold<double>(0, (m, d) => math.max(m, d.total));
    final chartMax = maxVal == 0 ? 1.0 : maxVal;

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) {
              final ratio = d.total / chartMax;
              final barH = math.max(4.0, ratio * 130);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (d.total > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(_compactCurrency(d.total),
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: d.isToday
                                    ? AppColors.primaryOrange
                                    : AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center),
                        ),
                      Container(
                        height: barH,
                        decoration: BoxDecoration(
                          color: d.isToday
                              ? AppColors.primaryOrange
                              : AppColors.primaryOrange.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: data.map((d) {
            return Expanded(
              child: Text(d.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 11,
                    fontWeight: d.isToday ? FontWeight.w700 : FontWeight.w400,
                    color: d.isToday
                        ? AppColors.primaryOrange
                        : AppColors.textSecondary,
                  )),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Line Chart ──
  Widget _buildLineChart(List<_DayData> data) {
    final maxVal =
        data.fold<double>(0, (m, d) => math.max(m, d.total));
    final chartMax = maxVal == 0 ? 1.0 : maxVal;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight - 10;
              final stepX = w / (data.length - 1);

              return CustomPaint(
                size: Size(w, h),
                painter: _LineChartPainter(
                  data: data,
                  maxValue: chartMax,
                  color: AppColors.primaryOrange,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: data.map((d) {
            return Expanded(
              child: Text(d.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 11,
                    fontWeight: d.isToday ? FontWeight.w700 : FontWeight.w400,
                    color: d.isToday
                        ? AppColors.primaryOrange
                        : AppColors.textSecondary,
                  )),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Pie Chart ──
  Widget _buildPieChart(List<_DayData> data) {
    final total = data.fold<double>(0, (s, d) => s + d.total);
    if (total == 0) {
      return const Center(child: Text('Belum ada data'));
    }

    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: _DonutChartPainter(
                values: data.map((d) => d.total).toList(),
                colors: List.generate(data.length, (i) {
                  final opacity = 0.3 + (i / data.length) * 0.7;
                  return AppColors.primaryOrange.withOpacity(opacity);
                }),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: data.map((d) {
              final pct = total > 0 ? (d.total / total * 100) : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withOpacity(
                            0.3 + (data.indexOf(d) / data.length) * 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${d.label}',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${pct.toStringAsFixed(0)}%',
                        style: AppTextStyles.caption),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  // Performance Panel (Branch / Terminal)
  // ──────────────────────────────────────────
  Widget _buildPerformancePanel({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<_EntityPerformance> data,
    required _PerfViewMode viewMode,
    required ValueChanged<_PerfViewMode> onViewModeChanged,
  }) {
    return _buildSectionCard(
      title: title,
      icon: icon,
      iconColor: iconColor,
      trailing: _buildPerfViewToggle(viewMode, onViewModeChanged),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: viewMode == _PerfViewMode.table
            ? _buildPerfTable(data)
            : viewMode == _PerfViewMode.bar
                ? _buildPerfBarChart(data)
                : viewMode == _PerfViewMode.line
                    ? _buildPerfLineChart(data)
                    : _buildPerfPieChart(data),
      ),
    );
  }

  Widget _buildPerfViewToggle(
      _PerfViewMode current, ValueChanged<_PerfViewMode> onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _perfToggleBtn(
              _PerfViewMode.table, Icons.table_chart_rounded, current, onChanged),
          _perfToggleBtn(
              _PerfViewMode.bar, Icons.bar_chart_rounded, current, onChanged),
          _perfToggleBtn(
              _PerfViewMode.line, Icons.show_chart_rounded, current, onChanged),
          _perfToggleBtn(
              _PerfViewMode.pie, Icons.pie_chart_rounded, current, onChanged),
        ],
      ),
    );
  }

  Widget _perfToggleBtn(_PerfViewMode mode, IconData icon,
      _PerfViewMode current, ValueChanged<_PerfViewMode> onChanged) {
    final isSelected = current == mode;
    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 16, color: isSelected ? Colors.white : AppColors.textHint),
      ),
    );
  }

  // ── Performance: Table View ──
  Widget _buildPerfTable(List<_EntityPerformance> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        headingTextStyle: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Nama')),
          DataColumn(label: Text('Revenue'), numeric: true),
          DataColumn(label: Text('Trx'), numeric: true),
          DataColumn(label: Text('AVO'), numeric: true),
        ],
        rows: List.generate(data.length, (i) {
          final d = data[i];
          final isTop = i == 0 && data.length > 1;
          return DataRow(
            color: WidgetStateProperty.resolveWith<Color?>((states) =>
                isTop ? AppColors.primaryOrange.withOpacity(0.08) : null),
            cells: [
              DataCell(Text('${i + 1}',
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w600))),
              DataCell(Text(d.name,
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: isTop ? FontWeight.w700 : FontWeight.w500))),
              DataCell(Text(Formatters.currency(d.revenue),
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isTop
                          ? AppColors.primaryOrange
                          : AppColors.textPrimary))),
              DataCell(Text('${d.transactionCount}',
                  style: AppTextStyles.bodySmall)),
              DataCell(Text(Formatters.currency(d.avo),
                  style: AppTextStyles.bodySmall)),
            ],
          );
        }),
      ),
    );
  }

  // ── Performance: Horizontal Bar Chart ──
  Widget _buildPerfBarChart(List<_EntityPerformance> data) {
    final maxRevenue = data.fold<double>(0, (m, d) => math.max(m, d.revenue));
    final chartMax = maxRevenue == 0 ? 1.0 : maxRevenue;

    return Column(
      children: List.generate(data.length, (i) {
        final d = data[i];
        final ratio = d.revenue / chartMax;
        final color = _perfColors[i % _perfColors.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(d.name,
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGrey,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio.clamp(0.02, 1.0),
                          child: Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.centerRight,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _compactCurrency(d.revenue),
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 36,
                    child: Text('${d.transactionCount}trx',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textHint, fontSize: 9),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── Performance: Line Chart ──
  Widget _buildPerfLineChart(List<_EntityPerformance> data) {
    if (data.isEmpty) return const Center(child: Text('Belum ada data'));
    final maxVal = data.fold<double>(0, (m, d) => math.max(m, d.revenue));
    final chartMax = maxVal == 0 ? 1.0 : maxVal;

    return SizedBox(
      height: math.max(180.0, data.length * 10.0 + 60),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight - 24;
          return Column(
            children: [
              Expanded(
                child: CustomPaint(
                  size: Size(w, h),
                  painter: _PerfLineChartPainter(
                    data: data,
                    maxValue: chartMax,
                    colors: _perfColors,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: data.map((d) {
                  return Expanded(
                    child: Text(
                      d.name,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 9, color: AppColors.textHint),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Performance: Pie/Donut Chart ──
  Widget _buildPerfPieChart(List<_EntityPerformance> data) {
    final totalRevenue = data.fold<double>(0, (s, d) => s + d.revenue);
    if (totalRevenue == 0) {
      return const Center(child: Text('Belum ada data'));
    }

    return SizedBox(
      height: math.max(160.0, data.length * 22.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _DonutChartPainter(
                  values: data.map((d) => d.revenue).toList(),
                  colors: List.generate(data.length,
                      (i) => _perfColors[i % _perfColors.length]),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(data.length, (i) {
                final d = data[i];
                final pct = (d.revenue / totalRevenue * 100);
                final color = _perfColors[i % _perfColors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(d.name,
                            style: AppTextStyles.caption
                                .copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      Text('${pct.toStringAsFixed(1)}%',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textHint)),
                      const SizedBox(width: 4),
                      Text(_compactCurrency(d.revenue),
                          style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700, fontSize: 10)),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────
  Widget _buildInsightRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
          Text(value,
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.heading3.copyWith(fontSize: 15)),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }

  Widget _buildLoadingCard(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  String _compactCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return amount.toStringAsFixed(0);
  }

  Widget _buildWelcomeHeader(User? user, Store? store) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selamat Datang,',
              style: AppTextStyles.bodyLarge
                  .copyWith(color: Colors.white.withOpacity(0.9))),
          const SizedBox(height: AppSpacing.xs),
          Text(user?.name ?? 'Kasir',
              style: AppTextStyles.heading2.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpacing.xs),
          Text(store?.name ?? 'Kompak Store',
              style: AppTextStyles.bodySmall
                  .copyWith(color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }

  // ═══════ Session Card (unchanged) ═══════
  Widget _buildSessionCard(
    BuildContext context, {
    required bool isOpen,
    PosSession? session,
    required VoidCallback onAction,
    VoidCallback? onClose,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpen ? AppColors.successGreen : AppColors.warningAmber,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isOpen ? AppColors.successGreen : AppColors.warningAmber)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isOpen ? Icons.point_of_sale_rounded : Icons.lock_rounded,
              color: isOpen ? AppColors.successGreen : AppColors.warningAmber,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isOpen ? 'Kasir Aktif' : 'Kasir Belum Dibuka',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                if (isOpen && session != null)
                  Text('Dibuka: ${Formatters.time(session.openedAt)}',
                      style: AppTextStyles.bodySmall),
                if (!isOpen)
                  Text('Buka kasir untuk memulai transaksi',
                      style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          if (isOpen && onClose != null)
            TextButton(onPressed: onClose, child: const Text('Tutup')),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryOrange),
            child: Text(isOpen ? 'Buka POS' : 'Mulai'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          splashColor: Colors.white24,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════ Drawer (unchanged) ═══════
  Future<void> _handleLogout(BuildContext context) async {
    final session = ref.read(activeSessionProvider).valueOrNull;
    final user = ref.read(currentUserProvider);
    if (user?.role == 'cashier' && session != null) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sesi Masih Aktif'),
          content: const Text(
            'Tutup sesi kasir terlebih dahulu sebelum logout.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    await performLogout(ref);
    if (context.mounted) context.go('/auth');
  }

  /// Open the multi-user PIN dialog. On success navigate to the
  /// attendance screen with the verified user's id.
  Future<void> _openAttendancePinDialog(BuildContext context) async {
    final user = await AttendancePinDialog.show(context);
    if (user == null || !context.mounted) return;
    context.push('/attendance?userId=${user.id}');
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);
    final session = activeSession.valueOrNull;
    final role = ref.watch(currentUserProvider)?.role ?? 'cashier';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(color: AppColors.primaryOrange),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.point_of_sale_rounded,
                      color: Colors.white, size: 40),
                  const SizedBox(height: AppSpacing.md),
                  Text('Kompak POS',
                      style:
                          AppTextStyles.heading2.copyWith(color: Colors.white)),
                  Text(
                      ref.watch(currentStoreProvider)?.name ?? 'Kompak Store',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white.withOpacity(0.8))),
                  if (ref.watch(currentUserProvider) != null)
                    Text(
                      '${ref.watch(currentUserProvider)!.name} (${role})',
                      style: AppTextStyles.caption
                          .copyWith(color: Colors.white.withOpacity(0.6)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (Permissions.canAccessPOS(role))
              _buildDrawerItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/pos/catalog');
                  }),
            if (Permissions.canViewReports(role))
              _buildExpandableSection(context,
                  icon: Icons.assessment_rounded,
                  label: 'Laporan',
                  children: [
                    _buildSubMenuItem(
                        icon: Icons.access_time_rounded,
                        label: 'Laporan Sesi',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/reports/sessions');
                        }),
                    _buildSubMenuItem(
                        icon: Icons.list_alt_rounded,
                        label: 'List Order',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/orders');
                        }),
                    _buildSubMenuItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Laporan Penjualan',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/reports/sales');
                        }),
                  ]),
            if (Permissions.canViewInventory(role))
              _buildExpandableSection(context,
                  icon: Icons.inventory_2_rounded,
                  label: 'Inventory',
                  children: [
                    _buildSubMenuItem(
                        icon: Icons.add_shopping_cart_rounded,
                        label: 'Restock Inventory',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/inventory/restock');
                        }),
                    _buildSubMenuItem(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Adjustment Inventory',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/inventory/adjustment');
                        }),
                    _buildSubMenuItem(
                        icon: Icons.analytics_rounded,
                        label: 'Laporan Inventory',
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/inventory/report');
                        }),
                  ]),
            if (Permissions.canViewKitchen(role))
              _buildDrawerItem(
                  icon: Icons.restaurant_rounded,
                  label: 'Kitchen Display',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/kitchen');
                  }),
            if (Permissions.canViewDashboard(role))
              _buildDrawerItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/dashboard');
                  }),
            const Divider(),
            if (session != null && Permissions.canAccessPOS(role))
              _buildDrawerItem(
                  icon: Icons.point_of_sale_outlined,
                  label: 'Tutup Kasir',
                  color: AppColors.warningAmber,
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) =>
                          CloseRegisterDialog(sessionId: session.id),
                    );
                  }),
            if (Permissions.canViewSettings(role))
              _buildDrawerItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  }),
            const Spacer(),
            _buildDrawerItem(
                icon: Icons.logout_rounded,
                label: 'Logout',
                color: AppColors.errorRed,
                onTap: () async {
                  Navigator.pop(context);
                  await performLogout(ref);
                  if (context.mounted) context.go('/auth');
                }),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textSecondary),
      title: Text(label,
          style: AppTextStyles.bodyLarge
              .copyWith(color: color ?? AppColors.textPrimary)),
      onTap: onTap,
    );
  }

  Widget _buildExpandableSection(BuildContext context,
      {required IconData icon,
      required String label,
      required List<Widget> children}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(label,
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.textPrimary)),
        childrenPadding: const EdgeInsets.only(left: AppSpacing.md),
        children: children,
      ),
    );
  }

  Widget _buildSubMenuItem(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(label, style: AppTextStyles.bodyMedium),
      dense: true,
      onTap: onTap,
    );
  }
}

// ══════════════════════════════════════════════
// Product Composition Panel (by Category)
// ══════════════════════════════════════════════
class _ProductCompositionPanel extends ConsumerWidget {
  final List<Order> orders;
  const _ProductCompositionPanel({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, double>>(
      future: _calcCategoryRevenue(ref),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final sorted = data.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final total = sorted.fold<double>(0, (s, e) => s + e.value);

        final colors = [
          AppColors.primaryOrange,
          AppColors.infoBlue,
          AppColors.successGreen,
          AppColors.warningAmber,
          Colors.deepPurple,
          Colors.teal,
          Colors.pink,
        ];

        // Limit to top 7
        final top = sorted.take(7).toList();

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.donut_large_rounded,
                        size: 20, color: AppColors.primaryOrange),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Komposisi Pendapatan per Kategori',
                        style:
                            AppTextStyles.heading3.copyWith(fontSize: 15)),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (top.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: Text('Belum ada data')))
              else
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      // Donut chart
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CustomPaint(
                          painter: _DonutChartPainter(
                            values: top.map((e) => e.value).toList(),
                            colors: List.generate(
                                top.length,
                                (i) =>
                                    colors[i % colors.length]),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Legend
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: top.asMap().entries.map((entry) {
                            final i = entry.key;
                            final cat = entry.value;
                            final pct = total > 0
                                ? (cat.value / total * 100)
                                : 0.0;
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color:
                                          colors[i % colors.length],
                                      borderRadius:
                                          BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(cat.key,
                                        style: AppTextStyles.caption
                                            .copyWith(
                                                fontWeight:
                                                    FontWeight.w600),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis),
                                  ),
                                  Text(
                                      '${pct.toStringAsFixed(1)}%',
                                      style: AppTextStyles.caption),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              // Insight
              if (top.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_rounded,
                            size: 16, color: AppColors.infoBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            total > 0
                                ? 'Kategori "${top.first.key}" menyumbang ${(top.first.value / total * 100).toStringAsFixed(0)}% dari total pendapatan'
                                : '',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.infoBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, double>> _calcCategoryRevenue(WidgetRef ref) async {
    if (orders.isEmpty) return {};
    final db = ref.read(databaseProvider);
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return {};

    // Load categories and products for mapping
    final categories = await db.categoryDao.getAllByStore(storeId);
    final products = await db.productDao.getAllByStore(storeId);

    final catNameMap = <String, String>{};
    for (final c in categories) catNameMap[c.id] = c.name;

    final prodCatMap = <String, String>{};
    for (final p in products) {
      prodCatMap[p.id] = catNameMap[p.categoryId] ?? 'Lainnya';
    }

    final Map<String, double> result = {};
    for (final order in orders) {
      final items = await db.orderDao.getItemsForOrder(order.id);
      for (final item in items) {
        final catName = prodCatMap[item.productId] ?? 'Lainnya';
        result[catName] = (result[catName] ?? 0) + item.subtotal;
      }
    }
    return result;
  }
}

// ══════════════════════════════════════════════
// Staff Performance & Payment Methods Panel
// ══════════════════════════════════════════════
class _StaffPaymentPanel extends ConsumerWidget {
  final List<Order> orders;
  const _StaffPaymentPanel({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<_StaffPaymentData>(
      future: _calculate(ref),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final paymentColors = {
          'cash': AppColors.successGreen,
          'card': AppColors.infoBlue,
          'qris': AppColors.primaryOrange,
          'transfer': Colors.deepPurple,
        };

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.people_rounded,
                        size: 20, color: AppColors.warningAmber),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Kinerja Staf & Pembayaran',
                        style:
                            AppTextStyles.heading3.copyWith(fontSize: 15)),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Staff revenue - horizontal bars
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pendapatan per Staf',
                        style: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.sm),
                    if (data.staffRevenue.isEmpty)
                      Text('Belum ada data',
                          style: AppTextStyles.caption)
                    else
                      ...data.staffRevenue.entries.take(5).map((e) {
                        final maxRev = data.staffRevenue.values
                            .fold<double>(0, math.max);
                        final ratio = maxRev > 0 ? e.value / maxRev : 0.0;
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key,
                                      style: AppTextStyles.caption.copyWith(
                                          fontWeight: FontWeight.w600)),
                                  Text(Formatters.currency(e.value),
                                      style: AppTextStyles.caption.copyWith(
                                          color: AppColors.primaryOrange)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  backgroundColor:
                                      AppColors.surfaceGrey,
                                  valueColor:
                                      const AlwaysStoppedAnimation(
                                          AppColors.primaryOrange),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Payment methods donut
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Metode Pembayaran',
                        style: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: AppSpacing.sm),
                    if (data.paymentMethods.isEmpty)
                      Text('Belum ada data',
                          style: AppTextStyles.caption)
                    else
                      Row(
                        children: [
                          SizedBox(
                            width: 90,
                            height: 90,
                            child: CustomPaint(
                              painter: _DonutChartPainter(
                                values: data.paymentMethods.values
                                    .toList(),
                                colors: data.paymentMethods.keys
                                    .map((k) =>
                                        paymentColors[k] ??
                                        AppColors.textHint)
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              children: data.paymentMethods.entries
                                  .map((e) {
                                final pct = data.paymentTotal > 0
                                    ? (e.value /
                                            data.paymentTotal *
                                            100)
                                    : 0.0;
                                final methodLabel = {
                                  'cash': 'Tunai',
                                  'card': 'Kartu',
                                  'qris': 'QRIS',
                                  'transfer': 'Transfer',
                                }[e.key] ?? e.key;

                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: paymentColors[e.key] ??
                                              AppColors.textHint,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(methodLabel,
                                          style: AppTextStyles.caption
                                              .copyWith(
                                                  fontWeight:
                                                      FontWeight.w600)),
                                      const Spacer(),
                                      Text(
                                          '${pct.toStringAsFixed(0)}%',
                                          style:
                                              AppTextStyles.caption),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<_StaffPaymentData> _calculate(WidgetRef ref) async {
    final db = ref.read(databaseProvider);

    // Staff revenue
    final Map<String, double> staffRev = {};
    final Map<String, String> cashierNames = {};
    for (final o in orders) {
      if (!cashierNames.containsKey(o.cashierId)) {
        final user = await db.userDao.getUserById(o.cashierId);
        cashierNames[o.cashierId] = user?.name ?? 'Unknown';
      }
      final name = cashierNames[o.cashierId]!;
      staffRev[name] = (staffRev[name] ?? 0) + o.total;
    }
    // Sort by revenue desc
    final sortedStaff = Map.fromEntries(
        staffRev.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

    // Payment methods
    final orderIds = orders.map((o) => o.id).toList();
    final payments = await db.paymentDao.getPaymentsForOrders(orderIds);
    final Map<String, double> methodMap = {};
    for (final p in payments) {
      final netAmount = p.amount - p.changeAmount;
      methodMap[p.method] = (methodMap[p.method] ?? 0) + netAmount;
    }
    final paymentTotal = methodMap.values.fold<double>(0, (s, v) => s + v);

    return _StaffPaymentData(
      staffRevenue: sortedStaff,
      paymentMethods: methodMap,
      paymentTotal: paymentTotal,
    );
  }
}

class _StaffPaymentData {
  final Map<String, double> staffRevenue;
  final Map<String, double> paymentMethods;
  final double paymentTotal;

  _StaffPaymentData({
    required this.staffRevenue,
    required this.paymentMethods,
    required this.paymentTotal,
  });
}

// ══════════════════════════════════════════════
// Inventory Summary Panel
// ══════════════════════════════════════════════
class _InventorySummaryPanel extends StatelessWidget {
  final List<InventoryWithProduct> items;
  final List<Order> orders;

  const _InventorySummaryPanel(
      {required this.items, required this.orders});

  @override
  Widget build(BuildContext context) {
    final totalProducts = items.length;
    final outOfStock = items.where((i) => i.inventory.quantity <= 0).length;
    final lowStock = items
        .where((i) =>
            i.inventory.quantity > 0 &&
            i.inventory.quantity <= i.inventory.lowStockThreshold)
        .length;
    final healthy = totalProducts - outOfStock - lowStock;
    final healthPct =
        totalProducts > 0 ? (healthy / totalProducts * 100) : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.inventory_2_rounded,
                    size: 20, color: Colors.teal),
                const SizedBox(width: AppSpacing.sm),
                Text('Ringkasan Inventory',
                    style: AppTextStyles.heading3.copyWith(fontSize: 15)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildMiniStat('Total Produk', '$totalProducts',
                        AppColors.infoBlue),
                    const SizedBox(width: AppSpacing.sm),
                    _buildMiniStat(
                        'Stok Aman', '$healthy', AppColors.successGreen),
                    const SizedBox(width: AppSpacing.sm),
                    _buildMiniStat(
                        'Stok Rendah', '$lowStock', AppColors.warningAmber),
                    const SizedBox(width: AppSpacing.sm),
                    _buildMiniStat(
                        'Habis', '$outOfStock', AppColors.errorRed),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Health bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Stock Health',
                            style: AppTextStyles.caption
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text('${healthPct.toStringAsFixed(0)}%',
                            style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.bold,
                                color: healthPct > 80
                                    ? AppColors.successGreen
                                    : healthPct > 50
                                        ? AppColors.warningAmber
                                        : AppColors.errorRed)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: healthPct / 100,
                        backgroundColor: AppColors.surfaceGrey,
                        valueColor: AlwaysStoppedAnimation(healthPct > 80
                            ? AppColors.successGreen
                            : healthPct > 50
                                ? AppColors.warningAmber
                                : AppColors.errorRed),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
                if (outOfStock > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_rounded,
                            size: 16, color: AppColors.errorRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$outOfStock produk habis stok, perlu segera restock!',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.errorRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: AppTextStyles.caption.copyWith(fontSize: 9),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// Executive Recommendations Panel
// ══════════════════════════════════════════════
class _RecommendationsPanel extends StatelessWidget {
  final _DashboardData data;
  final List<InventoryWithProduct> inventory;

  const _RecommendationsPanel(
      {required this.data, required this.inventory});

  @override
  Widget build(BuildContext context) {
    final recommendations = _generateRecommendations();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.lightbulb_rounded,
                    size: 20, color: AppColors.warningAmber),
                const SizedBox(width: AppSpacing.sm),
                Text('Ringkasan & Rekomendasi',
                    style: AppTextStyles.heading3.copyWith(fontSize: 15)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Executive summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primaryOrange.withOpacity(0.2)),
                  ),
                  child: Text(
                    _generateSummary(),
                    style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Rekomendasi Tindakan:',
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                ...recommendations.asMap().entries.map((e) {
                  final i = e.key;
                  final rec = e.value;
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: rec.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Icon(rec.icon,
                                size: 14, color: rec.color),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(rec.title,
                                  style: AppTextStyles.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: rec.color)),
                              Text(rec.description,
                                  style: AppTextStyles.caption
                                      .copyWith(height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateSummary() {
    final current = data.thisMonthCompleted;
    final prev = data.lastMonthCompleted;
    final curRevenue = current.fold<double>(0, (s, o) => s + o.total);
    final prevRevenue = prev.fold<double>(0, (s, o) => s + o.total);

    final trend = prevRevenue > 0
        ? ((curRevenue - prevRevenue) / prevRevenue * 100)
        : 0.0;
    final trendWord =
        trend >= 0 ? 'pertumbuhan positif' : 'penurunan';
    final trendPct = trend.abs().toStringAsFixed(1);

    final returns = data.thisMonthReturned.length;
    final returnStr = returns > 0
        ? ' Terdapat $returns order return bulan ini.'
        : '';

    return 'Bulan ini menunjukkan $trendWord ${trendPct}% pada pendapatan '
        'dibanding bulan lalu. Total ${current.length} transaksi berhasil '
        'diproses.$returnStr';
  }

  List<_Recommendation> _generateRecommendations() {
    final recs = <_Recommendation>[];

    // Inventory recommendations
    final outOfStock =
        inventory.where((i) => i.inventory.quantity <= 0).toList();
    final lowStock = inventory
        .where((i) =>
            i.inventory.quantity > 0 &&
            i.inventory.quantity <= i.inventory.lowStockThreshold)
        .toList();

    if (outOfStock.isNotEmpty) {
      final names = outOfStock.take(3).map((i) => i.productName).join(', ');
      recs.add(_Recommendation(
        icon: Icons.inventory_rounded,
        color: AppColors.errorRed,
        title: 'Stok',
        description:
            'Segera restock ${outOfStock.length} produk yang habis ($names${outOfStock.length > 3 ? ', ...' : ''}) untuk menghindari kehilangan penjualan.',
      ));
    }

    if (lowStock.isNotEmpty) {
      recs.add(_Recommendation(
        icon: Icons.warning_rounded,
        color: AppColors.warningAmber,
        title: 'Inventory',
        description:
            '${lowStock.length} produk dengan stok rendah. Pertimbangkan untuk melakukan restock sebelum habis.',
      ));
    }

    // Revenue trend
    final curRevenue =
        data.thisMonthCompleted.fold<double>(0, (s, o) => s + o.total);
    final prevRevenue =
        data.lastMonthCompleted.fold<double>(0, (s, o) => s + o.total);
    if (prevRevenue > 0 && curRevenue < prevRevenue) {
      recs.add(_Recommendation(
        icon: Icons.trending_down_rounded,
        color: AppColors.errorRed,
        title: 'Pendapatan',
        description:
            'Pendapatan bulan ini lebih rendah dari bulan lalu. Pertimbangkan program promosi untuk meningkatkan penjualan.',
      ));
    }

    // Return analysis
    final returns = data.thisMonthReturned;
    if (returns.length > 3) {
      recs.add(_Recommendation(
        icon: Icons.assignment_return_rounded,
        color: Colors.deepPurple,
        title: 'Return',
        description:
            'Ada ${returns.length} order return bulan ini. Periksa alasan return untuk meningkatkan kualitas layanan.',
      ));
    }

    // Peak hour staffing
    final allCompleted = data.last30DaysOrders
        .where((o) => o.status == 'completed')
        .toList();
    final Map<int, int> hourly = {};
    for (final o in allCompleted) {
      hourly[o.createdAt.hour] = (hourly[o.createdAt.hour] ?? 0) + 1;
    }
    if (hourly.isNotEmpty) {
      final peak = hourly.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      recs.add(_Recommendation(
        icon: Icons.schedule_rounded,
        color: AppColors.infoBlue,
        title: 'Operasional',
        description:
            'Optimalkan jadwal staf pada jam puncak ${peak.first.key.toString().padLeft(2, '0')}:00 untuk mempercepat layanan.',
      ));
    }

    // Default if no specific recs
    if (recs.isEmpty) {
      recs.add(_Recommendation(
        icon: Icons.check_circle_rounded,
        color: AppColors.successGreen,
        title: 'Status',
        description:
            'Semua indikator dalam kondisi baik. Pertahankan kinerja saat ini!',
      ));
    }

    return recs;
  }
}

class _Recommendation {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  _Recommendation({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}

// ══════════════════════════════════════════════
// Data models
// ══════════════════════════════════════════════
class _DayData {
  final String label;
  final double total;
  final int count;
  final bool isToday;

  _DayData({
    required this.label,
    required this.total,
    required this.count,
    required this.isToday,
  });
}

// ══════════════════════════════════════════════
// Custom painters
// ══════════════════════════════════════════════
class _LineChartPainter extends CustomPainter {
  final List<_DayData> data;
  final double maxValue;
  final Color color;

  _LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final stepX = size.width / (data.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i].total / maxValue * (size.height - 20));
      points.add(Offset(x, y));
    }

    // Draw fill
    if (points.length >= 2) {
      final fillPath = Path()..moveTo(points.first.dx, size.height);
      for (final p in points) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw line
    if (points.length >= 2) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(linePath, paint);
    }

    // Draw dots
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], data[i].isToday ? 5 : 3, dotPaint);
      if (data[i].isToday) {
        canvas.drawCircle(
            points[i], 7, Paint()..color = color.withOpacity(0.2));
      }
    }

    // Draw value labels on top
    for (int i = 0; i < points.length; i++) {
      if (data[i].total > 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: _compact(data[i].total),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: data[i].isToday ? color : Colors.grey,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas,
            Offset(
                points[i].dx - tp.width / 2, points[i].dy - tp.height - 4));
      }
    }
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}rb';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (s, v) => s + v);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.35;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    double startAngle = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      paint.color = colors[i % colors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Line chart painter for performance comparison (entities on X axis)
class _PerfLineChartPainter extends CustomPainter {
  final List<_EntityPerformance> data;
  final double maxValue;
  final List<Color> colors;

  _PerfLineChartPainter({
    required this.data,
    required this.maxValue,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final stepX = data.length > 1 ? w / (data.length - 1) : w / 2;

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = h - (h * i / 4);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Build points
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = data.length > 1 ? i * stepX : w / 2;
      final y = h - (data[i].revenue / maxValue * h * 0.85) - h * 0.05;
      points.add(Offset(x, y));
    }

    // Line path
    final linePaint = Paint()
      ..color = colors[0]
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }

    // Gradient fill
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, h)
      ..lineTo(points.first.dx, h)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors[0].withOpacity(0.3), colors[0].withOpacity(0.02)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Dots + value labels
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final color = colors[i % colors.length];

      canvas.drawCircle(pt, 4, Paint()..color = Colors.white);
      canvas.drawCircle(pt, 3, Paint()..color = color);

      final v = data[i].revenue;
      String label;
      if (v >= 1000000) {
        label = '${(v / 1000000).toStringAsFixed(1)}jt';
      } else if (v >= 1000) {
        label = '${(v / 1000).toStringAsFixed(0)}rb';
      } else {
        label = v.toStringAsFixed(0);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pt.dx - tp.width / 2, pt.dy - tp.height - 6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
