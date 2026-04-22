import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/database/app_database.dart';
import '../../models/enums.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/customer/customer_providers.dart';
import '../../modules/orders/order_providers.dart';
import '../../widgets/common/terminal_filter_dropdown.dart';
import '../../widgets/common/branch_filter_dropdown.dart';

/// Provider to resolve cashier name from ID.
final _cashierNameProvider =
    FutureProvider.family<String?, String>((ref, cashierId) async {
  final db = ref.watch(databaseProvider);
  final user = await db.userDao.getUserById(cashierId);
  return user?.name;
});

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', or OrderStatus.name

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
        title: Text('Orders', style: AppTextStyles.heading3),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Cari order number...',
                hintStyle:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                isDense: true,
              ),
              style: AppTextStyles.bodyMedium,
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

          // Status filter chips
          Container(
            color: Colors.white,
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                _buildFilterChip('Semua', 'all'),
                _buildFilterChip('Completed', 'completed'),
                _buildFilterChip('Confirmed', 'confirmed'),
                _buildFilterChip('Preparing', 'preparing'),
                _buildFilterChip('Ready', 'ready'),
                _buildFilterChip('Returned', 'returned'),
                _buildFilterChip('Cancelled', 'cancelled'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Order list
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final filtered = _applyFilters(orders);
                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    return _OrderTile(order: order);
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.errorRed),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Failed to load orders',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => ref.invalidate(ordersProvider),
                      child: Text('Retry',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.primaryOrange)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Order> _applyFilters(List<Order> orders) {
    var result = orders;

    // Status filter
    if (_statusFilter != 'all') {
      result = result.where((o) => o.status == _statusFilter).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((o) => o.orderNumber.toLowerCase().contains(q))
          .toList();
    }

    return result;
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = value),
        child: Chip(
          label: Text(label),
          labelStyle: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: isSelected
              ? AppColors.primaryOrange
              : AppColors.primaryOrange.withOpacity(0.08),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 80, color: AppColors.textHint.withOpacity(0.4)),
          const SizedBox(height: AppSpacing.md),
          Text('No orders found',
              style: AppTextStyles.heading3
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Text('Your order history will appear here',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _OrderTile extends ConsumerWidget {
  final Order order;

  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _parseStatus(order.status);
    final canComplete =
        status != OrderStatus.completed &&
        status != OrderStatus.cancelled &&
        status != OrderStatus.returned;
    final canReturn =
        status == OrderStatus.completed;

    return GestureDetector(
      onTap: () => context.push('/orders/${order.id}'),
      child: Container(
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
          children: [
            Row(
              children: [
                // Order icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: status == OrderStatus.returned
                        ? Colors.deepPurple.withOpacity(0.1)
                        : AppColors.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    status == OrderStatus.returned
                        ? Icons.assignment_return_rounded
                        : Icons.receipt_rounded,
                    color: status == OrderStatus.returned
                        ? Colors.deepPurple
                        : AppColors.primaryOrange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Order info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      // Customer name
                      if (order.customerId != null) ...[
                        const SizedBox(height: 2),
                        _CustomerNameLabel(customerId: order.customerId!),
                      ],
                      // Cashier info
                      const SizedBox(height: 2),
                      _CashierLabel(cashierId: order.cashierId),
                      const SizedBox(height: AppSpacing.xs),
                      Text(Formatters.dateTime(order.createdAt),
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                // Complete button for active orders
                if (canComplete)
                  IconButton(
                    onPressed: () async {
                      final db = ref.read(databaseProvider);
                      await db.orderDao
                          .updateOrderStatus(order.id, 'completed');
                      ref.invalidate(ordersProvider);
                      ref.invalidate(activeOrdersProvider);
                      ref.invalidate(todayOrderCountProvider);
                      ref.invalidate(todayRevenueProvider);
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    color: AppColors.successGreen,
                    tooltip: 'Tandai selesai',
                  ),
                // Total and status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currency(order.total),
                      style: AppTextStyles.priceMedium.copyWith(
                        color: status == OrderStatus.returned
                            ? Colors.deepPurple
                            : AppColors.primaryOrange,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildStatusBadge(status),
                  ],
                ),
              ],
            ),
            // Return button row
            if (canReturn) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReturnDialog(context, ref),
                    icon: const Icon(Icons.assignment_return_rounded, size: 16),
                    label: const Text('Return'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      side: const BorderSide(color: Colors.deepPurple),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReturnDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Return Order', style: AppTextStyles.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order: ${order.orderNumber}',
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'Total: ${Formatters.currency(order.total)}',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.primaryOrange),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Alasan Return *',
                hintText: 'Masukkan alasan return...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              await _processReturn(context, ref, reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Konfirmasi Return',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _processReturn(
      BuildContext context, WidgetRef ref, String reason) async {
    try {
      final db = ref.read(databaseProvider);
      final currentUser = ref.read(currentUserProvider);
      final storeId = ref.read(currentStoreIdProvider);

      // Wrap entire return operation in a transaction so that if any
      // inventory restore fails, nothing is committed (order stays 'completed').
      await db.transaction(() async {
        // Insert return record
        await db.orderReturnDao.insertReturn(
          OrderReturnsCompanion.insert(
            id: const Uuid().v4(),
            orderId: order.id,
            storeId: storeId ?? '',
            cashierId: currentUser?.id ?? '',
            reason: reason,
            returnAmount: order.total,
          ),
        );

        // Update order status to returned
        await db.orderDao.updateOrderStatus(order.id, 'returned');

        // Restore inventory for returned items (BOM-aware)
        final items = await db.orderDao.getItemsForOrder(order.id);
        for (final item in items) {
          final product = await db.productDao.getById(item.productId);
          if (product != null && product.hasBom) {
            // BOM product: restore each raw material component
            final bomItems =
                await db.bomDao.getItemsByProduct(item.productId);
            if (bomItems.isNotEmpty) {
              for (final bom in bomItems) {
                await db.inventoryDao.restockProduct(
                  bom.materialProductId,
                  bom.quantity * item.quantity.toDouble(),
                  userId: currentUser?.id,
                  type: 'return',
                );
              }
            } else {
              // hasBom=true but recipe empty → restore product itself
              await db.inventoryDao.restockProduct(
                item.productId,
                item.quantity.toDouble(),
                userId: currentUser?.id,
                type: 'return',
              );
            }
          } else {
            // Regular product: restore product itself
            await db.inventoryDao.restockProduct(
              item.productId,
              item.quantity.toDouble(),
              userId: currentUser?.id,
              type: 'return',
            );
          }
        }
      });

      // Invalidate providers
      ref.invalidate(ordersProvider);
      ref.invalidate(activeOrdersProvider);
      ref.invalidate(todayOrderCountProvider);
      ref.invalidate(todayRevenueProvider);
      ref.invalidate(todayCOGSProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${order.orderNumber} berhasil di-return'),
            backgroundColor: Colors.deepPurple,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal return order: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case OrderStatus.completed:
        bgColor = AppColors.successGreen.withOpacity(0.1);
        textColor = AppColors.successGreen;
        break;
      case OrderStatus.confirmed:
        bgColor = AppColors.infoBlue.withOpacity(0.1);
        textColor = AppColors.infoBlue;
        break;
      case OrderStatus.preparing:
        bgColor = AppColors.warningAmber.withOpacity(0.1);
        textColor = AppColors.warningAmber;
        break;
      case OrderStatus.ready:
        bgColor = AppColors.successGreen.withOpacity(0.1);
        textColor = AppColors.successGreen;
        break;
      case OrderStatus.cancelled:
        bgColor = AppColors.errorRed.withOpacity(0.1);
        textColor = AppColors.errorRed;
        break;
      case OrderStatus.draft:
        bgColor = AppColors.surfaceGrey;
        textColor = AppColors.textSecondary;
        break;
      case OrderStatus.returned:
        bgColor = Colors.deepPurple.withOpacity(0.1);
        textColor = Colors.deepPurple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.caption
            .copyWith(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  OrderStatus _parseStatus(String status) {
    return OrderStatus.values.firstWhere(
      (s) => s.name == status,
      orElse: () => OrderStatus.draft,
    );
  }
}

/// Small widget to resolve and display cashier name from ID
class _CashierLabel extends ConsumerWidget {
  final String cashierId;
  const _CashierLabel({required this.cashierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync = ref.watch(_cashierNameProvider(cashierId));
    return nameAsync.when(
      data: (name) {
        if (name == null) return const SizedBox.shrink();
        return Row(
          children: [
            const Icon(Icons.badge_rounded, size: 12, color: AppColors.textHint),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                name,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textHint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Small widget to resolve and display customer name from ID
class _CustomerNameLabel extends ConsumerWidget {
  final String customerId;
  const _CustomerNameLabel({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    return customerAsync.when(
      data: (customer) {
        if (customer == null) return const SizedBox.shrink();
        return Row(
          children: [
            Icon(Icons.person_rounded,
                size: 12, color: AppColors.primaryOrange),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                customer.name,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
