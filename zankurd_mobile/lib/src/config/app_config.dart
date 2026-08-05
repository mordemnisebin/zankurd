import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'release_config_validator.dart';

enum ReleaseConfigurationIssue { supabase, revenueCat }

class AppConfig {
  static const _defaultSupabaseUrl = 'https://hupivnxgjtsfafulzspo.supabase.co';
  static const _defaultSupabasePublishableKey =
      'sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s';
  static const _useBundledSupabaseDefaults = bool.fromEnvironment(
    'USE_BUNDLED_SUPABASE_DEFAULTS',
  );
  static const _appEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
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

  static String get _explicitSupabaseUrl =>
      _supabaseUrl != '' ? _supabaseUrl : _nextPublicSupabaseUrl;

  static String get _explicitSupabaseAnonKey => _supabaseAnonKey != ''
      ? _supabaseAnonKey
      : _nextPublicSupabasePublishableKey;

  static bool get hasExplicitSupabaseConfig => hasUsableSupabaseConfiguration(
    explicitUrl: _explicitSupabaseUrl,
    explicitAnonKey: _explicitSupabaseAnonKey,
    useBundledDefaults: false,
    bundledUrl: '',
    bundledAnonKey: '',
  );

  static bool get usesBundledSupabaseDefaults => _useBundledSupabaseDefaults;

  static bool get hasSupabaseConfig => hasUsableSupabaseConfiguration(
    explicitUrl: _explicitSupabaseUrl,
    explicitAnonKey: _explicitSupabaseAnonKey,
    useBundledDefaults: usesBundledSupabaseDefaults,
    bundledUrl: _defaultSupabaseUrl,
    bundledAnonKey: _defaultSupabasePublishableKey,
  );

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

  static RevenueCatPlatform? get _revenueCatPlatform {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return RevenueCatPlatform.android;
    if (Platform.isIOS || Platform.isMacOS) return RevenueCatPlatform.ios;
    return null;
  }

  static bool get hasRevenuecatConfig {
    final platform = _revenueCatPlatform;
    return platform != null &&
        ReleaseConfigValidator.isSafeRevenueCatKey(
          revenuecatApiKey,
          platform: platform,
          allowTestStoreKey: _appEnvironment == 'staging',
        );
  }

  /// Örnek env dosyasındaki dolu fakat çalışmayan şablon değerlerinin release
  /// kapısını geçmesini engeller.
  static List<ReleaseConfigurationIssue> validateReleaseClientValues({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String revenueCatKey,
    required bool requireRevenueCat,
    required RevenueCatPlatform revenueCatPlatform,
    bool allowRevenueCatTestStoreKey = false,
  }) {
    final issues = <ReleaseConfigurationIssue>[];
    if (!ReleaseConfigValidator.isSafeSupabaseUrl(supabaseUrl) ||
        !ReleaseConfigValidator.isSafeSupabaseClientKey(supabaseAnonKey)) {
      issues.add(ReleaseConfigurationIssue.supabase);
    }
    if (requireRevenueCat &&
        !ReleaseConfigValidator.isSafeRevenueCatKey(
          revenueCatKey,
          platform: revenueCatPlatform,
          allowTestStoreKey: allowRevenueCatTestStoreKey,
        )) {
      issues.add(ReleaseConfigurationIssue.revenueCat);
    }
    return issues;
  }

  /// Açık yapılandırma kısmen verilmişse veya şablonsa bundled değerlerle
  /// sessizce karıştırmaz. Bundled fallback yalnız iki açık alan da boşken
  /// kullanılabilir.
  static bool hasUsableSupabaseConfiguration({
    required String explicitUrl,
    required String explicitAnonKey,
    required bool useBundledDefaults,
    required String bundledUrl,
    required String bundledAnonKey,
  }) {
    final hasAnyExplicitValue =
        explicitUrl.trim().isNotEmpty || explicitAnonKey.trim().isNotEmpty;
    if (hasAnyExplicitValue) {
      return ReleaseConfigValidator.isSafeSupabaseUrl(explicitUrl) &&
          ReleaseConfigValidator.isSafeSupabaseClientKey(explicitAnonKey);
    }
    return useBundledDefaults &&
        ReleaseConfigValidator.isSafeSupabaseUrl(bundledUrl) &&
        ReleaseConfigValidator.isSafeSupabaseClientKey(bundledAnonKey);
  }

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

  // ── Kötüye kullanım bildirimi (Apple 1.2 / Play UGC şartı) ─────────
  //
  // Kullanıcı üretimi içerik barındıran uygulamalarda iletişim bilgisinin
  // YAYIMLANMIŞ olması zorunludur. Oda sohbeti 2026-07-31'de moderasyonuyla
  // birlikte geri geldi; bu adres o şartın dördüncü maddesini karşılar.
  //
  // Bilerek hesap silme sayfasındakiyle AYNI adres: iki ayrı destek kanalı
  // ikisinin de bakımsız kalmasına yol açar.
  static const supportEmail = 'nisebinbawer47@gmail.com';

  /// Ayarlar → Güvenlik satırının açtığı, konusu hazır e-posta.
  ///
  /// Konu metni çağrı yerinden gelir: yapılandırma dosyası dile
  /// bağımlı olmamalı, metinler anahtar defterinde durmalı.
  static Uri abuseReportUri({required String subject}) => Uri(
    scheme: 'mailto',
    path: supportEmail,
    queryParameters: {'subject': subject},
  );

  /// Beta geri bildirimini de aynı, takip edilebilir destek kanalına yönlendirir.
  static Uri feedbackUri({required String subject}) => Uri(
    scheme: 'mailto',
    path: supportEmail,
    queryParameters: {'subject': subject},
  );
}
