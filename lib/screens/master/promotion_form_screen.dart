import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/promotion/promotion_providers.dart';

class PromotionFormScreen extends ConsumerStatefulWidget {
  final String? promotionId;
  const PromotionFormScreen({super.key, this.promotionId});

  @override
  ConsumerState<PromotionFormScreen> createState() =>
      _PromotionFormScreenState();
}

class _PromotionFormScreenState extends ConsumerState<PromotionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  static const _uuid = Uuid();

  bool get _isEditing => widget.promotionId != null;
  bool _isLoaded = false;
  bool _isSaving = false;

  // Form fields
  final _namaController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _kodeDiskonController = TextEditingController();
  final _nilaiController = TextEditingController();
  final _maxDiskonController = TextEditingController();
  final _minQtyController = TextEditingController(text: '0');
  final _minSubtotalController = TextEditingController(text: '0');
  final _maxUsageController = TextEditingController(text: '0');
  final _priorityController = TextEditingController(text: '0');

  PromotionTipeProgram _tipeProgram = PromotionTipeProgram.otomatis;
  PromotionTipeReward _tipeReward = PromotionTipeReward.diskonPersentase;
  PromotionApplyTo _applyTo = PromotionApplyTo.order;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  List<int> _selectedDays = [];
  bool _isActive = true;
  String? _rewardProductId;
  String? _rewardProductName; // display name for selected free product

  // For product/category selection
  List<String> _selectedProductIds = [];
  List<String> _selectedCategoryIds = [];

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _kodeDiskonController.dispose();
    _nilaiController.dispose();
    _maxDiskonController.dispose();
    _minQtyController.dispose();
    _minSubtotalController.dispose();
    _maxUsageController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (!_isEditing || _isLoaded) return;
    _isLoaded = true;

    final db = ref.read(databaseProvider);
    final promo = await db.promotionDao.getById(widget.promotionId!);
    if (promo == null || !mounted) return;

    setState(() {
      _namaController.text = promo.namaPromo;
      _deskripsiController.text = promo.deskripsi ?? '';
      _tipeProgram = PromotionTipeProgram.fromDb(promo.tipeProgram);
      _kodeDiskonController.text = promo.kodeDiskon ?? '';
      _tipeReward = PromotionTipeReward.fromDb(promo.tipeReward);
      _nilaiController.text = promo.nilaiReward.toString();
      _applyTo = PromotionApplyTo.fromDb(promo.applyTo);
      _maxDiskonController.text =
          promo.maxDiskon != null ? promo.maxDiskon.toString() : '';
      _minQtyController.text = promo.minQty.toString();
      _minSubtotalController.text = promo.minSubtotal.toString();
      _maxUsageController.text = promo.maxUsage.toString();
      _priorityController.text = promo.priority.toString();
      _startDate = promo.startDate;
      _endDate = promo.endDate;
      _isActive = promo.isActive;
      _rewardProductId = promo.rewardProductId;

      // Load reward product name
      if (promo.rewardProductId != null) {
        db.productDao
            .getById(promo.rewardProductId!)
            .then((product) {
          if (product != null && mounted) {
            setState(() => _rewardProductName = product.name);
          }
        });
      }

      if (promo.daysOfWeek.isNotEmpty) {
        try {
          _selectedDays = (jsonDecode(promo.daysOfWeek) as List)
              .map((e) => (e as num).toInt())
              .toList();
        } catch (_) {}
      }

      if (promo.productIds.isNotEmpty) {
        try {
          _selectedProductIds = (jsonDecode(promo.productIds) as List)
              .map((e) => e as String)
              .toList();
        } catch (_) {}
      }

      if (promo.categoryIds.isNotEmpty) {
        try {
          _selectedCategoryIds = (jsonDecode(promo.categoryIds) as List)
              .map((e) => e as String)
              .toList();
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      _loadExisting();
    }

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
          _isEditing ? 'Edit Promosi' : 'Tambah Promosi',
          style: AppTextStyles.heading3,
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: Text(
              'Simpan',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _isSaving ? AppColors.textHint : AppColors.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Nama Promo
            _buildLabel('Nama Promosi'),
            TextFormField(
              controller: _namaController,
              decoration: _inputDecoration('Contoh: Diskon Weekend 10%'),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Deskripsi
            _buildLabel('Deskripsi (opsional)'),
            TextFormField(
              controller: _deskripsiController,
              decoration: _inputDecoration('Deskripsi promosi'),
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),

            // Tipe Program
            _buildLabel('Tipe Program'),
            DropdownButtonFormField<PromotionTipeProgram>(
              value: _tipeProgram,
              decoration: _inputDecoration(''),
              items: PromotionTipeProgram.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _tipeProgram = v!;
                  // Auto-set reward type for Beli X Gratis Y
                  if (v == PromotionTipeProgram.beliXGratisY) {
                    _tipeReward = PromotionTipeReward.produkGratis;
                    if (_nilaiController.text.isEmpty ||
                        _nilaiController.text == '0') {
                      _nilaiController.text = '1';
                    }
                    if (_minQtyController.text == '0') {
                      _minQtyController.text = '2';
                    }
                  }
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Kode Diskon (only for KODE_DISKON)
            if (_tipeProgram == PromotionTipeProgram.kodeDiskon) ...[
              _buildLabel('Kode Diskon'),
              TextFormField(
                controller: _kodeDiskonController,
                decoration: _inputDecoration('Contoh: HEMAT20'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (_tipeProgram == PromotionTipeProgram.kodeDiskon &&
                      (v == null || v.isEmpty)) {
                    return 'Kode wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Tipe Reward
            _buildLabel('Tipe Reward'),
            DropdownButtonFormField<PromotionTipeReward>(
              value: _tipeReward,
              decoration: _inputDecoration(''),
              items: PromotionTipeReward.values
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
                  .toList(),
              onChanged: (v) => setState(() => _tipeReward = v!),
            ),
            const SizedBox(height: AppSpacing.md),

            // Nilai Reward
            _buildLabel(_tipeReward == PromotionTipeReward.produkGratis
                ? 'Jumlah Gratis'
                : 'Nilai Reward'),
            TextFormField(
              controller: _nilaiController,
              decoration: _inputDecoration(
                _tipeReward == PromotionTipeReward.diskonPersentase
                    ? '10'
                    : _tipeReward == PromotionTipeReward.diskonNominal
                        ? '5000'
                        : '1',
              ).copyWith(
                suffixText: _tipeReward == PromotionTipeReward.diskonPersentase
                    ? '%'
                    : null,
                prefixText: _tipeReward == PromotionTipeReward.diskonNominal
                    ? 'Rp '
                    : null,
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if (double.tryParse(v) == null) return 'Angka tidak valid';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Produk Gratis selector (only for PRODUK_GRATIS reward) ──
            if (_tipeReward == PromotionTipeReward.produkGratis) ...[
              _buildLabel('Produk Gratis (Y)'),
              _buildRewardProductSelector(),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppColors.infoBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Produk gratis harus ada di keranjang agar promo berlaku. '
                        'Customer perlu menambahkan produk ini ke keranjang, '
                        'lalu sistem otomatis memberikan diskon 100% untuk produk tersebut.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.infoBlue,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Apply To (only for percentage/nominal)
            if (_tipeReward != PromotionTipeReward.produkGratis) ...[
              _buildLabel('Berlaku Untuk'),
              DropdownButtonFormField<PromotionApplyTo>(
                value: _applyTo,
                decoration: _inputDecoration(''),
                items: PromotionApplyTo.values
                    .map(
                        (e) => DropdownMenuItem(value: e, child: Text(e.label)))
                    .toList(),
                onChanged: (v) => setState(() => _applyTo = v!),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Max Diskon
            if (_tipeReward == PromotionTipeReward.diskonPersentase) ...[
              _buildLabel('Maks Diskon (opsional)'),
              TextFormField(
                controller: _maxDiskonController,
                decoration:
                    _inputDecoration('0 = tanpa batas').copyWith(prefixText: 'Rp '),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text('KONDISI', style: AppTextStyles.labelMedium.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.md),

            // Min Qty
            _buildLabel('Minimum Qty Item'),
            TextFormField(
              controller: _minQtyController,
              decoration: _inputDecoration('0 = tanpa batas'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),

            // Min Subtotal
            _buildLabel('Minimum Subtotal'),
            TextFormField(
              controller: _minSubtotalController,
              decoration:
                  _inputDecoration('0 = tanpa batas').copyWith(prefixText: 'Rp '),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),

            // Product selection
            _buildLabel('Berlaku Untuk Produk'),
            _buildProductSelector(),
            const SizedBox(height: AppSpacing.md),

            // Category selection
            _buildLabel('Berlaku Untuk Kategori'),
            _buildCategorySelector(),
            const SizedBox(height: AppSpacing.md),

            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text('MASA BERLAKU', style: AppTextStyles.labelMedium.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.md),

            // Start Date
            _buildLabel('Tanggal Mulai'),
            _buildDateField(_startDate, (d) => setState(() => _startDate = d)),
            const SizedBox(height: AppSpacing.md),

            // End Date
            _buildLabel('Tanggal Berakhir (opsional)'),
            _buildDateField(
              _endDate,
              (d) => setState(() => _endDate = d),
              allowClear: true,
            ),
            const SizedBox(height: AppSpacing.md),

            // Days of week
            _buildLabel('Hari Berlaku'),
            _buildDaysOfWeekChips(),
            const SizedBox(height: AppSpacing.md),

            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text('LAINNYA', style: AppTextStyles.labelMedium.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: AppSpacing.md),

            // Max Usage
            _buildLabel('Maks Penggunaan'),
            TextFormField(
              controller: _maxUsageController,
              decoration: _inputDecoration('0 = tanpa batas'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),

            // Priority
            _buildLabel('Prioritas'),
            TextFormField(
              controller: _priorityController,
              decoration: _inputDecoration('Semakin tinggi semakin duluan'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),

            // Active toggle
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: Text('Aktif', style: AppTextStyles.bodyMedium),
              activeColor: AppColors.primaryOrange,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text,
          style: AppTextStyles.labelMedium
              .copyWith(color: AppColors.textSecondary)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
      filled: true,
      fillColor: AppColors.surfaceGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildDateField(DateTime? date, ValueChanged<DateTime> onPick,
      {bool allowClear = false}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                date != null
                    ? Formatters.date(date)
                    : 'Pilih tanggal',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: date != null
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                ),
              ),
            ),
            if (allowClear && date != null)
              GestureDetector(
                onTap: () => setState(() => _endDate = null),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textHint),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysOfWeekChips() {
    const days = [
      {'label': 'Sen', 'value': 1},
      {'label': 'Sel', 'value': 2},
      {'label': 'Rab', 'value': 3},
      {'label': 'Kam', 'value': 4},
      {'label': 'Jum', 'value': 5},
      {'label': 'Sab', 'value': 6},
      {'label': 'Min', 'value': 7},
    ];

    return Wrap(
      spacing: 8,
      children: days.map((d) {
        final value = d['value'] as int;
        final selected = _selectedDays.contains(value);
        return FilterChip(
          label: Text(d['label'] as String),
          selected: selected,
          onSelected: (v) {
            setState(() {
              if (v) {
                _selectedDays.add(value);
              } else {
                _selectedDays.remove(value);
              }
            });
          },
          selectedColor: AppColors.primaryOrange.withOpacity(0.2),
          checkmarkColor: AppColors.primaryOrange,
          labelStyle: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.primaryOrange : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductSelector() {
    return InkWell(
      onTap: () => _showProductPickerDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedProductIds.isEmpty
                    ? 'Semua produk'
                    : '${_selectedProductIds.length} produk dipilih',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _selectedProductIds.isEmpty
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (_selectedProductIds.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _selectedProductIds.clear()),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textHint),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.inventory_2_outlined,
                size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return InkWell(
      onTap: () => _showCategoryPickerDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedCategoryIds.isEmpty
                    ? 'Semua kategori'
                    : '${_selectedCategoryIds.length} kategori dipilih',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _selectedCategoryIds.isEmpty
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                ),
              ),
            ),
            if (_selectedCategoryIds.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _selectedCategoryIds.clear()),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textHint),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.category_outlined,
                size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Future<void> _showProductPickerDialog() async {
    final db = ref.read(databaseProvider);
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;

    final products = await db.productDao.getAllByStore(storeId);
    final selected = Set<String>.from(_selectedProductIds);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Pilih Produk', style: AppTextStyles.heading3),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: products.length,
              itemBuilder: (_, i) {
                final p = products[i];
                return CheckboxListTile(
                  value: selected.contains(p.id),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v == true) {
                        selected.add(p.id);
                      } else {
                        selected.remove(p.id);
                      }
                    });
                  },
                  title: Text(p.name, style: AppTextStyles.bodyMedium),
                  subtitle: Text(Formatters.currency(p.price),
                      style: AppTextStyles.caption),
                  activeColor: AppColors.primaryOrange,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
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
              onPressed: () {
                setState(() => _selectedProductIds = selected.toList());
                Navigator.pop(ctx);
              },
              child: Text('OK',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.primaryOrange)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryPickerDialog() async {
    final db = ref.read(databaseProvider);
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;

    final categories = await db.categoryDao.getAllByStore(storeId);
    final selected = Set<String>.from(_selectedCategoryIds);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Pilih Kategori', style: AppTextStyles.heading3),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (_, i) {
                final c = categories[i];
                return CheckboxListTile(
                  value: selected.contains(c.id),
                  onChanged: (v) {
                    setDialogState(() {
                      if (v == true) {
                        selected.add(c.id);
                      } else {
                        selected.remove(c.id);
                      }
                    });
                  },
                  title: Text(c.name, style: AppTextStyles.bodyMedium),
                  activeColor: AppColors.primaryOrange,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
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
              onPressed: () {
                setState(() => _selectedCategoryIds = selected.toList());
                Navigator.pop(ctx);
              },
              child: Text('OK',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.primaryOrange)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardProductSelector() {
    return InkWell(
      onTap: () => _showRewardProductPickerDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
          border: _rewardProductId == null
              ? Border.all(color: AppColors.warningAmber.withOpacity(0.5))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              _rewardProductId != null
                  ? Icons.card_giftcard_rounded
                  : Icons.add_circle_outline_rounded,
              size: 20,
              color: _rewardProductId != null
                  ? AppColors.successGreen
                  : AppColors.warningAmber,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _rewardProductId != null
                        ? _rewardProductName ?? 'Produk dipilih'
                        : 'Pilih produk gratis *',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _rewardProductId != null
                          ? AppColors.textPrimary
                          : AppColors.warningAmber,
                      fontWeight: _rewardProductId != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (_rewardProductId != null)
                    Text(
                      'Produk ini akan gratis saat promo aktif',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.successGreen,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            if (_rewardProductId != null)
              GestureDetector(
                onTap: () => setState(() {
                  _rewardProductId = null;
                  _rewardProductName = null;
                }),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textHint),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Future<void> _showRewardProductPickerDialog() async {
    final db = ref.read(databaseProvider);
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;

    final products = await db.productDao.getAllByStore(storeId);
    if (!mounted) return;

    String searchQuery = '';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = searchQuery.isEmpty
              ? products
              : products
                  .where((p) =>
                      p.name.toLowerCase().contains(searchQuery.toLowerCase()))
                  .toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text('Pilih Produk Gratis', style: AppTextStyles.heading3),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
              child: Column(
                children: [
                  // Search
                  TextField(
                    onChanged: (v) =>
                        setDialogState(() => searchQuery = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Cari produk...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: AppColors.surfaceGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        final isSelected = _rewardProductId == p.id;
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.successGreen.withOpacity(0.1)
                                  : AppColors.surfaceGrey,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.inventory_2_outlined,
                              color: isSelected
                                  ? AppColors.successGreen
                                  : AppColors.textHint,
                              size: 20,
                            ),
                          ),
                          title: Text(p.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.normal)),
                          subtitle: Text(Formatters.currency(p.price),
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryOrange)),
                          onTap: () {
                            setState(() {
                              _rewardProductId = p.id;
                              _rewardProductName = p.name;
                            });
                            Navigator.pop(ctx);
                          },
                          dense: true,
                          selected: isSelected,
                        );
                      },
                    ),
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
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate free product selection
    if (_tipeReward == PromotionTipeReward.produkGratis &&
        _rewardProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih produk gratis terlebih dahulu'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final storeId = ref.read(currentStoreIdProvider);
      if (storeId == null) throw Exception('Store not found');

      final id = _isEditing ? widget.promotionId! : _uuid.v4();
      final nilaiReward = double.tryParse(_nilaiController.text) ?? 0;
      final maxDiskon = double.tryParse(_maxDiskonController.text);
      final minQty = int.tryParse(_minQtyController.text) ?? 0;
      final minSubtotal = double.tryParse(_minSubtotalController.text) ?? 0;
      final maxUsage = int.tryParse(_maxUsageController.text) ?? 0;
      final priority = int.tryParse(_priorityController.text) ?? 0;

      final entry = PromotionsCompanion(
        id: drift.Value(id),
        storeId: drift.Value(storeId),
        namaPromo: drift.Value(_namaController.text.trim()),
        deskripsi: drift.Value(_deskripsiController.text.trim().isNotEmpty
            ? _deskripsiController.text.trim()
            : null),
        tipeProgram: drift.Value(_tipeProgram.dbValue),
        kodeDiskon: drift.Value(
            _tipeProgram == PromotionTipeProgram.kodeDiskon
                ? _kodeDiskonController.text.trim().toUpperCase()
                : null),
        tipeReward: drift.Value(_tipeReward.dbValue),
        nilaiReward: drift.Value(nilaiReward),
        rewardProductId: drift.Value(_rewardProductId),
        applyTo: drift.Value(_applyTo.dbValue),
        maxDiskon: drift.Value(
            maxDiskon != null && maxDiskon > 0 ? maxDiskon : null),
        minQty: drift.Value(minQty),
        minSubtotal: drift.Value(minSubtotal),
        productIds: drift.Value(_selectedProductIds.isNotEmpty
            ? jsonEncode(_selectedProductIds)
            : ''),
        categoryIds: drift.Value(_selectedCategoryIds.isNotEmpty
            ? jsonEncode(_selectedCategoryIds)
            : ''),
        startDate: drift.Value(_startDate),
        endDate: drift.Value(_endDate),
        daysOfWeek: drift.Value(
            _selectedDays.isNotEmpty ? jsonEncode(_selectedDays) : ''),
        maxUsage: drift.Value(maxUsage),
        priority: drift.Value(priority),
        isActive: drift.Value(_isActive),
      );

      final db = ref.read(databaseProvider);
      if (_isEditing) {
        await db.promotionDao.updatePromotion(entry);
      } else {
        await db.promotionDao.insertPromotion(entry);
      }

      ref.invalidate(promotionsProvider);
      ref.invalidate(activePromotionsProvider);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
