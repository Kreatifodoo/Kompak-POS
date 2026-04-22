import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_startup.dart';
import 'core/database/app_database.dart';
import 'core/database/seed_data.dart';
import 'core/license/license_model.dart';
import 'core/license/license_provider.dart';
import 'core/license/license_service.dart';
import 'modules/core_providers.dart';

void main() async {
  await appStartup();

  // Enable immersive sticky mode — navigation bar auto-hides,
  // swipe up from bottom edge to reveal it temporarily (mobile only).
  if (!kIsWeb) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [SystemUiOverlay.top],
    );
  }

  final prefs = await SharedPreferences.getInstance();

  // ── Cek status lisensi sebelum runApp ─────────────────────────────────
  // Dilakukan di sini agar router bisa langsung membacanya secara sinkron.
  // Jika belum diaktivasi, router akan redirect ke /activate.
  final licenseService = LicenseService(
    prefs: prefs,
    secureStorage: const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
  final licenseStatus = await licenseService.checkLicenseStatus();

  // ── Seed data hanya jika lisensi valid ────────────────────────────────
  // Mencegah seed berjalan di install yang belum resmi diaktivasi.
  if (licenseStatus.isValid) {
    final isSeeded = prefs.getBool('data_seeded') ?? false;
    if (!isSeeded) {
      final db = AppDatabase();
      await SeedData.seedIfEmpty(db);
      await db.close();
      await prefs.setBool('data_seeded', true);
    }

    // Auto-seed default charges for existing installs upgrading to v5
    final isChargesSeeded = prefs.getBool('charges_seeded') ?? false;
    if (!isChargesSeeded) {
      final db = AppDatabase();
      final stores = await db.storeDao.getAllStores();
      for (final store in stores) {
        await SeedData.seedDefaultChargesIfEmpty(db, store.id);
      }
      await db.close();
      await prefs.setBool('charges_seeded', true);
    }

    // ── Background re-verifikasi online (non-blocking) ─────────────────
    // Dilakukan setelah runApp agar tidak menunda startup.
    if (licenseService.isVerificationDue()) {
      Future.delayed(const Duration(seconds: 5), () {
        licenseService.verifyOnline();
      });
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Override licenseStatusProvider dengan hasil pre-check di atas
        licenseStatusProvider.overrideWith((ref) => licenseStatus),
      ],
      child: const KompakPosApp(),
    ),
  );
}
