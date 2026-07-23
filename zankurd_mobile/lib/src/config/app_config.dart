class AppConfig {
  static const _defaultSupabaseUrl = 'https://hupivnxgjtsfafulzspo.supabase.co';
  static const _defaultSupabasePublishableKey =
      'sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s';
  static const _useBundledSupabaseDefaults = bool.fromEnvironment(
    'USE_BUNDLED_SUPABASE_DEFAULTS',
  );

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

  static bool get hasExplicitSupabaseConfig =>
      (_supabaseUrl != '' || _nextPublicSupabaseUrl != '') &&
      (_supabaseAnonKey != '' || _nextPublicSupabasePublishableKey != '');

  static bool get usesBundledSupabaseDefaults => _useBundledSupabaseDefaults;

  static bool get hasSupabaseConfig =>
      hasExplicitSupabaseConfig ||
      (usesBundledSupabaseDefaults &&
          supabaseUrl.isNotEmpty &&
          supabaseAnonKey.isNotEmpty);
}
