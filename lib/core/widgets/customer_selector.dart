import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/formatters.dart';
import '../../modules/core_providers.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/customer/customer_providers.dart';
import '../../modules/pos/cart_providers.dart';
import '../../modules/orders/order_providers.dart';

/// Customer selector bar shown above cart items.
/// Shared between mobile CartScreen and web CartPanel.
class CustomerSelector extends ConsumerStatefulWidget {
  /// If true, uses compact layout for web cart panel
  final bool compact;

  const CustomerSelector({super.key, this.compact = false});

  @override
  ConsumerState<CustomerSelector> createState() => _CustomerSelectorState();
}

class _CustomerSelectorState extends ConsumerState<CustomerSelector> {
  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final customerId = cart.customerId;

    if (customerId != null) {
      return _buildSelectedCustomer(customerId);
    }
    return _buildSelectButton();
  }

  Widget _buildSelectButton() {
    return InkWell(
      onTap: () => _showCustomerPicker(),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: widget.compact ? 8 : AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryOrange.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.2),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded,
                size: widget.compact ? 18 : 20,
                color: AppColors.primaryOrange),
            SizedBox(width: widget.compact ? 6 : AppSpacing.sm),
            Expanded(
              child: Text(
                'Pilih Customer',
                style: (widget.compact
                        ? AppTextStyles.caption
                        : AppTextStyles.bodySmall)
                    .copyWith(
                  color: AppColors.primaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: widget.compact ? 12 : 14,
                color: AppColors.primaryOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedCustomer(String customerId) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));

    return customerAsync.when(
      data: (customer) {
        if (customer == null) {
          // Customer deleted, clear selection
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(cartProvider.notifier).clearCustomer();
          });
          return _buildSelectButton();
        }
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: widget.compact ? 6 : AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.successGreen.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.successGreen.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: widget.compact ? 28 : 32,
                height: widget.compact ? 28 : 32,
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.person_rounded,
                    size: widget.compact ? 16 : 18,
                    color: AppColors.successGreen),
              ),
              SizedBox(width: widget.compact ? 6 : AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer.name,
                      style: (widget.compact
                              ? AppTextStyles.caption
                              : AppTextStyles.bodySmall)
                          .copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customer.phone != null &&
                        customer.phone!.isNotEmpty) ...[
                      Text(
                        customer.phone!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textHint,
                          fontSize: widget.compact ? 10 : 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // History button
              InkWell(
                onTap: () => _showCustomerHistory(customer),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.history_rounded,
                      size: widget.compact ? 18 : 20,
                      color: AppColors.infoBlue),
                ),
              ),
              const SizedBox(width: 2),
              // Remove button
              InkWell(
                onTap: () => ref.read(cartProvider.notifier).clearCustomer(),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      size: widget.compact ? 16 : 18,
                      color: AppColors.errorRed),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => _buildSelectButton(),
    );
  }

  void _showCustomerPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomerPickerSheet(),
    );
  }

  void _showCustomerHistory(Customer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerHistorySheet(customer: customer),
    );
  }
}

// --------------- Customer Picker Bottom Sheet ---------------

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  List<Customer> _results = [];
  bool _isLoading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomers([String query = '']) async {
    final storeId = ref.read(currentStoreIdProvider);
    if (storeId == null) return;
    setState(() => _isLoading = true);
    try {
      final service = ref.read(customerServiceProvider);
      final results = query.isEmpty
          ? await service.getAllByStore(storeId)
          : await service.searchCustomers(storeId, query);
      if (mounted) setState(() { _results = results; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadCustomers(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Text('Pilih Customer', style: AppTextStyles.heading3),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        // Use walk-in (no customer)
                      },
                      icon: const Icon(Icons.person_off_rounded, size: 18),
                      label: const Text('Walk-in'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau no. telp...',
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textHint),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surfaceGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Results
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline_rounded,
                                    size: 48,
                                    color: AppColors.textHint.withOpacity(0.4)),
                                const SizedBox(height: AppSpacing.sm),
                                Text('Tidak ada customer ditemukan',
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(color: AppColors.textHint)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final customer = _results[index];
                              return _buildCustomerItem(customer);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerItem(Customer customer) {
    return InkWell(
      onTap: () {
        ref.read(cartProvider.notifier).setCustomer(customer.id);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppColors.primaryOrange, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (customer.phone != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.phone_rounded,
                            size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(customer.phone!,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${customer.points} pts',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.warningAmber,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------- Customer History Bottom Sheet ---------------

class CustomerHistorySheet extends ConsumerWidget {
  final Customer customer;

  const CustomerHistorySheet({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CustomerHistorySheet(customer: customer);
  }
}

class _CustomerHistorySheet extends ConsumerWidget {
  final Customer customer;

  const _CustomerHistorySheet({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customerOrdersProvider(customer.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: AppColors.primaryOrange, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name,
                              style: AppTextStyles.heading3
                                  .copyWith(fontSize: 16)),
                          if (customer.phone != null)
                            Text(customer.phone!,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              // Summary
              ordersAsync.when(
                data: (orders) {
                  final totalSpent =
                      orders.fold<double>(0, (sum, o) => sum + o.total);
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _summaryItem(
                          'Total Transaksi',
                          '${orders.length}',
                          Icons.receipt_long_rounded,
                          AppColors.infoBlue,
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.grey.shade300,
                        ),
                        _summaryItem(
                          'Total Belanja',
                          Formatters.currency(totalSpent),
                          Icons.attach_money_rounded,
                          AppColors.successGreen,
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.grey.shade300,
                        ),
                        _summaryItem(
                          'Points',
                          '${customer.points}',
                          Icons.star_rounded,
                          AppColors.warningAmber,
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Label
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Riwayat Transaksi',
                      style: AppTextStyles.labelMedium),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Orders list
              Expanded(
                child: ordersAsync.when(
                  data: (orders) {
                    if (orders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48,
                                color: AppColors.textHint.withOpacity(0.3)),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Belum ada transaksi',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: AppColors.textHint)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _buildOrderTile(order);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Center(
                    child: Text('Gagal memuat riwayat transaksi'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryItem(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTile(Order order) {
    return Container(
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_rounded,
                color: AppColors.successGreen, size: 20),
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
    );
  }
}
