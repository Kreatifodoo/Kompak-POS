import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/database/app_database.dart';
import '../../models/enums.dart';
import '../../models/applied_promotion_model.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/orders/order_providers.dart';
import '../../widgets/common/terminal_filter_dropdown.dart';
import '../../widgets/common/branch_filter_dropdown.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  DateTimeRange? _selectedRange;
  String _filterLabel = 'Hari Ini';

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Laporan Penjualan', style: AppTextStyles.heading3),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            color: Colors.white,
            child: Row(
              children: [
                _buildFilterChip('Hari Ini', () {
                  setState(() => _filterLabel = 'Hari Ini');
                }),
                const SizedBox(width: AppSpacing.xs),
                _buildFilterChip('Minggu Ini', () {
                  setState(() => _filterLabel = 'Minggu Ini');
                }),
                const SizedBox(width: AppSpacing.xs),
                _buildFilterChip('Bulan Ini', () {
                  setState(() => _filterLabel = 'Bulan Ini');
                }),
                const SizedBox(width: AppSpacing.xs),
                _buildFilterChip('Custom', () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (range != null) {
                    setState(() {
                      _selectedRange = range;
                      _filterLabel = 'Custom';
                    });
                  }
                }),
              ],
            ),
          ),
          // Terminal & branch filter
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            color: Colors.white,
            child: const Row(
              children: [
                BranchFilterDropdown(),
                SizedBox(width: 8),
                TerminalFilterDropdown(),
              ],
            ),
          ),
          const Divider(height: 1),

          // Report content
          Expanded(
            child: ordersAsync.when(
              data: (orders) => _buildReportContent(orders),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent(List<Order> allOrders) {
    final filtered = _filterOrders(allOrders);

    // Separate completed, returned, and other
    final completedOrders =
        filtered.where((o) => o.status == 'completed').toList();
    final returnedOrders =
        filtered.where((o) => o.status == 'returned').toList();

    if (completedOrders.isEmpty && returnedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 64, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.md),
            Text('Belum ada data penjualan',
                style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    final totalSales =
        completedOrders.fold<double>(0, (sum, o) => sum + o.total);
    final totalDiscount =
        completedOrders.fold<double>(0, (sum, o) => sum + o.discountAmount);
    final totalTax =
        completedOrders.fold<double>(0, (sum, o) => sum + o.taxAmount);
    final totalReturns =
        returnedOrders.fold<double>(0, (sum, o) => sum + o.total);
    final netSales = totalSales - totalReturns;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards row 1
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Penjualan',
                  Formatters.currency(totalSales),
                  AppColors.successGreen,
                  Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSummaryCard(
                  'Total Transaksi',
                  '${completedOrders.length}',
                  AppColors.infoBlue,
                  Icons.receipt_long_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Summary cards row 2
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Diskon',
                  Formatters.currency(totalDiscount),
                  AppColors.warningAmber,
                  Icons.discount_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSummaryCard(
                  'Total Pajak/Biaya',
                  Formatters.currency(totalTax),
                  Colors.purple,
                  Icons.account_balance_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Return & Net Sales cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Return',
                  Formatters.currency(totalReturns),
                  Colors.deepPurple,
                  Icons.assignment_return_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSummaryCard(
                  'Net Sales',
                  Formatters.currency(netSales),
                  AppColors.primaryOrange,
                  Icons.attach_money_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Top 5 Product by Sales
          _buildTop5ProductCard(completedOrders),

          const SizedBox(height: AppSpacing.md),

          // Top 5 Customer by Transaction
          _buildTop5CustomerCard(completedOrders),

          const SizedBox(height: AppSpacing.md),

          // Promotion Insights
          _buildPromotionInsightsCard(completedOrders),

          const SizedBox(height: AppSpacing.md),

          // Sales Insights
          _buildSalesInsightsCard(completedOrders, totalSales, totalDiscount, netSales),

          // Return details section
          if (returnedOrders.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Detail Return', style: AppTextStyles.heading3),
            const SizedBox(height: AppSpacing.sm),
            ...returnedOrders.map((order) => _buildOrderTile(order, isReturn: true)),
          ],

          const SizedBox(height: AppSpacing.lg),
          Text('Detail Transaksi', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          ...completedOrders.map((order) => _buildOrderTile(order)),
        ],
      ),
    );
  }

  Widget _buildTop5ProductCard(List<Order> orders) {
    return FutureBuilder<List<_ProductSalesData>>(
      future: _getTop5Products(orders),
      builder: (context, snapshot) {
        final products = snapshot.data ?? [];
        return _buildAnalyticsCard(
          title: 'Top 5 Produk Terlaris',
          icon: Icons.star_rounded,
          iconColor: AppColors.warningAmber,
          child: products.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('Belum ada data'),
                )
              : Column(
                  children: products.asMap().entries.map((entry) {
                    final i = entry.key;
                    final p = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                          horizontal: AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primaryOrange,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                Text('${p.qty} terjual',
                                    style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          Text(Formatters.currency(p.totalSales),
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryOrange)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  Future<List<_ProductSalesData>> _getTop5Products(List<Order> orders) async {
    if (orders.isEmpty) return [];
    final db = ref.read(databaseProvider);
    final Map<String, _ProductSalesData> map = {};
    for (final order in orders) {
      final items = await db.orderDao.getItemsForOrder(order.id);
      for (final item in items) {
        final existing = map[item.productId];
        if (existing != null) {
          map[item.productId] = _ProductSalesData(
            name: item.productName,
            qty: existing.qty + item.quantity,
            totalSales: existing.totalSales + item.subtotal,
          );
        } else {
          map[item.productId] = _ProductSalesData(
            name: item.productName,
            qty: item.quantity,
            totalSales: item.subtotal,
          );
        }
      }
    }
    final sorted = map.values.toList()
      ..sort((a, b) => b.totalSales.compareTo(a.totalSales));
    return sorted.take(5).toList();
  }

  Widget _buildTop5CustomerCard(List<Order> orders) {
    // Group by customerId
    final Map<String?, int> customerCounts = {};
    final Map<String?, double> customerTotals = {};
    for (final o in orders) {
      final cid = o.customerId ?? '__walk_in__';
      customerCounts[cid] = (customerCounts[cid] ?? 0) + 1;
      customerTotals[cid] = (customerTotals[cid] ?? 0) + o.total;
    }

    final sorted = customerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();

    return _buildAnalyticsCard(
      title: 'Top 5 Customer by Transaksi',
      icon: Icons.people_rounded,
      iconColor: AppColors.infoBlue,
      child: top5.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('Belum ada data'))
          : Column(
              children: top5.asMap().entries.map((entry) {
                final i = entry.key;
                final cid = entry.value.key;
                final count = entry.value.value;
                final total = customerTotals[cid] ?? 0;
                final isWalkIn = cid == '__walk_in__';
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                      horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.infoBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.infoBlue,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: isWalkIn
                            ? Text('Walk-in Customer',
                                style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic))
                            : _CustomerNameResolver(customerId: cid!),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$count trx',
                              style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600)),
                          Text(Formatters.currency(total),
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryOrange)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPromotionInsightsCard(List<Order> orders) {
    // Parse promotions from all orders
    final Map<String, _PromoData> promoMap = {};
    int ordersWithPromo = 0;
    double totalPromoDiscount = 0;

    for (final o in orders) {
      if (o.promotionsJson != null && o.promotionsJson!.isNotEmpty) {
        ordersWithPromo++;
        try {
          final promoList = (jsonDecode(o.promotionsJson!) as List)
              .map((e) =>
                  AppliedPromotion.fromJson(e as Map<String, dynamic>))
              .toList();
          for (final promo in promoList) {
            totalPromoDiscount += promo.discountAmount;
            final existing = promoMap[promo.namaPromo];
            if (existing != null) {
              promoMap[promo.namaPromo] = _PromoData(
                name: promo.namaPromo,
                usageCount: existing.usageCount + 1,
                totalDiscount: existing.totalDiscount + promo.discountAmount,
              );
            } else {
              promoMap[promo.namaPromo] = _PromoData(
                name: promo.namaPromo,
                usageCount: 1,
                totalDiscount: promo.discountAmount,
              );
            }
          }
        } catch (_) {}
      }
    }

    final promoList = promoMap.values.toList()
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));

    // Count combo orders
    int comboOrders = 0;
    for (final o in orders) {
      // We'd need order items to check, but we can estimate from promotions
    }

    return _buildAnalyticsCard(
      title: 'Insight Promosi & Diskon',
      icon: Icons.local_offer_rounded,
      iconColor: AppColors.successGreen,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInsightRow(
              'Order dgn Promosi',
              '$ordersWithPromo dari ${orders.length} (${orders.isEmpty ? 0 : (ordersWithPromo * 100 / orders.length).toStringAsFixed(1)}%)',
              Icons.campaign_rounded,
            ),
            _buildInsightRow(
              'Total Diskon Promosi',
              Formatters.currency(totalPromoDiscount),
              Icons.money_off_rounded,
            ),
            if (promoList.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Program Promosi Aktif:',
                  style: AppTextStyles.bodySmall
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              ...promoList.take(5).map((p) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        Icon(Icons.circle,
                            size: 6, color: AppColors.successGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(p.name,
                              style: AppTextStyles.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                            '${p.usageCount}x | -${Formatters.currency(p.totalDiscount)}',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textHint)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSalesInsightsCard(
    List<Order> orders,
    double totalSales,
    double totalDiscount,
    double netSales,
  ) {
    if (orders.isEmpty) return const SizedBox.shrink();

    final avgOrder = totalSales / orders.length;

    // Group by hour for peak hours
    final Map<int, int> hourlyCount = {};
    for (final o in orders) {
      final h = o.createdAt.hour;
      hourlyCount[h] = (hourlyCount[h] ?? 0) + 1;
    }
    final peakHour = hourlyCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final peakHourStr = peakHour.isNotEmpty
        ? '${peakHour.first.key.toString().padLeft(2, '0')}:00 (${peakHour.first.value} trx)'
        : '-';

    // Discount rate
    final discountRate =
        totalSales > 0 ? (totalDiscount / (totalSales + totalDiscount) * 100) : 0.0;

    return _buildAnalyticsCard(
      title: 'Sales Insights',
      icon: Icons.insights_rounded,
      iconColor: AppColors.primaryOrange,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInsightRow(
              'Rata-rata per Transaksi',
              Formatters.currency(avgOrder),
              Icons.analytics_rounded,
            ),
            _buildInsightRow(
              'Jam Tersibuk',
              peakHourStr,
              Icons.access_time_filled_rounded,
            ),
            _buildInsightRow(
              'Discount Rate',
              '${discountRate.toStringAsFixed(1)}%',
              Icons.percent_rounded,
            ),
            _buildInsightRow(
              'Total Order',
              '${orders.length} transaksi',
              Icons.shopping_bag_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textHint),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Text(value,
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
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
                Text(title,
                    style: AppTextStyles.heading3.copyWith(fontSize: 15)),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  List<Order> _filterOrders(List<Order> orders) {
    final now = DateTime.now();
    // Only show completed and returned orders in sales report
    final salesOrders = orders.where((o) =>
        o.status == 'completed' || o.status == 'returned').toList();

    switch (_filterLabel) {
      case 'Hari Ini':
        return salesOrders
            .where((o) =>
                o.createdAt.year == now.year &&
                o.createdAt.month == now.month &&
                o.createdAt.day == now.day)
            .toList();
      case 'Minggu Ini':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return salesOrders
            .where((o) => o.createdAt.isAfter(
                DateTime(weekStart.year, weekStart.month, weekStart.day)))
            .toList();
      case 'Bulan Ini':
        return salesOrders
            .where((o) =>
                o.createdAt.year == now.year &&
                o.createdAt.month == now.month)
            .toList();
      case 'Custom':
        if (_selectedRange != null) {
          return salesOrders
              .where((o) =>
                  o.createdAt.isAfter(_selectedRange!.start
                      .subtract(const Duration(days: 1))) &&
                  o.createdAt.isBefore(
                      _selectedRange!.end.add(const Duration(days: 1))))
              .toList();
        }
        return salesOrders;
      default:
        return salesOrders;
    }
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    final isSelected = _filterLabel == label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryOrange
              : AppColors.primaryOrange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppColors.primaryOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String value, Color color, IconData icon) {
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
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style:
                  AppTextStyles.heading3.copyWith(color: color, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildOrderTile(Order order, {bool isReturn = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (isReturn)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(Icons.assignment_return_rounded,
                  size: 18, color: Colors.deepPurple),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderNumber,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(Formatters.dateTime(order.createdAt),
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            '${isReturn ? '-' : ''}${Formatters.currency(order.total)}',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isReturn ? Colors.deepPurple : AppColors.successGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSalesData {
  final String name;
  final int qty;
  final double totalSales;

  _ProductSalesData({
    required this.name,
    required this.qty,
    required this.totalSales,
  });
}

class _PromoData {
  final String name;
  final int usageCount;
  final double totalDiscount;

  _PromoData({
    required this.name,
    required this.usageCount,
    required this.totalDiscount,
  });
}

/// Resolves customer name from ID for display in top 5
class _CustomerNameResolver extends ConsumerWidget {
  final String customerId;
  const _CustomerNameResolver({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<Customer?>(
      future: db.customerDao.getById(customerId),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? 'Customer';
        return Text(name,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis);
      },
    );
  }
}
