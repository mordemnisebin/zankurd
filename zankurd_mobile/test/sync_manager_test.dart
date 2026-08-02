import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';

/// Her isteği anında reddeden HTTP client — gerçek soket açılmaz.
class _AlwaysFailingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw Exception('injected: ağ erişilemez');
  }
}

/// Cihaz çevrimdışı: `sync()` kuyruğa dokunmadan döner.
class _OfflineConnectivityMonitor implements ConnectivityMonitor {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => const [
    ConnectivityResult.none,
  ];
}

class _ThrowingConnectivityMonitor implements ConnectivityMonitor {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    throw StateError('connectivity listener unavailable');
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    throw StateError('connectivity check unavailable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncManager.resetForTesting();
  });

  test('SyncManager eski XP kuyruğunu güvenle temizler', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.syncQueue':
          '[{"type":"sync_xp","xp":150,"delta":150,"retries":0}]',
    });
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    await manager.sync();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zankurd.syncQueue'), '[]');
  });

  test(
    'SyncManager initializes even when connectivity plugin is unavailable',
    () async {
      final repository = MockZanKurdRepository();

      final manager = await SyncManager.initialize(
        repository,
        connectivityMonitor: _ThrowingConnectivityMonitor(),
      );

      await manager.sync();

      expect(manager, isA<SyncManager>());
    },
  );

  test('clearQueue resets pending updates in memory and preferences', () async {
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    await manager.queueQuizReward(
      score: 100,
      correctCount: 1,
      bestStreak: 1,
      totalQuestions: 1,
    );
    await manager.clearQueue();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zankurd.syncQueue'), '[]');
  });

  // 2026-07-25 denetim bulgusu: çıkışta yalnız dispose() çağrılıyor,
  // `_instance` dolu kalıyordu. Sonraki initialize() erken dönüyor ve
  // connectivity dinleyicisi bir daha kurulmuyordu — çevrimdışı XP
  // senkronizasyonu uygulama ömrü boyunca ölüyordu.
  test('shutdown yeni bir SyncManager kurulmasına izin verir', () async {
    final repository = MockZanKurdRepository();
    final first = await SyncManager.initialize(repository);

    await SyncManager.shutdown();

    final second = await SyncManager.initialize(repository);
    expect(identical(first, second), isFalse);
    expect(SyncManager.instance, same(second));
  });

  // 2026-07-31 denetim bulgusu: `initialize` uygulama ömrü boyunca yalnız
  // `main()` içinde bir kez çağrılıyor, `signOut()` ise her seferinde
  // `shutdown()` ile singleton'ı boşaltıyordu. Onu geri kuran hiçbir yer
  // yoktu, dolayısıyla aynı oturumda çıkıp tekrar giren kullanıcıda:
  //
  // * çevrimdışı ödül kuyruğu o oturum boyunca tamamen ölüydü,
  // * `SyncManager.instance` `StateError` fırlatıyordu ve bu çağrı
  //   `_claimCoins` içinde try bloğunun DIŞINDA durduğu için istisna
  //   `Navigator.pushReplacement(QuizResultScreen)` satırına ulaşmadan
  //   yukarı kaçıyordu — oyuncu son soruda, düğmesi kilitli hâlde takılı
  //   kalıyor, turunun sonucunu hiç göremiyordu.
  test('çıkış sonrası yeniden giriş kuyruğu ayağa kaldırır', () async {
    final repository = MockZanKurdRepository();
    await SyncManager.initialize(repository);

    await SyncManager.shutdown();
    expect(
      SyncManager.maybeInstance,
      isNull,
      reason: 'shutdown singleton ı bırakmalı.',
    );

    await SyncManager.restart();
    expect(
      SyncManager.maybeInstance,
      isNotNull,
      reason: 'Yeni oturumda kuyruk yeniden kurulmalı.',
    );
    // Kurulduktan sonra fırlatmayan erişim de fırlatan erişim de çalışır.
    expect(() => SyncManager.instance, returnsNormally);
  });

  test('hiç kurulmamışken restart sessizce döner', () async {
    // Test ortamı ve Supabase yapılandırması olmayan derlemeler için:
    // `restart` bir şey bulamazsa fırlatmamalı.
    expect(SyncManager.maybeInstance, isNull);
    await SyncManager.restart();
    expect(SyncManager.maybeInstance, isNull);
  });

  test('maybeInstance kurulu değilken fırlatmaz', () async {
    expect(SyncManager.maybeInstance, isNull);
    expect(() => SyncManager.instance, throwsStateError);
  });

  test('shutdown bekleyen kayıtları temizler', () async {
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    await manager.queueQuizReward(
      score: 100,
      correctCount: 1,
      bestStreak: 1,
      totalQuestions: 1,
    );
    await SyncManager.shutdown();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zankurd.syncQueue'), '[]');
  });

  // Kuyruk canlı liste üzerinde döndüğü için, `await` sırasında gelen yeni
  // kayıt ConcurrentModificationError fırlatmamalı.
  test('sync sırasında yeni kayıt eklemek çökmeye yol açmaz', () async {
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    Future<void> queueReward(int score) => manager.queueQuizReward(
      score: score,
      correctCount: 1,
      bestStreak: 1,
      totalQuestions: 1,
    );

    final firstQueued = queueReward(100);
    final syncing = manager.sync();
    final secondQueued = queueReward(200);
    final thirdQueued = queueReward(300);
    await Future.wait([firstQueued, secondQueued, thirdQueued, syncing]);
    await manager.sync();

    expect(manager.pendingCount, 0);
  });

  test('eşzamanlı sync çağrıları tek tur olarak çalışır', () async {
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    await manager.queueQuizReward(
      score: 100,
      correctCount: 1,
      bestStreak: 1,
      totalQuestions: 1,
    );
    await Future.wait([manager.sync(), manager.sync(), manager.sync()]);

    expect(manager.pendingCount, 0);
  });

  test('istemci artık XP senkronizasyon API yüzeyi sunmaz', () {
    final source = File('lib/src/data/sync_manager.dart').readAsStringSync();
    expect(source, isNot(contains('void queueXP(')));
    expect(source, isNot(contains('awardProfileXPDelta(')));
    expect(source, contains('Dropping unsupported legacy XP item'));
  });

  test('çevrimdışı bitirilen turun ödülü kuyrukta kalır', () async {
    // 2026-07-26: çevrimdışı bitirilen turda `claim_quiz_reward` düşüyor,
    // coin sessizce kayboluyordu. XP aynı durumda kuyruğa giriyordu; coin
    // girmiyordu. Kuyruğa giren şey miktar değil turun olgularıdır — ödülü
    // yine sunucu hesaplar.
    //
    // Sahte depo yolunda `sync()` kuyruğu boşalttığı için gerçek Supabase
    // deposu ve çevrimdışı bir bağlantı gözlemcisi kullanılır: kaydın
    // *kalıcı* olduğu ancak böyle ölçülür.
    final manager = await SyncManager.initialize(
      SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _AlwaysFailingHttpClient(),
        ),
      ),
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );
    await manager.clearQueue();

    await manager.queueQuizReward(
      score: 720,
      correctCount: 8,
      bestStreak: 5,
      totalQuestions: 10,
      roomId: 'room-42',
    );
    await manager.sync();

    expect(manager.pendingCount, 1, reason: 'ödül kuyruktan düştü');

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('zankurd.syncQueue') ?? '[]';
    expect(raw.contains('sync_quiz_reward'), isTrue);
    expect(raw.contains('room-42'), isTrue);

    // Kayıt yalnız turun olgularını taşımalı: içine bir miktar alanı
    // girerse ödülü istemci söylüyor demektir ve sunucu yetkisi orada
    // biter.
    expect(raw.contains('"amount"'), isFalse);
    expect(raw.contains('"coins"'), isFalse);
  });
}
