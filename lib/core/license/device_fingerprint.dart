import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Menghasilkan fingerprint unik untuk perangkat Android.
///
/// Kombinasi dari beberapa field hardware yang stabil sehingga
/// fingerprint tidak berubah walau app di-reinstall.
/// Catatan: Fingerprint AKAN berubah jika HP di-factory reset
/// (karena ANDROID_ID berubah) — ini disengaja untuk mencegah
/// transfer lisensi dengan cara reset HP.
class DeviceFingerprint {
  DeviceFingerprint._();

  static Future<String> compute() async {
    if (kIsWeb) {
      // Web tidak didukung untuk licensing (POS ini hanya Android)
      return 'web-unsupported';
    }

    try {
      final info = await DeviceInfoPlugin().androidInfo;

      // Gabungkan field yang paling stabil
      final raw = [
        info.id,          // ANDROID_ID — unik per perangkat, reset saat factory reset
        info.model,       // e.g. "SM-A515F"
        info.brand,       // e.g. "samsung"
        info.hardware,    // e.g. "qcom"
        info.board,       // e.g. "msm8953"
        'kompak_pos_v1',  // namespace salt — hasil hash unik per app ini
      ].join('|');

      final bytes = utf8.encode(raw);
      return sha256.convert(bytes).toString(); // 64-char hex string
    } catch (e) {
      // Fallback jika device_info_plus gagal (emulator lama, dll)
      return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Mengembalikan info perangkat yang bisa ditampilkan ke user / dikirim ke server
  static Future<Map<String, String>> getDeviceInfo() async {
    if (kIsWeb) return {'model': 'Web', 'brand': 'Web', 'android_version': 'N/A'};
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return {
        'model': info.model,
        'brand': info.brand,
        'android_version': info.version.release,
      };
    } catch (_) {
      return {'model': 'Unknown', 'brand': 'Unknown', 'android_version': 'Unknown'};
    }
  }
}
