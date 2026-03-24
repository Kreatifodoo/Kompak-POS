import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';
import 'package:kompak_pos/core/utils/formatters.dart';
import 'package:kompak_pos/models/cart_item_model.dart';
import 'package:kompak_pos/widgets/common/quantity_selector.dart';

/// A single row representing a [CartItem] inside the cart list.
///
/// Shows an image placeholder (or network image), the product name, unit price,
/// quantity controls, the computed line total, and a delete button.
class CartItemTile extends StatelessWidget {
  /// The cart item to display.
  final CartItem item;

  /// Index of this item in the cart list (useful for animations / keys).
  final int index;

  /// Called with the new quantity when the user changes it.
  final ValueChanged<int> onQuantityChanged;

  /// Called when the user taps the delete button.
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  /// Generates a consistent gradient from the product name hash.
  List<Color> _placeholderGradient(String name) {
    final hash = name.hashCode;
    const gradients = [
      [Color(0xFFFF9A8B), Color(0xFFFF6A88)],
      [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
      [Color(0xFF84FAB0), Color(0xFF8FD3F4)],
      [Color(0xFFFCCB90), Color(0xFFD57EEB)],
      [Color(0xFF667EEA), Color(0xFF764BA2)],
      [Color(0xFFF6D365), Color(0xFFFDA085)],
    ];
    return gradients[hash.abs() % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _placeholderGradient(item.productName);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGrey),
        ),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            // Image placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _buildPlaceholder(gradientColors),
                      )
                    : _buildPlaceholder(gradientColors),
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Name, price, and quantity
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name
                  Text(
                    item.productName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Unit price
                  Text(
                    Formatters.currency(item.productPrice),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Quantity selector
                  QuantitySelector(
                    value: item.quantity,
                    onChanged: onQuantityChanged,
                    min: 1,
                    buttonSize: 28,
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // Line total and delete button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Delete button
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.errorRed,
                    ),
                    padding: EdgeInsets.zero,
                    splashRadius: 16,
                    tooltip: 'Remove item',
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Line total
                Text(
                  Formatters.currency(item.lineTotal),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: 22,
          color: Color.fromARGB(150, 255, 255, 255),
        ),
      ),
    );
  }
}
