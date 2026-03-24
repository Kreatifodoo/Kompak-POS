import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/database/app_database.dart';
import '../../../models/cart_item_model.dart';
import '../../../services/combo_service.dart';
import '../../../modules/combo/combo_providers.dart';

/// Bottom sheet for selecting combo items when adding a combo product to cart.
/// Returns a CartItem with comboSelections populated, or null if cancelled.
class ComboSelectionSheet extends ConsumerStatefulWidget {
  final Product comboProduct;

  const ComboSelectionSheet({super.key, required this.comboProduct});

  @override
  ConsumerState<ComboSelectionSheet> createState() =>
      _ComboSelectionSheetState();
}

class _ComboSelectionSheetState extends ConsumerState<ComboSelectionSheet> {
  // groupId -> list of selected ComboItemWithProduct
  final Map<String, List<ComboItemWithProduct>> _selections = {};
  int _quantity = 1;

  double get _totalExtraPrice {
    double total = 0;
    for (final items in _selections.values) {
      for (final item in items) {
        total += item.comboGroupItem.extraPrice;
      }
    }
    return total;
  }

  double get _lineTotal =>
      (widget.comboProduct.price + _totalExtraPrice) * _quantity;

  bool _isValid(List<ComboGroupWithItems> groups) {
    for (final g in groups) {
      final selected = _selections[g.group.id]?.length ?? 0;
      if (selected < g.group.minSelect) return false;
    }
    return true;
  }

  void _toggleItem(ComboGroup group, ComboItemWithProduct item) {
    setState(() {
      final list = _selections[group.id] ?? [];
      final idx = list.indexWhere(
          (s) => s.comboGroupItem.id == item.comboGroupItem.id);

      if (idx >= 0) {
        // Deselect
        list.removeAt(idx);
      } else {
        if (group.maxSelect == 1) {
          // Single select: replace
          list.clear();
          list.add(item);
        } else if (list.length < group.maxSelect) {
          // Multi select: add if under max
          list.add(item);
        }
      }
      _selections[group.id] = list;
    });
  }

  bool _isSelected(String groupId, String itemId) {
    return _selections[groupId]
            ?.any((s) => s.comboGroupItem.id == itemId) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final configAsync =
        ref.watch(comboConfigProvider(widget.comboProduct.id));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: configAsync.when(
        data: (groups) => _buildContent(groups),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 200,
          child: Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildContent(List<ComboGroupWithItems> groups) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.dashboard_customize_rounded,
                    color: AppColors.primaryOrange, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.comboProduct.name,
                        style: AppTextStyles.heading3),
                    const SizedBox(height: 2),
                    Text(
                      'Harga dasar: ${Formatters.currency(widget.comboProduct.price)}',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Groups
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (context, index) =>
                _buildGroup(groups[index]),
          ),
        ),
        // Quantity + total
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Quantity selector
                Row(
                  children: [
                    Text('Jumlah', style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        if (_quantity > 1) setState(() => _quantity--);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _quantity > 1
                              ? AppColors.surfaceGrey
                              : AppColors.surfaceGrey.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.remove_rounded,
                            size: 20,
                            color: _quantity > 1
                                ? AppColors.textPrimary
                                : AppColors.textHint),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      child: Text('$_quantity',
                          style: AppTextStyles.heading3),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _quantity++),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Add to cart button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isValid(groups)
                        ? () => _addToCart(groups)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_shopping_cart_rounded,
                            color: Colors.white),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Tambah ke Keranjang',
                            style: AppTextStyles.buttonText),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '- ${Formatters.currency(_lineTotal)}',
                          style: AppTextStyles.buttonText
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroup(ComboGroupWithItems groupData) {
    final group = groupData.group;
    final selectedCount = _selections[group.id]?.length ?? 0;
    final isComplete = selectedCount >= group.minSelect;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(group.name,
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isComplete
                    ? AppColors.successGreen.withOpacity(0.1)
                    : AppColors.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                group.maxSelect == 1
                    ? 'Pilih 1'
                    : 'Pilih ${group.minSelect}-${group.maxSelect}',
                style: AppTextStyles.caption.copyWith(
                  color: isComplete
                      ? AppColors.successGreen
                      : AppColors.warningAmber,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
            if (isComplete) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle_rounded,
                  size: 16, color: AppColors.successGreen),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...groupData.items.map((item) => _buildItemOption(group, item)),
      ],
    );
  }

  Widget _buildItemOption(ComboGroup group, ComboItemWithProduct item) {
    final selected =
        _isSelected(group.id, item.comboGroupItem.id);

    return GestureDetector(
      onTap: () => _toggleItem(group, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryOrange.withOpacity(0.08)
              : AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryOrange : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Radio / checkbox indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: group.maxSelect == 1
                    ? BoxShape.circle
                    : BoxShape.rectangle,
                borderRadius: group.maxSelect > 1
                    ? BorderRadius.circular(6)
                    : null,
                color: selected
                    ? AppColors.primaryOrange
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.primaryOrange
                      : AppColors.textHint,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppColors.primaryOrange
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (item.product.description != null &&
                      item.product.description!.isNotEmpty)
                    Text(
                      item.product.description!,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (item.comboGroupItem.extraPrice > 0)
              Text(
                '+${Formatters.currency(item.comboGroupItem.extraPrice)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addToCart(List<ComboGroupWithItems> groups) {
    final comboSelections = <ComboSelection>[];

    for (final groupData in groups) {
      final selected = _selections[groupData.group.id] ?? [];
      for (final item in selected) {
        comboSelections.add(ComboSelection(
          groupId: groupData.group.id,
          groupName: groupData.group.name,
          productId: item.product.id,
          productName: item.product.name,
          extraPrice: item.comboGroupItem.extraPrice,
        ));
      }
    }

    final cartItem = CartItem(
      productId: widget.comboProduct.id,
      productName: widget.comboProduct.name,
      productPrice: widget.comboProduct.price + _totalExtraPrice,
      quantity: _quantity,
      lineTotal: _lineTotal,
      imageUrl: widget.comboProduct.imageUrl,
      description: widget.comboProduct.description,
      isCombo: true,
      comboSelections: comboSelections,
    );

    Navigator.pop(context, cartItem);
  }
}
