import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/analytics_consent_provider.dart';
import 'package:zankurd_mobile/src/utils/error_reporter.dart';

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

  // 2026-10-29 (Opus 5.5 + GPT-6 Astra kararı): kullanım analizi ve hata
  // raporları AYRI anahtar, ikisi de seçim yokken KAPALI. 2026-10-23'teki
  // "varsayılan açık" seçimden önce veri gönderiyordu; Ayarlar'dan
  // kapatılabilmesi önceden izin sayılmaz.
  test('seçim yokken ikisi de kapalı; açma kalıcı', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = await AnalyticsConsentProvider.load();
    expect(provider.enabled, isFalse);
    expect(provider.crashReportsEnabled, isFalse);
    expect(AnalyticsConsentProvider.isEnabled, isFalse);
    expect(ErrorReporter.crashlyticsEnabled, isFalse);

    await provider.setEnabled(true);
    final reloaded = await AnalyticsConsentProvider.load();
    expect(reloaded.enabled, isTrue);
    // Analizi açmak hata raporlarını açmaz.
    expect(reloaded.crashReportsEnabled, isFalse);
  });

  test('hata raporları ayrı açılır; analiz bayrağına dokunmaz', () async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      ErrorReporter.resetFatalHandlersForTesting();
      ErrorReporter.crashlyticsEnabled = false;
    });
    final provider = await AnalyticsConsentProvider.load();
    await provider.setCrashReportsEnabled(true);
    expect(provider.crashReportsEnabled, isTrue);
    expect(ErrorReporter.crashlyticsEnabled, isTrue);
    expect(provider.enabled, isFalse);
    expect(AnalyticsConsentProvider.isEnabled, isFalse);
    final reloaded = await AnalyticsConsentProvider.load();
    expect(reloaded.crashReportsEnabled, isTrue);
    expect(reloaded.enabled, isFalse);
  });

  test('eski tek anahtardaki AÇIK seçim iki rızaya da taşınır', () async {
    // Eski anahtar ikisini birlikte yönetiyordu; açıkça saklanmış seçim
    // korunur. Anahtar hiç yoksa (seçim yapılmamış) kapalı başlar.
    SharedPreferences.setMockInitialValues({'zankurd.analyticsConsent': true});
    addTearDown(() => ErrorReporter.crashlyticsEnabled = false);
    final provider = await AnalyticsConsentProvider.load();
    expect(provider.enabled, isTrue);
    expect(provider.crashReportsEnabled, isTrue);
  });

  test('daha önce kapatılmış seçim korunur', () async {
    SharedPreferences.setMockInitialValues({'zankurd.analyticsConsent': false});
    final provider = await AnalyticsConsentProvider.load();
    expect(provider.enabled, isFalse);
    expect(provider.crashReportsEnabled, isFalse);
  });

  test('analizi açmadan önce hata raporu seçimi diske yazılır', () async {
    // İlk yüklemede hata raporu anahtarı yazılamadıysa, analizi açan yazım
    // önce onu (kapalı) kaydeder; yoksa sonraki açılışta eski anahtardan
    // devralma analiz seçimini hata raporlarına da taşırdı.
    SharedPreferences.setMockInitialValues({});
    final provider = AnalyticsConsentProvider();
    expect(await provider.setEnabled(true), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('zankurd.crashReportsConsent'), isFalse);
    final reloaded = await AnalyticsConsentProvider.load();
    expect(reloaded.enabled, isTrue);
    expect(reloaded.crashReportsEnabled, isFalse);
  });

  test(
    'başarısız devralma sonrası önbellekteki anahtar güvence sayılmaz',
    () async {
      // Önbellekte anahtar var ama devralma yazımı başarısızdı: analiz yazımı
      // hata raporu seçimini yeniden yazmadan geçmemeli.
      SharedPreferences.setMockInitialValues({
        'zankurd.crashReportsConsent': true,
      });
      final provider = AnalyticsConsentProvider();
      AnalyticsConsentProvider.debugMarkCrashChoicePending();
      expect(await provider.setEnabled(true), isTrue);
      final prefs = await SharedPreferences.getInstance();
      // Yeniden yazım provider'ın gerçek (kapalı) seçimini kaydeder.
      expect(prefs.getBool('zankurd.crashReportsConsent'), isFalse);
    },
  );

  test('yükseltmede kalıcı SDK izni Dart\'tan önce kapatılır', () {
    // 2.1.1+41 ve öncesinde SDK'lara `true` KALICI yazıldı; manifest/plist
    // varsayılanı bunu ezmez. Android'de MainActivity, iOS'ta Firebase
    // kurulur kurulmaz iki ölçüm de kapatılır; rıza varsa sonra açılır.
    final activity = File(
      'android/app/src/main/kotlin/com/zankurd/zankurd_mobile/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('enforceMeasurementConsent()'));
    expect(activity, contains('flutter.zankurd.analyticsConsent'));
    expect(activity, contains('flutter.zankurd.crashReportsConsent'));
    expect(activity, contains('setAnalyticsCollectionEnabled'));
    expect(activity, contains('setCrashlyticsCollectionEnabled'));
    final main = File('lib/main.dart').readAsStringSync();
    expect(
      main,
      contains(
        'await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);',
      ),
    );
    // Crashlytics, Activity'den (ve arka plan başlangıcından) önce
    // FirebaseInitProvider ile başlar; kalıcı izni daha önce çalışan
    // sağlayıcı kapatır.
    final provider = File(
      'android/app/src/main/kotlin/com/zankurd/zankurd_mobile/ConsentInitProvider.kt',
    ).readAsStringSync();
    expect(provider, contains('"com.google.firebase.crashlytics"'));
    expect(provider, contains('"firebase_crashlytics_collection_enabled"'));
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(
      RegExp(
        r'android:name="\.ConsentInitProvider"[\s\S]*?android:initOrder="200"',
      ).hasMatch(manifest),
      isTrue,
    );
  });

  test('rıza yokken hata kaydı Crashlytics\'e gitmez', () {
    // ErrorReporter.record bayrak kapalıyken Firebase'e dokunmadan döner;
    // test ortamında Firebase yok — dokunsaydı yakalanan istisnaya düşerdi,
    // bu yüzden kaynağı da sabitliyoruz.
    ErrorReporter.crashlyticsEnabled = false;
    ErrorReporter.record(StateError('x'), StackTrace.current);
    final src = File('lib/src/utils/error_reporter.dart').readAsStringSync();
    expect(src, contains('if (kIsWeb || !crashlyticsEnabled) return;'));
  });

  test('yerel SDK\'lar seçimden önce toplamaz (plist + manifest)', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in [
      'FIREBASE_ANALYTICS_COLLECTION_ENABLED',
      'FirebaseCrashlyticsCollectionEnabled',
    ]) {
      expect(
        RegExp('<key>$key</key>\\s*<false/>').hasMatch(plist),
        isTrue,
        reason: '$key Info.plist\'te false olmalı',
      );
    }
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final key in [
      'firebase_analytics_collection_enabled',
      'firebase_crashlytics_collection_enabled',
    ]) {
      expect(
        RegExp(
          'android:name="$key"\\s*android:value="false"',
        ).hasMatch(manifest),
        isTrue,
        reason: '$key AndroidManifest\'te false olmalı',
      );
    }
  });

  test(
    'consent sonradan açılınca fatal hata yakalayıcıları da bağlanır',
    () async {
      SharedPreferences.setMockInitialValues({});
      final originalFlutterHandler = FlutterError.onError;
      final originalPlatformHandler = PlatformDispatcher.instance.onError;
      void sentinelFlutterHandler(FlutterErrorDetails details) {}
      bool sentinelPlatformHandler(Object error, StackTrace stack) => false;
      FlutterError.onError = sentinelFlutterHandler;
      PlatformDispatcher.instance.onError = sentinelPlatformHandler;
      addTearDown(() {
        ErrorReporter.resetFatalHandlersForTesting();
        FlutterError.onError = originalFlutterHandler;
        PlatformDispatcher.instance.onError = originalPlatformHandler;
        ErrorReporter.crashlyticsEnabled = false;
      });

      final provider = await AnalyticsConsentProvider.load();
      await provider.setCrashReportsEnabled(true);

      expect(ErrorReporter.crashlyticsEnabled, isTrue);
      expect(FlutterError.onError, isNot(same(sentinelFlutterHandler)));
      expect(
        PlatformDispatcher.instance.onError,
        isNot(same(sentinelPlatformHandler)),
      );
    },
  );

  test('analytics consent defaults to off and persists a user choice', () {
    final provider = File(
      'lib/src/providers/analytics_consent_provider.dart',
    ).readAsStringSync();

    expect(provider, contains('analytics ?? defaultEnabled'));
    expect(provider, contains('static const defaultEnabled = false;'));
    expect(provider, contains('prefs.setBool(key, value)'));
  });

  test('analytics initialization is gated by consent', () {
    final main = File('lib/main.dart').readAsStringSync();
    final settings = File(
      'lib/src/screens/settings_screen.dart',
    ).readAsStringSync();

    expect(main, contains('if (analyticsConsentProvider.enabled)'));
    expect(main, contains('analyticsConsentProvider.crashReportsEnabled'));
    expect(settings, contains('analytics-consent-switch'));
    expect(settings, contains('crash-reports-consent-switch'));
    expect(
      settings,
      contains('AnalyticsService.instance.initialize(enabled: true)'),
    );
    expect(
      main,
      contains('AnalyticsService.instance.initialize(enabled: true)'),
    );
  });

  test(
    'setEnabled tamamlanırken provider dispose edilirse hata fırlatmaz ve true döner',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = await AnalyticsConsentProvider.load();
      final future = provider.setEnabled(false);
      provider.dispose();
      expect(await future, isTrue);
      expect(AnalyticsConsentProvider.isEnabled, isFalse);
    },
  );
}
