class AppConfig {
  static const _defaultSupabaseUrl = 'https://hupivnxgjtsfafulzspo.supabase.co';
  static const _defaultSupabasePublishableKey =
      'sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s';

  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _nextPublicSupabaseUrl = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_URL',
  );
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _nextPublicSupabasePublishableKey = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
  );

  static const supabaseUrl = _supabaseUrl != ''
      ? _supabaseUrl
      : _nextPublicSupabaseUrl != ''
      ? _nextPublicSupabaseUrl
      : _defaultSupabaseUrl;
  static const supabaseAnonKey = _supabaseAnonKey != ''
      ? _supabaseAnonKey
      : _nextPublicSupabasePublishableKey != ''
      ? _nextPublicSupabasePublishableKey
      : _defaultSupabasePublishableKey;

  static bool isSafeClientSupabaseKey(String key) {
    final normalized = key.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return !normalized.startsWith('sb_secret_') &&
        !normalized.contains('service_role');
  }

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && isSafeClientSupabaseKey(supabaseAnonKey);
}
