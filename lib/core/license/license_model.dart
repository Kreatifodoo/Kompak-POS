/// Data lisensi yang tersimpan di flutter_secure_storage setelah aktivasi.
class LicenseModel {
  final String activationToken;     // UUID dari server, disimpan lokal
  final String deviceFingerprint;   // SHA-256 fingerprint saat aktivasi
  final String customerName;        // Nama pelanggan
  final String? storeName;          // Nama toko (opsional)
  final String licenseKey;          // KOMP-XXXX-XXXX-XXXX
  final DateTime activatedAt;       // Waktu pertama aktivasi
  final DateTime? expiresAt;        // null = lisensi seumur hidup

  const LicenseModel({
    required this.activationToken,
    required this.deviceFingerprint,
    required this.customerName,
    this.storeName,
    required this.licenseKey,
    required this.activatedAt,
    this.expiresAt,
  });

  bool get isPerpetual => expiresAt == null;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
    'activation_token': activationToken,
    'device_fingerprint': deviceFingerprint,
    'customer_name': customerName,
    'store_name': storeName,
    'license_key': licenseKey,
    'activated_at': activatedAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
  };

  factory LicenseModel.fromJson(Map<String, dynamic> json) => LicenseModel(
    activationToken: json['activation_token'] as String,
    deviceFingerprint: json['device_fingerprint'] as String,
    customerName: json['customer_name'] as String,
    storeName: json['store_name'] as String?,
    licenseKey: json['license_key'] as String,
    activatedAt: DateTime.parse(json['activated_at'] as String),
    expiresAt: json['expires_at'] != null
        ? DateTime.parse(json['expires_at'] as String)
        : null,
  );
}

/// Status lisensi saat startup app
enum LicenseStatusType {
  valid,          // Lisensi valid, device cocok → app bisa jalan
  notActivated,   // Belum pernah aktivasi → tampilkan layar aktivasi
  deviceMismatch, // Fingerprint berbeda → bukan perangkat yang diaktivasi
  revoked,        // Server menyatakan lisensi dicabut
  expired,        // Lisensi sudah lewat masa berlaku
}

class LicenseStatus {
  final LicenseStatusType type;
  final LicenseModel? license;

  const LicenseStatus({required this.type, this.license});

  bool get isValid => type == LicenseStatusType.valid;

  static const LicenseStatus notActivated =
      LicenseStatus(type: LicenseStatusType.notActivated);

  static const LicenseStatus deviceMismatch =
      LicenseStatus(type: LicenseStatusType.deviceMismatch);

  static const LicenseStatus revoked =
      LicenseStatus(type: LicenseStatusType.revoked);

  static const LicenseStatus expired =
      LicenseStatus(type: LicenseStatusType.expired);
}
