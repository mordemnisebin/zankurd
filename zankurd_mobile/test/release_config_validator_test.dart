import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/release_config_validator.dart';

void main() {
  group('Supabase release configuration', () {
    test('accepts only a root HTTPS Supabase project URL', () {
      expect(
        ReleaseConfigValidator.isSafeSupabaseUrl(
          'https://abcdefghijklmnopqrst.supabase.co',
        ),
        isTrue,
      );

      for (final unsafeUrl in [
        'http://abcdefghijklmnopqrst.supabase.co',
        'https://abcdefghijklmnopqrst.example.com',
        'https://user@abcdefghijklmnopqrst.supabase.co',
        'https://abcdefghijklmnopqrst.supabase.co/rest/v1',
        'https://abcdefghijklmnopqrst.supabase.co?debug=true',
        'https://-abcdefghijklmnopqrs.supabase.co',
        'https://abcdefghijklmnopqrs-.supabase.co',
        ' https://abcdefghijklmnopqrst.supabase.co',
      ]) {
        expect(
          ReleaseConfigValidator.isSafeSupabaseUrl(unsafeUrl),
          isFalse,
          reason: 'Unsafe Supabase URL must fail closed.',
        );
      }
    });

    test('accepts publishable keys and legacy anon JWTs', () {
      expect(
        ReleaseConfigValidator.isSafeSupabaseClientKey(
          'sb_publishable_abcdefghijklmnopqrstuvwxyz0123456789',
        ),
        isTrue,
      );
      expect(
        ReleaseConfigValidator.isSafeSupabaseClientKey(_jwtForRole('anon')),
        isTrue,
      );
    });

    test('rejects secret, service-role, and malformed Supabase keys', () {
      for (final unsafeKey in [
        'sb_'
            'secret_abcdefghijklmnopqrstuvwxyz0123456789',
        'service_role_not_a_client_key',
        _jwtForRole('service_role'),
        _jwtForRole('authenticated'),
        'header.not-base64.signature',
        'sb_publishable_short',
        ' sb_publishable_abcdefghijklmnopqrstuvwxyz0123456789',
      ]) {
        expect(
          ReleaseConfigValidator.isSafeSupabaseClientKey(unsafeKey),
          isFalse,
          reason: 'Privileged or malformed key must fail closed.',
        );
      }
    });
  });

  group('RevenueCat release configuration', () {
    test('accepts only the public SDK key for the selected platform', () {
      const androidKey = 'goog_abcdefghijklmnopqrstuvwxyz012345';
      const iosKey = 'appl_abcdefghijklmnopqrstuvwxyz012345';

      expect(
        ReleaseConfigValidator.isSafeRevenueCatKey(
          androidKey,
          platform: RevenueCatPlatform.android,
        ),
        isTrue,
      );
      expect(
        ReleaseConfigValidator.isSafeRevenueCatKey(
          iosKey,
          platform: RevenueCatPlatform.ios,
        ),
        isTrue,
      );
      expect(
        ReleaseConfigValidator.isSafeRevenueCatKey(
          iosKey,
          platform: RevenueCatPlatform.android,
        ),
        isFalse,
      );
      expect(
        ReleaseConfigValidator.isSafeRevenueCatKey(
          androidKey,
          platform: RevenueCatPlatform.ios,
        ),
        isFalse,
      );
    });

    test('rejects test and secret keys in production', () {
      for (final unsafeKey in [
        'test_abcdefghijklmnopqrstuvwxyz012345',
        'sk_'
            'abcdefghijklmnopqrstuvwxyz012345',
        'goog_short',
        'goog_your-public-sdk-key',
      ]) {
        expect(
          ReleaseConfigValidator.isSafeRevenueCatKey(
            unsafeKey,
            platform: RevenueCatPlatform.android,
          ),
          isFalse,
        );
      }
    });

    test('allows a Test Store key only behind the staging gate', () {
      const testStoreKey = 'test_abcdefghijklmnopqrstuvwxyz012345';

      expect(
        ReleaseConfigValidator.isSafeRevenueCatKey(
          testStoreKey,
          platform: RevenueCatPlatform.android,
          allowTestStoreKey: true,
        ),
        isTrue,
      );
      expect(
        ReleaseConfigValidator.isSafeRevenueCatKey(
          testStoreKey,
          platform: RevenueCatPlatform.ios,
          allowTestStoreKey: true,
        ),
        isTrue,
      );
    });
  });
}

String _jwtForRole(String role) {
  String part(Map<String, Object> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${part({'role': role, 'iss': 'supabase'})}.signature';
}
