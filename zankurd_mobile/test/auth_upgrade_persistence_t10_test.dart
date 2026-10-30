import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// No network: actual Supabase persistence/restoration, mock HTTP and preferences.
// iOS install-overlay proof is recorded separately; this guards SDK semantics.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'T10 anonymous session restores without another signup after restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      var signups = 0;
      const userId = '00000000-0000-4000-8000-000000000010';
      final expiry =
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
          1000;
      String segment(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token =
          '${segment({'alg': 'HS256'})}.${segment({'sub': userId, 'exp': expiry})}.fixture';
      final client = MockClient((request) async {
        expect(request.url.host, '127.0.0.1');
        expect(request.url.path, '/auth/v1/signup');
        signups++;
        return http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'local-fixture-refresh',
            'token_type': 'bearer',
            'expires_in': 86400,
            'expires_at': expiry,
            'user': {
              'id': userId,
              'aud': 'authenticated',
              'created_at': '2026-10-30T00:00:00Z',
              'is_anonymous': true,
              'app_metadata': <String, Object>{},
              'user_metadata': <String, Object>{},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      Future<Supabase> boot() => Supabase.initialize(
        url: 'http://127.0.0.1:55441',
        publishableKey: 'local-fixture-only',
        httpClient: client,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: false,
          detectSessionInUri: false,
        ),
      );

      final oldBoot = await boot();
      await oldBoot.client.auth.signInAnonymously();
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('sb-127-auth-token'), isTrue);
      await oldBoot.dispose();

      final newBoot = await boot();
      addTearDown(newBoot.dispose);
      expect(newBoot.client.auth.currentUser?.id, userId);
      expect(newBoot.client.auth.currentUser?.isAnonymous, isTrue);
      expect(newBoot.client.auth.currentSession, isNotNull);
      expect(
        signups,
        1,
        reason: 'Reinstall/restart must reuse the existing guest identity',
      );
    },
  );
}
