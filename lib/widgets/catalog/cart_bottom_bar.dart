import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';
import 'package:kompak_pos/core/utils/formatters.dart';

/// An orange bottom bar that summarises the current cart state.
///
/// Displays "[itemCount] items in cart - Rp [total]" with a cart icon on the
/// left and a forward arrow on the right. Tapping the bar triggers [onTap].
class CartBottomBar extends StatelessWidget {
  /// Number of items currently in the cart.
  final int itemCount;

  /// Cart total in the local currency.
  final double total;

  /// Called when the bar is tapped.
  final VoidCallback onTap;

  const CartBottomBar({
    super.key,
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Material(
          color: AppColors.primaryOrange,
          borderRadius: BorderRadius.circular(16),
          elevation: 4,
          shadowColor: const Color.fromARGB(60, 255, 107, 53),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  // Cart icon with item count badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(40, 255, 255, 255),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              itemCount > 99 ? '99+' : itemCount.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Summary text
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$itemCount ${itemCount == 1 ? 'item' : 'items'} in cart',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: const Color.fromARGB(200, 255, 255, 255),
                          ),
                        ),
                        Text(
                          Formatters.currency(total),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Forward arrow
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(40, 255, 255, 255),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
