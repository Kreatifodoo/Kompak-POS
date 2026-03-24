import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';
import 'package:kompak_pos/core/utils/formatters.dart';
import 'package:kompak_pos/models/cart_state_model.dart';
import 'package:kompak_pos/models/enums.dart';

/// A summary card showing Subtotal, Discount, Tax, and Total for the cart.
///
/// Renders each row as a label / value pair. The discount row is only shown
/// when a discount is applied. The total row is highlighted with a bold style.
class OrderSummaryCard extends StatelessWidget {
  /// The current cart state containing all financial data.
  final CartState cartState;

  const OrderSummaryCard({
    super.key,
    required this.cartState,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        cartState.discountType != null && cartState.discountValue > 0;
    final discountAmount = cartState.discountAmount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Order Summary',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Subtotal
          _SummaryRow(
            label: 'Subtotal',
            value: Formatters.currency(cartState.subtotal),
          ),

          // Discount (conditional)
          if (hasDiscount) ...[
            const SizedBox(height: AppSpacing.xs),
            _SummaryRow(
              label: _discountLabel,
              value: '- ${Formatters.currency(discountAmount)}',
              valueColor: AppColors.discountRed,
            ),
          ],

          // Tax
          const SizedBox(height: AppSpacing.xs),
          _SummaryRow(
            label: 'Tax (${(cartState.taxRate * 100).toStringAsFixed(0)}%)',
            value: Formatters.currency(cartState.taxAmount),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(color: AppColors.dividerGrey, height: 1),
          ),

          // Total
          _SummaryRow(
            label: 'Total',
            value: Formatters.currency(cartState.total),
            isBold: true,
            valueColor: AppColors.primaryOrange,
            labelStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            valueStyle: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  String get _discountLabel {
    if (cartState.discountType == DiscountType.percentage) {
      return 'Discount (${cartState.discountValue.toStringAsFixed(0)}%)';
    }
    return 'Discount';
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: labelStyle ??
              GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: valueStyle ??
              GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}
