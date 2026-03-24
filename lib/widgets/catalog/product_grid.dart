import 'package:flutter/material.dart';
import 'package:kompak_pos/core/database/app_database.dart';
import 'package:kompak_pos/core/theme/app_spacing.dart';
import 'package:kompak_pos/widgets/catalog/product_card.dart';

/// A 2-column sliver grid that displays [Product] items as [ProductCard] tiles.
///
/// Typically used inside a [CustomScrollView] alongside other slivers such as
/// a [SliverAppBar] or [SliverToBoxAdapter] header.
class ProductGrid extends StatelessWidget {
  /// The list of products to display.
  final List<Product> products;

  /// Called when a product card is tapped.
  final ValueChanged<Product> onProductTap;

  /// Aspect ratio for each grid cell (width / height). Defaults to 0.72
  /// which produces a tall card matching the product card design.
  final double childAspectRatio;

  /// Horizontal and vertical spacing between grid items.
  final double spacing;

  /// Padding around the entire grid.
  final EdgeInsetsGeometry padding;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.childAspectRatio = 0.72,
    this.spacing = AppSpacing.md,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No products found',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade400,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              onTap: () => onProductTap(product),
            );
          },
          childCount: products.length,
        ),
      ),
    );
  }
}
