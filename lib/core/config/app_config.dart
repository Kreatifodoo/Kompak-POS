class AppConfig {
  AppConfig._();

  static const String appName = 'Kompak POS';
  static const String appVersion = '1.0.0';
  static const double defaultTaxRate = 0.11; // 11%
  static const String defaultCurrency = 'Rp';
  static const String orderPrefix = 'KP';
  static const int syncIntervalMinutes = 15;
  static const int maxSyncRetries = 5;
  static const int searchDebounceMs = 300;
}
