import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';

void main() {
  test('bundled Supabase defaults remain available as fallback values', () {
    expect(AppConfig.supabaseUrl, 'https://hupivnxgjtsfafulzspo.supabase.co');
    expect(
      AppConfig.supabaseAnonKey,
      'sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s',
    );
  });

  test('ordinary test builds do not auto-enable live Supabase', () {
    expect(AppConfig.hasExplicitSupabaseConfig, isFalse);
    expect(AppConfig.usesBundledSupabaseDefaults, isFalse);
    expect(AppConfig.hasSupabaseConfig, isFalse);
  });

  group('release configuration validation', () {
    test('release rejects untouched mobile template values', () {
      expect(
        AppConfig.validateReleaseClientValues(
          supabaseUrl: 'https://your-project.supabase.co',
          supabaseAnonKey: 'your-public-anon-key',
          revenueCatKey: 'goog_your-public-sdk-key',
          requireRevenueCat: true,
        ),
        unorderedEquals([
          ReleaseConfigurationIssue.supabase,
          ReleaseConfigurationIssue.revenueCat,
        ]),
      );
    });

    test('bundled defaults cannot mask invalid explicit Supabase values', () {
      for (final explicit in [
        (url: 'https://your-project.supabase.co', key: 'your-public-anon-key'),
        (url: 'https://staging.zankurd.invalid', key: ''),
      ]) {
        expect(
          AppConfig.hasUsableSupabaseConfiguration(
            explicitUrl: explicit.url,
            explicitAnonKey: explicit.key,
            useBundledDefaults: true,
            bundledUrl: 'https://production.zankurd.invalid',
            bundledAnonKey: 'sb_publishable_public_client_key',
          ),
          isFalse,
          reason:
              'Açık değer varsa bundled fallback onu tamamlamamalı veya '
              'şablon değeri gizlememeli.',
        );
      }
    });

    test('bundled defaults remain usable when explicit values are absent', () {
      expect(
        AppConfig.hasUsableSupabaseConfiguration(
          explicitUrl: '',
          explicitAnonKey: '',
          useBundledDefaults: true,
          bundledUrl: 'https://production.zankurd.invalid',
          bundledAnonKey: 'sb_publishable_public_client_key',
        ),
        isTrue,
      );
    });

    test('release rejects a missing Supabase configuration', () {
      expect(
        AppConfig.validateForRelease(
          isReleaseMode: true,
          requireRevenueCat: false,
          hasSupabaseOverride: false,
          hasRevenueCatOverride: true,
        ),
        contains(ReleaseConfigurationIssue.supabase),
      );
    });

    test('mobile release rejects a missing RevenueCat configuration', () {
      expect(
        AppConfig.validateForRelease(
          isReleaseMode: true,
          requireRevenueCat: true,
          hasSupabaseOverride: true,
          hasRevenueCatOverride: false,
        ),
        contains(ReleaseConfigurationIssue.revenueCat),
      );
    });

    test('debug and fully configured release builds remain valid', () {
      expect(
        AppConfig.validateForRelease(
          isReleaseMode: false,
          requireRevenueCat: true,
          hasSupabaseOverride: false,
          hasRevenueCatOverride: false,
        ),
        isEmpty,
      );
      expect(
        AppConfig.validateForRelease(
          isReleaseMode: true,
          requireRevenueCat: true,
          hasSupabaseOverride: true,
          hasRevenueCatOverride: true,
        ),
        isEmpty,
      );
    });
  });
}
