// Soğuk açılışta geç kurtarmanın DÖRT kusuru (2026-10-02 denetimi):
//
//   1. Kurtarma kök widget'ı yeni `key` ile yeniden `runApp` ediyordu —
//      `GlobalKey` Flutter'ın eski `MaterialApp` elementini ağaç sökmeden
//      geri alması yüzünden rota yığını DEĞİŞMİYOR, açık rotalar eski
//      çevrimdışı depoyla kalıyordu.
//   2. `RemoteAvailability` zaman aşan probe yolculuğunu bırakıp yenisini
//      başlatıyordu (eşzamanlı çok istek).
//   3. Kurtarma sıfırdan `AuthProvider` kuruyordu → yeni anonim oturum
//      riski, misafirin yerel ilerlemesi başka kimliğe taşınabilirdi.
//   4. Probe, başlatma hata verince `Supabase.initialize`ı BİR DAHA
//      çağırıyordu → "already initialized" ile kalıcı çevrimdışı.
//
// Bu dosya 1 ve 3'ü kilitler: kurtarma ağaç tazelemez, yalnız depo
// takası yapar; oturum yoksa TAKAS YOKTUR (anonim oturum açılmaz,
// SharedPreferences silinmez).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/offline_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/repository_holder.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/services/remote_upgrade.dart';

import 'support/widget_test_helpers.dart';

/// Kayıtlı (kalıcı) oturumu taklit eden istemci.
///
/// [signInAnonymously] fırlatarak kurtarmanın YENİ anonim oturum
/// AÇAMADIĞINI doğrular: çağrılsa bile test düşer.
class _SessionGoTrue extends GoTrueClient {
  _SessionGoTrue(this.session)
    : super(url: 'https://example.invalid/auth/v1', autoRefreshToken: false);

  final Session? session;

  @override
  Session? get currentSession => session;

  @override
  User? get currentUser => session?.user;

  @override
  Future<AuthResponse> signInAnonymously({
    Map<String, dynamic>? data,
    String? captchaToken,
  }) => fail('kurtarmada anonim oturum AÇILMAMALI');
}

class _FakeSupabaseClient extends SupabaseClient {
  _FakeSupabaseClient(GoTrueClient authClient)
    : _authClient = authClient,
      super(
        'https://example.invalid',
        'anon-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  final GoTrueClient _authClient;

  @override
  GoTrueClient get auth => _authClient;
}

/// `currentUserId` okumasını SAYAR — kabuğun hangi depoyu okuduğunun
/// kanıtı.
class _CountingRepository extends MockZanKurdRepository {
  int userIdReads = 0;

  @override
  String? get currentUserId {
    userIdReads += 1;
    return 'user';
  }
}

Session _session(String userId) => Session(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  tokenType: 'bearer',
  user: User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00.000Z',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kurtarma oturumu', () {
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'zankurd.xp.total': '123'});
      LocalProgressScope.debugReset();
      await SyncManager.resetForTesting();
      preferences = await SharedPreferences.getInstance();
    });

    test('kayıtlı oturum YOKSA kurtarma vazgeçer — anonim oturum açılmaz, '
        'depo değişmez, yerel ilerleme silinmez', () async {
      final authProvider = AuthProvider.offline();
      expect(await authProvider.signInAsGuest(), isTrue);
      expect(authProvider.isAuthenticated, isTrue);

      final client = _FakeSupabaseClient(_SessionGoTrue(null));
      final holder = RepositoryHolder(OfflineZanKurdRepository());

      final applied = await upgradeOfflineBootToRemote(
        client: client,
        authProvider: authProvider,
        repositoryHolder: holder,
        createRepository: (_) => fail('depoya geçilmemeli'),
        onRepositoryReady: (_) => fail('SyncManager kurulmamalı'),
      );

      expect(applied, isFalse, reason: 'oturum yoksa kurtarma uygulanmaz');
      expect(
        holder.repository,
        isA<OfflineZanKurdRepository>(),
        reason: 'sağlayıcı değişmeden kalmalı',
      );
      expect(
        authProvider.isOfflineMode,
        isTrue,
        reason: 'çevrimdışı mod korunmalı',
      );
      expect(
        authProvider.isAuthenticated,
        isTrue,
        reason: 'misafir oturumu kaybolmamalı',
      );
      expect(
        client.auth.currentSession,
        isNull,
        reason: 'yeni anonim oturum açılmamalı',
      );
      await preferences.reload();
      expect(
        preferences.getString('zankurd.xp.total'),
        '123',
        reason: 'yerel ilerleme silinmemeli',
      );
    });

    test('kayıtlı oturum yeniden kullanılır — depo takası uygulanır, '
        'anonim oturum AÇILMAZ', () async {
      final authProvider = AuthProvider.offline();
      await authProvider.signInAsGuest();

      final client = _FakeSupabaseClient(_SessionGoTrue(_session('user-1')));
      final holder = RepositoryHolder(OfflineZanKurdRepository());
      var syncCalls = 0;
      ZanKurdRepository? syncedWith;

      final applied = await upgradeOfflineBootToRemote(
        client: client,
        authProvider: authProvider,
        repositoryHolder: holder,
        createRepository: (_) => _CountingRepository(),
        onRepositoryReady: (repository) async {
          syncCalls += 1;
          syncedWith = repository;
        },
      );

      expect(applied, isTrue, reason: 'kurtarma uygulanmalı');
      expect(
        holder.repository,
        isA<_CountingRepository>(),
        reason: 'yeni depoya geçilmeli',
      );
      expect(syncCalls, 1, reason: 'senkron bir kez kurulmalı');
      expect(identical(syncedWith, holder.repository), isTrue);
      expect(authProvider.isOfflineMode, isFalse);
      expect(
        authProvider.currentUser?.id,
        'user-1',
        reason: 'kalıcı Supabase oturumu yeniden kullanılmalı',
      );
      expect(
        client.auth.currentSession?.user.id,
        'user-1',
        reason: 'oturum aynen durmalı — yenisi açılmamalı',
      );
      expect(
        LocalProgressScope.activeUserId,
        'user-1',
        reason: 'yerel ilerleme yeni oturuma bağlanmalı',
      );
      await preferences.reload();
      // Normal girişteki göçle aynı: genel anahtar kullanıcının kapsamına
      // TAŞINIR (`LocalProgressScope.migrateLegacy`); değer kaybolmaz.
      expect(
        preferences.getString(
          LocalProgressScope.physicalFor('user-1', 'zankurd.xp.total'),
        ),
        '123',
        reason: 'yerel ilerleme kullanıcının kapsamına taşınmalı, silinmemeli',
      );
    });
  });

  group('kabuk depo takası', () {
    testWidgets('takas kabuğa yansır, kök ağaç tazelenmez', (tester) async {
      // Store tekillerini sıfırla ve hazır ayarları yaz (yan etki).
      freshMockRepository();
      final opening = _CountingRepository();
      final replacement = _CountingRepository();
      final holder = RepositoryHolder(opening);

      await tester.pumpWidget(
        testShell(
          repositoryHolder: holder,
          child: AppShell(
            repository: opening,
            connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        opening.userIdReads,
        greaterThan(0),
        reason: 'kabuk açılış deposunu okumalı',
      );
      final shell = tester.widget<AppShell>(find.byType(AppShell));
      final readsBefore = opening.userIdReads;

      holder.switchTo(replacement);
      await tester.pumpAndSettle();

      expect(
        replacement.userIdReads,
        greaterThan(0),
        reason: 'kabuk YENİ depodan okumalı',
      );
      expect(
        opening.userIdReads,
        readsBefore,
        reason: 'eski depo artık okunmamalı',
      );
      expect(
        identical(tester.widget<AppShell>(find.byType(AppShell)), shell),
        isTrue,
        reason: 'ağaç tazelenmemiş olmalı — kurtarma rota yığını bozmaz',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
