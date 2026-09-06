import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/services/native_auth_service.dart';

/// iOS'ta Google/Apple girişinin native SDK yolundan gittiğini ve sağlayıcı
/// ekranının kapatılmasının hata sayılmadığını bağlar.
///
/// ## Kusur
///
/// Native akış eklendiğinde `native_auth_service_test.dart` yalnız
/// `NativeAuthCredential`in alanlarını okuyordu — yani veri sınıfı test
/// ediliyordu, akışın kendisi değil. `AuthProvider`ın hangi platformda native
/// SDK'ya, hangisinde tarayıcı tabanlı Supabase OAuth'una gittiği; iptalin
/// `false` dönüp **hata mesajı üretmediği**; misafir hesabı bağlamanın da aynı
/// yoldan geçtiği hiçbir yerde ölçülmüyordu.
///
/// ## Niçin ölçülemiyordu
///
/// `AuthProvider.test()` `_client`i `null` bırakır ve `_run` istemci yokken
/// gövdeyi hiç çalıştırmadan `true` döner. Yani sahte bir `NativeAuthService`
/// enjekte edilse bile hiç çağrılmıyordu. Çözüm, `supabase_offline_fallback`
/// testlerinin kullandığı yolun aynısı: gerçek bir `SupabaseClient`, ama her
/// isteği anında reddeden bir HTTP client ile. İptal yolu ağa hiç çıkmadan
/// döndüğü için bu testler deterministik ve soketsizdir.
class _AlwaysFailingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw Exception('injected: ağ erişilemez');
  }
}

/// Hangi sağlayıcının sorulduğunu sayar; `credential` verilmezse SDK'nın
/// kullanıcı tarafından kapatılmasını (iptal) taklit eder.
class _RecordingNativeAuthService implements NativeAuthService {
  _RecordingNativeAuthService({this.google, this.apple});

  final NativeAuthCredential? google;
  final NativeAuthCredential? apple;

  int googleCalls = 0;
  int appleCalls = 0;

  @override
  Future<NativeAuthCredential?> signInWithGoogle() async {
    googleCalls++;
    return google;
  }

  @override
  Future<NativeAuthCredential?> signInWithApple() async {
    appleCalls++;
    return apple;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingNativeAuthService native;

  AuthProvider providerFor(
    TargetPlatform platform, {
    NativeAuthCredential? google,
    NativeAuthCredential? apple,
  }) {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    native = _RecordingNativeAuthService(google: google, apple: apple);
    return AuthProvider(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: _AlwaysFailingHttpClient(),
      ),
      nativeAuth: native,
    );
  }

  group('iOS native SDK yolundan gider', () {
    test('Google girişi native servise sorar', () async {
      final auth = providerFor(TargetPlatform.iOS);
      addTearDown(auth.dispose);

      await auth.signInWithGoogle();

      expect(native.googleCalls, 1);
      expect(native.appleCalls, 0);
    });

    test('Apple girişi native servise sorar', () async {
      final auth = providerFor(TargetPlatform.iOS);
      addTearDown(auth.dispose);

      await auth.signInWithApple();

      expect(native.appleCalls, 1);
      expect(native.googleCalls, 0);
    });

    // Misafir ilerlemesini koruyan bağlama yolu da native olmalı: eskiden
    // giriş native, bağlama tarayıcı üzerinden gitseydi kullanıcı aynı
    // ekranda iki farklı akış görürdü.
    test('misafir hesabı Google ile bağlama da native servise sorar', () async {
      final auth = providerFor(TargetPlatform.iOS);
      addTearDown(auth.dispose);

      await auth.linkGoogleAccount();

      expect(native.googleCalls, 1);
    });

    test('misafir hesabı Apple ile bağlama da native servise sorar', () async {
      final auth = providerFor(TargetPlatform.iOS);
      addTearDown(auth.dispose);

      await auth.linkAppleAccount();

      expect(native.appleCalls, 1);
    });
  });

  group('sağlayıcı ekranını kapatmak hata değildir', () {
    test('iptal edilen Google girişi hata mesajı üretmez', () async {
      final auth = providerFor(TargetPlatform.iOS);
      addTearDown(auth.dispose);

      final success = await auth.signInWithGoogle();

      expect(success, isFalse);
      expect(
        auth.errorMessage,
        isNull,
        reason: 'Kullanıcı kendi kapattı; ekranda kırmızı hata çıkmamalı.',
      );
      expect(
        auth.isLoading,
        isFalse,
        reason: 'Yükleme perdesi asılı kalmamalı',
      );
    });

    test('iptal edilen Apple girişi hata mesajı üretmez', () async {
      final auth = providerFor(TargetPlatform.iOS);
      addTearDown(auth.dispose);

      final success = await auth.signInWithApple();

      expect(success, isFalse);
      expect(auth.errorMessage, isNull);
      expect(auth.isLoading, isFalse);
    });

    // İptalin sessiz olması, *gerçek* hataların da sessizleşmesi anlamına
    // gelmemeli. SDK bir kimlik döndürdüğünde akış Supabase'e devam eder ve
    // oradaki başarısızlık kullanıcıya söylenmelidir — yoksa düğmeye basan
    // kişi hiçbir şey olmamış gibi aynı ekranda kalır.
    test(
      'SDK kimlik döndürdüğünde Supabase hatası kullanıcıya söylenir',
      () async {
        final auth = providerFor(
          TargetPlatform.iOS,
          google: const NativeAuthCredential.google(
            idToken: 'gecerli-gorunumlu-token',
            accessToken: 'erisim-tokeni',
          ),
        );
        addTearDown(auth.dispose);

        final success = await auth.signInWithGoogle();

        expect(success, isFalse);
        expect(native.googleCalls, 1);
        expect(
          auth.errorMessage,
          isNotNull,
          reason:
              'Supabase erişilemezken akış iptalmiş gibi sessiz kalmamalı; '
              'kullanıcı niçin giremediğini görmeli.',
        );
        expect(auth.isLoading, isFalse);
      },
    );
  });

  group('iOS dışında tarayıcı tabanlı OAuth korunur', () {
    // Android'de `google_sign_in` yapılandırması yok; akış Supabase'in
    // `signInWithOAuth`una düşmeli. Native servise dokunulması, iOS'a özel
    // yapılandırmanın sessizce başka platforma sızdığı anlamına gelirdi.
    for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
      test('$platform Google girişinde native servise dokunmaz', () async {
        final auth = providerFor(platform);
        addTearDown(auth.dispose);

        await auth.signInWithGoogle();

        expect(native.googleCalls, 0);
      });

      test('$platform Apple girişinde native servise dokunmaz', () async {
        final auth = providerFor(platform);
        addTearDown(auth.dispose);

        await auth.signInWithApple();

        expect(native.appleCalls, 0);
      });
    }
  });
}
