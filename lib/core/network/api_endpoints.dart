class ApiEndpoints {
  ApiEndpoints._();

  static const String products = '/products';
  static const String orders = '/orders';
  static const String sync = '/sync';
  static const String inventory = '/inventory';
  static const String customers = '/customers';
  static const String stores = '/stores';
  static const String auth = '/auth';

  // ── Supabase Edge Functions (License) ────────────────────────────────
  // Base: https://<project-ref>.supabase.co/functions/v1/
  static const String licenseActivate = '/functions/v1/license-activate';
  static const String licenseVerify   = '/functions/v1/license-verify';
  static const String licenseDownload = '/functions/v1/download';
}
