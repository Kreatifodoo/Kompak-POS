class EnvConfig {
  EnvConfig._();

  static const String baseUrl = 'https://api.kompakpos.com/v1';
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const int syncBatchSize = 50;
}
