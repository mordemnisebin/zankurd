import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

enum ReleaseConfigurationIssue { supabase, revenueCat }

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

  // ── RevenueCat (abonelik) ──────────────────────────────────────────────
  // RevenueCat public API anahtarları derleme zamanı env ile taşınır.
  // Boşsa premium özellikler sessizce devre dışı kalır (mock/test modu).
  static const _revenuecatApiKeyAndroid = String.fromEnvironment(
    'REVENUECAT_API_KEY_ANDROID',
  );
  static const _revenuecatApiKeyIos = String.fromEnvironment(
    'REVENUECAT_API_KEY_IOS',
  );
  static const _revenuecatApiKeyWeb = String.fromEnvironment(
    'REVENUECAT_API_KEY_WEB',
  );

  /// Platforma uygun RevenueCat public API anahtarı. BoşsaRevenueCat
  /// devre dışıdır — [PremiumService] mock moda düşer.
  static String get revenuecatApiKey {
    if (kIsWeb) return _revenuecatApiKeyWeb;
    if (Platform.isAndroid) return _revenuecatApiKeyAndroid;
    if (Platform.isIOS || Platform.isMacOS) return _revenuecatApiKeyIos;
    return '';
  }

  static bool get hasRevenuecatConfig => revenuecatApiKey.isNotEmpty;

  /// Üretim derlemesinin yanlışlıkla demo veriyle veya satın alma desteği
  /// olmadan yayımlanmasını engelleyen, yan etkisiz başlangıç kontrolü.
  static List<ReleaseConfigurationIssue> validateForRelease({
    required bool isReleaseMode,
    required bool requireRevenueCat,
    bool? hasSupabaseOverride,
    bool? hasRevenueCatOverride,
  }) {
    if (!isReleaseMode) return const [];

    final issues = <ReleaseConfigurationIssue>[];
    if (!(hasSupabaseOverride ?? hasSupabaseConfig)) {
      issues.add(ReleaseConfigurationIssue.supabase);
    }
    if (requireRevenueCat && !(hasRevenueCatOverride ?? hasRevenuecatConfig)) {
      issues.add(ReleaseConfigurationIssue.revenueCat);
    }
    return issues;
  }

  // ── Yasal bağlantılar (mağaza şartı) ───────────────────────────────────
  // Gizlilik politikası ve kullanım koşulları sayfaları. Bu sayfaların
  // yayında ve erişilebilir olması App Store / Play şartıdır.
  // privacy.html ve terms.html web derlemesiyle birlikte yayınlanır.
  static const privacyPolicyUrl = 'https://www.zankurd.com/privacy.html';
  static const termsOfServiceUrl = 'https://www.zankurd.com/terms.html';
}
