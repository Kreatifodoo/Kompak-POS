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
import '../../modules/terminal/terminal_providers.dart';

class TerminalFormScreen extends ConsumerStatefulWidget {
  final String? terminalId;
  const TerminalFormScreen({super.key, this.terminalId});

  bool get isEditing => terminalId != null;

  @override
  ConsumerState<TerminalFormScreen> createState() => _TerminalFormScreenState();
}

class _TerminalFormScreenState extends ConsumerState<TerminalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isLoading = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _codeController = TextEditingController();
    if (widget.isEditing) {
      _loadTerminal();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadTerminal() async {
    if (_isLoaded) return;
    setState(() => _isLoading = true);

    try {
      final service = ref.read(terminalServiceProvider);
      final terminal = await service.getById(widget.terminalId!);
      if (terminal != null && mounted) {
        setState(() {
          _nameController.text = terminal.name;
          _codeController.text = terminal.code;
          _isActive = terminal.isActive;
          _isLoaded = true;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
        context.showSnackBar('Terminal tidak ditemukan', isError: true);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showSnackBar('Gagal memuat terminal: $e', isError: true);
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
      final service = ref.read(terminalServiceProvider);
      final name = _nameController.text.trim();
      final code = _codeController.text.trim();

      if (widget.isEditing) {
        await service.updateTerminal(
          id: widget.terminalId!,
          storeId: storeId,
          name: name,
          code: code,
          isActive: _isActive,
        );
      } else {
        await service.createTerminal(
          storeId: storeId,
          name: name,
          code: code,
        );
      }

      // Invalidate terminals provider
      ref.invalidate(terminalsProvider(storeId));

      if (mounted) {
        context.showSnackBar(
          widget.isEditing ? 'Terminal diperbarui' : 'Terminal dibuat',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Gagal menyimpan terminal: $e', isError: true);
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
        title: Text('Hapus Terminal', style: AppTextStyles.heading3),
        content: Text(
          'Yakin ingin menghapus terminal "${_nameController.text}"?',
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
      final service = ref.read(terminalServiceProvider);
      await service.deleteTerminal(widget.terminalId!);
      final storeId = ref.read(currentStoreIdProvider);
      if (storeId != null) ref.invalidate(terminalsProvider(storeId));
      if (mounted) {
        context.showSnackBar('Terminal dihapus');
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
          widget.isEditing ? 'Edit Terminal' : 'Tambah Terminal',
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
                  Text('Nama Terminal',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _nameController,
                    validator: (v) => Validators.required(v, 'Nama'),
                    decoration: InputDecoration(
                      hintText: 'contoh: Kasir 1',
                      prefixIcon: const Icon(Icons.point_of_sale_rounded,
                          color: AppColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderGrey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderGrey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primaryOrange, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.md),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Code field
                  Text('Kode Terminal',
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _codeController,
                    validator: (v) => Validators.required(v, 'Kode'),
                    decoration: InputDecoration(
                      hintText: 'contoh: T-001',
                      prefixIcon: const Icon(Icons.tag_rounded,
                          color: AppColors.textSecondary, size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderGrey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderGrey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primaryOrange, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.md),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Active toggle (only in edit mode)
                  if (widget.isEditing) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderGrey),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.power_settings_new_rounded,
                              color: _isActive
                                  ? AppColors.successGreen
                                  : AppColors.textHint,
                              size: 24),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status Terminal',
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(fontWeight: FontWeight.w600)),
                                Text(
                                  _isActive
                                      ? 'Terminal aktif dan bisa digunakan'
                                      : 'Terminal nonaktif',
                                  style: AppTextStyles.caption
                                      .copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isActive,
                            activeColor: AppColors.primaryOrange,
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Printer info (read-only in edit mode)
                  if (widget.isEditing) ...[
                    FutureBuilder(
                      future: ref
                          .read(terminalServiceProvider)
                          .getById(widget.terminalId!),
                      builder: (context, snapshot) {
                        final terminal = snapshot.data;
                        if (terminal == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderGrey),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                terminal.printerName != null
                                    ? Icons.print_rounded
                                    : Icons.print_disabled_rounded,
                                color: terminal.printerName != null
                                    ? AppColors.successGreen
                                    : AppColors.textHint,
                                size: 24,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Printer',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                                fontWeight: FontWeight.w600)),
                                    Text(
                                      terminal.printerName ??
                                          'Belum di-setup. Atur di menu Printer Settings.',
                                      style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  const SizedBox(height: AppSpacing.lg),

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
                              widget.isEditing ? 'Simpan Perubahan' : 'Buat Terminal',
                              style: AppTextStyles.buttonText,
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
