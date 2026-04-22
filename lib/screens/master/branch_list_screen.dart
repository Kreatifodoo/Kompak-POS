import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/database/app_database.dart';
import '../../modules/auth/auth_providers.dart';

class BranchListScreen extends ConsumerWidget {
  const BranchListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);

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
        title: Text('Kelola Cabang', style: AppTextStyles.heading3),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryOrange,
        onPressed: () => context.push('/settings/branches/new'),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: branchesAsync.when(
        data: (branches) {
          if (branches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_mall_directory_outlined,
                      size: 64,
                      color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Belum ada cabang',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Tap + untuk menambah cabang baru',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Info banner
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.infoBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.infoBlue.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.infoBlue, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Setiap cabang memiliki data terpisah: inventory, produk, promo, dan receipt settings sendiri.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.infoBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Branch list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: branches.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _BranchCard(branch: branches[index]),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final Store branch;
  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/settings/branches/${branch.id}/edit'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.store_mall_directory_rounded,
                  color: AppColors.primaryOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.name,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (branch.address != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        branch.address!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (branch.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        branch.phone!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
