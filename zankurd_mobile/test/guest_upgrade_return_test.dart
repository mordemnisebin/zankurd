/// E-posta onaylı misafir yükseltmesi uygulamaya DÖNMELİ.
///
/// Kusur: `upgradeGuestAccount`, `updateUser`a yönlendirme vermiyordu
/// (onay bağlantısı site adresine gidiyordu) ve onaydan sonra oturumu
/// tazeleyen hiçbir şey yoktu: JWT `is_anonymous` taşımaya devam ediyor,
/// `isGuest` yeniden başlatmaya kadar `true` kalıyor, kullanıcı hesabını
/// kaydettiğini sanırken uygulama onu misafir sayıyordu.
///
/// Niçin sessizdi: test ortamında onay bağlantısı hiç açılmaz; yalnız
/// gerçek bir cihazda, posta uygulamasından geri dönüldüğünde görünür.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

class _OfflineHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw Exception('injected: ağ erişilemez');
}

User _user({required bool anonymous, String? pendingEmail}) => User(
  id: 'u-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-15T00:00:00Z',
  isAnonymous: anonymous,
  newEmail: pendingEmail,
  email: anonymous ? '' : 'rojda@example.com',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
  });

  test('onay bekleyen yükseltme yalnız anonim + new_email iken sayılır', () {
    expect(
      AuthProvider.hasPendingUpgrade(
        _user(anonymous: true, pendingEmail: 'a@b.co'),
      ),
      isTrue,
    );
    expect(AuthProvider.hasPendingUpgrade(_user(anonymous: true)), isFalse);
    expect(
      AuthProvider.hasPendingUpgrade(
        _user(anonymous: false, pendingEmail: 'a@b.co'),
      ),
      isFalse,
    );
    expect(AuthProvider.hasPendingUpgrade(null), isFalse);
  });

  test(
    'onaydan sonra ön plana dönüş isGuest\'i yeniden başlatmadan çevirir',
    () async {
      final auth = AuthProvider(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _OfflineHttp(),
        ),
      );
      addTearDown(auth.dispose);
      await auth.debugPrepareSessionUser(
        _user(anonymous: true, pendingEmail: 'rojda@example.com'),
        restartSync: false,
      );
      expect(auth.isGuest, isTrue);

      var notified = 0;
      auth.addListener(() => notified++);
      final flipped = await auth.refreshGuestUpgrade(
        refresh: (_) async => _user(anonymous: false),
      );

      expect(flipped, isTrue);
      expect(auth.isGuest, isFalse);
      expect(auth.needsEmailConfirmation, isFalse);
      expect(notified, greaterThan(0));
    },
  );

  test(
    'ağ çağrısı yalnız bekleyen yükseltmede ve 10 sn\'de bir yapılır',
    () async {
      final auth = AuthProvider(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _OfflineHttp(),
        ),
      );
      addTearDown(auth.dispose);

      var calls = 0;
      Future<User?> refresh(SupabaseClient _) async {
        calls++;
        return _user(anonymous: true, pendingEmail: 'rojda@example.com');
      }

      // Sıradan misafir: hiç ağ çağrısı yok.
      await auth.debugPrepareSessionUser(
        _user(anonymous: true),
        restartSync: false,
      );
      await auth.refreshGuestUpgrade(refresh: refresh);
      expect(calls, 0);

      await auth.debugPrepareSessionUser(
        _user(anonymous: true, pendingEmail: 'rojda@example.com'),
        restartSync: false,
      );
      final t0 = DateTime(2026, 10, 15, 12);
      await auth.refreshGuestUpgrade(refresh: refresh, now: t0);
      await auth.refreshGuestUpgrade(
        refresh: refresh,
        now: t0.add(const Duration(seconds: 3)),
      );
      expect(calls, 1, reason: '10 sn içinde ikinci çağrı sınırlanır');
      await auth.refreshGuestUpgrade(
        refresh: refresh,
        now: t0.add(const Duration(seconds: 11)),
      );
      expect(calls, 2);
    },
  );

  test('yükseltme çağrısı uygulamanın yönlendirmesini taşır ve yaşam '
      'döngüsünde tazeler', () {
    final source = File(
      'lib/src/providers/auth_provider.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<bool> upgradeGuestAccount(');
    final body = source.substring(start, start + 900);
    expect(body, contains('emailRedirectTo: authRedirectUri'));
    expect(source, contains('AppLifecycleState.resumed'));
    expect(source, contains('refreshGuestUpgrade()'));
  });

  test('yaşam döngüsü: resumed olayı tazelemeyi tetikler', () {
    // WidgetsBindingObserver bağlı kalır ve dispose'ta çıkarılır.
    final auth = AuthProvider(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: _OfflineHttp(),
      ),
    );
    expect(
      () => auth.didChangeAppLifecycleState(AppLifecycleState.resumed),
      returnsNormally,
    );
    auth.dispose();
  });
}
