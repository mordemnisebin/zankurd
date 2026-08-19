import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/analytics_consent_provider.dart';

/// Çağrılırsa testi düşürür — "kullanım analizi" anahtarı kapalıyken bu
/// uca hiç istek gitmemeli.
class _FailIfCalledHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError('Beklenmedik istek: ${request.url.path}');
  }
}

class _LogAnalyticsEventHttpClient extends http.BaseClient {
  final requestedPaths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    final bytes = utf8.encode(
      jsonEncode([
        {'success': true},
      ]),
    );
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  group('logAnalyticsEvent — ikinci ölçüm yolu (2026-08-14 denetimi)', () {
    // `AnalyticsConsentProvider.isEnabled` bir statik alan; her testte
    // sıfırdan başlasın diye açıkça kapatılır.
    setUp(() => AnalyticsConsentProvider.isEnabled = false);
    tearDown(() => AnalyticsConsentProvider.isEnabled = false);

    test('anahtar kapalıyken sunucuya hiç istek gitmez', () async {
      // Ayarlar > Gizlilik'te "Kullanım analizi" kapalı (varsayılan) iken
      // bile her tur/ders/arkadaşlık isteği kullanıcı kimliğiyle
      // Supabase'e yazılıyordu — anahtar yalnız Firebase Analytics'i
      // durduruyordu.
      final repo = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _FailIfCalledHttpClient(),
        ),
      );

      final result = await repo.logAnalyticsEvent('quiz_complete', null);
      expect(result, isFalse);
    });

    test('anahtar açıkken olay gerçekten gönderilir', () async {
      AnalyticsConsentProvider.isEnabled = true;
      final httpClient = _LogAnalyticsEventHttpClient();
      final repo = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final result = await repo.logAnalyticsEvent('quiz_complete', null);
      expect(result, isTrue);
      expect(httpClient.requestedPaths, ['/rest/v1/rpc/log_analytics_event']);
    });

    test('setEnabled(false) statik bayrağı da kapatır', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = await AnalyticsConsentProvider.load();
      await provider.setEnabled(true);
      expect(AnalyticsConsentProvider.isEnabled, isTrue);
      await provider.setEnabled(false);
      expect(AnalyticsConsentProvider.isEnabled, isFalse);
    });
  });

  test('consent is off by default and persists when enabled', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = await AnalyticsConsentProvider.load();
    expect(provider.enabled, isFalse);

    await provider.setEnabled(true);
    final reloaded = await AnalyticsConsentProvider.load();
    expect(reloaded.enabled, isTrue);
  });

  test('analytics consent defaults to off and persists a user choice', () {
    final provider = File(
      'lib/src/providers/analytics_consent_provider.dart',
    ).readAsStringSync();

    expect(provider, contains("prefs.getBool(_storageKey) ?? false"));
    expect(provider, contains('setBool(_storageKey, value)'));
  });

  test('analytics initialization is gated by consent', () {
    final main = File('lib/main.dart').readAsStringSync();
    final settings = File(
      'lib/src/screens/settings_screen.dart',
    ).readAsStringSync();

    expect(main, contains('if (analyticsConsentProvider.enabled)'));
    expect(settings, contains('analytics-consent-switch'));
    expect(settings, contains('AnalyticsService.instance.initialize()'));
  });
}
