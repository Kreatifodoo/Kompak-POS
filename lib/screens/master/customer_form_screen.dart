import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/validators.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/formatters.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/orders/order_providers.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final String? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingData = false;
  Customer? _existingCustomer;

  bool get _isEditing => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadCustomer();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    setState(() => _isLoadingData = true);
    try {
      final service = ref.read(customerServiceProvider);
      final customer = await service.getById(widget.customerId!);
      if (customer != null && mounted) {
        setState(() {
          _existingCustomer = customer;
          _nameController.text = customer.name;
          _phoneController.text = customer.phone ?? '';
          _emailController.text = customer.email ?? '';
          _isLoadingData = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingData = false);
        context.showSnackBar('Customer not found', isError: true);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        context.showSnackBar('Error loading customer', isError: true);
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Customer' : 'Add Customer',
          style: AppTextStyles.heading3,
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text('Name *', style: AppTextStyles.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _nameController,
                      validator: (v) => Validators.required(v, 'Name'),
                      decoration: const InputDecoration(
                        hintText: 'Customer name',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Phone
                    Text('Phone', style: AppTextStyles.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _phoneController,
                      validator: Validators.phone,
                      decoration: const InputDecoration(
                        hintText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Email
                    Text('Email', style: AppTextStyles.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _emailController,
                      validator: Validators.email,
                      decoration: const InputDecoration(
                        hintText: 'Email address',
                        prefixIcon: Icon(Icons.email_rounded),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),

                    // Points (read-only in edit mode)
                    if (_isEditing && _existingCustomer != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Points', style: AppTextStyles.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star_rounded, color: AppColors.warningAmber, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${_existingCustomer!.points} points',
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Transaction history (edit mode)
                    if (_isEditing && _existingCustomer != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Riwayat Transaksi',
                          style: AppTextStyles.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      _buildTransactionHistory(),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditing ? 'Update Customer' : 'Add Customer',
                                style: AppTextStyles.buttonText,
                              ),
                      ),
                    ),

                    // Delete button (edit mode)
                    if (_isEditing) ...[
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _delete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.errorRed,
                            side: const BorderSide(color: AppColors.errorRed),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Delete Customer',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.errorRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTransactionHistory() {
    final ordersAsync =
        ref.watch(customerOrdersProvider(widget.customerId!));

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 36,
                    color: AppColors.textHint.withOpacity(0.4)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Belum ada transaksi',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textHint),
                ),
              ],
            ),
          );
        }

        final totalSpent =
            orders.fold<double>(0, (sum, o) => sum + o.total);

        return Column(
          children: [
            // Summary row
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryOrange.withOpacity(0.15),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${orders.length}',
                          style: AppTextStyles.heading3.copyWith(
                            color: AppColors.primaryOrange,
                          ),
                        ),
                        Text('Total Order',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: AppColors.primaryOrange.withOpacity(0.15),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          Formatters.currency(totalSpent),
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                        Text('Total Belanja',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Order list (show last 10)
            ...orders.take(10).map((order) => Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_rounded,
                            color: AppColors.successGreen, size: 18),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.orderNumber,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.dateTime(order.createdAt),
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.currency(order.total),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ],
                  ),
                )),
            if (orders.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'dan ${orders.length - 10} transaksi lainnya...',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textHint),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Gagal memuat riwayat transaksi',
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.errorRed),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(customerServiceProvider);
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
      final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();

      if (_isEditing) {
        await service.updateCustomer(
          id: widget.customerId!,
          storeId: storeId,
          name: name,
          phone: phone,
          email: email,
          points: _existingCustomer?.points ?? 0,
        );
        if (mounted) context.showSnackBar('Customer updated');
      } else {
        await service.createCustomer(
          storeId: storeId,
          name: name,
          phone: phone,
          email: email,
        );
        if (mounted) context.showSnackBar('Customer added');
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete "${_existingCustomer?.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(customerServiceProvider);
      await service.deleteCustomer(widget.customerId!);
      if (mounted) {
        context.showSnackBar('Customer deleted');
        context.pop();
      }
    } catch (e) {
      if (mounted) context.showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
