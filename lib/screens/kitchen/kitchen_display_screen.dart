import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../models/enums.dart';
import '../../modules/orders/order_providers.dart';
import '../../modules/core_providers.dart';

class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  ConsumerState<KitchenDisplayScreen> createState() =>
      _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(activeOrdersProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeOrdersAsync = ref.watch(activeOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Kitchen Display',
          style: AppTextStyles.heading3.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.invalidate(activeOrdersProvider),
          ),
        ],
      ),
      body: activeOrdersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return _buildEmptyState();
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 600
                      ? 2
                      : 1;
              return GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                ),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return _KitchenOrderCard(
                    order: order,
                    onStatusUpdate: (newStatus) =>
                        _updateOrderStatus(order.id, newStatus),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primaryOrange),
          ),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.errorRed),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load orders',
                style: AppTextStyles.bodyLarge.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => ref.invalidate(activeOrdersProvider),
                child: Text(
                  'Retry',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.primaryOrange),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.kitchen_rounded,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No active orders',
            style: AppTextStyles.heading3.copyWith(
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'New orders will appear here automatically',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final db = ref.read(databaseProvider);
      await db.orderDao.updateOrderStatus(orderId, newStatus);
      ref.invalidate(activeOrdersProvider);
      if (newStatus == 'completed') {
        ref.invalidate(todayOrderCountProvider);
        ref.invalidate(todayRevenueProvider);
        ref.invalidate(todayOrdersProvider);
      }
      if (mounted) {
        context.showSnackBar('Order updated to ${newStatus.capitalize}');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to update order', isError: true);
      }
    }
  }
}

class _KitchenOrderCard extends ConsumerWidget {
  final Order order;
  final void Function(String newStatus) onStatusUpdate;

  const _KitchenOrderCard({
    required this.order,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = OrderStatus.values.firstWhere(
      (s) => s.name == order.status,
      orElse: () => OrderStatus.confirmed,
    );
    final elapsed = DateTime.now().difference(order.createdAt);
    final itemsAsync = ref.watch(orderItemsProvider(order.id));

    Color borderColor;
    Color headerColor;
    switch (status) {
      case OrderStatus.confirmed:
        borderColor = AppColors.infoBlue;
        headerColor = AppColors.infoBlue;
        break;
      case OrderStatus.preparing:
        borderColor = AppColors.warningAmber;
        headerColor = AppColors.warningAmber;
        break;
      case OrderStatus.ready:
        borderColor = AppColors.successGreen;
        headerColor = AppColors.successGreen;
        break;
      default:
        borderColor = AppColors.textSecondary;
        headerColor = AppColors.textSecondary;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.orderNumber,
                  style: AppTextStyles.heading3.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatElapsed(elapsed),
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items
          Expanded(
            child: itemsAsync.when(
              data: (items) => ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGrey,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${item.quantity}',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item.productName,
                          style: AppTextStyles.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Error')),
            ),
          ),

          // Action button
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: _buildActionButton(status),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(OrderStatus status) {
    String label;
    Color color;
    String nextStatus;

    switch (status) {
      case OrderStatus.confirmed:
        label = 'Start Preparing';
        color = AppColors.warningAmber;
        nextStatus = 'preparing';
        break;
      case OrderStatus.preparing:
        label = 'Mark Ready';
        color = AppColors.successGreen;
        nextStatus = 'ready';
        break;
      case OrderStatus.ready:
        label = 'Complete';
        color = AppColors.primaryOrange;
        nextStatus = 'completed';
        break;
      default:
        label = 'Update';
        color = AppColors.textSecondary;
        nextStatus = 'completed';
    }

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: () => onStatusUpdate(nextStatus),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonText.copyWith(fontSize: 14),
        ),
      ),
    );
  }

  String _formatElapsed(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return '${duration.inSeconds}s';
  }
}
