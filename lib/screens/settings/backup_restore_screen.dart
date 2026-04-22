import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../modules/auth/auth_providers.dart';
import '../../modules/core_providers.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _loading = false;
  String _loadingMessage = '';

  static const _prefLastBackup = 'last_backup_at';

  String? _lastBackupAt() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(_prefLastBackup);
  }

  Future<void> _setLastBackup() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      _prefLastBackup,
      DateTime.now().toIso8601String(),
    );
  }

  // ─── Backup Flow ─────────────────────────────────────────

  Future<void> _doBackup() async {
    setState(() {
      _loading = true;
      _loadingMessage = 'Membuat backup...';
    });

    try {
      final backupService = ref.read(backupServiceProvider);
      final file = await backupService.createBackup();

      // Send to Telegram
      if (mounted) {
        setState(() => _loadingMessage = 'Mengirim ke Telegram...');
      }
      try {
        await backupService.sendBackupToTelegram(file);
      } catch (_) {
        // Telegram send is best-effort
      }

      await _setLastBackup();

      if (!mounted) return;
      setState(() => _loading = false);

      // Share file
      await Share.shareXFiles([XFile(file.path)]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup berhasil dibuat'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        setState(() {}); // refresh last backup time
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat backup: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ─── Restore Flow ────────────────────────────────────────

  Future<void> _doRestore() async {
    // 1. Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;
    final file = File(filePath);

    // 2. Validate
    setState(() {
      _loading = true;
      _loadingMessage = 'Memvalidasi file backup...';
    });

    try {
      final backupService = ref.read(backupServiceProvider);
      final meta = await backupService.validateBackupFile(file);

      if (!mounted) return;
      setState(() => _loading = false);

      // 3. Show preview & confirm
      final confirmed = await _showRestoreConfirmDialog(meta);
      if (confirmed != true || !mounted) return;

      // 4. Restore
      setState(() {
        _loading = true;
        _loadingMessage = 'Memulihkan data...';
      });

      await backupService.restoreFromFile(file);

      if (!mounted) return;
      setState(() => _loading = false);

      // 5. Show success then logout
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Berhasil'),
          content: const Text(
            'Data berhasil dipulihkan. Aplikasi akan kembali ke halaman login.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      await performLogout(ref);
      if (mounted) context.go('/auth');
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulihkan data: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<bool?> _showRestoreConfirmDialog(Map<String, dynamic> meta) {
    final storeName = meta['store_name'] ?? 'Unknown';
    final createdAt = DateTime.parse(meta['created_at'] as String);
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(createdAt);
    final counts = meta['table_counts'] as Map<String, dynamic>? ?? {};

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Toko', storeName.toString()),
                  const SizedBox(height: 4),
                  _infoRow('Tanggal Backup', dateStr),
                  const SizedBox(height: 4),
                  _infoRow('Produk', '${counts['products'] ?? 0}'),
                  _infoRow('Transaksi', '${counts['orders'] ?? 0}'),
                  _infoRow('User', '${counts['users'] ?? 0}'),
                  _infoRow('Pelanggan', '${counts['customers'] ?? 0}'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded,
                      color: AppColors.errorRed, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Semua data saat ini akan diganti dengan data dari backup!',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.errorRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Restore'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        Text(value,
            style: AppTextStyles.bodySmall
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lastBackup = _lastBackupAt();
    String lastBackupText = 'Belum pernah';
    if (lastBackup != null) {
      final dt = DateTime.tryParse(lastBackup);
      if (dt != null) {
        lastBackupText = DateFormat('dd MMM yyyy, HH:mm').format(dt);
      }
    }

    return Stack(
      children: [
        Scaffold(
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
              'Backup & Restore',
              style:
                  AppTextStyles.heading3.copyWith(color: AppColors.textPrimary),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // ── Info Banner ──
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.infoBlue, Color(0xFF1565C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.cloud_upload_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Backup & Restore',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cadangkan data untuk pindah device atau pulihkan dari backup sebelumnya.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── BACKUP Section ──
              _sectionLabel('BACKUP'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Backup terakhir: $lastBackupText',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Backup akan menyimpan semua data termasuk produk, transaksi, user, pengaturan, dan lainnya. File juga akan dikirim ke Telegram jika sudah dikonfigurasi.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _doBackup,
                        icon: const Icon(Icons.backup_rounded),
                        label: const Text('Buat Backup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── RESTORE Section ──
              _sectionLabel('RESTORE'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.warningAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.warningAmber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Data saat ini akan diganti sepenuhnya dengan data dari file backup.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.warningAmber,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Pilih file backup (.kompak_backup) dari device Anda untuk memulihkan data. Pastikan file berasal dari aplikasi Kompak POS.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _doRestore,
                        icon: const Icon(Icons.restore_rounded),
                        label: const Text('Pilih File Backup'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryOrange,
                          side: const BorderSide(
                              color: AppColors.primaryOrange),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),

        // ── Loading Overlay ──
        if (_loading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _loadingMessage,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(
        text,
        style: AppTextStyles.labelMedium.copyWith(
          letterSpacing: 1.2,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
