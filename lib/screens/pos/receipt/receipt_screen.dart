import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/extensions.dart';
import 'dart:convert';
import '../../../core/database/app_database.dart';
import '../../../models/applied_charge_model.dart';
import '../../../models/applied_promotion_model.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/enums.dart';
import '../../../modules/orders/order_providers.dart';
import '../../../modules/customer/customer_providers.dart';
import '../../../modules/core_providers.dart';
import '../../../modules/auth/auth_providers.dart';

class ReceiptScreen extends ConsumerWidget {
  final String orderId;

  const ReceiptScreen({super.key, required this.orderId});

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
        automaticallyImplyLeading: false,
        title: Text(
          'Receipt',
          style: AppTextStyles.heading3,
        ),
        centerTitle: true,
      ),
      body: orderAsync.when(
        data: (order) {
          if (order == null) {
            return Center(
              child: Text(
                'Order not found',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          return itemsAsync.when(
            data: (items) => paymentAsync.when(
              data: (payment) => _buildReceiptContent(
                context,
                ref,
                order,
                items,
                payment,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildReceiptContent(
    BuildContext context,
    WidgetRef ref,
    Order order,
    List<OrderItem> items,
    Payment? payment,
  ) {
    return Column(
      children: [
        // Success header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.successGreen,
                  size: 48,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Order Completed!',
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.successGreen,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                order.orderNumber,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Receipt card
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receipt header
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'KOMPAK POS',
                          style: AppTextStyles.heading3.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          Formatters.dateTime(order.createdAt),
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Customer info
                  if (order.customerId != null)
                    _buildCustomerInfo(ref, order.customerId!),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),

                  // Items
                  ...items.map((item) {
                    final itemSavings = (item.originalPrice != null &&
                            item.originalPrice! > item.productPrice)
                        ? (item.originalPrice! - item.productPrice) *
                            item.quantity
                        : 0.0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${item.quantity}x',
                                  style:
                                      AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                              Text(
                                Formatters.currency(item.subtotal),
                                style:
                                    AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Per-unit price (when qty > 1 or pricelist discount)
                        if (item.quantity > 1 ||
                            (item.originalPrice != null &&
                                item.originalPrice! > item.productPrice))
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 32, bottom: 1),
                            child: Text(
                              '@${Formatters.currency(item.productPrice)}/pcs',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                        // Combo selections
                        if (item.extrasJson != null &&
                            item.extrasJson!.isNotEmpty)
                          Builder(builder: (_) {
                            try {
                              final extras = jsonDecode(item.extrasJson!)
                                  as Map<String, dynamic>;
                              if (extras['isCombo'] == true) {
                                final selections =
                                    (extras['comboSelections']
                                            as List<dynamic>?) ??
                                        [];
                                return Column(
                                  children: selections.map((selJson) {
                                    final sel = ComboSelection.fromJson(
                                        selJson as Map<String, dynamic>);
                                    final extraLabel = sel.extraPrice > 0
                                        ? ' (+${Formatters.currency(sel.extraPrice)})'
                                        : '';
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          left: 32, bottom: 1),
                                      child: Row(
                                        children: [
                                          Icon(
                                              Icons
                                                  .check_circle_outlined,
                                              size: 12,
                                              color:
                                                  AppColors.infoBlue),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${sel.productName}$extraLabel',
                                              style: AppTextStyles
                                                  .caption
                                                  .copyWith(
                                                color: AppColors
                                                    .textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              }
                            } catch (_) {}
                            return const SizedBox.shrink();
                          }),
                        if (item.notes != null &&
                            item.notes!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 32,
                              bottom: AppSpacing.xs,
                            ),
                            child: Text(
                              '>> ${item.notes}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (itemSavings > 0)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 32,
                              bottom: AppSpacing.sm,
                            ),
                            child: Text(
                              'Hemat ${Formatters.currency(itemSavings)}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: AppSpacing.xs),
                      ],
                    );
                  }),

                  const SizedBox(height: AppSpacing.sm),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),

                  // Totals
                  _buildReceiptRow(
                    'Subtotal',
                    Formatters.currency(order.subtotal),
                  ),
                  if (order.discountAmount > 0)
                    _buildReceiptRow(
                      'Discount',
                      '-${Formatters.currency(order.discountAmount)}',
                      valueColor: AppColors.discountRed,
                    ),
                  // Promotions breakdown
                  Builder(builder: (_) {
                    if (order.promotionsJson != null &&
                        order.promotionsJson!.isNotEmpty) {
                      final promoList =
                          (jsonDecode(order.promotionsJson!) as List)
                              .map((e) => AppliedPromotion.fromJson(
                                  e as Map<String, dynamic>))
                              .toList();
                      return Column(
                        children: promoList.map((promo) {
                          final label = promo.tipeReward ==
                                  PromotionTipeReward.diskonPersentase
                              ? '${promo.namaPromo} (${promo.nilaiReward.toStringAsFixed(promo.nilaiReward.truncateToDouble() == promo.nilaiReward ? 0 : 1)}%)'
                              : promo.namaPromo;
                          return _buildReceiptRow(
                            label,
                            '-${Formatters.currency(promo.discountAmount)}',
                            valueColor: AppColors.successGreen,
                          );
                        }).toList(),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  // Charges breakdown (dynamic)
                  Builder(builder: (_) {
                    if (order.chargesJson != null &&
                        order.chargesJson!.isNotEmpty) {
                      final chargesList =
                          (jsonDecode(order.chargesJson!) as List)
                              .map((e) => AppliedCharge.fromJson(
                                  e as Map<String, dynamic>))
                              .toList();
                      return Column(
                        children: chargesList.map((charge) {
                          final label =
                              charge.tipe == ChargeTipe.persentase
                                  ? '${charge.namaBiaya} (${charge.nilai.toStringAsFixed(charge.nilai.truncateToDouble() == charge.nilai ? 0 : 1)}%)'
                                  : charge.namaBiaya;
                          final prefix =
                              charge.isDeduction ? '-' : '';
                          return _buildReceiptRow(
                            label,
                            '$prefix${Formatters.currency(charge.amount.abs())}',
                            valueColor: charge.isDeduction
                                ? AppColors.discountRed
                                : null,
                          );
                        }).toList(),
                      );
                    }
                    // Fallback for old orders
                    if (order.taxAmount > 0) {
                      return _buildReceiptRow(
                        'Tax',
                        Formatters.currency(order.taxAmount),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(thickness: 2),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL', style: AppTextStyles.heading3),
                      Text(
                        Formatters.currency(order.total),
                        style: AppTextStyles.priceLarge.copyWith(
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ],
                  ),

                  // Payment info
                  if (payment != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    _buildReceiptRow(
                      'Payment',
                      payment.method.toUpperCase(),
                    ),
                    if (payment.method == 'cash') ...[
                      _buildReceiptRow(
                        'Tendered',
                        Formatters.currency(payment.amount),
                      ),
                      _buildReceiptRow(
                        'Change',
                        Formatters.currency(payment.changeAmount),
                        valueColor: AppColors.successGreen,
                      ),
                    ],
                  ],

                  // Savings info — pricelist + promotion savings
                  Builder(builder: (_) {
                    double totalSavings = items.fold<double>(0, (sum, item) {
                      if (item.originalPrice != null &&
                          item.originalPrice! > item.productPrice) {
                        return sum +
                            (item.originalPrice! - item.productPrice) *
                                item.quantity;
                      }
                      return sum;
                    });
                    // Add promotion discounts
                    if (order.promotionsJson != null &&
                        order.promotionsJson!.isNotEmpty) {
                      final promoList =
                          (jsonDecode(order.promotionsJson!) as List)
                              .map((e) => AppliedPromotion.fromJson(
                                  e as Map<String, dynamic>))
                              .toList();
                      for (final promo in promoList) {
                        totalSavings += promo.discountAmount;
                      }
                    }
                    if (totalSavings <= 0) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      width: double.infinity,
                      margin:
                          const EdgeInsets.only(top: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen
                            .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Anda hemat ${Formatters.currency(totalSavings)}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Text(
                      'Thank you!',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom buttons
        _buildBottomActions(context, ref, order, items, payment),
      ],
    );
  }

  Widget _buildCustomerInfo(WidgetRef ref, String customerId) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    return customerAsync.when(
      data: (customer) {
        if (customer == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.person_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Customer: ${customer.name}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (customer.phone != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '(${customer.phone})',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textHint),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
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

  Widget _buildBottomActions(
    BuildContext context,
    WidgetRef ref,
    Order order,
    List<OrderItem> items,
    Payment? payment,
  ) {
    return Container(
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
        child: Row(
          children: [
            // Print Receipt button
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _printReceipt(context, ref, order, items, payment);
                    if (context.mounted) context.go('/pos/catalog');
                  },
                  icon: const Icon(Icons.print_rounded),
                  label: Text(
                    'Print Receipt',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    side: const BorderSide(color: AppColors.primaryOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // New Order button
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go('/pos/catalog');
                  },
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: Text(
                    'New Order',
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
          ],
        ),
      ),
    );
  }

  Future<void> _printReceipt(
    BuildContext context,
    WidgetRef ref,
    Order order,
    List<OrderItem> items,
    Payment? payment,
  ) async {
    if (payment == null) {
      context.showSnackBar('Payment data not available', isError: true);
      return;
    }

    final printerService = ref.read(printerServiceProvider);
    final receiptService = ref.read(receiptServiceProvider);
    final currentUser = ref.read(currentUserProvider);
    final currentStore = ref.read(currentStoreProvider);

    // Notify user and run printing in background — no blocking dialog
    context.showSnackBar('Printing receipt...');

    // Resolve customer name if available
    String? customerName;
    if (order.customerId != null) {
      final customerSvc = ref.read(customerServiceProvider);
      final customer = await customerSvc.getById(order.customerId!);
      customerName = customer?.name;
    }

    // Fire-and-forget: run in background so UI stays responsive
    () async {
      try {
        final connected = await printerService.ensureConnected();
        if (!connected) {
          if (context.mounted) {
            context.showSnackBar(
              'Printer not connected. Go to Settings → Printer to connect.',
              isError: true,
            );
          }
          return;
        }

        final currentTerminal = ref.read(currentTerminalProvider);
        final bytes = await receiptService.generateReceipt(
          storeName: currentStore?.name ?? 'Kompak Store',
          storeAddress: currentStore?.address ?? '',
          cashierName: currentUser?.name ?? 'Cashier',
          order: order,
          items: items,
          payment: payment,
          logoPath: currentStore?.logoUrl,
          customerName: customerName,
          receiptHeader: currentStore?.receiptHeader,
          receiptFooter: currentStore?.receiptFooter,
          terminalName: currentTerminal?.name,
        );

        final success = await printerService.printReceipt(bytes);

        if (context.mounted) {
          if (success) {
            context.showSnackBar('Receipt printed successfully');
          } else {
            context.showSnackBar(
              'Failed to send data to printer. Try printing again.',
              isError: true,
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          context.showSnackBar('Print error: $e', isError: true);
        }
      }
    }();
  }
}
