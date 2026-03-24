import 'package:flutter/foundation.dart' show kIsWeb;

/// Cross-platform utility helpers
class PlatformUtils {
  /// Whether app is running in a web browser
  static bool get isWeb => kIsWeb;

  /// Whether app is running on a mobile device (Android/iOS)
  static bool get isMobile => !kIsWeb;
}
