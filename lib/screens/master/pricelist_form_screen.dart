import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/formatters.dart';
import '../../core/database/app_database.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/pricelist/pricelist_providers.dart';

const _uuid = Uuid();

class PricelistFormScreen extends ConsumerStatefulWidget {
  final String? pricelistId;
  const PricelistFormScreen({super.key, this.pricelistId});

  @override
  ConsumerState<PricelistFormScreen> createState() =>
      _PricelistFormScreenState();
}

class _PricelistFormScreenState extends ConsumerState<PricelistFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isActive = true;
  bool _isLoaded = false;
  bool _isSaving = false;

  // Product tier rows: each entry = {productId, productName, tiers: [{minQty, maxQty, price}]}
  final List<_ProductTierGroup> _productGroups = [];

  bool get _isEditing => widget.pricelistId != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_isLoaded || !_isEditing) return;
    _isLoaded = true;

    final svc = ref.read(pricelistServiceProvider);
    final pl = await svc.getById(widget.pricelistId!);
    if (pl == null) return;

    _nameController.text = pl.name;
    _startDate = pl.startDate;
    _endDate = pl.endDate;
    _isActive = pl.isActive;

    final items = await svc.getItems(widget.pricelistId!);
    final db = ref.read(databaseProvider);

    // Group items by productId
    final Map<String, _ProductTierGroup> grouped = {};
    for (final item in items) {
      if (!grouped.containsKey(item.productId)) {
        final product = await db.productDao.getById(item.productId);
        grouped[item.productId] = _ProductTierGroup(
          productId: item.productId,
          productName: product?.name ?? 'Unknown',
          originalPrice: product?.price ?? 0,
          tiers: [],
        );
      }
      grouped[item.productId]!.tiers.add(_TierRow(
        minQty: item.minQty,
        maxQty: item.maxQty,
        price: item.price,
      ));
    }

    setState(() {
      _productGroups.clear();
      _productGroups.addAll(grouped.values);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) _loadExisting();

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
          _isEditing ? 'Edit Pricelist' : 'New Pricelist',
          style: AppTextStyles.heading3,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Name
            _buildLabel('Pricelist Name'),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('e.g. Promo Ramadan'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Name required' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Date range
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Start Date'),
                      _buildDateButton(_startDate, (d) {
                        setState(() => _startDate = d);
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('End Date'),
                      _buildDateButton(_endDate, (d) {
                        setState(() => _endDate = d);
                      }),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Active toggle
            SwitchListTile(
              title: Text('Active', style: AppTextStyles.bodyMedium),
              value: _isActive,
              activeColor: AppColors.primaryOrange,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _isActive = v),
            ),

            const Divider(height: AppSpacing.xl),

            // Products + tiers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Products & Price Tiers',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                TextButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Product'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            if (_productGroups.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No products added yet.\nTap "Add Product" above.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textHint),
                  ),
                ),
              ),

            ..._productGroups.asMap().entries.map((entry) {
              final idx = entry.key;
              final group = entry.value;
              return _buildProductGroup(idx, group);
            }),

            const SizedBox(height: AppSpacing.xl),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        _isEditing ? 'Update Pricelist' : 'Create Pricelist',
                        style: AppTextStyles.buttonText,
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGroup(int groupIdx, _ProductTierGroup group) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.productName,
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        'Base price: ${Formatters.currency(group.originalPrice)}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.errorRed, size: 20),
                  onPressed: () {
                    setState(() => _productGroups.removeAt(groupIdx));
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Tier header
            Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('Min Qty',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 2,
                    child: Text('Max Qty',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600))),
                Expanded(
                    flex: 3,
                    child: Text('Price',
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w600))),
                const SizedBox(width: 32),
              ],
            ),
            const SizedBox(height: 4),

            ...group.tiers.asMap().entries.map((tierEntry) {
              final tierIdx = tierEntry.key;
              final tier = tierEntry.value;
              return _buildTierRow(groupIdx, tierIdx, tier, group.originalPrice);
            }),

            TextButton.icon(
              onPressed: () {
                setState(() {
                  final lastMax = group.tiers.isEmpty
                      ? 0
                      : group.tiers.last.maxQty;
                  group.tiers.add(_TierRow(
                    minQty: lastMax + 1,
                    maxQty: 0,
                    price: group.originalPrice,
                  ));
                });
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Tier'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                textStyle: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierRow(
      int groupIdx, int tierIdx, _TierRow tier, double originalPrice) {
    final savings = originalPrice - tier.price;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _smallNumberField(
              value: tier.minQty,
              onChanged: (v) =>
                  setState(() => _productGroups[groupIdx].tiers[tierIdx].minQty = v),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: _smallNumberField(
              value: tier.maxQty,
              hint: '∞',
              onChanged: (v) =>
                  setState(() => _productGroups[groupIdx].tiers[tierIdx].maxQty = v),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _smallPriceField(
                  value: tier.price,
                  onChanged: (v) =>
                      setState(() => _productGroups[groupIdx].tiers[tierIdx].price = v),
                ),
                if (savings > 0)
                  Text(
                    'Save ${Formatters.currencyCompact(savings)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.successGreen,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16, color: AppColors.textHint),
              onPressed: () {
                setState(() =>
                    _productGroups[groupIdx].tiers.removeAt(tierIdx));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallNumberField({
    required int value,
    String? hint,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      initialValue: value == 0 ? '' : value.toString(),
      keyboardType: TextInputType.number,
      style: AppTextStyles.bodySmall,
      decoration: InputDecoration(
        hintText: hint ?? '0',
        hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textHint),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
      ),
      onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
    );
  }

  Widget _smallPriceField({
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return TextFormField(
      initialValue: value.toStringAsFixed(0),
      keyboardType: TextInputType.number,
      style: AppTextStyles.bodySmall,
      decoration: InputDecoration(
        prefixText: 'Rp ',
        prefixStyle:
            AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
      ),
      onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
    );
  }

  Future<void> _addProduct() async {
    final db = ref.read(databaseProvider);
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;

    final products = await db.productDao.getAllByStore(storeId);
    final existing = _productGroups.map((g) => g.productId).toSet();
    final available = products.where((p) => !existing.contains(p.id)).toList();

    if (available.isEmpty) {
      if (mounted) {
        context.showSnackBar('All products already added');
      }
      return;
    }

    if (!mounted) return;
    final selected = await showDialog<Product>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Product'),
        children: available.map((p) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, p),
            child: Row(
              children: [
                Expanded(child: Text(p.name)),
                Text(Formatters.currency(p.price),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      setState(() {
        _productGroups.add(_ProductTierGroup(
          productId: selected.id,
          productName: selected.name,
          originalPrice: selected.price,
          tiers: [
            _TierRow(minQty: 1, maxQty: 0, price: selected.price),
          ],
        ));
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productGroups.isEmpty) {
      context.showSnackBar('Add at least one product', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final svc = ref.read(pricelistServiceProvider);
      final storeId = ref.read(currentStoreIdProvider) ?? '';

      String plId;
      if (_isEditing) {
        plId = widget.pricelistId!;
        await svc.updatePricelist(
          id: plId,
          name: _nameController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
          isActive: _isActive,
        );
      } else {
        plId = await svc.createPricelist(
          storeId: storeId,
          name: _nameController.text.trim(),
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      // Replace all items
      final items = <PricelistItemsCompanion>[];
      for (final group in _productGroups) {
        for (final tier in group.tiers) {
          items.add(PricelistItemsCompanion.insert(
            id: _uuid.v4(),
            pricelistId: plId,
            productId: group.productId,
            minQty: Value(tier.minQty),
            maxQty: Value(tier.maxQty),
            price: tier.price,
          ));
        }
      }
      await svc.replaceItems(plId, items);

      ref.invalidate(pricelistsProvider);

      if (mounted) {
        context.showSnackBar(
            _isEditing ? 'Pricelist updated' : 'Pricelist created');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text,
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600)),
      );

  Widget _buildDateButton(DateTime date, ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGrey),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(Formatters.date(date), style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primaryOrange, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      );
}

// ── Local data models ──

class _ProductTierGroup {
  final String productId;
  final String productName;
  final double originalPrice;
  final List<_TierRow> tiers;

  _ProductTierGroup({
    required this.productId,
    required this.productName,
    required this.originalPrice,
    required this.tiers,
  });
}

class _TierRow {
  int minQty;
  int maxQty;
  double price;

  _TierRow({
    required this.minQty,
    required this.maxQty,
    required this.price,
  });
}
