import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/license/license_model.dart';
import '../../core/license/license_provider.dart';

class LicenseExpiredScreen extends ConsumerWidget {
  const LicenseExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licenseStatus = ref.watch(licenseStatusProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (icon, title, message, color) = switch (licenseStatus.type) {
      LicenseStatusType.revoked => (
          Icons.block_outlined,
          'Lisensi Dicabut',
          'Lisensi aplikasi ini telah dicabut oleh admin. Hubungi admin untuk informasi lebih lanjut.',
          colorScheme.error,
        ),
      LicenseStatusType.expired => (
          Icons.timer_off_outlined,
          'Lisensi Kedaluwarsa',
          'Masa berlaku lisensi aplikasi ini telah habis. Hubungi admin untuk perpanjangan.',
          Colors.orange,
        ),
      LicenseStatusType.deviceMismatch => (
          Icons.phonelink_erase_outlined,
          'Perangkat Tidak Dikenal',
          'Lisensi ini terdaftar untuk perangkat yang berbeda. Aplikasi tidak dapat digunakan di perangkat ini.',
          colorScheme.error,
        ),
      _ => (
          Icons.error_outline,
          'Lisensi Tidak Valid',
          'Terjadi masalah dengan lisensi aplikasi. Hubungi admin.',
          colorScheme.error,
        ),
    };

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon
                  Icon(icon, size: 72, color: color),
                  const SizedBox(height: 24),

                  // Judul
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Pesan
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Tombol hubungi admin
                  FilledButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(
                          'https://wa.me/6281234567890'
                          '?text=Halo+Admin%2C+lisensi+Kompak+POS+saya+bermasalah.');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Hubungi Admin via WhatsApp'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Jika device mismatch tidak bisa, tapi kalau expired/revoked
                  // bisa coba input license key baru
                  if (licenseStatus.type != LicenseStatusType.deviceMismatch)
                    OutlinedButton(
                      onPressed: () => context.go('/activate'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Masukkan License Key Baru'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
