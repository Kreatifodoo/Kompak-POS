import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/extensions.dart';
import '../../core/database/app_database.dart';
import '../../modules/combo/combo_providers.dart';
import '../../modules/core_providers.dart';
import '../../modules/product/product_providers.dart';

/// Screen to configure combo groups and their items for a combo product.
class ComboConfigScreen extends ConsumerWidget {
  final String productId;
  const ComboConfigScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));
    final groupsAsync = ref.watch(comboGroupsProvider(productId));

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
            Text('Konfigurasi Combo', style: AppTextStyles.heading3),
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
        onPressed: () => _showAddGroupDialog(context, ref),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_customize_outlined,
                      size: 64,
                      color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Belum ada pilihan combo',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Tap + untuk menambah grup pilihan',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _ComboGroupCard(
              group: groups[index],
              productId: productId,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showAddGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final minController = TextEditingController(text: '1');
    final maxController = TextEditingController(text: '1');
    final orderController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Grup Pilihan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Grup',
                  hintText: 'e.g. Pilih Makanan Utama',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min Pilih',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Pilih',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Urutan',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final service = ref.read(comboServiceProvider);
              await service.createGroup(
                productId: productId,
                name: name,
                minSelect: int.tryParse(minController.text) ?? 1,
                maxSelect: int.tryParse(maxController.text) ?? 1,
                sortOrder: int.tryParse(orderController.text) ?? 0,
              );
              ref.invalidate(comboGroupsProvider(productId));
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _ComboGroupCard extends ConsumerWidget {
  final ComboGroup group;
  final String productId;

  const _ComboGroupCard({required this.group, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(comboGroupItemsProvider(group.id));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.infoBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.dashboard_customize_rounded,
                      color: AppColors.infoBlue, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name,
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        'Pilih ${group.minSelect}${group.maxSelect > group.minSelect ? "-${group.maxSelect}" : ""} item  •  Urutan #${group.sortOrder}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') {
                      _showEditGroupDialog(context, ref);
                    } else if (val == 'delete') {
                      _showDeleteGroupDialog(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit Grup')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Hapus Grup',
                            style: TextStyle(color: AppColors.errorRed))),
                  ],
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            // Items list
            itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      'Belum ada item. Tap + untuk menambahkan produk.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint),
                    ),
                  );
                }
                return Column(
                  children: items
                      .map((item) => _ComboItemTile(
                            item: item,
                            groupId: group.id,
                            productId: productId,
                          ))
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (e, _) => Text('Error: $e'),
            ),
            // Add item button
            TextButton.icon(
              onPressed: () =>
                  _showAddItemDialog(context, ref, group.id),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah Item'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: group.name);
    final minController =
        TextEditingController(text: group.minSelect.toString());
    final maxController =
        TextEditingController(text: group.maxSelect.toString());
    final orderController =
        TextEditingController(text: group.sortOrder.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Grup'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama Grup'),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Min Pilih'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Max Pilih'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: orderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Urutan'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final service = ref.read(comboServiceProvider);
              await service.updateGroup(
                id: group.id,
                productId: productId,
                name: name,
                minSelect: int.tryParse(minController.text) ?? 1,
                maxSelect: int.tryParse(maxController.text) ?? 1,
                sortOrder: int.tryParse(orderController.text) ?? 0,
              );
              ref.invalidate(comboGroupsProvider(productId));
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Grup'),
        content: Text('Hapus grup "${group.name}" beserta semua item-nya?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final service = ref.read(comboServiceProvider);
              await service.deleteGroup(group.id);
              ref.invalidate(comboGroupsProvider(productId));
            },
            child: const Text('Hapus',
                style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(
      BuildContext context, WidgetRef ref, String groupId) {
    // Show product picker
    final productsAsync = ref.read(allProductsProvider);
    final products = productsAsync.valueOrNull ?? [];

    if (products.isEmpty) {
      context.showSnackBar('Tidak ada produk tersedia');
      return;
    }

    final extraPriceController = TextEditingController(text: '0');
    String? selectedProductId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tambah Item ke Grup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedProductId,
                  decoration:
                      const InputDecoration(labelText: 'Pilih Produk'),
                  items: products
                      .where((p) => !p.isCombo) // can't nest combos
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
                TextField(
                  controller: extraPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga Tambahan',
                    prefixText: 'Rp ',
                    helperText: '0 = tanpa biaya tambahan',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            TextButton(
              onPressed: () async {
                if (selectedProductId == null) return;
                Navigator.pop(ctx);
                final service = ref.read(comboServiceProvider);
                await service.addItemToGroup(
                  comboGroupId: groupId,
                  productId: selectedProductId!,
                  extraPrice:
                      double.tryParse(extraPriceController.text) ?? 0,
                );
                ref.invalidate(comboGroupItemsProvider(groupId));
              },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComboItemTile extends ConsumerWidget {
  final ComboGroupItem item;
  final String groupId;
  final String productId;

  const _ComboItemTile({
    required this.item,
    required this.groupId,
    required this.productId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(item.productId));

    return productAsync.when(
      data: (product) {
        if (product == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fastfood_outlined,
                    size: 18, color: AppColors.textHint),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: AppTextStyles.bodySmall
                            .copyWith(fontWeight: FontWeight.w500)),
                    if (item.extraPrice > 0)
                      Text(
                        '+${Formatters.currency(item.extraPrice)}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primaryOrange),
                      ),
                  ],
                ),
              ),
              Text(
                Formatters.currency(product.price),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textHint),
                onPressed: () async {
                  final service = ref.read(comboServiceProvider);
                  await service.deleteItem(item.id);
                  ref.invalidate(comboGroupItemsProvider(groupId));
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
          height: 36,
          child: Center(
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)))),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
