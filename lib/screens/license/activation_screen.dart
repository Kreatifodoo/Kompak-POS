import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/database/seed_data.dart';
import '../../core/license/license_provider.dart';
import '../../core/license/license_model.dart';
import '../../core/license/license_service.dart';

class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  // Format otomatis: KOMP-XXXX-XXXX-XXXX saat user mengetik
  String _formatLicenseKey(String raw) {
    // Hapus semua karakter non-alphanumeric
    final clean = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

    // Batasi 16 karakter (setelah "KOMP")
    final prefix = clean.startsWith('KOMP') ? 'KOMP' : 'KOMP';
    final body = clean.startsWith('KOMP')
        ? clean.substring(4).replaceAll(RegExp(r'[^A-Z0-9]'), '')
        : clean.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final limited = body.substring(0, body.length.clamp(0, 12));

    final parts = <String>[];
    for (var i = 0; i < limited.length; i += 4) {
      parts.add(limited.substring(i, (i + 4).clamp(0, limited.length)));
    }

    if (parts.isEmpty) return '$prefix-';
    return '$prefix-${parts.join('-')}';
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(licenseServiceProvider);
      final license = await service.activate(_keyController.text.trim());

      // Update provider status
      ref.read(licenseStatusProvider.notifier).state =
          LicenseStatus(type: LicenseStatusType.valid, license: license);

      // Seed data essensial (store + admin PIN 1234 + payment methods)
      // Harus dilakukan di sini karena saat startup lisensi belum valid
      final prefs = await SharedPreferences.getInstance();
      final isSeeded = prefs.getBool('data_seeded') ?? false;
      if (!isSeeded) {
        final db = AppDatabase();
        await SeedData.seedIfEmpty(db);
        await db.close();
        await prefs.setBool('data_seeded', true);
      }

      if (mounted) {
        context.go('/');
      }
    } on LicenseException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() =>
          _errorMessage = 'Terjadi kesalahan. Pastikan koneksi internet aktif.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.verified_outlined,
                      size: 44,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Judul
                  Text(
                    'Aktivasi Kompak POS',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan license key yang Anda terima dari admin untuk mengaktifkan aplikasi.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Form input license key
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _keyController,
                          decoration: InputDecoration(
                            labelText: 'License Key',
                            hintText: 'KOMP-XXXX-XXXX-XXXX',
                            prefixIcon: const Icon(Icons.key_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            errorText: _errorMessage,
                            errorMaxLines: 3,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            _LicenseKeyFormatter(),
                          ],
                          keyboardType: TextInputType.text,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'License key tidak boleh kosong';
                            }
                            final clean = value.trim().toUpperCase();
                            final pattern = RegExp(
                                r'^KOMP-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
                            if (!pattern.hasMatch(clean)) {
                              return 'Format tidak valid. Contoh: KOMP-A3F7-C891-X2QR';
                            }
                            return null;
                          },
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // Tombol Aktivasi
                        FilledButton(
                          onPressed: _isLoading ? null : _activate,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Aktifkan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Info kontak
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(
                          'Belum punya license key?\nHubungi admin untuk mendapatkan akses.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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

/// InputFormatter untuk auto-format KOMP-XXXX-XXXX-XXXX
class _LicenseKeyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      // Tambah tanda hubung setelah posisi 4, 8, 12 (KOMP|XXXX|XXXX|XXXX)
      if (i == 4 || i == 8 || i == 12) buffer.write('-');
      if (i >= 16) break; // Maksimal 16 karakter alphanumeric
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
