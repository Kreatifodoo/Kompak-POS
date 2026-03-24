import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/cart_state_model.dart';
import '../../../models/enums.dart';
import '../../../modules/auth/auth_providers.dart';
import '../../../modules/core_providers.dart';
import '../../../modules/pos/cart_providers.dart';
import '../../../modules/promotion/promotion_providers.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/widgets/customer_selector.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

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
          'Current Order',
          style: AppTextStyles.heading3,
        ),
        actions: [
          if (cart.isNotEmpty)
            TextButton(
              onPressed: () {
                _showClearCartDialog(context, ref);
              },
              child: Text(
                'Clear All',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.errorRed,
                ),
              ),
            ),
        ],
      ),
      body: cart.isEmpty
          ? _buildEmptyCart(context)
          : Column(
              children: [
                // Customer selector
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
                  ),
                  child: CustomerSelector(),
                ),
                const Divider(height: AppSpacing.md),
                // Cart items list
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _CartItemTile(
                        item: item,
                        index: index,
                      );
                    },
                  ),
                ),
                // Order summary
                _buildOrderSummary(context, cart),
              ],
            ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: AppColors.textHint.withOpacity(0.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your cart is empty',
            style: AppTextStyles.heading3.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Add some products to get started',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
            ),
            child: Text(
              'Browse Products',
              style: AppTextStyles.buttonText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(BuildContext context, CartState cart) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
        child: Column(
          children: [
            // Summary rows
            _buildSummaryRow('Subtotal', Formatters.currency(cart.subtotal)),
            if (cart.discountAmount > 0)
              _buildSummaryRow(
                'Discount',
                '-${Formatters.currency(cart.discountAmount)}',
                valueColor: AppColors.discountRed,
              ),
            // Promotions breakdown (exclude free product promos — shown inline on item)
            ...cart.promotions.where((p) => !p.isFreeProduct).map((promo) {
              final label = promo.tipeReward == PromotionTipeReward.diskonPersentase
                  ? '${promo.namaPromo} (${promo.nilaiReward.toStringAsFixed(promo.nilaiReward.truncateToDouble() == promo.nilaiReward ? 0 : 1)}%)'
                  : promo.namaPromo;
              return _buildSummaryRow(
                label,
                '-${Formatters.currency(promo.discountAmount)}',
                valueColor: AppColors.successGreen,
              );
            }),
            // Promo code input
            _buildPromoCodeRow(context),
            // Dynamic charges breakdown
            ...cart.charges.map((charge) {
              final label = charge.tipe == ChargeTipe.persentase
                  ? '${charge.namaBiaya} (${charge.nilai.toStringAsFixed(charge.nilai.truncateToDouble() == charge.nilai ? 0 : 1)}%)'
                  : charge.namaBiaya;
              final prefix = charge.isDeduction ? '-' : '';
              return _buildSummaryRow(
                label,
                '$prefix${Formatters.currency(charge.amount.abs())}',
                valueColor: charge.isDeduction ? AppColors.discountRed : null,
              );
            }),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(),
            ),
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: AppTextStyles.heading3),
                Text(
                  Formatters.currency(cart.total),
                  style: AppTextStyles.priceLarge.copyWith(
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Proceed button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => context.push('/pos/payment'),
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
                    Text(
                      'Proceed Transactions',
                      style: AppTextStyles.buttonText,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCodeRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: InkWell(
        onTap: () => _showPromoCodeDialog(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.successGreen.withOpacity(0.4),
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.local_offer_rounded,
                  size: 16, color: AppColors.successGreen),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Punya kode promo?',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: AppColors.successGreen),
            ],
          ),
        ),
      ),
    );
  }

  void _showPromoCodeDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Masukkan Kode Promo', style: AppTextStyles.heading3),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Contoh: HEMAT20',
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surfaceGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.confirmation_number_rounded,
                  color: AppColors.textHint),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final code = controller.text.trim().toUpperCase();
                if (code.isEmpty) return;

                // Validate code exists
                final promoSvc = ref.read(promotionServiceProvider);
                final storeId = ref.read(currentStoreIdProvider);
                if (storeId == null) return;

                final promo = await promoSvc.validateCode(storeId, code);
                if (promo == null) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Kode promo tidak ditemukan')),
                    );
                  }
                  return;
                }

                ref.read(cartProvider.notifier).applyPromoCode(code);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Promo "${promo.namaPromo}" diterapkan!')),
                  );
                }
              },
              child: Text('Terapkan',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.primaryOrange, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
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

  void _showClearCartDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Cart', style: AppTextStyles.heading3),
        content: Text(
          'Are you sure you want to remove all items from the cart?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(ctx);
            },
            child: Text(
              'Clear',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  final int index;

  const _CartItemTile({
    required this.item,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CrossPlatformImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    ),
                  )
                : _buildPlaceholder(),
          ),
          const SizedBox(width: AppSpacing.md),
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (item.savings > 0 && item.originalPrice != null) ...[
                  Row(
                    children: [
                      Text(
                        Formatters.currency(item.originalPrice!),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        Formatters.currency(item.productPrice),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hemat ${Formatters.currency(item.savings)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else
                  Text(
                    Formatters.currency(item.productPrice),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (item.selectedExtras.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.selectedExtras.entries
                        .map((e) => '${e.value['name']}')
                        .join(', '),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
                if (item.isCombo && item.comboSelections.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  ...item.comboSelections.map((sel) => Padding(
                        padding: const EdgeInsets.only(bottom: 1),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outlined,
                                size: 12, color: AppColors.infoBlue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${sel.groupName}: ${sel.productName}${sel.extraPrice > 0 ? " (+${Formatters.currency(sel.extraPrice)})" : ""}',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.notes_rounded,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.notes!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                // Free product promo badge (inline under the free item)
                Builder(builder: (_) {
                  final cart = ref.watch(cartProvider);
                  final freePromos = cart.promotions.where((p) =>
                      p.isFreeProduct &&
                      p.freeProductId == item.productId);
                  if (freePromos.isEmpty) return const SizedBox.shrink();
                  final promo = freePromos.first;
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppColors.successGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎁 ', style: TextStyle(fontSize: 12)),
                          Flexible(
                            child: Text(
                              '${promo.namaPromo} — Gratis x${promo.freeProductQty} (-${Formatters.currency(promo.discountAmount)})',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSpacing.sm),
                // Quantity controls
                Row(
                  children: [
                    _buildQuantityButton(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        ref.read(cartProvider.notifier).updateQuantity(
                              index,
                              item.quantity - 1,
                            );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text(
                        '${item.quantity}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _buildQuantityButton(
                      icon: Icons.add_rounded,
                      isPrimary: true,
                      onTap: () {
                        ref.read(cartProvider.notifier).updateQuantity(
                              index,
                              item.quantity + 1,
                            );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Line total + delete
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.currency(item.lineTotal),
                style: AppTextStyles.priceMedium.copyWith(
                  color: AppColors.primaryOrange,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: () {
                  ref.read(cartProvider.notifier).removeItem(index);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.errorRed,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.fastfood_outlined,
        size: 28,
        color: AppColors.primaryOrange.withOpacity(0.4),
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primaryOrange : AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isPrimary ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}
