import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utility class for hashing PINs using SHA-256 with a fixed salt.
class PinHash {
  static const _salt = 'kompak_pos_pin_salt_v1';

  /// Hash a plain-text PIN using SHA-256 + salt.
  static String hash(String pin) {
    final bytes = utf8.encode('$_salt:$pin');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify a plain-text PIN against a stored hash.
  static bool verify(String pin, String storedHash) {
    return hash(pin) == storedHash;
  }
}
