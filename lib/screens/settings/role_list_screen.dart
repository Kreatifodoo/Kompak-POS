import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/database/app_database.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/rbac/rbac_providers.dart';

class RoleListScreen extends ConsumerWidget {
  const RoleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeId = ref.watch(currentStoreIdProvider);
    final rolesAsync = ref.watch(availableRolesProvider(storeId));

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
        title: Text('Kelola Role', style: AppTextStyles.heading3),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryOrange,
        onPressed: () => context.push('/settings/roles/new'),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: rolesAsync.when(
        data: (roles) {
          if (roles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings_rounded,
                      size: 64, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.md),
                  Text('Belum ada role',
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: roles.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final role = roles[index];
              return _RoleCard(role: role);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _RoleCard extends ConsumerWidget {
  final Role role;
  const _RoleCard({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permAsync = ref.watch(rolePermissionsProvider(role.id));
    final permCount = permAsync.valueOrNull?.length ?? 0;

    return GestureDetector(
      onTap: () => context.push('/settings/roles/${role.id}'),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _roleColor(role.id).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _roleIcon(role.id),
                color: _roleColor(role.id),
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(role.name,
                          style: AppTextStyles.bodyLarge
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: AppSpacing.sm),
                      if (role.isSystem)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.infoBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('System',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.infoBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              )),
                        ),
                    ],
                  ),
                  if (role.description != null &&
                      role.description!.isNotEmpty)
                    Text(role.description!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  Text('$permCount permissions',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textHint)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String id) {
    switch (id) {
      case 'owner':
        return AppColors.warningAmber;
      case 'admin':
        return AppColors.infoBlue;
      case 'branch_manager':
        return AppColors.successGreen;
      case 'cashier':
        return AppColors.primaryOrange;
      case 'kitchen':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _roleIcon(String id) {
    switch (id) {
      case 'owner':
        return Icons.shield_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'branch_manager':
        return Icons.store_rounded;
      case 'cashier':
        return Icons.point_of_sale_rounded;
      case 'kitchen':
        return Icons.restaurant_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}
