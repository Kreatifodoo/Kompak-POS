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

class PaymentMethodFormScreen extends ConsumerStatefulWidget {
  final String? paymentMethodId;

  const PaymentMethodFormScreen({
    super.key,
    this.paymentMethodId,
  });

  @override
  ConsumerState<PaymentMethodFormScreen> createState() =>
      _PaymentMethodFormScreenState();
}

class _PaymentMethodFormScreenState
    extends ConsumerState<PaymentMethodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'cash';
  bool _isLoading = false;
  bool _isLoadingData = false;

  bool get _isEditMode => widget.paymentMethodId != null;

  static const _typeOptions = [
    {'value': 'cash', 'label': 'Cash'},
    {'value': 'card', 'label': 'Card'},
    {'value': 'qris', 'label': 'QRIS'},
    {'value': 'transfer', 'label': 'Transfer'},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadPaymentMethod();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentMethod() async {
    setState(() => _isLoadingData = true);

    try {
      final service = ref.read(paymentMethodServiceProvider);
      final method = await service.getById(widget.paymentMethodId!);

      if (method == null) {
        if (!mounted) return;
        context.showSnackBar('Payment method not found', isError: true);
        context.pop();
        return;
      }

      _nameController.text = method.name;
      _descriptionController.text = method.description ?? '';
      setState(() {
        _selectedType = method.type;
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('Failed to load payment method', isError: true);
      context.pop();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) {
      context.showSnackBar('No store selected', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(paymentMethodServiceProvider);
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      if (_isEditMode) {
        await service.updatePaymentMethod(
          id: widget.paymentMethodId!,
          storeId: storeId,
          name: name,
          type: _selectedType,
          description: description.isEmpty ? null : description,
        );
      } else {
        await service.createPaymentMethod(
          storeId: storeId,
          name: name,
          type: _selectedType,
          description: description.isEmpty ? null : description,
        );
      }

      if (!mounted) return;
      context.showSnackBar(
        _isEditMode
            ? 'Payment method updated'
            : 'Payment method created',
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('Failed to save payment method', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Payment Method',
          style: AppTextStyles.heading3,
        ),
        content: Text(
          'Are you sure you want to delete this payment method? This action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(paymentMethodServiceProvider);
      await service.deletePaymentMethod(widget.paymentMethodId!);
      if (!mounted) return;
      context.showSnackBar('Payment method deleted');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('Failed to delete payment method', isError: true);
      setState(() => _isLoading = false);
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
          _isEditMode ? 'Edit Payment Method' : 'Add Payment Method',
          style: AppTextStyles.heading3,
        ),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.errorRed),
              onPressed: _isLoading ? null : _delete,
            ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Name field
                    Text(
                      'Name *',
                      style: AppTextStyles.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _nameController,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'e.g. Cash, Debit Card, QRIS',
                        hintStyle: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textHint),
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
                          borderSide:
                              const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                      ),
                      validator: (value) =>
                          Validators.required(value, 'Name'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Type field
                    Text(
                      'Type *',
                      style: AppTextStyles.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
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
                          borderSide:
                              const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                      ),
                      items: _typeOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option['value'],
                              child: Text(option['label']!),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedType = value);
                        }
                      },
                      validator: (value) =>
                          value == null ? 'Type is required' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Description field
                    Text(
                      'Description',
                      style: AppTextStyles.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _descriptionController,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Optional description',
                        hintStyle: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textHint),
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
                          borderSide:
                              const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Save button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditMode ? 'Update' : 'Save',
                                style: AppTextStyles.buttonText,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
