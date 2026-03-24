import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/config/app_config.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/printer/printer_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStore = ref.watch(currentStoreProvider);
    final printerConnected = ref.watch(printerConnectedProvider);

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
          'Settings',
          style: AppTextStyles.heading3,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store info header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.store_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentStore?.name ?? 'Kompak Store',
                          style: AppTextStyles.heading3.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Active',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'GENERAL',
                style: AppTextStyles.labelMedium.copyWith(
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildMenuItem(
              context,
              icon: Icons.store_rounded,
              iconColor: AppColors.primaryOrange,
              title: 'Store Settings',
              subtitle: currentStore?.name ?? 'Configure your store',
              onTap: () => context.push('/settings/store'),
            ),

            _buildMenuItem(
              context,
              icon: Icons.print_rounded,
              iconColor: AppColors.infoBlue,
              title: 'Printer Settings',
              subtitle: printerConnected ? 'Connected' : 'Not connected',
              trailing: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: printerConnected
                      ? AppColors.successGreen
                      : AppColors.errorRed,
                  shape: BoxShape.circle,
                ),
              ),
              onTap: () => context.push('/settings/printer'),
            ),

            // Sync menu hidden — orders save locally without sync
            // _buildMenuItem(
            //   context,
            //   icon: Icons.sync_rounded,
            //   iconColor: AppColors.warningAmber,
            //   title: 'Sync Status',
            //   subtitle: 'Up to date',
            //   onTap: () => context.push('/settings/sync'),
            // ),

            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'MASTER DATA',
                style: AppTextStyles.labelMedium.copyWith(
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildMenuItem(
              context,
              icon: Icons.inventory_2_rounded,
              iconColor: AppColors.successGreen,
              title: 'Products',
              subtitle: 'Manage products & pricing',
              onTap: () => context.push('/settings/products'),
            ),

            _buildMenuItem(
              context,
              icon: Icons.price_change_rounded,
              iconColor: Colors.purple,
              title: 'Pricelists',
              subtitle: 'Manage price tiers & promos',
              onTap: () => context.push('/settings/pricelists'),
            ),

            _buildMenuItem(
              context,
              icon: Icons.category_rounded,
              iconColor: AppColors.warningAmber,
              title: 'Categories',
              subtitle: 'Manage product categories',
              onTap: () => context.push('/settings/categories'),
            ),

            _buildMenuItem(
              context,
              icon: Icons.people_rounded,
              iconColor: AppColors.infoBlue,
              title: 'Users',
              subtitle: 'Manage staff & access',
              onTap: () => context.push('/settings/users'),
            ),

            _buildMenuItem(
              context,
              icon: Icons.point_of_sale_rounded,
              iconColor: Colors.deepPurple,
              title: 'Kelola Terminal',
              subtitle: 'Mesin kasir & printer assignment',
              onTap: () => context.push('/settings/terminals'),
            ),

            _buildMenuItem(
              context,
              icon: Icons.person_rounded,
              iconColor: AppColors.primaryOrange,
              title: 'Customers',
              subtitle: 'Manage customer database',
              onTap: () => context.push('/settings/customers'),
            ),

            _buildMenuItem(
              context,
              icon: Icons.payment_rounded,
              iconColor: AppColors.discountRed,
              title: 'Payment Methods',
              subtitle: 'Configure payment options',
              onTap: () => context.push('/settings/payment-methods'),
            ),

            _buildMenuItem(
              context,
              icon: Icons.receipt_long_rounded,
              iconColor: Colors.teal,
              title: 'Master Biaya',
              subtitle: 'Kelola pajak, biaya & potongan',
              onTap: () => context.push('/settings/charges'),
            ),

            _buildMenuItem(
              context,
              icon: Icons.local_offer_rounded,
              iconColor: AppColors.successGreen,
              title: 'Promosi',
              subtitle: 'Kelola promo, diskon & reward',
              onTap: () => context.push('/settings/promotions'),
            ),

            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'LAPORAN',
                style: AppTextStyles.labelMedium.copyWith(
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildMenuItem(
              context,
              icon: Icons.assessment_rounded,
              iconColor: AppColors.infoBlue,
              title: 'Laporan Session',
              subtitle: 'Riwayat buka & tutup kasir',
              onTap: () => context.push('/settings/reports/sessions'),
            ),

            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'APP',
                style: AppTextStyles.labelMedium.copyWith(
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildMenuItem(
              context,
              icon: Icons.info_outline_rounded,
              iconColor: AppColors.textSecondary,
              title: 'About',
              subtitle:
                  '${AppConfig.appName} v${AppConfig.appVersion}',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: AppConfig.appName,
                  applicationVersion: AppConfig.appVersion,
                  applicationIcon: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.point_of_sale_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  children: [
                    Text(
                      'A modern point-of-sale application for small businesses.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  trailing,
                  const SizedBox(width: AppSpacing.sm),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
