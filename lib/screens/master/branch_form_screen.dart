import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/validators.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';

class BranchFormScreen extends ConsumerStatefulWidget {
  final String? branchId;
  const BranchFormScreen({super.key, this.branchId});

  bool get isEditing => branchId != null;

  @override
  ConsumerState<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends ConsumerState<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _taxRateController;
  late TextEditingController _currencyController;
  late TextEditingController _receiptHeaderController;
  late TextEditingController _receiptFooterController;
  bool _isSaving = false;
  bool _isLoading = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _taxRateController = TextEditingController(text: '11');
    _currencyController = TextEditingController(text: 'Rp');
    _receiptHeaderController = TextEditingController();
    _receiptFooterController = TextEditingController();
    if (widget.isEditing) {
      _loadBranch();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _taxRateController.dispose();
    _currencyController.dispose();
    _receiptHeaderController.dispose();
    _receiptFooterController.dispose();
    super.dispose();
  }

  Future<void> _loadBranch() async {
    if (_isLoaded) return;
    setState(() => _isLoading = true);

    try {
      final service = ref.read(storeServiceProvider);
      final branch = await service.getById(widget.branchId!);
      if (branch != null && mounted) {
        setState(() {
          _nameController.text = branch.name;
          _addressController.text = branch.address ?? '';
          _phoneController.text = branch.phone ?? '';
          _taxRateController.text = (branch.taxRate * 100).toStringAsFixed(0);
          _currencyController.text = branch.currencySymbol;
          _receiptHeaderController.text = branch.receiptHeader ?? '';
          _receiptFooterController.text = branch.receiptFooter ?? '';
          _isLoaded = true;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
        context.showSnackBar('Cabang tidak ditemukan', isError: true);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showSnackBar('Gagal memuat cabang: $e', isError: true);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) {
      context.showSnackBar('No store selected', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(storeServiceProvider);
      final name = _nameController.text.trim();
      final address = _addressController.text.trim();
      final phone = _phoneController.text.trim();
      final taxRate = (double.tryParse(_taxRateController.text) ?? 11) / 100;
      final currency = _currencyController.text.trim();
      final header = _receiptHeaderController.text.trim();
      final footer = _receiptFooterController.text.trim();

      if (widget.isEditing) {
        await service.updateBranch(
          id: widget.branchId!,
          name: name,
          parentId: storeId,
          address: address.isEmpty ? null : address,
          phone: phone.isEmpty ? null : phone,
          taxRate: taxRate,
          currencySymbol: currency,
          receiptHeader: header.isEmpty ? null : header,
          receiptFooter: footer.isEmpty ? null : footer,
        );
      } else {
        await service.createBranch(
          parentId: storeId,
          name: name,
          address: address.isEmpty ? null : address,
          phone: phone.isEmpty ? null : phone,
          taxRate: taxRate,
          currencySymbol: currency,
          receiptHeader: header.isEmpty ? null : header,
          receiptFooter: footer.isEmpty ? null : footer,
        );
      }

      if (mounted) {
        context.showSnackBar(
          widget.isEditing ? 'Cabang diperbarui' : 'Cabang dibuat',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Gagal menyimpan cabang: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Cabang', style: AppTextStyles.heading3),
        content: Text(
          'Yakin ingin menghapus cabang "${_nameController.text}"?\n\nSemua data cabang (terminal, produk, inventory, dll) akan hilang.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.errorRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(storeServiceProvider);
      await service.deleteBranch(widget.branchId!);
      if (mounted) {
        context.showSnackBar('Cabang dihapus');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Gagal menghapus: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          widget.isEditing ? 'Edit Cabang' : 'Tambah Cabang',
          style: AppTextStyles.heading3,
        ),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.errorRed),
              onPressed: _delete,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Name field
                  _buildLabel('Nama Cabang'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'contoh: Cabang Kemang',
                    icon: Icons.store_mall_directory_rounded,
                    validator: (v) => Validators.required(v, 'Nama'),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Address field
                  _buildLabel('Alamat'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTextField(
                    controller: _addressController,
                    hint: 'Jl. Kemang Raya No. 10',
                    icon: Icons.location_on_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Phone field
                  _buildLabel('Telepon'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTextField(
                    controller: _phoneController,
                    hint: '021-12345678',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Tax rate
                  _buildLabel('Tarif Pajak (%)'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTextField(
                    controller: _taxRateController,
                    hint: '11',
                    icon: Icons.receipt_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Currency symbol
                  _buildLabel('Simbol Mata Uang'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTextField(
                    controller: _currencyController,
                    hint: 'Rp',
                    icon: Icons.attach_money_rounded,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Receipt header
                  _buildLabel('Header Receipt'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTextField(
                    controller: _receiptHeaderController,
                    hint: 'Text yang muncul di atas receipt',
                    icon: Icons.text_fields_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Receipt footer
                  _buildLabel('Footer Receipt'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTextField(
                    controller: _receiptFooterController,
                    hint: 'Text yang muncul di bawah receipt',
                    icon: Icons.text_fields_rounded,
                    maxLines: 2,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'Simpan Perubahan'
                                  : 'Buat Cabang',
                              style: AppTextStyles.buttonText,
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style:
            AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon:
            Icon(icon, color: AppColors.textSecondary, size: 20),
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
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
      ),
    );
  }
}
