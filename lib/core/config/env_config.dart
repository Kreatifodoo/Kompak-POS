class EnvConfig {
  EnvConfig._();

  static const String baseUrl = 'https://api.kompakpos.com/v1';
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  static const int syncBatchSize = 50;

  // ── Supabase (License System) ──────────────────────────────────────────
  // Ganti dengan URL dan anon key dari dashboard Supabase Anda:
  // https://supabase.com/dashboard/project/<project-ref>/settings/api
  static const String supabaseUrl = 'https://qyxvxoavypqbiacinqbz.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF5eHZ4b2F2eXBxYmlhY2lucWJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2NjQ4NTEsImV4cCI6MjA5MjI0MDg1MX0.2yaXi_YJqY_eyOwYQJ0IQigTMrIKRAiYRZl8uavdHa8';
}
