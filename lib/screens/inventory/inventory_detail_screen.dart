import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../modules/inventory/inventory_providers.dart';
import '../../modules/core_providers.dart';

class InventoryDetailScreen extends ConsumerWidget {
  final String productId;

  const InventoryDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryForProductProvider(productId));

    return Scaffold(
      backgroundColor: AppColors.scaffoldWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Inventory Detail',
          style: AppTextStyles.heading3,
        ),
      ),
      body: inventoryAsync.when(
        data: (inventory) {
          if (inventory == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: AppColors.textHint.withOpacity(0.4),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Inventory not found',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          return _InventoryDetailBody(
            productId: productId,
            inventory: inventory,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _InventoryDetailBody extends ConsumerStatefulWidget {
  final String productId;
  final InventoryData inventory;

  const _InventoryDetailBody({
    required this.productId,
    required this.inventory,
  });

  @override
  ConsumerState<_InventoryDetailBody> createState() =>
      _InventoryDetailBodyState();
}

class _InventoryDetailBodyState extends ConsumerState<_InventoryDetailBody> {
  Product? _product;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final db = ref.read(databaseProvider);
    final p = await db.productDao.getById(widget.productId);
    if (mounted) setState(() => _product = p);
  }

  @override
  Widget build(BuildContext context) {
    final inventory = widget.inventory;
    final stockColor = _getStockColor(inventory);
    final sku = _product?.sku;
    final productName = _product?.name ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Stock level card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (productName.isNotEmpty) ...[
                  Text(
                    productName,
                    style: AppTextStyles.heading3,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stockColor.withOpacity(0.1),
                    border: Border.all(color: stockColor, width: 3),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          inventory.quantity.toStringAsFixed(0),
                          style: AppTextStyles.heading1.copyWith(
                            color: stockColor,
                            fontSize: 36,
                          ),
                        ),
                        Text(
                          inventory.unit,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: stockColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStockLabel(inventory),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: stockColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Details card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Details',
                  style: AppTextStyles.heading3.copyWith(fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildInfoRow(
                    'SKU', sku != null && sku.isNotEmpty ? sku : '-'),
                _buildInfoRow('Unit', inventory.unit),
                _buildThresholdRow(context, inventory),
                _buildInfoRow(
                  'Current Stock',
                  '${inventory.quantity.toStringAsFixed(0)} ${inventory.unit}',
                ),
                if (inventory.lastRestockAt != null)
                  _buildInfoRow(
                    'Last Restock',
                    Formatters.dateTime(inventory.lastRestockAt!),
                  ),
                _buildInfoRow(
                  'Last Updated',
                  Formatters.dateTime(inventory.updatedAt),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Restock button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _showRestockDialog(context, inventory),
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white),
              label: Text('Restock', style: AppTextStyles.buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdRow(BuildContext context, InventoryData inventory) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Low Stock Threshold',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: () => _showThresholdDialog(context, inventory),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${inventory.lowStockThreshold.toStringAsFixed(0)} ${inventory.unit}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit_rounded,
                    size: 16, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showThresholdDialog(BuildContext context, InventoryData inventory) {
    final controller = TextEditingController(
      text: inventory.lowStockThreshold.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Set Low Stock Threshold', style: AppTextStyles.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alert will show when stock falls below this number.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter threshold',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textHint),
                suffix: Text(inventory.unit, style: AppTextStyles.bodySmall),
                filled: true,
                fillColor: AppColors.surfaceGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val == null || val < 0) return;
              Navigator.pop(ctx);
              try {
                final db = ref.read(databaseProvider);
                await db.inventoryDao
                    .updateLowStockThreshold(inventory.productId, val);
                ref.invalidate(
                    inventoryForProductProvider(inventory.productId));
                ref.invalidate(inventoryWithProductProvider);
                ref.invalidate(lowStockProvider);
                if (context.mounted) {
                  context.showSnackBar('Threshold updated');
                }
              } catch (e) {
                if (context.mounted) {
                  context.showSnackBar('Failed: $e', isError: true);
                }
              }
            },
            child: Text(
              'Save',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRestockDialog(BuildContext context, InventoryData inventory) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Restock', style: AppTextStyles.heading3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter quantity to add to stock:',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter quantity',
                hintStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textHint),
                suffix: Text(inventory.unit, style: AppTextStyles.bodySmall),
                filled: true,
                fillColor: AppColors.surfaceGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final qty = double.tryParse(controller.text);
              if (qty == null || qty <= 0) return;
              Navigator.pop(ctx);
              try {
                final inventoryService = ref.read(inventoryServiceProvider);
                await inventoryService.restockProduct(
                    inventory.productId, qty);
                ref.invalidate(
                    inventoryForProductProvider(inventory.productId));
                ref.invalidate(inventoryWithProductProvider);
                ref.invalidate(lowStockProvider);
                if (context.mounted) {
                  context.showSnackBar(
                      'Restocked ${qty.toStringAsFixed(0)} ${inventory.unit}');
                }
              } catch (e) {
                if (context.mounted) {
                  context.showSnackBar('Restock failed: $e', isError: true);
                }
              }
            },
            child: Text(
              'Restock',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStockColor(InventoryData inv) {
    if (inv.quantity <= 0) return AppColors.errorRed;
    if (inv.quantity <= inv.lowStockThreshold) return AppColors.warningAmber;
    return AppColors.successGreen;
  }

  String _getStockLabel(InventoryData inv) {
    if (inv.quantity <= 0) return 'Out of Stock';
    if (inv.quantity <= inv.lowStockThreshold) return 'Low Stock';
    return 'In Stock';
  }
}
