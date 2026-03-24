import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/database/app_database.dart' hide PaymentMethod;
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';
import 'package:kompak_pos/core/utils/formatters.dart';
import 'package:kompak_pos/models/enums.dart';

/// An on-screen receipt preview widget that mimics the look of a thermal
/// (ESC/POS) receipt.
///
/// The widget renders a white receipt-shaped container with a slightly
/// jagged bottom edge, monospace-style text, and dashed separators.
class ReceiptPreview extends StatelessWidget {
  /// The order record.
  final Order order;

  /// Line items for the order.
  final List<OrderItem> items;

  /// Payment record for the order.
  final Payment payment;

  /// Name of the store printed at the top of the receipt.
  final String storeName;

  /// Address line printed below the store name.
  final String storeAddress;

  /// Name of the cashier who processed the order.
  final String cashierName;

  const ReceiptPreview({
    super.key,
    required this.order,
    required this.items,
    required this.payment,
    required this.storeName,
    required this.storeAddress,
    required this.cashierName,
  });

  // Monospace-like text style used throughout the receipt.
  static TextStyle _mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.sourceCodePro(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 320,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(20, 0, 0, 0),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Store header
              _buildStoreHeader(),
              _dashedDivider(),

              // Order info
              _buildOrderInfo(),
              _dashedDivider(),

              // Items
              _buildItemsList(),
              _dashedDivider(),

              // Totals
              _buildTotals(),
              _dashedDivider(),

              // Payment info
              _buildPaymentInfo(),
              _dashedDivider(),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreHeader() {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          storeName.toUpperCase(),
          style: _mono(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          storeAddress,
          style: _mono(fontSize: 11, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildOrderInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          _textRow('Order', order.orderNumber),
          _textRow('Date', Formatters.dateTime(order.createdAt)),
          _textRow('Cashier', cashierName),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: _mono(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      '  ${item.quantity} x ${Formatters.currencyCompact(item.productPrice)}',
                      style: _mono(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      Formatters.currencyCompact(item.subtotal),
                      style: _mono(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTotals() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          _textRow(
            'Subtotal',
            Formatters.currencyCompact(order.subtotal),
          ),
          if (order.discountAmount > 0)
            _textRow(
              'Discount',
              '-${Formatters.currencyCompact(order.discountAmount)}',
            ),
          if (order.taxAmount > 0)
            _textRow(
              'Tax',
              Formatters.currencyCompact(order.taxAmount),
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: _mono(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Text(
                'Rp ${Formatters.currencyCompact(order.total)}',
                style: _mono(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    final methodLabel = _paymentMethodLabel(payment.method);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          _textRow('Payment', methodLabel),
          _textRow('Paid', Formatters.currency(payment.amount)),
          if (payment.changeAmount > 0)
            _textRow('Change', Formatters.currency(payment.changeAmount)),
          if (payment.referenceNumber != null &&
              payment.referenceNumber!.isNotEmpty)
            _textRow('Ref', payment.referenceNumber!),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: [
          Text(
            'Thank you for your purchase!',
            style: _mono(fontSize: 11, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            'Powered by Kompak POS',
            style: _mono(fontSize: 10, color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  // ---------- Helpers ----------

  Widget _textRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(label, style: _mono(fontSize: 12)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: _mono(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 4.0;
          const dashGap = 3.0;
          final dashCount =
              (constraints.maxWidth / (dashWidth + dashGap)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(dashCount, (_) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: dashGap / 2),
                child: SizedBox(
                  width: dashWidth,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.dividerGrey),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  /// Converts the raw database method string back to a display label.
  String _paymentMethodLabel(String method) {
    for (final pm in PaymentMethod.values) {
      if (pm.name == method) return pm.label;
    }
    // Fallback: capitalise the first letter.
    if (method.isEmpty) return method;
    return method[0].toUpperCase() + method.substring(1);
  }
}
