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

/// Embedded cart panel for web split-layout POS.
/// Shows cart items + order summary in a single column.
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context, ref, cart),
          const Divider(height: 1),
          // Customer selector
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
            child: const CustomerSelector(compact: true),
          ),
          const Divider(height: 8),
          // Content
          Expanded(
            child: cart.isEmpty
                ? _buildEmptyState()
                : _buildCartContent(context, ref, cart),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, CartState cart) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_rounded,
              color: AppColors.primaryOrange, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Current Order',
              style: AppTextStyles.heading3.copyWith(fontSize: 16),
            ),
          ),
          if (cart.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${cart.itemCount} item',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              onTap: () => _showClearCartDialog(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.delete_sweep_outlined,
                    color: AppColors.errorRed, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: AppColors.textHint.withOpacity(0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Keranjang kosong',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pilih produk untuk memulai',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(BuildContext context, WidgetRef ref, CartState cart) {
    return Column(
      children: [
        // Scrollable cart items
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            itemCount: cart.items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return _CartPanelItem(item: item, index: index);
            },
          ),
        ),
        // Order summary (sticky bottom)
        _buildOrderSummary(context, ref, cart),
      ],
    );
  }

  Widget _buildOrderSummary(
      BuildContext context, WidgetRef ref, CartState cart) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          _summaryRow('Subtotal', Formatters.currency(cart.subtotal)),
          if (cart.discountAmount > 0)
            _summaryRow(
              'Discount',
              '-${Formatters.currency(cart.discountAmount)}',
              valueColor: AppColors.discountRed,
            ),
          // Promotions (exclude free product promos — shown inline on item)
          ...cart.promotions.where((p) => !p.isFreeProduct).map((promo) {
            final label = promo.tipeReward == PromotionTipeReward.diskonPersentase
                ? '${promo.namaPromo} (${promo.nilaiReward.toStringAsFixed(promo.nilaiReward.truncateToDouble() == promo.nilaiReward ? 0 : 1)}%)'
                : promo.namaPromo;
            return _summaryRow(
              label,
              '-${Formatters.currency(promo.discountAmount)}',
              valueColor: AppColors.successGreen,
            );
          }),
          // Promo code
          _buildPromoCodeRow(context, ref),
          // Charges
          ...cart.charges.map((charge) {
            final label = charge.tipe == ChargeTipe.persentase
                ? '${charge.namaBiaya} (${charge.nilai.toStringAsFixed(charge.nilai.truncateToDouble() == charge.nilai ? 0 : 1)}%)'
                : charge.namaBiaya;
            final prefix = charge.isDeduction ? '-' : '';
            return _summaryRow(
              label,
              '$prefix${Formatters.currency(charge.amount.abs())}',
              valueColor: charge.isDeduction ? AppColors.discountRed : null,
            );
          }),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: AppTextStyles.heading3.copyWith(fontSize: 15)),
              Text(
                Formatters.currency(cart.total),
                style: AppTextStyles.priceLarge.copyWith(
                  color: AppColors.primaryOrange,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Proceed button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.push('/pos/payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Bayar', style: AppTextStyles.buttonText),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeRow(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: () => _showPromoCodeDialog(context, ref),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.successGreen.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.local_offer_rounded,
                  size: 14, color: AppColors.successGreen),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Punya kode promo?',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 10, color: AppColors.successGreen),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showPromoCodeDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Masukkan Kode Promo', style: AppTextStyles.heading3),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Contoh: HEMAT20',
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
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
                final promoSvc = ref.read(promotionServiceProvider);
                final storeId = ref.read(currentStoreIdProvider);
                if (storeId == null) return;
                final promo = await promoSvc.validateCode(storeId, code);
                if (promo == null) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Kode promo tidak ditemukan')),
                    );
                  }
                  return;
                }
                ref.read(cartProvider.notifier).applyPromoCode(code);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text('Promo "${promo.namaPromo}" diterapkan!')),
                  );
                }
              },
              child: Text('Terapkan',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Kosongkan Keranjang', style: AppTextStyles.heading3),
        content: Text(
          'Hapus semua item dari keranjang?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(ctx);
            },
            child: Text('Hapus',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }
}

/// Compact cart item tile for the web cart panel.
class _CartPanelItem extends ConsumerWidget {
  final CartItem item;
  final int index;

  const _CartPanelItem({required this.item, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small product thumbnail
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CrossPlatformImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    ),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 8),
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.currency(item.productPrice),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (item.isCombo && item.comboSelections.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.comboSelections.map((s) => s.productName).join(', '),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.infoBlue,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.notes!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint,
                      fontStyle: FontStyle.italic,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Free product promo badge (inline)
                Builder(builder: (_) {
                  final cart = ref.watch(cartProvider);
                  final freePromos = cart.promotions.where((p) =>
                      p.isFreeProduct &&
                      p.freeProductId == item.productId);
                  if (freePromos.isEmpty) return const SizedBox.shrink();
                  final promo = freePromos.first;
                  return Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.successGreen.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎁 ', style: TextStyle(fontSize: 10)),
                          Flexible(
                            child: Text(
                              '${promo.namaPromo} — Gratis x${promo.freeProductQty} (-${Formatters.currency(promo.discountAmount)})',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                // Quantity controls
                Row(
                  children: [
                    _qtyBtn(
                      icon: Icons.remove,
                      onTap: () => ref
                          .read(cartProvider.notifier)
                          .updateQuantity(index, item.quantity - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${item.quantity}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _qtyBtn(
                      icon: Icons.add,
                      isPrimary: true,
                      onTap: () => ref
                          .read(cartProvider.notifier)
                          .updateQuantity(index, item.quantity + 1),
                    ),
                    const Spacer(),
                    // Delete
                    InkWell(
                      onTap: () =>
                          ref.read(cartProvider.notifier).removeItem(index),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: AppColors.errorRed),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Line total
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              Formatters.currency(item.lineTotal),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Icon(
        Icons.fastfood_outlined,
        size: 20,
        color: AppColors.primaryOrange.withOpacity(0.3),
      ),
    );
  }

  Widget _qtyBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primaryOrange : AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isPrimary ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}
