import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/config/app_config.dart';
import '../../core/database/demo_seeder.dart';
import '../../core/database/seed_data.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/core_providers.dart';
import '../../modules/printer/printer_providers.dart';
import '../../core/utils/permissions.dart';

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

            _buildMenuItem(
              context,
              icon: Icons.send_rounded,
              iconColor: Colors.blue,
              title: 'Telegram',
              subtitle: 'Laporan otomatis ke Telegram',
              onTap: () => context.push('/settings/telegram'),
            ),

            _buildMenuItem(
              context,
              icon: Icons.wifi_rounded,
              iconColor: AppColors.successGreen,
              title: 'LAN Sync',
              subtitle: 'Sinkronisasi antar device via WiFi',
              onTap: () => context.push('/settings/lan-sync'),
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

            // Branch management (HQ only)
            if (ref.watch(isHQUserProvider))
              _buildMenuItem(
                context,
                icon: Icons.store_mall_directory_rounded,
                iconColor: Colors.teal,
                title: 'Kelola Cabang',
                subtitle: 'Tambah & kelola cabang toko',
                onTap: () => context.push('/settings/branches'),
              ),

            // Role management (owner/admin only)
            if (Permissions.canManageUsers(
                ref.watch(currentUserProvider)?.role ?? ''))
              _buildMenuItem(
                context,
                icon: Icons.admin_panel_settings_rounded,
                iconColor: Colors.indigo,
                title: 'Kelola Role',
                subtitle: 'Atur role & hak akses pengguna',
                onTap: () => context.push('/settings/roles'),
              ),

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
                'BACKUP & RESTORE',
                style: AppTextStyles.labelMedium.copyWith(letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildMenuItem(
              context,
              icon: Icons.backup_rounded,
              iconColor: AppColors.infoBlue,
              title: 'Backup & Restore',
              subtitle: 'Cadangkan atau pulihkan data',
              onTap: () => context.push('/settings/backup'),
            ),

            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'DATA DEMO',
                style: AppTextStyles.labelMedium.copyWith(letterSpacing: 1.2),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildMenuItem(
              context,
              icon: Icons.science_rounded,
              iconColor: Colors.deepPurple,
              title: 'Muat Data Demo Multi-Cabang',
              subtitle: 'Buat data HQ + 2 cabang + transaksi untuk uji coba',
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Muat Data Demo?'),
                    content: const Text(
                      'Akan dibuat:\n'
                      '• 3 toko (HQ + 2 cabang)\n'
                      '• 5 terminal POS\n'
                      '• Katalog produk lengkap + combo + resep\n'
                      '• Pricelist, promosi, biaya, pelanggan\n'
                      '• ±19 transaksi demo\n\n'
                      'Data ini TIDAK akan menimpa data yang sudah ada.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Muat',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                if (!context.mounted) return;

                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Expanded(
                            child: Text('Memuat data demo...\nMohon tunggu.')),
                      ],
                    ),
                  ),
                );

                try {
                  final db = ref.read(databaseProvider);
                  await DemoSeeder.seedDemoData(db);
                  if (context.mounted) {
                    Navigator.pop(context); // close loading
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => AlertDialog(
                        title: const Text('Data Demo Berhasil Dimuat!'),
                        content: const Text(
                          'Login dengan PIN berikut untuk uji coba:\n\n'
                          '🔑 9999 → Owner Kompak (HQ)\n'
                          '🔑 1111 → Admin HQ\n'
                          '🔑 2222 → Budi / Kasir Selatan 1\n'
                          '🔑 3333 → Sari / Kasir Selatan 2\n'
                          '🔑 4444 → Andi / Kasir Timur 1\n'
                          '🔑 5555 → Dewi / Kasir Timur 2\n\n'
                          'Tekan OK untuk logout dan login ulang dengan PIN demo.',
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                            ),
                            child: const Text('OK — Logout & Login Ulang',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    // Logout so providers reset and user can login with demo PIN
                    if (context.mounted) {
                      await performLogout(ref);
                      if (context.mounted) context.go('/auth');
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.errorRed,
                      ),
                    );
                  }
                }
              },
            ),

            const SizedBox(height: AppSpacing.sm),
            _buildMenuItem(
              context,
              icon: Icons.delete_sweep_rounded,
              iconColor: Colors.red.shade700,
              title: 'Hapus Semua Data',
              subtitle: 'Reset aplikasi ke kondisi awal (kosong)',
              onTap: () async {
                final db = ref.read(databaseProvider);

                // Deteksi apakah ini data demo atau data asli
                final stores = await db.storeDao.getAllStores();
                final isDemoData = stores.any((s) => s.name == 'Warung Kompak HQ');
                final hasRealData = stores.isNotEmpty && !isDemoData;

                if (!context.mounted) return;

                // Jika ada data asli, tampilkan warning ekstra
                if (hasRealData) {
                  final confirmExtra = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      icon: const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 48),
                      title: const Text('⚠️ BUKAN Data Demo!'),
                      content: const Text(
                        'Data yang ada di aplikasi ini adalah DATA ASLI toko Anda, '
                        'bukan data demo.\n\n'
                        'Menghapus data ini akan menghilangkan SEMUA transaksi, '
                        'produk, pelanggan, dan pengaturan yang sudah Anda buat.\n\n'
                        'Tindakan ini TIDAK BISA dibatalkan!\n\n'
                        'Apakah Anda benar-benar yakin?',
                        style: TextStyle(height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Saya Mengerti, Hapus Data Asli',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmExtra != true) return;
                  if (!context.mounted) return;
                }

                // Konfirmasi akhir (berlaku untuk semua jenis data)
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    icon: Icon(
                      isDemoData
                          ? Icons.science_rounded
                          : Icons.delete_forever_rounded,
                      color: isDemoData ? Colors.deepPurple : Colors.red,
                      size: 40,
                    ),
                    title: Text(isDemoData
                        ? 'Hapus Data Demo?'
                        : 'Konfirmasi Hapus Data Asli'),
                    content: Text(isDemoData
                        ? 'Semua data demo akan dihapus dan aplikasi dikembalikan ke kondisi awal.'
                        : 'Ketik "HAPUS" untuk mengkonfirmasi penghapusan data asli Anda.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: isDemoData
                                ? Colors.deepPurple
                                : Colors.red.shade700),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Hapus Semua',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                if (!context.mounted) return;

                // Tampilkan loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AlertDialog(
                    content: Row(children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Menghapus semua data...'),
                    ]),
                  ),
                );

                try {
                  // Hapus semua data dari database (urutan: child → parent)
                  await db.transaction(() async {
                    await db.delete(db.comboGroupItems).go();
                    await db.delete(db.comboGroups).go();
                    await db.delete(db.bomItems).go();
                    await db.delete(db.productExtras).go();
                    await db.delete(db.pricelistItems).go();
                    await db.delete(db.pricelists).go();
                    await db.delete(db.promotions).go();
                    await db.delete(db.charges).go();
                    await db.delete(db.orderReturns).go();
                    await db.delete(db.orderItems).go();
                    await db.delete(db.payments).go();
                    await db.delete(db.orders).go();
                    await db.delete(db.posSessions).go();
                    await db.delete(db.syncQueue).go();
                    await db.delete(db.attendances).go();
                    await db.delete(db.inventoryMovements).go();
                    await db.delete(db.inventory).go();
                    await db.delete(db.products).go();
                    await db.delete(db.categories).go();
                    await db.delete(db.customers).go();
                    await db.delete(db.paymentMethods).go();
                    await db.delete(db.rolePermissions).go();
                    await db.delete(db.rbacPermissions).go();
                    await db.delete(db.roles).go();
                    await db.delete(db.users).go();
                    await db.delete(db.terminals).go();
                    await db.delete(db.stores).go();
                  });

                  // Re-seed data essensial (store + admin PIN 1234 + payment methods)
                  await SeedData.seedIfEmpty(db);

                  // Reset semua flag seed
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('data_seeded');
                  await prefs.remove('charges_seeded');
                  await prefs.remove('demo_data_seeded');

                  if (context.mounted) {
                    Navigator.pop(context); // close loading
                    await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => AlertDialog(
                        title: const Text('Berhasil!'),
                        content: const Text(
                          'Semua data telah dihapus.\n\n'
                          'Aplikasi akan restart ke kondisi awal.\n'
                          'Login menggunakan PIN: 1234',
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange),
                            child: const Text('OK',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (context.mounted) {
                      await performLogout(ref);
                      if (context.mounted) context.go('/auth');
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context); // close loading
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.errorRed,
                    ));
                  }
                }
              },
            ),

            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'PANDUAN',
                style: AppTextStyles.labelMedium.copyWith(
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildMenuItem(
              context,
              icon: Icons.menu_book_rounded,
              iconColor: Colors.teal,
              title: 'Panduan Penggunaan',
              subtitle: 'Cara menggunakan aplikasi Kompak POS',
              onTap: () => context.push('/settings/manual'),
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
