import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';

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

class _OnlineConnectivityMonitor implements ConnectivityMonitor {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => const [
    ConnectivityResult.wifi,
  ];
}

class _MutableConnectivityMonitor implements ConnectivityMonitor {
  _MutableConnectivityMonitor(this.result);

  ConnectivityResult result;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [result];
}

class _GatedConnectivityMonitor implements ConnectivityMonitor {
  _GatedConnectivityMonitor();

  final ConnectivityResult result = ConnectivityResult.wifi;
  final Completer<void> checkStarted = Completer<void>();
  final Completer<void> allowCheck = Completer<void>();
  int listenerCount = 0;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    listenerCount += 1;
    return const Stream.empty();
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (!checkStarted.isCompleted) checkStarted.complete();
    await allowCheck.future;
    return [result];
  }
}

class _OwnedSupabaseRepository extends SupabaseZanKurdRepository {
  _OwnedSupabaseRepository({required this.userId})
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _AlwaysFailingHttpClient(),
        ),
      );

  String? userId;
  int awardCalls = 0;
  Completer<void>? awardStarted;
  Completer<void>? allowAward;

  @override
  String? get currentUserId => userId;

  @override
  Future<QuizRewardClaim> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    awardCalls += 1;
    awardStarted?.complete();
    await allowAward?.future;
    return (amount: 1, dailyCapReached: false);
  }
}

/// `awardQuizCoins` her seferinde başarısız olur — retry tükenmesini
/// gerçek bir HTTP çağrısına ihtiyaç duymadan tetikler.
class _AlwaysFailingRewardRepository extends SupabaseZanKurdRepository {
  _AlwaysFailingRewardRepository({required this.userId})
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _AlwaysFailingHttpClient(),
        ),
      );

  String? userId;

  @override
  String? get currentUserId => userId;

  @override
  Future<QuizRewardClaim> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    throw Exception('injected: reward RPC always fails');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncManager.resetForTesting();
  });

  test(
    'SyncManager eski sahipsiz kuyruğu göndermeden karantinaya alır',
    () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.syncQueue':
            '[{"type":"sync_xp","xp":150,"delta":150,"retries":0}]',
      });
      final repository = _OwnedSupabaseRepository(userId: 'user-a');
      final manager = await SyncManager.initialize(
        repository,
        connectivityMonitor: _OnlineConnectivityMonitor(),
      );

      await manager.sync();

      final prefs = await SharedPreferences.getInstance();
      expect(repository.awardCalls, 0);
      expect(prefs.getString('zankurd.syncQueue'), isNull);
      expect(
        prefs.getString('zankurd.syncQueue.legacyQuarantine'),
        contains('sync_xp'),
      );
    },
  );

  test(
    'SyncManager sahibi doğrulanan eski kuyruğu kaybetmeden taşır',
    () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.syncQueue': jsonEncode([
          {
            'type': 'sync_quiz_reward',
            'score': 100,
            'correctCount': 1,
            'bestStreak': 1,
            'totalQuestions': 1,
            'roomId': null,
            'playerId': 'user-a',
            'timestamp': 1,
            'retries': 0,
          },
        ]),
      });
      final repository = _OwnedSupabaseRepository(userId: 'user-a');
      final manager = await SyncManager.initialize(
        repository,
        connectivityMonitor: _OnlineConnectivityMonitor(),
      );

      await manager.sync();

      final prefs = await SharedPreferences.getInstance();
      expect(repository.awardCalls, 1);
      expect(prefs.getString('zankurd.syncQueue'), isNull);
      expect(prefs.getString('zankurd.syncQueue.legacyQuarantine'), isNull);
    },
  );

  test('eski kuyruk signed-out durumda sahiplerine göre ayrılır', () async {
    Map<String, dynamic> reward(String? playerId, String roomId) => {
      'type': 'sync_quiz_reward',
      'score': 100,
      'correctCount': 1,
      'bestStreak': 1,
      'totalQuestions': 1,
      'roomId': roomId,
      'playerId': playerId,
      'timestamp': 1,
      'retries': 0,
    };

    SharedPreferences.setMockInitialValues({
      'zankurd.syncQueue': jsonEncode([
        reward('user-a', 'room-a'),
        reward('user-b', 'room-b'),
        reward(null, 'room-ownerless'),
      ]),
    });
    final repository = _OwnedSupabaseRepository(userId: null);
    final connectivity = _OfflineConnectivityMonitor();
    await SyncManager.initialize(repository, connectivityMonitor: connectivity);

    repository.userId = 'user-a';
    await SyncManager.restart();
    expect(SyncManager.instance.pendingCount, 1);

    repository.userId = 'user-b';
    await SyncManager.restart();
    expect(SyncManager.instance.pendingCount, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('zankurd.syncQueue.legacyQuarantine'),
      contains('room-ownerless'),
    );
  });

  test('legacy merge yalnız retries değişti diye ödülü çoğaltmaz', () async {
    Map<String, dynamic> reward(int retries) => {
      'type': 'sync_quiz_reward',
      'score': 100,
      'correctCount': 1,
      'bestStreak': 1,
      'totalQuestions': 1,
      'roomId': 'room-stable',
      'playerId': 'user-a',
      'timestamp': 123,
      'retries': retries,
    };
    SharedPreferences.setMockInitialValues({
      'zankurd.syncQueue': jsonEncode([reward(0)]),
      'zankurd.syncQueue.v2.user-a': jsonEncode([reward(1)]),
    });
    final manager = await SyncManager.initialize(
      _OwnedSupabaseRepository(userId: 'user-a'),
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );

    expect(manager.pendingCount, 1);
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
    final scopedKey = prefs.getKeys().singleWhere(
      (key) => key.startsWith('zankurd.syncQueue.v2.'),
    );
    expect(prefs.getString(scopedKey), '[]');
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

  test(
    'çevrimdışı shutdown bekleyen ödülü aynı kullanıcı için korur',
    () async {
      final repository = _OwnedSupabaseRepository(userId: 'user-a');
      final manager = await SyncManager.initialize(
        repository,
        connectivityMonitor: _OfflineConnectivityMonitor(),
      );

      await manager.queueQuizReward(
        score: 100,
        correctCount: 1,
        bestStreak: 1,
        totalQuestions: 1,
      );
      await SyncManager.shutdown();

      final restored = await SyncManager.initialize(
        repository,
        connectivityMonitor: _OfflineConnectivityMonitor(),
      );
      expect(restored.pendingCount, 1);
    },
  );

  test('hesap silme shutdown kuyruğu açıkça atar', () async {
    final repository = _OwnedSupabaseRepository(userId: 'user-a');
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );
    await manager.queueQuizReward(
      score: 100,
      correctCount: 1,
      bestStreak: 1,
      totalQuestions: 1,
    );

    await SyncManager.shutdown(flush: false, discardQueue: true);
    final restored = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );

    expect(restored.pendingCount, 0);
  });

  test(
    'hedefli hesap silme yalnız belirtilen kullanıcının kuyruğunu atar',
    () async {
      Map<String, dynamic> reward(String playerId, String roomId) => {
        'type': 'sync_quiz_reward',
        'score': 100,
        'correctCount': 1,
        'bestStreak': 1,
        'totalQuestions': 1,
        'roomId': roomId,
        'playerId': playerId,
        'timestamp': 1,
        'retries': 0,
      };
      SharedPreferences.setMockInitialValues({
        'zankurd.syncQueue.v2.user-a': jsonEncode([reward('user-a', 'room-a')]),
        'zankurd.syncQueue.v2.user-b': jsonEncode([reward('user-b', 'room-b')]),
        'zankurd.syncQueue.legacyQuarantine': jsonEncode([
          reward('', 'room-ownerless'),
        ]),
      });
      final repository = _OwnedSupabaseRepository(userId: 'user-a');
      await SyncManager.initialize(
        repository,
        connectivityMonitor: _OfflineConnectivityMonitor(),
      );

      await SyncManager.discardQueueForUser('user-b');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('zankurd.syncQueue.v2.user-a'),
        contains('room-a'),
      );
      expect(prefs.getString('zankurd.syncQueue.v2.user-b'), isNull);
      expect(prefs.getString('zankurd.syncQueue.legacyQuarantine'), isNull);
      expect(SyncManager.maybeInstance, isNull);
    },
  );

  test('hesap değişimi önceki kullanıcının kuyruğunu açmaz', () async {
    final repository = _OwnedSupabaseRepository(userId: 'user-a');
    final connectivity = _MutableConnectivityMonitor(ConnectivityResult.none);
    final first = await SyncManager.initialize(
      repository,
      connectivityMonitor: connectivity,
    );
    await first.queueQuizReward(
      score: 100,
      correctCount: 1,
      bestStreak: 1,
      totalQuestions: 1,
    );

    repository.userId = 'user-b';
    connectivity.result = ConnectivityResult.wifi;
    await SyncManager.restart();
    await SyncManager.instance.sync();
    expect(SyncManager.instance.pendingCount, 0);
    expect(repository.awardCalls, 0);

    repository.userId = 'user-a';
    connectivity.result = ConnectivityResult.none;
    await SyncManager.restart();
    expect(SyncManager.instance.pendingCount, 1);
  });

  test('ağ kontrolü sırasında hesap değişirse eski ödül gönderilmez', () async {
    final repository = _OwnedSupabaseRepository(userId: 'user-a');
    final connectivity = _GatedConnectivityMonitor();
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: connectivity,
    );
    await manager.queueQuizReward(
      score: 100,
      correctCount: 1,
      bestStreak: 1,
      totalQuestions: 1,
    );
    await connectivity.checkStarted.future;

    repository.userId = 'user-b';
    connectivity.allowCheck.complete();
    await manager.sync();

    expect(repository.awardCalls, 0);
    expect(manager.pendingCount, 1);
  });

  test('eşzamanlı initialize çağrıları tek güncel manager yayımlar', () async {
    final repository = _OwnedSupabaseRepository(userId: 'user-a');
    final connectivity = _GatedConnectivityMonitor();
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: connectivity,
    );
    await manager.queueQuizReward(
      score: 100,
      correctCount: 1,
      bestStreak: 1,
      totalQuestions: 1,
    );
    await connectivity.checkStarted.future;

    repository.userId = 'user-b';
    final firstInitialize = SyncManager.initialize(
      repository,
      connectivityMonitor: connectivity,
    );
    final secondInitialize = SyncManager.initialize(
      repository,
      connectivityMonitor: connectivity,
    );
    connectivity.allowCheck.complete();

    final managers = await Future.wait([firstInitialize, secondInitialize]);
    expect(managers[0], same(managers[1]));
    expect(SyncManager.instance, same(managers[0]));
    expect(connectivity.listenerCount, 2);
  });

  test('shutdown devam eden sync tamamlanmadan dönmez', () async {
    final repository = _OwnedSupabaseRepository(userId: 'user-a')
      ..awardStarted = Completer<void>()
      ..allowAward = Completer<void>();
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );
    await manager.queueQuizReward(
      score: 100,
      correctCount: 1,
      bestStreak: 1,
      totalQuestions: 1,
    );
    await repository.awardStarted!.future;

    var shutdownCompleted = false;
    final shutdown = SyncManager.shutdown().whenComplete(
      () => shutdownCompleted = true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(shutdownCompleted, isFalse);

    repository.allowAward!.complete();
    await shutdown;
    expect(repository.awardCalls, 1);
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
      _OwnedSupabaseRepository(userId: 'user-a'),
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
    final raw = prefs
        .getKeys()
        .where((key) => key.startsWith('zankurd.syncQueue.v2.'))
        .map(prefs.getString)
        .whereType<String>()
        .join();
    expect(raw.contains('sync_quiz_reward'), isTrue);
    expect(raw.contains('room-42'), isTrue);

    // Kayıt yalnız turun olgularını taşımalı: içine bir miktar alanı
    // girerse ödülü istemci söylüyor demektir ve sunucu yetkisi orada
    // biter.
    expect(raw.contains('"amount"'), isFalse);
    expect(raw.contains('"coins"'), isFalse);
  });

  /// ## Kusur
  ///
  /// Retry'ları tükenen bir çevrimdışı ödül (`_maxRetries` = 5), her iki
  /// `catch` dalında da yalnız `ErrorReporter.record` ile loglanıp
  /// `_queue`ya geri eklenmeden düşüyordu. `_queue` boşaldığı için
  /// `pendingCountNotifier` hemen 0'a iniyor, profil ekranındaki
  /// `_SyncStatusChip` de "Bulutla senkronize" yazıyordu — oysa
  /// `awardQuizCoins` RPC'si sunucuda HİÇ çalışmamıştı. Kullanıcı tur
  /// sonunda "kazandığı" coin'in aslında hiç hesabına geçmediğini asla
  /// öğrenemiyordu (2026-08-14 denetimi).
  ///
  /// ## Düzeltme
  ///
  /// Retry tükenince kayıt artık `_failedItems`e taşınır, ayrı bir
  /// `zankurd.syncQueue.failed.v1.<userId>` anahtarında kalıcılaşır ve
  /// `SyncManager.failedCountNotifier` ile UI'a sızar. `retryFailedItems()`
  /// kullanıcı elle karşılık verdiğinde kaydı kuyruğa geri koyup yeniden
  /// dener; otomatik değildir — aksi hâlde kalıcı bir hata (ör. eksik
  /// migration, bkz. 42883 dalı) sonsuz döngüye girerdi.
  test('retry tükenen ödül sessizce kaybolmaz, "senkronize edilemedi" '
      'durumuna taşınır ve elle yeniden denenebilir', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.syncQueue.v2.user-a': jsonEncode([
        {
          'queueId': 'q-exhausted-1',
          'type': 'sync_quiz_reward',
          'score': 100,
          'correctCount': 1,
          'bestStreak': 1,
          'totalQuestions': 1,
          'roomId': 'room-1',
          'playerId': 'user-a',
          'timestamp': 1,
          // Bu turda başarısız olursa 5'e (maxRetries) ulaşır.
          'retries': 4,
        },
      ]),
    });
    final repository = _AlwaysFailingRewardRepository(userId: 'user-a');
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );

    await manager.sync();

    // Kayıt kuyruktan düştü ama SESSİZCE kaybolmadı.
    expect(manager.pendingCount, 0);
    expect(manager.failedCount, 1);
    expect(SyncManager.pendingCountNotifier.value, 0);
    expect(SyncManager.failedCountNotifier.value, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('zankurd.syncQueue.failed.v1.user-a'),
      contains('room-1'),
    );

    // Kullanıcı elle yeniden dener.
    await manager.retryFailedItems();
    expect(manager.failedCount, 0);
    expect(manager.pendingCount, 1);
    expect(SyncManager.failedCountNotifier.value, 0);
    expect(prefs.getString('zankurd.syncQueue.v2.user-a'), contains('room-1'));
  });
}
