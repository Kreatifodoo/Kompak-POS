import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/database/app_database.dart';
import '../../modules/pricelist/pricelist_providers.dart';
import '../../modules/core_providers.dart';

class PricelistListScreen extends ConsumerWidget {
  const PricelistListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pricelistsAsync = ref.watch(pricelistsProvider);

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
        title: Text('Pricelists', style: AppTextStyles.heading3),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryOrange,
        onPressed: () => context.push('/settings/pricelists/new'),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: pricelistsAsync.when(
        data: (pricelists) {
          if (pricelists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.price_change_outlined,
                      size: 64,
                      color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('No pricelists yet',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Tap + to create one',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: pricelists.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) =>
                _PricelistTile(pricelist: pricelists[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _PricelistTile extends ConsumerWidget {
  final Pricelist pricelist;
  const _PricelistTile({required this.pricelist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isActive = pricelist.isActive &&
        now.isAfter(pricelist.startDate) &&
        now.isBefore(pricelist.endDate);
    final isUpcoming = pricelist.isActive && now.isBefore(pricelist.startDate);
    final isExpired = now.isAfter(pricelist.endDate);

    final statusLabel = isActive
        ? 'Active'
        : isUpcoming
            ? 'Upcoming'
            : isExpired
                ? 'Expired'
                : 'Inactive';
    final statusColor = isActive
        ? AppColors.successGreen
        : isUpcoming
            ? Colors.orange
            : Colors.grey;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push('/settings/pricelists/${pricelist.id}/edit'),
        onLongPress: () => _showDeleteDialog(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.price_change_rounded,
                    color: statusColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pricelist.name,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.date(pricelist.startDate)} - ${Formatters.date(pricelist.endDate)}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pricelist'),
        content: Text('Delete "${pricelist.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(pricelistServiceProvider)
                  .deletePricelist(pricelist.id);
              ref.invalidate(pricelistsProvider);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
  }
}
