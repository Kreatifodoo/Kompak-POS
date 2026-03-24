import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../models/enums.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/charge/charge_providers.dart';

class ChargeFormScreen extends ConsumerStatefulWidget {
  final String? chargeId;
  const ChargeFormScreen({super.key, this.chargeId});

  @override
  ConsumerState<ChargeFormScreen> createState() => _ChargeFormScreenState();
}

class _ChargeFormScreenState extends ConsumerState<ChargeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nilaiController = TextEditingController();
  final _urutanController = TextEditingController();

  ChargeKategori _kategori = ChargeKategori.pajak;
  ChargeTipe _tipe = ChargeTipe.persentase;
  ChargeIncludeBase _includeBase = ChargeIncludeBase.subtotal;
  bool _isActive = true;
  bool _isLoaded = false;
  bool _isSaving = false;

  bool get _isEditing => widget.chargeId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _nilaiController.dispose();
    _urutanController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    if (_isLoaded || !_isEditing) return;
    _isLoaded = true;

    final svc = ref.read(chargeServiceProvider);
    final charge = await svc.getById(widget.chargeId!);
    if (charge == null) return;

    _nameController.text = charge.namaBiaya;
    _nilaiController.text = charge.nilai.toStringAsFixed(
        charge.nilai.truncateToDouble() == charge.nilai ? 0 : 2);
    _urutanController.text = charge.urutan.toString();
    _kategori = ChargeKategori.fromDb(charge.kategori);
    _tipe = ChargeTipe.fromDb(charge.tipe);
    _includeBase = ChargeIncludeBase.fromDb(charge.includeBase);
    _isActive = charge.isActive;

    if (mounted) setState(() {});
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
          _isEditing ? 'Edit Biaya' : 'Tambah Biaya',
          style: AppTextStyles.heading3,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Nama Biaya
            _buildLabel('Nama Biaya'),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('e.g. PPN 11%'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Nama biaya wajib diisi' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Kategori
            _buildLabel('Kategori'),
            DropdownButtonFormField<ChargeKategori>(
              value: _kategori,
              decoration: _inputDecoration(''),
              items: ChargeKategori.values
                  .map((k) => DropdownMenuItem(
                        value: k,
                        child: Row(
                          children: [
                            Icon(_kategoriIcon(k),
                                size: 18, color: _kategoriColor(k)),
                            const SizedBox(width: 8),
                            Text(k.label),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _kategori = v);
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Tipe + Nilai (side by side)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Tipe'),
                      DropdownButtonFormField<ChargeTipe>(
                        value: _tipe,
                        decoration: _inputDecoration(''),
                        items: ChargeTipe.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.label,
                                      style: AppTextStyles.bodyMedium),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _tipe = v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Nilai'),
                      TextFormField(
                        controller: _nilaiController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: _inputDecoration(
                          _tipe == ChargeTipe.persentase ? 'e.g. 11' : 'e.g. 5000',
                        ).copyWith(
                          suffixText: _tipe == ChargeTipe.persentase ? '%' : null,
                          prefixText: _tipe == ChargeTipe.nominal ? 'Rp ' : null,
                          prefixStyle: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Wajib diisi';
                          if (double.tryParse(v) == null) return 'Angka invalid';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Urutan
            _buildLabel('Urutan Perhitungan'),
            TextFormField(
              controller: _urutanController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('e.g. 1').copyWith(
                helperText: 'Urutan kecil dihitung terlebih dahulu',
                helperStyle: AppTextStyles.caption
                    .copyWith(color: AppColors.textHint),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Wajib diisi';
                if (int.tryParse(v) == null) return 'Angka integer';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Include Base
            _buildLabel('Basis Perhitungan'),
            DropdownButtonFormField<ChargeIncludeBase>(
              value: _includeBase,
              decoration: _inputDecoration(''),
              items: ChargeIncludeBase.values
                  .map((b) => DropdownMenuItem(
                        value: b,
                        child: Text(b.label, style: AppTextStyles.bodyMedium),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _includeBase = v);
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Active toggle
            SwitchListTile(
              title: Text('Aktif', style: AppTextStyles.bodyMedium),
              value: _isActive,
              activeColor: AppColors.primaryOrange,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _isActive = v),
            ),

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
                        _isEditing ? 'Simpan Perubahan' : 'Tambah Biaya',
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final svc = ref.read(chargeServiceProvider);
      final storeId = ref.read(currentStoreIdProvider) ?? '';
      final nilai = double.parse(_nilaiController.text.trim());
      final urutan = int.parse(_urutanController.text.trim());

      if (_isEditing) {
        await svc.updateCharge(
          id: widget.chargeId!,
          namaBiaya: _nameController.text.trim(),
          kategori: _kategori.dbValue,
          tipe: _tipe.dbValue,
          nilai: nilai,
          urutan: urutan,
          isActive: _isActive,
          includeBase: _includeBase.dbValue,
        );
      } else {
        await svc.createCharge(
          storeId: storeId,
          namaBiaya: _nameController.text.trim(),
          kategori: _kategori.dbValue,
          tipe: _tipe.dbValue,
          nilai: nilai,
          urutan: urutan,
          includeBase: _includeBase.dbValue,
        );
      }

      ref.invalidate(chargesProvider);
      ref.invalidate(activeChargesProvider);

      if (mounted) {
        context.showSnackBar(
            _isEditing ? 'Biaya diperbarui' : 'Biaya ditambahkan');
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

  IconData _kategoriIcon(ChargeKategori k) => switch (k) {
        ChargeKategori.pajak => Icons.account_balance_rounded,
        ChargeKategori.layanan => Icons.room_service_rounded,
        ChargeKategori.potongan => Icons.discount_rounded,
      };

  Color _kategoriColor(ChargeKategori k) => switch (k) {
        ChargeKategori.pajak => AppColors.infoBlue,
        ChargeKategori.layanan => AppColors.warningAmber,
        ChargeKategori.potongan => AppColors.discountRed,
      };

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
