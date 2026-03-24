import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../models/enums.dart';
import '../../modules/orders/order_providers.dart';
import '../../modules/customer/customer_providers.dart';
import '../../modules/printer/printer_providers.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final itemsAsync = ref.watch(orderItemsProvider(orderId));
    final paymentAsync = ref.watch(orderPaymentProvider(orderId));

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
        title: Text(
          'Order Detail',
          style: AppTextStyles.heading3,
        ),
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return Center(
              child: Text(
                'Order not found',
                style: AppTextStyles.bodyLarge
                    .copyWith(color: AppColors.textSecondary),
              ),
            );
          }
          return itemsAsync.when(
            data: (items) => paymentAsync.when(
              data: (payment) =>
                  _buildContent(context, ref, order, items, payment),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Order order,
    List<OrderItem> items,
    Payment? payment,
  ) {
    final status = OrderStatus.values.firstWhere(
      (s) => s.name == order.status,
      orElse: () => OrderStatus.draft,
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
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
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order.orderNumber,
                            style: AppTextStyles.heading2,
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            Formatters.dateTime(order.createdAt),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                      // Customer info
                      if (order.customerId != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _buildCustomerRow(ref, order.customerId!),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Items section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
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
                      Text(
                        'Items',
                        style: AppTextStyles.heading3.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...items.map((item) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primaryOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${item.quantity}x',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.primaryOrange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.productName,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '@ ${Formatters.currency(item.productPrice)}',
                                        style: AppTextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  Formatters.currency(item.subtotal),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Order summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
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
                      Text(
                        'Order Summary',
                        style: AppTextStyles.heading3.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildSummaryRow(
                          'Subtotal', Formatters.currency(order.subtotal)),
                      if (order.discountAmount > 0)
                        _buildSummaryRow(
                          'Discount',
                          '-${Formatters.currency(order.discountAmount)}',
                          valueColor: AppColors.discountRed,
                        ),
                      _buildSummaryRow(
                          'Tax', Formatters.currency(order.taxAmount)),
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: AppTextStyles.heading3),
                          Text(
                            Formatters.currency(order.total),
                            style: AppTextStyles.priceLarge.copyWith(
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Payment info
                if (payment != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
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
                        Text(
                          'Payment',
                          style:
                              AppTextStyles.heading3.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildSummaryRow(
                            'Method', payment.method.toUpperCase()),
                        _buildSummaryRow('Amount Tendered',
                            Formatters.currency(payment.amount)),
                        if (payment.changeAmount > 0)
                          _buildSummaryRow(
                            'Change',
                            Formatters.currency(payment.changeAmount),
                            valueColor: AppColors.successGreen,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Reprint button
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _reprintReceipt(
                      context, ref, order, items, payment);
                },
                icon: const Icon(Icons.print_rounded, color: Colors.white),
                label: Text(
                  'Reprint Receipt',
                  style: AppTextStyles.buttonText,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerRow(WidgetRef ref, String customerId) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    return customerAsync.when(
      data: (customer) {
        if (customer == null) return const SizedBox.shrink();
        return Row(
          children: [
            Icon(Icons.person_rounded,
                size: 16, color: AppColors.primaryOrange),
            const SizedBox(width: AppSpacing.xs),
            Text(
              customer.name,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryOrange,
              ),
            ),
            if (customer.phone != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                customer.phone!,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textHint),
              ),
            ],
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _reprintReceipt(
    BuildContext context,
    WidgetRef ref,
    Order order,
    List<OrderItem> items,
    Payment? payment,
  ) async {
    final printerService = ref.read(printerServiceProvider);
    final receiptService = ref.read(receiptServiceProvider);
    final isConnected = ref.read(printerConnectedProvider);
    final currentUser = ref.read(currentUserProvider);
    final currentStore = ref.read(currentStoreProvider);

    if (!isConnected) {
      context.showSnackBar(
        'Printer not connected. Go to Settings to connect.',
        isError: true,
      );
      return;
    }

    if (payment == null) {
      context.showSnackBar('Payment data not available', isError: true);
      return;
    }

    try {
      // Resolve customer name
      String? customerName;
      if (order.customerId != null) {
        final customerSvc = ref.read(customerServiceProvider);
        final customer = await customerSvc.getById(order.customerId!);
        customerName = customer?.name;
      }

      final bytes = await receiptService.generateReceipt(
        storeName: currentStore?.name ?? 'Kompak Store',
        storeAddress: currentStore?.address ?? '',
        cashierName: currentUser?.name ?? 'Cashier',
        order: order,
        items: items,
        payment: payment,
        customerName: customerName,
        receiptHeader: currentStore?.receiptHeader,
        receiptFooter: currentStore?.receiptFooter,
      );
      final success = await printerService.printReceipt(bytes);
      if (context.mounted) {
        if (success) {
          context.showSnackBar('Receipt printed successfully');
        } else {
          context.showSnackBar('Failed to print receipt', isError: true);
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar('Print error: $e', isError: true);
      }
    }
  }
}
