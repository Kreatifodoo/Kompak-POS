import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'license_model.dart';
import 'license_service.dart';
import '../../modules/core_providers.dart';

// ─── Service Provider ─────────────────────────────────────────────────────────

final licenseServiceProvider = Provider<LicenseService>((ref) {
  return LicenseService(
    prefs: ref.watch(sharedPreferencesProvider),
    secureStorage: const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
});

// ─── Status Provider ──────────────────────────────────────────────────────────
//
// Di-override di main() dengan nilai yang sudah di-await sebelum runApp,
// sehingga router bisa membacanya secara sinkron.
//
// Cara pakai di router:
//   final licenseStatus = ref.read(licenseStatusProvider);
//   if (!licenseStatus.isValid) return '/activate';

final licenseStatusProvider = StateProvider<LicenseStatus>((ref) {
  // Default: belum diaktivasi (seharusnya di-override oleh main())
  return LicenseStatus.notActivated;
});
