class AppConfig {
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _nextPublicSupabaseUrl = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_URL',
  );
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _nextPublicSupabasePublishableKey = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
  );

  static const supabaseUrl = _supabaseUrl == ''
      ? _nextPublicSupabaseUrl
      : _supabaseUrl;
  static const supabaseAnonKey = _supabaseAnonKey == ''
      ? _nextPublicSupabasePublishableKey
      : _supabaseAnonKey;

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
