import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kompak_pos/core/database/app_database.dart';
import 'package:kompak_pos/core/theme/app_colors.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';
import 'package:kompak_pos/widgets/common/discount_badge.dart';
import 'package:kompak_pos/widgets/common/price_tag.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
  });

  /// Generates a consistent gradient from the product name hash.
  List<Color> _placeholderGradient(String name) {
    final hash = name.hashCode;
    final gradients = [
      [const Color(0xFFFF9A8B), const Color(0xFFFF6A88)],
      [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)],
      [const Color(0xFF84FAB0), const Color(0xFF8FD3F4)],
      [const Color(0xFFFCCB90), const Color(0xFFD57EEB)],
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF6D365), const Color(0xFFFDA085)],
      [const Color(0xFFA1C4FD), const Color(0xFFC2E9FB)],
      [const Color(0xFFFA709A), const Color(0xFFFEE140)],
    ];
    return gradients[hash.abs() % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.discountPercent != null &&
        product.discountPercent! > 0;
    final gradientColors = _placeholderGradient(product.name);

    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area with optional discount badge
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    // Gradient placeholder (or image)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 36,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ),
                    // Discount badge
                    if (hasDiscount)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: DiscountBadge(
                          percentage: product.discountPercent!,
                        ),
                      ),
                  ],
                ),
              ),
              // Product details
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Product name
                      Text(
                        product.name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Description
                      if (product.description != null &&
                          product.description!.isNotEmpty)
                        Text(
                          product.description!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const Spacer(),
                      // Price
                      _buildPrice(hasDiscount),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrice(bool hasDiscount) {
    if (hasDiscount) {
      final discountedPrice =
          product.price * (1 - product.discountPercent! / 100);
      return Row(
        children: [
          PriceTag(
            price: discountedPrice,
            size: PriceTagSize.small,
            color: AppColors.primaryOrange,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: PriceTag(
              price: product.price,
              size: PriceTagSize.small,
              color: AppColors.textHint,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }

    return PriceTag(
      price: product.price,
      size: PriceTagSize.small,
      color: AppColors.primaryOrange,
    );
  }
}
