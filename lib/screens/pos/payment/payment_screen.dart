import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/extensions.dart';
import '../../../models/enums.dart';
import '../../../modules/pos/cart_providers.dart';
import '../../../modules/payments/payment_providers.dart';
import '../../../modules/core_providers.dart';
import '../../../modules/auth/auth_providers.dart';
import '../../../modules/payment_method/payment_method_providers.dart';
import '../../../modules/pos_session/pos_session_providers.dart';
import '../../../core/database/app_database.dart' as db;

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String _cashInput = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentMethodProvider.notifier).state = PaymentMethod.cash;
      ref.read(cashTenderedProvider.notifier).state = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final paymentMethod = ref.watch(paymentMethodProvider);
    final cashTendered = ref.watch(cashTenderedProvider);
    final change = cashTendered - cart.total;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Payment',
          style: AppTextStyles.heading3,
        ),
      ),
      body: Column(
        children: [
          // Total amount header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            margin: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Total Amount',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Formatters.currency(cart.total),
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.primaryOrange,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${cart.itemCount} items',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),

          // Payment method selection (loaded dynamically from DB)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Method',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ref.watch(paymentMethodsProvider).when(
                  data: (methods) {
                    final activeMethods = methods.isNotEmpty
                        ? methods
                        : <db.PaymentMethod>[];
                    // Fallback to enum if no DB methods
                    if (activeMethods.isEmpty) {
                      return Row(
                        children: PaymentMethod.values.map((method) {
                          final isSelected = paymentMethod == method;
                          return Expanded(
                            child: _buildMethodChip(
                              isSelected: isSelected,
                              icon: _getMethodIcon(method),
                              label: method.label,
                              isLast: method == PaymentMethod.transfer,
                              onTap: () {
                                ref.read(paymentMethodProvider.notifier).state = method;
                                if (method != PaymentMethod.cash) {
                                  ref.read(cashTenderedProvider.notifier).state = cart.total;
                                  setState(() => _cashInput = '');
                                }
                              },
                            ),
                          );
                        }).toList(),
                      );
                    }
                    return Row(
                      children: activeMethods.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final pm = entry.value;
                        final enumMethod = _typeToEnum(pm.type);
                        final isSelected = paymentMethod == enumMethod;
                        return Expanded(
                          child: _buildMethodChip(
                            isSelected: isSelected,
                            icon: _getTypeIcon(pm.type),
                            label: pm.name,
                            isLast: idx == activeMethods.length - 1,
                            onTap: () {
                              ref.read(paymentMethodProvider.notifier).state = enumMethod;
                              if (enumMethod != PaymentMethod.cash) {
                                ref.read(cashTenderedProvider.notifier).state = cart.total;
                                setState(() => _cashInput = '');
                              }
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => Row(
                    children: PaymentMethod.values.map((method) {
                      final isSelected = paymentMethod == method;
                      return Expanded(
                        child: _buildMethodChip(
                          isSelected: isSelected,
                          icon: _getMethodIcon(method),
                          label: method.label,
                          isLast: method == PaymentMethod.transfer,
                          onTap: () {
                            ref.read(paymentMethodProvider.notifier).state = method;
                            if (method != PaymentMethod.cash) {
                              ref.read(cashTenderedProvider.notifier).state = cart.total;
                              setState(() => _cashInput = '');
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  error: (_, __) => Row(
                    children: PaymentMethod.values.map((method) {
                      final isSelected = paymentMethod == method;
                      return Expanded(
                        child: _buildMethodChip(
                          isSelected: isSelected,
                          icon: _getMethodIcon(method),
                          label: method.label,
                          isLast: method == PaymentMethod.transfer,
                          onTap: () {
                            ref.read(paymentMethodProvider.notifier).state = method;
                            if (method != PaymentMethod.cash) {
                              ref.read(cashTenderedProvider.notifier).state = cart.total;
                              setState(() => _cashInput = '');
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Cash input section
          if (paymentMethod == PaymentMethod.cash) ...[
            Expanded(
              child: _buildCashSection(cart.total, cashTendered, change),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getMethodIcon(paymentMethod),
                      size: 64,
                      color: AppColors.primaryOrange.withOpacity(0.3),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Ready for ${paymentMethod.label} payment',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Complete order button
          _buildCompleteButton(cart.total, paymentMethod, cashTendered),
        ],
      ),
    );
  }

  Widget _buildCashSection(double total, double tendered, double change) {
    return Column(
      children: [
        // Cash tendered display
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'Cash Tendered',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _cashInput.isEmpty ? 'Rp 0' : Formatters.currency(double.tryParse(_cashInput) ?? 0),
                style: AppTextStyles.priceLarge.copyWith(
                  fontSize: 28,
                ),
              ),
              if (tendered >= total && tendered > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Change: ${Formatters.currency(change)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Quick amount buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              _buildQuickAmountButton(total),
              const SizedBox(width: AppSpacing.sm),
              _buildQuickAmountButton(_roundUp(total, 10000)),
              const SizedBox(width: AppSpacing.sm),
              _buildQuickAmountButton(_roundUp(total, 50000)),
              const SizedBox(width: AppSpacing.sm),
              _buildQuickAmountButton(_roundUp(total, 100000)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Numeric keypad
        Expanded(
          child: _buildNumericKeypad(),
        ),
      ],
    );
  }

  Widget _buildQuickAmountButton(double amount) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _cashInput = amount.toStringAsFixed(0);
          });
          ref.read(cashTenderedProvider.notifier).state = amount;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              Formatters.currency(amount),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  double _roundUp(double value, double increment) {
    return (value / increment).ceil() * increment;
  }

  Widget _buildNumericKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['00', '0', 'del'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: keys.map((row) {
          return Expanded(
            child: Row(
              children: row.map((key) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color: key == 'del'
                          ? AppColors.surfaceGrey
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _onKeyTap(key),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderGrey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: key == 'del'
                                ? const Icon(Icons.backspace_outlined,
                                    color: AppColors.textPrimary, size: 22)
                                : Text(
                                    key,
                                    style: AppTextStyles.heading3.copyWith(
                                      fontSize: 20,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _onKeyTap(String key) {
    setState(() {
      if (key == 'del') {
        if (_cashInput.isNotEmpty) {
          _cashInput = _cashInput.substring(0, _cashInput.length - 1);
        }
      } else {
        if (_cashInput.length < 12) {
          _cashInput += key;
        }
      }
    });
    final amount = double.tryParse(_cashInput) ?? 0;
    ref.read(cashTenderedProvider.notifier).state = amount;
  }

  Widget _buildCompleteButton(
    double total,
    PaymentMethod method,
    double cashTendered,
  ) {
    final canComplete = method != PaymentMethod.cash || cashTendered >= total;

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
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canComplete && !_isProcessing
                ? () => _completeOrder()
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              disabledBackgroundColor: AppColors.borderGrey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Complete Order',
                        style: AppTextStyles.buttonText,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _completeOrder() async {
    setState(() => _isProcessing = true);

    try {
      final cart = ref.read(cartProvider);
      final paymentMethod = ref.read(paymentMethodProvider);
      final cashTendered = ref.read(cashTenderedProvider);
      final orderService = ref.read(orderServiceProvider);
      final currentUser = ref.read(currentUserProvider);
      final storeId = ref.read(currentStoreIdProvider);

      if (cart.isEmpty) {
        if (mounted) context.showSnackBar('Cart is empty', isError: true);
        return;
      }

      final amountTendered =
          paymentMethod == PaymentMethod.cash ? cashTendered : cart.total;

      // ISS-017: Validate required fields
      if (storeId == null || currentUser == null) {
        if (mounted) {
          context.showSnackBar('Sesi tidak valid. Silakan login ulang.', isError: true);
        }
        return;
      }

      final sessionId = ref.read(activeSessionIdProvider);
      final terminalId = ref.read(terminalIdProvider);

      final orderId = await orderService.createOrder(
        cart: cart,
        paymentMethod: paymentMethod,
        amountTendered: amountTendered,
        storeId: storeId,
        terminalId: terminalId,
        cashierId: currentUser.id,
        customerId: cart.customerId,
        sessionId: sessionId,
      );

      ref.read(cartProvider.notifier).clearCart();
      ref.read(cashTenderedProvider.notifier).state = 0;

      if (mounted) {
        context.go('/pos/receipt/$orderId');
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Failed to create order: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildMethodChip({
    required bool isSelected,
    required IconData icon,
    required String label,
    required bool isLast,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryOrange : AppColors.surfaceGrey,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? null : Border.all(color: AppColors.borderGrey),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 28,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.payments_rounded;
      case PaymentMethod.card:
        return Icons.credit_card_rounded;
      case PaymentMethod.qris:
        return Icons.qr_code_rounded;
      case PaymentMethod.transfer:
        return Icons.account_balance_rounded;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'cash': return Icons.payments_rounded;
      case 'card': return Icons.credit_card_rounded;
      case 'qris': return Icons.qr_code_rounded;
      case 'transfer': return Icons.account_balance_rounded;
      default: return Icons.payment_rounded;
    }
  }

  PaymentMethod _typeToEnum(String type) {
    switch (type) {
      case 'cash': return PaymentMethod.cash;
      case 'card': return PaymentMethod.card;
      case 'qris': return PaymentMethod.qris;
      case 'transfer': return PaymentMethod.transfer;
      default: return PaymentMethod.cash;
    }
  }
}
