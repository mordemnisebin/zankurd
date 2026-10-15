/// Kayıtlı hesabın normal çıkışı yerel ilerlemeyi SİLMEZ.
///
/// Kusur: `signOut`, hesap türüne bakmadan seri, rozet, ustalık, yanlışlar ve
/// seviye ilerlemesini siliyordu. Kayıtlı kullanıcı çıkıp aynı telefonda
/// geri girdiğinde (ya da telefon değiştirdiğinde) hepsini kaybediyordu;
/// premium "seri koruma" satıyor ama seri hesapla gitmiyordu.
///
/// Niçin sessizdi: çıkış hata vermez, ilerleme "temizlendi" sanılırdı (çıkış
/// onay metni de böyle söylüyordu). Anahtarlar zaten kullanıcı kimliğine
/// kapsamlı olduğu için silmek gereksizdi; yabancı kullanıcı yalıtımı
/// kapsamdan geliyor, silmeden değil.
///
/// Misafir çıkışı ve hesap silme eskisi gibi siler (uyarı metni öyle diyor).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/progress_sync.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

class _OfflineHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw Exception('injected: ağ erişilemez');
}

User _user(String id, {bool anonymous = false}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-10-15T00:00:00Z',
  isAnonymous: anonymous,
);

/// Gerçek istemci kurulurken `initialSession` (oturumsuz) olayı bir sonraki
/// turda gelir ve `_currentUser`ı sıfırlar; testin kullanıcısını ezmesin diye
/// önce o olay boşaltılır.
Future<AuthProvider> _provider() async {
  final auth = AuthProvider(
    SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test_key',
      httpClient: _OfflineHttp(),
    ),
  );
  await pumpEventQueue();
  // Çıkış olayı test bittikten sonra gelebilir; atmadan önce boşalt.
  addTearDown(() async {
    await pumpEventQueue();
    auth.dispose();
  });
  return auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
    XPStore.resetInstance();
    StreakStore.resetInstance();
    BadgeService.resetInstance();
  });

  tearDown(ProgressSyncService.unbind);

  Future<void> seed(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      LocalProgressScope.physicalFor(userId, 'zankurd.xp.total'),
      640,
    );
    await prefs.setInt(
      LocalProgressScope.physicalFor(userId, 'zankurd.streak.current'),
      9,
    );
    await prefs.setStringList(
      LocalProgressScope.physicalFor(userId, 'zankurd.badges.unlocked'),
      ['perfect_game'],
    );
  }

  test(
    'kayıtlı kullanıcı çıkınca ilerleme diskte kalır, geri girince görünür',
    () async {
      await seed('reg-1');
      final auth = await _provider();
      await auth.debugPrepareSessionUser(_user('reg-1'), restartSync: false);
      expect(LocalProgressScope.activeUserId, 'reg-1');
      expect((await XPStore.load()).totalXP, 640);

      await auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          LocalProgressScope.physicalFor('reg-1', 'zankurd.xp.total'),
        ),
        640,
        reason: 'kayıtlı hesabın çıkışı XP\'yi silmemeli',
      );
      expect(
        prefs.getInt(
          LocalProgressScope.physicalFor('reg-1', 'zankurd.streak.current'),
        ),
        9,
      );
      expect(
        prefs.getStringList(
          LocalProgressScope.physicalFor('reg-1', 'zankurd.badges.unlocked'),
        ),
        ['perfect_game'],
      );

      // Aynı kullanıcı geri girer: eksiksiz görünür.
      XPStore.resetInstance();
      StreakStore.resetInstance();
      LocalProgressScope.debugReset();
      final again = await _provider();
      await again.debugPrepareSessionUser(_user('reg-1'), restartSync: false);
      expect((await XPStore.load()).totalXP, 640);
      expect((await StreakStore.load()).effectiveStreak(), isA<int>());
      expect((await BadgeService.load()).isUnlocked('perfect_game'), isTrue);
    },
  );

  test(
    'çıkış sonrası sahipsiz oturum çıkan hesabın kapsamını kullanmaz',
    () async {
      await seed('reg-1');
      final auth = await _provider();
      await auth.debugPrepareSessionUser(_user('reg-1'), restartSync: false);

      await auth.signOut();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(LocalProgressScope.ownerKey),
        LocalProgressScope.offlineUserId,
      );
      // Sonraki çevrimdışı oturum kendi ayrı kapsamına bağlanır.
      await LocalProgressScope.activateOffline(prefs);
      expect(LocalProgressScope.activeUserId, LocalProgressScope.offlineUserId);
    },
  );

  test(
    'başka bir kullanıcı girince önceki hesabın ilerlemesini görmez',
    () async {
      await seed('reg-1');
      final auth = await _provider();
      await auth.debugPrepareSessionUser(_user('reg-1'), restartSync: false);
      await auth.signOut();

      XPStore.resetInstance();
      LocalProgressScope.debugReset();
      final other = await _provider();
      await other.debugPrepareSessionUser(_user('reg-2'), restartSync: false);

      expect(LocalProgressScope.activeUserId, 'reg-2');
      expect((await XPStore.load()).totalXP, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          LocalProgressScope.physicalFor('reg-1', 'zankurd.xp.total'),
        ),
        640,
        reason: 'yalıtım kapsamdan gelir; ilk hesabın verisi yerinde',
      );
    },
  );

  test('misafir çıkışı yerel ilerlemeyi eskisi gibi siler', () async {
    await seed('guest-1');
    final auth = await _provider();
    await auth.debugPrepareSessionUser(
      _user('guest-1', anonymous: true),
      restartSync: false,
    );

    await auth.signOut();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(
        LocalProgressScope.physicalFor('guest-1', 'zankurd.xp.total'),
      ),
      isNull,
    );
    expect(
      prefs.getStringList(
        LocalProgressScope.physicalFor('guest-1', 'zankurd.badges.unlocked'),
      ),
      isNull,
    );
  });

  test(
    'hesap silme (discardPendingRewards) kayıtlı hesapta da siler',
    () async {
      await seed('reg-1');
      final auth = await _provider();
      await auth.debugPrepareSessionUser(_user('reg-1'), restartSync: false);

      await auth.signOut(
        discardPendingRewards: true,
        pendingRewardsOwnerId: 'reg-1',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          LocalProgressScope.physicalFor('reg-1', 'zankurd.xp.total'),
        ),
        isNull,
      );
    },
  );

  test('kayıtlı oturumda eşitleme bağlanır, misafirde bağlanmaz', () async {
    final registered = await _provider();
    await registered.debugPrepareSessionUser(
      _user('reg-1'),
      restartSync: false,
    );
    expect(ProgressSyncService.maybeInstance?.userId, 'reg-1');

    final guest = await _provider();
    await guest.debugPrepareSessionUser(
      _user('guest-1', anonymous: true),
      restartSync: false,
    );
    expect(ProgressSyncService.maybeInstance, isNull);
  });
}
