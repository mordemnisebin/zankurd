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
