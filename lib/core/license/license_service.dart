import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_fingerprint.dart';
import 'license_model.dart';
import '../config/env_config.dart';
import '../utils/logger.dart';

/// Storage keys untuk flutter_secure_storage (terenkripsi / hardware-backed)
class _SecureKeys {
  static const String licenseData = 'license_data_v1'; // JSON LicenseModel
}

/// Storage keys untuk SharedPreferences (tidak sensitif)
class _PrefKeys {
  static const String lastVerifiedAt = 'license_last_verified_at'; // ISO8601
  static const String isRevoked = 'license_is_revoked';            // bool
}

/// Interval re-verifikasi online: setiap 30 hari
const _verifyIntervalDays = 30;

/// Grace period sebelum hard lock: 60 hari tanpa online check
const _graceMaxDays = 60;

class LicenseService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  final Dio _dio;

  LicenseService({
    required SharedPreferences prefs,
    FlutterSecureStorage? secureStorage,
    Dio? dio,
  })  : _prefs = prefs,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        ),
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: EnvConfig.supabaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'Content-Type': 'application/json',
                'apikey': EnvConfig.supabaseAnonKey,
              },
            ));

  // ─── Baca lisensi lokal ──────────────────────────────────────────────────

  Future<LicenseModel?> _readLocalLicense() async {
    try {
      final raw = await _secureStorage.read(key: _SecureKeys.licenseData);
      if (raw == null) return null;
      return LicenseModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.error('Gagal membaca lisensi lokal', e);
      return null;
    }
  }

  Future<void> _saveLocalLicense(LicenseModel license) async {
    await _secureStorage.write(
      key: _SecureKeys.licenseData,
      value: jsonEncode(license.toJson()),
    );
  }

  // ─── Cek status saat startup ─────────────────────────────────────────────

  /// Dipanggil di main() sebelum runApp. Hasilnya di-override ke licenseStatusProvider.
  Future<LicenseStatus> checkLicenseStatus() async {
    // Apakah pernah direvoke oleh server?
    final wasRevoked = _prefs.getBool(_PrefKeys.isRevoked) ?? false;
    if (wasRevoked) return LicenseStatus.revoked;

    final license = await _readLocalLicense();
    if (license == null) return LicenseStatus.notActivated;

    // Cek apakah lisensi sudah expired (masa berlaku habis)
    if (license.isExpired) return LicenseStatus.expired;

    // Cek device fingerprint cocok dengan saat aktivasi
    final currentFp = await DeviceFingerprint.compute();
    if (currentFp != license.deviceFingerprint) {
      AppLogger.warning('Device fingerprint tidak cocok — bukan perangkat asli');
      return LicenseStatus.deviceMismatch;
    }

    // Cek grace period: jika sudah lebih dari 60 hari tanpa verifikasi online
    final lastVerified = _prefs.getString(_PrefKeys.lastVerifiedAt);
    if (lastVerified != null) {
      final daysSince = DateTime.now()
          .difference(DateTime.parse(lastVerified))
          .inDays;
      if (daysSince > _graceMaxDays) {
        AppLogger.warning('Grace period habis ($daysSince hari tanpa koneksi)');
        // Tetap valid tapi tandai perlu verifikasi segera
        // (tidak hard-lock agar kasir tidak kena dampak)
      }
    }

    return LicenseStatus(type: LicenseStatusType.valid, license: license);
  }

  // ─── Aktivasi (dipanggil dari ActivationScreen) ──────────────────────────

  /// Kirim license key + device fingerprint ke Supabase.
  /// Simpan token aktivasi ke secure storage jika berhasil.
  Future<LicenseModel> activate(String licenseKey) async {
    final fp = await DeviceFingerprint.compute();
    final deviceInfo = await DeviceFingerprint.getDeviceInfo();

    try {
      final response = await _dio.post(
        '/functions/v1/license-activate',
        data: {
          'license_key': licenseKey.trim().toUpperCase(),
          'device_fingerprint': fp,
          'device_model': deviceInfo['model'],
          'device_brand': deviceInfo['brand'],
          'android_version': deviceInfo['android_version'],
          'app_version': '1.0.8',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final license = LicenseModel(
        activationToken: data['activation_token'] as String,
        deviceFingerprint: fp,
        customerName: data['customer_name'] as String,
        storeName: data['store_name'] as String?,
        licenseKey: licenseKey.trim().toUpperCase(),
        activatedAt: DateTime.now(),
        expiresAt: data['expires_at'] != null
            ? DateTime.tryParse(data['expires_at'] as String)
            : null,
      );

      await _saveLocalLicense(license);
      // Tandai verifikasi baru saja dilakukan
      await _prefs.setString(
          _PrefKeys.lastVerifiedAt, DateTime.now().toIso8601String());
      await _prefs.setBool(_PrefKeys.isRevoked, false);

      AppLogger.info('Aktivasi berhasil: ${license.customerName}');
      return license;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final serverMsg = e.response?.data is Map
          ? (e.response!.data as Map)['error'] as String?
          : null;

      AppLogger.error('Aktivasi gagal (HTTP $statusCode)', e);
      throw LicenseException(serverMsg ?? _errorFromStatus(statusCode));
    }
  }

  // ─── Re-verifikasi online (background, setiap 30 hari) ──────────────────

  bool isVerificationDue() {
    final last = _prefs.getString(_PrefKeys.lastVerifiedAt);
    if (last == null) return true;
    final daysSince =
        DateTime.now().difference(DateTime.parse(last)).inDays;
    return daysSince >= _verifyIntervalDays;
  }

  /// Non-blocking — dipanggil di background.
  /// Jika server menyatakan dicabut, set flag isRevoked.
  Future<void> verifyOnline() async {
    final license = await _readLocalLicense();
    if (license == null) return;

    final fp = await DeviceFingerprint.compute();

    try {
      final response = await _dio.post(
        '/functions/v1/license-verify',
        data: {
          'activation_token': license.activationToken,
          'device_fingerprint': fp,
        },
      );

      final data = response.data as Map<String, dynamic>;
      if (data['valid'] == true) {
        await _prefs.setString(
            _PrefKeys.lastVerifiedAt, DateTime.now().toIso8601String());
        AppLogger.info('Verifikasi lisensi online: valid');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        final reason = (e.response?.data as Map?)?['reason'] as String?;
        AppLogger.warning('Lisensi dicabut/tidak valid: $reason');
        if (reason == 'license_revoked' || reason == 'device_deactivated') {
          await _prefs.setBool(_PrefKeys.isRevoked, true);
        }
      } else {
        // Error jaringan biasa — abaikan, coba lagi 30 hari lagi
        AppLogger.warning('Verifikasi online gagal (jaringan): ${e.message}');
      }
    }
  }

  // ─── Hapus lisensi lokal (reset) ─────────────────────────────────────────

  Future<void> clearLicense() async {
    await _secureStorage.delete(key: _SecureKeys.licenseData);
    await _prefs.remove(_PrefKeys.lastVerifiedAt);
    await _prefs.remove(_PrefKeys.isRevoked);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _errorFromStatus(int? code) {
    switch (code) {
      case 404:
        return 'License key tidak ditemukan. Periksa kembali kode yang dimasukkan.';
      case 403:
        return 'Lisensi tidak aktif atau sudah dicabut. Hubungi admin.';
      case 400:
        return 'Format license key tidak valid. Contoh: KOMP-A3F7-C891-X2QR';
      default:
        return 'Tidak dapat terhubung ke server. Pastikan internet aktif dan coba lagi.';
    }
  }
}

/// Exception khusus untuk error lisensi (pesan sudah user-friendly)
class LicenseException implements Exception {
  final String message;
  const LicenseException(this.message);

  @override
  String toString() => message;
}
