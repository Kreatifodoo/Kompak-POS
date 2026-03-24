import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../modules/bom/bom_providers.dart';
import '../../modules/core_providers.dart';
import '../../services/bom_service.dart';
import '../../modules/product/product_providers.dart';

/// Screen to configure Bill of Materials (BOM) recipe for a product.
/// When sold, inventory deduction will use BOM components instead of the product itself.
class BomConfigScreen extends ConsumerWidget {
  final String productId;
  const BomConfigScreen({super.key, required this.productId});

  static const _unitOptions = ['pcs', 'gram', 'kg', 'ml', 'liter'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));
    final bomAsync = ref.watch(bomConfigProvider(productId));

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konfigurasi Resep (BOM)', style: AppTextStyles.heading3),
            productAsync.when(
              data: (p) => Text(
                p?.name ?? '',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryOrange,
        onPressed: () => _showAddItemDialog(context, ref),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: bomAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.science_outlined,
                      size: 64,
                      color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Belum ada bahan baku',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Tap + untuk menambah komponen resep',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }

          // Calculate total BOM cost
          double totalBomCost = 0;
          for (final item in items) {
            totalBomCost += (item.material.costPrice ?? 0) * item.bomItem.quantity;
          }

          return Column(
            children: [
              // Info banner with total cost
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.successGreen.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.successGreen, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Saat produk ini dijual, stok produk utama TIDAK terpotong. Yang terpotong adalah stok bahan baku di bawah sesuai jumlah yang dijual. COGS tetap dihitung dari cost produk utama.',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.successGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Cost Resep',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            totalBomCost.toCurrency(),
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // BOM items list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => _BomItemCard(
                    bomItemWithProduct: items[index],
                    productId: productId,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.read(allProductsProvider);
    final products = productsAsync.valueOrNull ?? [];

    if (products.isEmpty) {
      context.showSnackBar('Tidak ada produk tersedia');
      return;
    }

    // Collect materialProductIds already in the BOM to prevent duplicates
    final bomAsync = ref.read(bomConfigProvider(productId));
    final existingMaterialIds = bomAsync.valueOrNull
            ?.map((e) => e.bomItem.materialProductId)
            .toSet() ??
        {};

    final qtyController = TextEditingController(text: '1');
    String? selectedProductId;
    String selectedUnit = 'pcs';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Tambah Bahan Baku', style: AppTextStyles.heading3),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration: InputDecoration(
                    labelText: 'Pilih Bahan Baku',
                    filled: true,
                    fillColor: AppColors.surfaceGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  isExpanded: true,
                  items: products
                      .where((p) =>
                          p.id != productId && // exclude self
                          !existingMaterialIds.contains(p.id)) // exclude duplicates
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedProductId = v),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Jumlah',
                          filled: true,
                          fillColor: AppColors.surfaceGrey,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: InputDecoration(
                          labelText: 'Satuan',
                          filled: true,
                          fillColor: AppColors.surfaceGrey,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _unitOptions
                            .map((u) => DropdownMenuItem(
                                value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedUnit = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
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
                if (selectedProductId == null) return;
                final qty = double.tryParse(qtyController.text);
                if (qty == null || qty <= 0) return;
                Navigator.pop(ctx);
                final service = ref.read(bomServiceProvider);
                await service.addItem(
                  productId: productId,
                  materialProductId: selectedProductId!,
                  quantity: qty,
                  unit: selectedUnit,
                );
                ref.invalidate(bomConfigProvider(productId));
              },
              child: Text('Tambah',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BomItemCard extends ConsumerWidget {
  final BomItemWithProduct bomItemWithProduct;
  final String productId;

  const _BomItemCard({required this.bomItemWithProduct, required this.productId});

  BomItem get bomItem => bomItemWithProduct.bomItem;
  Product get material => bomItemWithProduct.material;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCost = (material.costPrice ?? 0) * bomItem.quantity;

    return Card(
      elevation: 0,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_outlined,
                  color: AppColors.successGreen, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            // Material info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(material.name,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatQty(bomItem.quantity)} ${bomItem.unit} per produk',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cost: ${(material.costPrice ?? 0).toCurrency()} × ${_formatQty(bomItem.quantity)} = ${itemCost.toCurrency()}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primaryOrange),
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  _showEditDialog(context, ref);
                } else if (val == 'delete') {
                  _showDeleteDialog(context, ref, material.name);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus',
                        style: TextStyle(color: AppColors.errorRed))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(2);
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref) {
    final qtyController =
        TextEditingController(text: _formatQty(bomItem.quantity));
    String selectedUnit = bomItem.unit;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit ${material.name}',
              style: AppTextStyles.heading3),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: qtyController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Jumlah',
                          filled: true,
                          fillColor: AppColors.surfaceGrey,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: InputDecoration(
                          labelText: 'Satuan',
                          filled: true,
                          fillColor: AppColors.surfaceGrey,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: BomConfigScreen._unitOptions
                            .map((u) => DropdownMenuItem(
                                value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedUnit = v);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
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
                final qty = double.tryParse(qtyController.text);
                if (qty == null || qty <= 0) return;
                Navigator.pop(ctx);
                final service = ref.read(bomServiceProvider);
                await service.updateItem(
                  id: bomItem.id,
                  productId: productId,
                  materialProductId: bomItem.materialProductId,
                  quantity: qty,
                  unit: selectedUnit,
                  sortOrder: bomItem.sortOrder,
                );
                ref.invalidate(bomConfigProvider(productId));
              },
              child: Text('Simpan',
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primaryOrange,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, String materialName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Bahan Baku', style: AppTextStyles.heading3),
        content: Text(
          'Hapus "$materialName" dari resep?',
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
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(bomServiceProvider);
              await service.deleteItem(bomItem.id);
              ref.invalidate(bomConfigProvider(productId));
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
