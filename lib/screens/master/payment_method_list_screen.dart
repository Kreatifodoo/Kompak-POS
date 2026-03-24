import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';

class PaymentMethodListScreen extends ConsumerStatefulWidget {
  const PaymentMethodListScreen({super.key});

  @override
  ConsumerState<PaymentMethodListScreen> createState() =>
      _PaymentMethodListScreenState();
}

class _PaymentMethodListScreenState
    extends ConsumerState<PaymentMethodListScreen> {
  List<dynamic> _methods = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final storeId = ref.read(currentStoreIdProvider);
      if (storeId == null) {
        setState(() {
          _error = 'No store selected';
          _isLoading = false;
        });
        return;
      }

      final service = ref.read(paymentMethodServiceProvider);
      final methods = await service.getAllByStore(storeId);
      setState(() {
        _methods = methods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load payment methods';
        _isLoading = false;
      });
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'cash':
        return Icons.attach_money;
      case 'card':
        return Icons.credit_card;
      case 'qris':
        return Icons.qr_code;
      case 'transfer':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  String _labelForType(String type) {
    switch (type) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'Transfer';
      default:
        return type.capitalize;
    }
  }

  Future<void> _deleteMethod(dynamic method) async {
    final activeCount =
        _methods.where((m) => m.isActive as bool).length;

    if (method.isActive && activeCount <= 1) {
      if (!mounted) return;
      context.showSnackBar(
        'Cannot delete the last active payment method',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Payment Method',
          style: AppTextStyles.heading3,
        ),
        content: Text(
          'Are you sure you want to delete "${method.name}"? This action cannot be undone.',
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

    try {
      final service = ref.read(paymentMethodServiceProvider);
      await service.deletePaymentMethod(method.id as String);
      if (!mounted) return;
      context.showSnackBar('Payment method deleted');
      _loadMethods();
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('Failed to delete payment method', isError: true);
    }
  }

  Future<void> _navigateToForm({String? methodId}) async {
    final route = methodId != null
        ? '/settings/payment-methods/$methodId/edit'
        : '/settings/payment-methods/new';
    await context.push(route);
    _loadMethods();
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
          'Payment Methods',
          style: AppTextStyles.heading3,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _navigateToForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.errorRed),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _loadMethods,
              child: Text(
                'Retry',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
    }

    if (_methods.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadMethods,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _methods.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final method = _methods[index];
          return _buildMethodTile(method);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment_outlined,
            size: 80,
            color: AppColors.textHint.withOpacity(0.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No payment methods',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tap + to add your first payment method',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTile(dynamic method) {
    final type = method.type as String;
    final isActive = method.isActive as bool;

    return Slidable(
      key: ValueKey(method.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _deleteMethod(method),
            backgroundColor: AppColors.errorRed,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => _navigateToForm(methodId: method.id as String),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    _iconForType(type),
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Name and type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name as String,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGrey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _labelForType(type),
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Active status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.successGreen.withOpacity(0.1)
                      : AppColors.textHint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: AppTextStyles.caption.copyWith(
                    color:
                        isActive ? AppColors.successGreen : AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
