import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/config/release_config_validator.dart';

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
          revenueCatPlatform: RevenueCatPlatform.android,
        ),
        unorderedEquals([
          ReleaseConfigurationIssue.supabase,
          ReleaseConfigurationIssue.revenueCat,
        ]),
      );
    });

    test('release rejects privileged or malformed client values', () {
      expect(
        AppConfig.validateReleaseClientValues(
          supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
          supabaseAnonKey:
              'sb_'
              'secret_abcdefghijklmnopqrstuvwxyz0123456789',
          revenueCatKey: 'goog_abcdefghijklmnopqrstuvwxyz012345',
          requireRevenueCat: true,
          revenueCatPlatform: RevenueCatPlatform.android,
        ),
        contains(ReleaseConfigurationIssue.supabase),
      );
      expect(
        AppConfig.validateReleaseClientValues(
          supabaseUrl: 'https://abcdefghijklmnopqrst.example.com',
          supabaseAnonKey:
              'sb_publishable_abcdefghijklmnopqrstuvwxyz0123456789',
          revenueCatKey: 'test_abcdefghijklmnopqrstuvwxyz012345',
          requireRevenueCat: true,
          revenueCatPlatform: RevenueCatPlatform.android,
        ),
        unorderedEquals([
          ReleaseConfigurationIssue.supabase,
          ReleaseConfigurationIssue.revenueCat,
        ]),
      );
    });

    test('release rejects a RevenueCat key for the other platform', () {
      expect(
        AppConfig.validateReleaseClientValues(
          supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
          supabaseAnonKey:
              'sb_publishable_abcdefghijklmnopqrstuvwxyz0123456789',
          revenueCatKey: 'appl_abcdefghijklmnopqrstuvwxyz012345',
          requireRevenueCat: true,
          revenueCatPlatform: RevenueCatPlatform.android,
        ),
        contains(ReleaseConfigurationIssue.revenueCat),
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
            bundledUrl: 'https://abcdefghijklmnopqrst.supabase.co',
            bundledAnonKey:
                'sb_publishable_abcdefghijklmnopqrstuvwxyz0123456789',
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
          bundledUrl: 'https://abcdefghijklmnopqrst.supabase.co',
          bundledAnonKey: 'sb_publishable_abcdefghijklmnopqrstuvwxyz0123456789',
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
