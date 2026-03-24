import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/database/app_database.dart';
import '../../../models/cart_item_model.dart';
import '../../../modules/product/product_providers.dart';
import '../../../modules/pos/cart_providers.dart';
import '../../../modules/pricelist/pricelist_providers.dart';
import '../../../services/pricelist_service.dart';
import '../combo/combo_selection_sheet.dart';
import '../../../core/widgets/cross_platform_image.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));
    final extrasAsync = ref.watch(productExtrasProvider(productId));

    return productAsync.when(
      data: (product) {
        if (product == null) {
          return Scaffold(
            backgroundColor: AppColors.darkBackground,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
            body: Center(
              child: Text(
                'Product not found',
                style: AppTextStyles.heading3.copyWith(color: AppColors.textLight),
              ),
            ),
          );
        }

        return _ProductDetailBody(
          product: product,
          extrasAsync: extrasAsync,
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Center(
          child: Text(
            'Error loading product',
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.errorRed),
          ),
        ),
      ),
    );
  }
}

class _ProductDetailBody extends ConsumerStatefulWidget {
  final Product product;
  final AsyncValue<List<ProductExtra>> extrasAsync;

  const _ProductDetailBody({
    required this.product,
    required this.extrasAsync,
  });

  @override
  ConsumerState<_ProductDetailBody> createState() => _ProductDetailBodyState();
}

class _ProductDetailBodyState extends ConsumerState<_ProductDetailBody> {
  int _quantity = 1;
  final Map<String, dynamic> _selectedExtras = {};
  final TextEditingController _notesController = TextEditingController();

  double get _extrasTotal {
    double total = 0;
    _selectedExtras.forEach((key, value) {
      if (value is Map && value.containsKey('price')) {
        total += (value['price'] as num).toDouble();
      }
    });
    return total;
  }

  double get _lineTotal {
    return (widget.product.price + _extrasTotal) * _quantity;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: CustomScrollView(
        slivers: [
          // Image header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.darkBackground,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryOrange.withOpacity(0.3),
                      AppColors.darkBackground,
                    ],
                  ),
                ),
                child: widget.product.imageUrl != null &&
                        widget.product.imageUrl!.isNotEmpty
                    ? _buildProductImage(widget.product.imageUrl!)
                    : _buildImagePlaceholder(),
              ),
            ),
          ),
          // Product details
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name
                  Text(
                    widget.product.name,
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Description
                  if (widget.product.description != null) ...[
                    Text(
                      widget.product.description!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  // Price with pricelist awareness
                  _buildPriceSection(),
                  // Discount badge
                  if (widget.product.discountPercent != null &&
                      widget.product.discountPercent! > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.discountRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.product.discountPercent!.toStringAsFixed(0)}% OFF',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.discountRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  // Extras section
                  _buildExtrasSection(),
                  const SizedBox(height: AppSpacing.lg),
                  // Quantity selector
                  _buildQuantitySelector(),
                  const SizedBox(height: AppSpacing.lg),
                  // Notes
                  _buildNotesField(),
                  const SizedBox(height: AppSpacing.xl),
                  // Add to cart button
                  _buildAddToCartButton(),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String imageUrl) {
    return CrossPlatformImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _notesController,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'e.g. No onion, extra spicy...',
            hintStyle:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.surfaceGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(AppSpacing.md),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    final priceAsync = ref.watch(catalogPriceProvider(
      (productId: widget.product.id, price: widget.product.price),
    ));
    return priceAsync.when(
      data: (result) {
        if (result != null) {
          final savingsTotal = result.savingsPerUnit * _quantity;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(result.tierPrice),
                    style: AppTextStyles.priceLarge.copyWith(
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    Formatters.currency(widget.product.price),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textHint,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Hemat ${Formatters.currency(savingsTotal)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        }
        return Text(
          Formatters.currency(widget.product.price),
          style: AppTextStyles.priceLarge.copyWith(
            color: AppColors.primaryOrange,
          ),
        );
      },
      loading: () => Text(
        Formatters.currency(widget.product.price),
        style: AppTextStyles.priceLarge.copyWith(
          color: AppColors.primaryOrange,
        ),
      ),
      error: (_, __) => Text(
        Formatters.currency(widget.product.price),
        style: AppTextStyles.priceLarge.copyWith(
          color: AppColors.primaryOrange,
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Icon(
        Icons.fastfood_outlined,
        size: 80,
        color: AppColors.primaryOrange.withOpacity(0.3),
      ),
    );
  }

  Widget _buildExtrasSection() {
    return widget.extrasAsync.when(
      data: (extras) {
        if (extras.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customize',
              style: AppTextStyles.heading3,
            ),
            const SizedBox(height: AppSpacing.md),
            ...extras.map((extra) => _buildExtraGroup(extra)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildExtraGroup(ProductExtra extra) {
    List<dynamic> options = [];
    try {
      options = jsonDecode(extra.optionsJson) as List<dynamic>;
    } catch (_) {}

    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              extra.name,
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),
            if (extra.isRequired) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.errorRed,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: options.map<Widget>((option) {
            final optionMap = option as Map<String, dynamic>;
            final name = optionMap['name'] as String? ?? '';
            final price = (optionMap['price'] as num?)?.toDouble() ?? 0;
            final isSelected = _selectedExtras[extra.name]?['name'] == name;

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedExtras.remove(extra.name);
                  } else {
                    _selectedExtras[extra.name] = {
                      'name': name,
                      'price': price,
                    };
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryOrange.withOpacity(0.1)
                      : AppColors.surfaceGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryOrange : AppColors.borderGrey,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected
                            ? AppColors.primaryOrange
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (price > 0)
                      Text(
                        '+${Formatters.currency(price)}',
                        style: AppTextStyles.caption.copyWith(
                          color: isSelected
                              ? AppColors.primaryOrange
                              : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        Text(
          'Quantity',
          style: AppTextStyles.heading3,
        ),
        const Spacer(),
        // Decrement
        GestureDetector(
          onTap: () {
            if (_quantity > 1) {
              setState(() => _quantity--);
            }
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _quantity > 1
                  ? AppColors.surfaceGrey
                  : AppColors.surfaceGrey.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.remove_rounded,
              color: _quantity > 1 ? AppColors.textPrimary : AppColors.textHint,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            '$_quantity',
            style: AppTextStyles.heading2.copyWith(fontSize: 24),
          ),
        ),
        // Increment
        GestureDetector(
          onTap: () => setState(() => _quantity++),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddToCartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () async {
          if (widget.product.isCombo) {
            final result = await showModalBottomSheet<CartItem>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  ComboSelectionSheet(comboProduct: widget.product),
            );
            if (result != null && context.mounted) {
              ref.read(cartProvider.notifier).addItem(result);
              context.showSnackBar('${widget.product.name} added to cart');
              context.pop();
            }
            return;
          }
          final notes = _notesController.text.trim();
          final cartItem = CartItem(
            productId: widget.product.id,
            productName: widget.product.name,
            productPrice: widget.product.price + _extrasTotal,
            quantity: _quantity,
            selectedExtras: Map<String, dynamic>.from(_selectedExtras),
            lineTotal: _lineTotal,
            imageUrl: widget.product.imageUrl,
            description: widget.product.description,
            notes: notes.isNotEmpty ? notes : null,
          );
          ref.read(cartProvider.notifier).addItem(cartItem);
          context.showSnackBar('${widget.product.name} added to cart');
          context.pop();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Add to Cart',
              style: AppTextStyles.buttonText,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '- ${Formatters.currency(_lineTotal)}',
              style: AppTextStyles.buttonText.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
