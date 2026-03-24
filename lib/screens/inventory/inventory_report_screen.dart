import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/database/app_database.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/inventory/inventory_providers.dart';
import '../../modules/orders/order_providers.dart';

class InventoryReportScreen extends ConsumerWidget {
  const InventoryReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryWithProductProvider);
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
        title: Text('Laporan Inventory', style: AppTextStyles.heading3),
      ),
      body: inventoryAsync.when(
        data: (items) => ordersAsync.when(
          data: (orders) => _buildContent(context, ref, items, orders),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<InventoryWithProduct> items,
    List<Order> allOrders,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_rounded, size: 64, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.md),
            Text('Belum ada data inventory',
                style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    final totalProducts = items.length;
    final lowStockItems = items
        .where((i) =>
            i.inventory.quantity <= i.inventory.lowStockThreshold &&
            i.inventory.quantity > 0)
        .toList();
    final outOfStock = items.where((i) => i.inventory.quantity <= 0).toList();

    // Calculate total inventory value
    final totalStockValue = items.fold<double>(0, (sum, item) {
      return sum; // We don't have cost per unit in inventory data
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Produk',
                  '$totalProducts',
                  Icons.inventory_2_rounded,
                  AppColors.infoBlue,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSummaryCard(
                  'Stok Rendah',
                  '${lowStockItems.length}',
                  Icons.warning_rounded,
                  AppColors.warningAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Habis',
                  '${outOfStock.length}',
                  Icons.remove_shopping_cart_rounded,
                  AppColors.errorRed,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSummaryCard(
                  'Stok Tersedia',
                  '${totalProducts - outOfStock.length}',
                  Icons.check_circle_rounded,
                  AppColors.successGreen,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Top 5 Product by Qty Sold
          _Top5QtyWidget(orders: allOrders),

          const SizedBox(height: AppSpacing.md),

          // Pareto Analysis
          _ParetoAnalysisWidget(orders: allOrders, inventoryItems: items),

          const SizedBox(height: AppSpacing.md),

          // Inventory Insights
          _buildInventoryInsights(items, lowStockItems, outOfStock),

          // Out of stock section
          if (outOfStock.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Stok Habis',
                style: AppTextStyles.heading3
                    .copyWith(color: AppColors.errorRed)),
            const SizedBox(height: AppSpacing.sm),
            ...outOfStock.map((item) => _buildInventoryTile(
                  item,
                  statusColor: AppColors.errorRed,
                  statusText: 'HABIS',
                )),
          ],

          // Low stock section
          if (lowStockItems.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Stok Rendah',
                style: AppTextStyles.heading3
                    .copyWith(color: AppColors.warningAmber)),
            const SizedBox(height: AppSpacing.sm),
            ...lowStockItems.map((item) => _buildInventoryTile(
                  item,
                  statusColor: AppColors.warningAmber,
                  statusText: 'RENDAH',
                )),
          ],

          const SizedBox(height: AppSpacing.lg),
          Text('Semua Produk', style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((item) => _buildInventoryTile(item)),
        ],
      ),
    );
  }

  Widget _buildInventoryInsights(
    List<InventoryWithProduct> items,
    List<InventoryWithProduct> lowStock,
    List<InventoryWithProduct> outOfStock,
  ) {
    final healthyPct = items.isEmpty
        ? 0.0
        : ((items.length - lowStock.length - outOfStock.length) /
                items.length *
                100);

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
                Icon(Icons.insights_rounded,
                    size: 20, color: AppColors.primaryOrange),
                const SizedBox(width: AppSpacing.sm),
                Text('Inventory Insights',
                    style: AppTextStyles.heading3.copyWith(fontSize: 15)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _buildInsightRow(
                  'Stock Health',
                  '${healthyPct.toStringAsFixed(1)}% produk stok aman',
                  Icons.health_and_safety_rounded,
                  healthyPct > 80
                      ? AppColors.successGreen
                      : healthyPct > 50
                          ? AppColors.warningAmber
                          : AppColors.errorRed,
                ),
                _buildInsightRow(
                  'Perlu Restock',
                  '${lowStock.length + outOfStock.length} produk',
                  Icons.shopping_cart_checkout_rounded,
                  AppColors.warningAmber,
                ),
                _buildInsightRow(
                  'Out of Stock Rate',
                  items.isEmpty
                      ? '0%'
                      : '${(outOfStock.length / items.length * 100).toStringAsFixed(1)}%',
                  Icons.remove_shopping_cart_rounded,
                  AppColors.errorRed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
          Text(value,
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String value, IconData icon, Color color) {
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              style: AppTextStyles.heading3.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildInventoryTile(InventoryWithProduct item,
      {Color? statusColor, String? statusText}) {
    final isOutOfStock = item.inventory.quantity <= 0;
    final isLow = !isOutOfStock &&
        item.inventory.quantity <= item.inventory.lowStockThreshold;

    final color = statusColor ??
        (isOutOfStock
            ? AppColors.errorRed
            : isLow
                ? AppColors.warningAmber
                : AppColors.successGreen);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    'Min: ${item.inventory.lowStockThreshold.toStringAsFixed(0)}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.inventory.quantity.toStringAsFixed(0),
                style: AppTextStyles.heading3
                    .copyWith(fontSize: 16, color: color),
              ),
              if (statusText != null)
                Text(statusText,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Top 5 Products by Qty Sold widget
class _Top5QtyWidget extends ConsumerWidget {
  final List<Order> orders;
  const _Top5QtyWidget({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedOrders =
        orders.where((o) => o.status == 'completed').toList();

    return FutureBuilder<List<_ProductQtyData>>(
      future: _calculateTop5(ref, completedOrders),
      builder: (context, snapshot) {
        final data = snapshot.data ?? [];

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
                    Icon(Icons.star_rounded,
                        size: 20, color: AppColors.warningAmber),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Top 5 Produk (Qty Terjual)',
                        style:
                            AppTextStyles.heading3.copyWith(fontSize: 15)),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (data.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('Belum ada data'))
              else
                ...data.asMap().entries.map((entry) {
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
                            color:
                                AppColors.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primaryOrange,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(p.name,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('${p.qty} qty',
                            style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryOrange)),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  Future<List<_ProductQtyData>> _calculateTop5(
      WidgetRef ref, List<Order> orders) async {
    if (orders.isEmpty) return [];
    final db = ref.read(databaseProvider);
    final Map<String, _ProductQtyData> map = {};
    for (final order in orders) {
      final items = await db.orderDao.getItemsForOrder(order.id);
      for (final item in items) {
        final existing = map[item.productId];
        if (existing != null) {
          map[item.productId] = _ProductQtyData(
            name: item.productName,
            qty: existing.qty + item.quantity,
          );
        } else {
          map[item.productId] = _ProductQtyData(
            name: item.productName,
            qty: item.quantity,
          );
        }
      }
    }
    final sorted = map.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    return sorted.take(5).toList();
  }
}

/// Pareto Analysis Widget - classifies products as Fast/Slow/Dead stock
class _ParetoAnalysisWidget extends ConsumerWidget {
  final List<Order> orders;
  final List<InventoryWithProduct> inventoryItems;

  const _ParetoAnalysisWidget({
    required this.orders,
    required this.inventoryItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get last 30 days completed orders
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recentOrders = orders
        .where((o) =>
            o.status == 'completed' && o.createdAt.isAfter(thirtyDaysAgo))
        .toList();

    return FutureBuilder<_ParetoResult>(
      future: _calculatePareto(ref, recentOrders),
      builder: (context, snapshot) {
        final result = snapshot.data ??
            _ParetoResult(fastMoving: [], slowMoving: [], deadStock: []);

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
                    Icon(Icons.stacked_bar_chart_rounded,
                        size: 20, color: AppColors.infoBlue),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Pareto Analysis (30 Hari)',
                        style:
                            AppTextStyles.heading3.copyWith(fontSize: 15)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    // Summary row
                    Row(
                      children: [
                        _buildParetoChip(
                          'Fast Moving',
                          '${result.fastMoving.length}',
                          AppColors.successGreen,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildParetoChip(
                          'Slow Moving',
                          '${result.slowMoving.length}',
                          AppColors.warningAmber,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _buildParetoChip(
                          'Dead Stock',
                          '${result.deadStock.length}',
                          AppColors.errorRed,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Fast Moving
                    if (result.fastMoving.isNotEmpty) ...[
                      _buildParetoSection(
                          'Fast Moving', result.fastMoving, AppColors.successGreen),
                    ],

                    // Slow Moving
                    if (result.slowMoving.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _buildParetoSection(
                          'Slow Moving', result.slowMoving, AppColors.warningAmber),
                    ],

                    // Dead Stock
                    if (result.deadStock.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _buildParetoSection(
                          'Dead Stock', result.deadStock, AppColors.errorRed),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParetoChip(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(count,
                style: AppTextStyles.heading3
                    .copyWith(fontSize: 18, color: color)),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: color, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildParetoSection(
      String title, List<_ParetoItem> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 6),
            Text(title,
                style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ...items.take(5).map((item) => Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(item.name,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${item.qtySold} terjual',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            )),
        if (items.length > 5)
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text('...dan ${items.length - 5} lainnya',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textHint, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Future<_ParetoResult> _calculatePareto(
      WidgetRef ref, List<Order> orders) async {
    final db = ref.read(databaseProvider);

    // Get all product sales qty for the period
    final Map<String, int> productQty = {};
    final Map<String, String> productNames = {};

    for (final order in orders) {
      final items = await db.orderDao.getItemsForOrder(order.id);
      for (final item in items) {
        productQty[item.productId] =
            (productQty[item.productId] ?? 0) + item.quantity;
        productNames[item.productId] = item.productName;
      }
    }

    // Get all product IDs from inventory
    final allProductIds =
        inventoryItems.map((i) => i.inventory.productId).toSet();

    // Products with no sales in period = dead stock
    final soldProductIds = productQty.keys.toSet();
    final deadStockIds = allProductIds.difference(soldProductIds);

    // Sort sold products by qty
    final sortedSold = productQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Pareto: top 20% by cumulative sales = fast moving, rest = slow moving
    final totalQtySold =
        sortedSold.fold<int>(0, (sum, e) => sum + e.value);
    final List<_ParetoItem> fastMoving = [];
    final List<_ParetoItem> slowMoving = [];
    int cumulative = 0;

    for (final entry in sortedSold) {
      cumulative += entry.value;
      final item = _ParetoItem(
        name: productNames[entry.key] ?? 'Unknown',
        qtySold: entry.value,
      );
      if (totalQtySold > 0 && cumulative <= totalQtySold * 0.8) {
        fastMoving.add(item);
      } else {
        slowMoving.add(item);
      }
    }

    // If fast moving is empty but there are sales, put at least the top one
    if (fastMoving.isEmpty && sortedSold.isNotEmpty) {
      fastMoving.add(_ParetoItem(
        name: productNames[sortedSold.first.key] ?? 'Unknown',
        qtySold: sortedSold.first.value,
      ));
      if (slowMoving.isNotEmpty) slowMoving.removeAt(0);
    }

    final deadStock = deadStockIds.map((id) {
      final inv = inventoryItems.firstWhere(
        (i) => i.inventory.productId == id,
      );
      return _ParetoItem(name: inv.productName, qtySold: 0);
    }).toList();

    return _ParetoResult(
      fastMoving: fastMoving,
      slowMoving: slowMoving,
      deadStock: deadStock,
    );
  }
}

class _ProductQtyData {
  final String name;
  final int qty;
  _ProductQtyData({required this.name, required this.qty});
}

class _ParetoItem {
  final String name;
  final int qtySold;
  _ParetoItem({required this.name, required this.qtySold});
}

class _ParetoResult {
  final List<_ParetoItem> fastMoving;
  final List<_ParetoItem> slowMoving;
  final List<_ParetoItem> deadStock;
  _ParetoResult({
    required this.fastMoving,
    required this.slowMoving,
    required this.deadStock,
  });
}
