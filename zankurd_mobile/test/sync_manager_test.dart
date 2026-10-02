// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/durable_write.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/data/tournament_progress_publisher.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
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
class _ServerXpRepository extends SupabaseZanKurdRepository {
  _ServerXpRepository({required this.userId, required this.total})
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _AlwaysFailingHttpClient(),
        ),
      );

  String? userId;
  int total;
  int xpCalls = 0;
  int roomXpCalls = 0;

  @override
  String? get currentUserId => userId;

  @override
  Future<int> awardXp(int delta) async {
    xpCalls += 1;
    return total;
  }

  @override
  Future<ServerXpWrite> awardXpDurable(int delta, String idempotencyKey) async {
    final awarded = await awardXp(delta);
    return ServerXpWrite(total: awarded, retryable: true);
  }

  @override
  Future<int> awardRoomXp(String roomId) async {
    roomXpCalls += 1;
    return total;
  }
}

class _ReconcileXpRepository extends SupabaseZanKurdRepository {
  _ReconcileXpRepository({
    required this.userId,
    required this.serverXp,
    this.failAward = false,
  }) : super(
         SupabaseClient(
           'https://example.supabase.co',
           'sb_publishable_test_key',
           httpClient: _AlwaysFailingHttpClient(),
         ),
       );

  String? userId;
  int serverXp;
  bool failAward;
  int xpCalls = 0;
  int lastDelta = 0;

  @override
  String? get currentUserId => userId;

  @override
  Future<int?> loadServerXp() async => serverXp;

  @override
  Future<int> awardXp(int delta) async {
    xpCalls += 1;
    lastDelta = delta;
    if (failAward) throw StateError('xp award failed');
    serverXp += delta;
    return serverXp;
  }

  @override
  Future<ServerXpWrite> awardXpDurable(int delta, String idempotencyKey) async {
    final awarded = await awardXp(delta);
    return ServerXpWrite(total: awarded, retryable: true);
  }
}

class _FavoriteSyncRepository extends SupabaseZanKurdRepository {
  _FavoriteSyncRepository({required this.userId, required this.fail})
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _AlwaysFailingHttpClient(),
        ),
      );

  String? userId;
  bool fail;
  final calls = <(String, bool)>[];

  @override
  String? get currentUserId => userId;

  @override
  Future<bool> toggleFavoriteQuestion(
    QuizQuestion question,
    bool favorite,
  ) async {
    calls.add((question.id, favorite));
    if (fail) throw StateError('favorite failed');
    return favorite;
  }
}

class _TournamentSyncRepository extends SupabaseZanKurdRepository {
  _TournamentSyncRepository({required this.userId, required this.acknowledged})
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _AlwaysFailingHttpClient(),
        ),
      );

  String? userId;
  bool acknowledged;
  final stages = <String>[];

  @override
  String? get currentUserId => userId;

  @override
  Future<bool> saveTournamentProgress(
    String stage,
    int userScore,
    int opponentScore,
    List<String> botWinners,
  ) async {
    stages.add(stage);
    return acknowledged;
  }
}

class _LessonSyncRepository extends SupabaseZanKurdRepository {
  _LessonSyncRepository({required this.userId, required this.acknowledged})
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _AlwaysFailingHttpClient(),
        ),
      );

  String? userId;
  bool acknowledged;
  final lessonIds = <String>[];

  @override
  String? get currentUserId => userId;

  @override
  Future<bool> markLessonCompleted(String lessonId) async {
    lessonIds.add(lessonId);
    return acknowledged;
  }
}

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

  test('eski solo sync_xp sunucuya gitmeden kuyruktan düşer', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.syncQueue.v2.user-a': jsonEncode([
        {
          'type': 'sync_xp',
          'delta': 25,
          'idempotencyKey': 'cache-25',
          'playerId': 'user-a',
          'retries': 0,
        },
      ]),
      LocalProgressScope.physicalFor('user-a', 'zankurd.xp.total'): 10,
    });
    LocalProgressScope.bind('user-a');
    XPStore.resetInstance();
    addTearDown(() {
      LocalProgressScope.debugReset();
      XPStore.resetInstance();
    });
    final repository = _ServerXpRepository(userId: 'user-a', total: 125);
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );

    await manager.sync();

    XPStore.resetInstance();
    expect(repository.xpCalls, 0);
    expect(repository.roomXpCalls, 0);
    expect((await XPStore.load()).totalXP, 10);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zankurd.syncQueue.v2.user-a'), anyOf(isNull, '[]'));
  });

  test('oda sync_xp yalnız doğrulanmış oda RPC yolunu kullanır', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.syncQueue.v2.user-a': jsonEncode([
        {
          'type': 'sync_xp',
          'roomId': 'room-verified',
          'playerId': 'user-a',
          'retries': 0,
        },
      ]),
      LocalProgressScope.physicalFor('user-a', 'zankurd.xp.total'): 10,
    });
    LocalProgressScope.bind('user-a');
    XPStore.resetInstance();
    addTearDown(() {
      LocalProgressScope.debugReset();
      XPStore.resetInstance();
    });
    final repository = _ServerXpRepository(userId: 'user-a', total: 125);
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );

    await manager.sync();

    XPStore.resetInstance();
    expect(repository.xpCalls, 0);
    expect(repository.roomXpCalls, 1);
    expect((await XPStore.load()).totalXP, 125);
  });

  test('sunucu XP daha yüksekse çubuk onu alır', () async {
    SharedPreferences.setMockInitialValues({
      LocalProgressScope.physicalFor('user-a', 'zankurd.xp.total'): 80,
    });
    LocalProgressScope.bind('user-a');
    XPStore.resetInstance();
    addTearDown(() {
      LocalProgressScope.debugReset();
      XPStore.resetInstance();
    });
    final repository = _ReconcileXpRepository(userId: 'user-a', serverXp: 100);
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );

    await manager.reconcileXpCache();

    XPStore.resetInstance();
    expect(repository.xpCalls, 0);
    expect((await XPStore.load()).totalXP, 100);
  });

  test('yerel XP yüksekse rekabetçi sunucu XP değiştirilmez', () async {
    SharedPreferences.setMockInitialValues({
      LocalProgressScope.physicalFor('user-a', 'zankurd.xp.total'): 80,
    });
    LocalProgressScope.bind('user-a');
    XPStore.resetInstance();
    addTearDown(() {
      LocalProgressScope.debugReset();
      XPStore.resetInstance();
    });
    final repository = _ReconcileXpRepository(userId: 'user-a', serverXp: 20);
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );

    await manager.reconcileXpCache();
    await manager.reconcileXpCache();

    XPStore.resetInstance();
    expect(repository.xpCalls, 0);
    expect(repository.lastDelta, 0);
    expect((await XPStore.load()).totalXP, 80);
  });

  test('eski bekleyen solo XP düşürülür ve yeni fark yazılmaz', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.syncQueue.v2.user-a': jsonEncode([
        {
          'type': 'sync_xp',
          'delta': 5,
          'idempotencyKey': 'pending-5',
          'playerId': 'user-a',
          'retries': 0,
        },
      ]),
      LocalProgressScope.physicalFor('user-a', 'zankurd.xp.total'): 80,
    });
    LocalProgressScope.bind('user-a');
    XPStore.resetInstance();
    addTearDown(() {
      LocalProgressScope.debugReset();
      XPStore.resetInstance();
    });
    final repository = _ReconcileXpRepository(
      userId: 'user-a',
      serverXp: 20,
      failAward: true,
    );
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );
    await manager.sync();
    final callsAfterQueue = repository.xpCalls;

    await manager.reconcileXpCache();

    expect(repository.xpCalls, callsAfterQueue);
    expect(repository.xpCalls, 0);
    expect(repository.lastDelta, 0);
    XPStore.resetInstance();
    expect((await XPStore.load()).totalXP, 80);
  });

  test('favori kuyruğu aynı soruda son isteği tutar', () async {
    final repository = _FavoriteSyncRepository(userId: 'user-a', fail: true);
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );

    await manager.retainFavorite(questionId: 'q1', favorite: true);
    await manager.retainFavorite(questionId: 'q1', favorite: false);

    expect(manager.queuedFavorite('q1'), isFalse);
    expect(repository.calls, isEmpty);
  });

  test('favori yazımı onaylanınca kuyruktan düşer', () async {
    final repository = _FavoriteSyncRepository(userId: 'user-a', fail: false);
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );

    await manager.retainFavorite(questionId: 'q1', favorite: false);
    await manager.sync();

    expect(repository.calls, contains(('q1', false)));
    expect(manager.queuedFavorite('q1'), isNull);
  });

  test('turnuva kuyruğu yalnız son aşamayı tutar', () async {
    final repository = _TournamentSyncRepository(
      userId: 'user-a',
      acknowledged: false,
    );
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );

    await manager.retainLatestTournamentProgress(
      acknowledged: false,
      stage: 'quarter',
      userScore: 1,
      opponentScore: 0,
      botWinners: const ['a'],
    );
    await manager.retainLatestTournamentProgress(
      acknowledged: false,
      stage: 'semi',
      userScore: 2,
      opponentScore: 1,
      botWinners: const ['b'],
    );

    expect(manager.queuedTournamentStage, 'semi');
    expect(repository.stages, isEmpty);

    await manager.retainLatestTournamentProgress(
      acknowledged: true,
      stage: 'final',
      userScore: 3,
      opponentScore: 1,
      botWinners: const [],
    );

    expect(manager.queuedTournamentStage, isNull);
  });

  test('yayıncı onay gelmeyince son aşamayı bırakır', () async {
    final repository = _TournamentSyncRepository(
      userId: 'user-a',
      acknowledged: false,
    );
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );

    await TournamentProgressPublisher.publish(
      repository: repository,
      stage: 'quarter',
      userScore: 1,
      opponentScore: 0,
      botWinners: const ['a'],
    );
    await TournamentProgressPublisher.publish(
      repository: repository,
      stage: 'semi',
      userScore: 2,
      opponentScore: 0,
      botWinners: const ['b'],
    );

    expect(manager.queuedTournamentStage, 'semi');
    expect(repository.stages, ['quarter', 'semi']);

    repository.acknowledged = true;
    await TournamentProgressPublisher.publish(
      repository: repository,
      stage: 'final',
      userScore: 3,
      opponentScore: 1,
      botWinners: const [],
    );

    expect(manager.queuedTournamentStage, isNull);
    expect(repository.stages, ['quarter', 'semi', 'final']);
  });

  test('onaylanmayan turnuva aşaması yeniden denenir', () async {
    final repository = _TournamentSyncRepository(
      userId: 'user-a',
      acknowledged: false,
    );
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );

    await manager.retainLatestTournamentProgress(
      acknowledged: false,
      stage: 'quarter',
      userScore: 4,
      opponentScore: 2,
      botWinners: const ['bot'],
    );
    await manager.sync();

    expect(repository.stages, contains('quarter'));
    expect(manager.queuedTournamentStage, 'quarter');
  });

  test('aynı kullanıcının çevrimdışı ders slugları kuyruğa girer', () async {
    SharedPreferences.setMockInitialValues({
      LocalProgressScope.physicalFor(
        'user-a',
        'zankurd.offline.completedLessonIds',
      ): [
        'everyday_1',
      ],
    });
    LocalProgressScope.bind('user-a');
    addTearDown(LocalProgressScope.debugReset);
    final repository = _LessonSyncRepository(
      userId: 'user-a',
      acknowledged: false,
    );
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );

    await manager.queueScopedOfflineLessons();

    expect(manager.pendingLessonCompletionCount, 1);
    expect(repository.lessonIds, isEmpty);
  });

  test('onaylanmayan ders tamamlama kuyrukta kalır', () async {
    final repository = _LessonSyncRepository(
      userId: 'user-a',
      acknowledged: false,
    );
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );

    await manager.queueLessonCompletion('lesson-1');
    await manager.sync();

    expect(repository.lessonIds, contains('lesson-1'));
    expect(manager.hasPendingLessonCompletion, isTrue);
  });

  test('onaylanan ders çevrimdışı listeden de düşer', () async {
    final lessonKey = LocalProgressScope.physicalFor(
      'user-a',
      'zankurd.offline.completedLessonIds',
    );
    SharedPreferences.setMockInitialValues({
      lessonKey: ['everyday_1'],
    });
    LocalProgressScope.bind('user-a');
    addTearDown(LocalProgressScope.debugReset);
    final repository = _LessonSyncRepository(
      userId: 'user-a',
      acknowledged: true,
    );
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );

    await manager.queueLessonCompletion('everyday_1');
    await manager.sync();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(lessonKey), isEmpty);
    expect(manager.hasPendingLessonCompletion, isFalse);
  });

  test('onaylanan ders tamamlama kuyruktan düşer', () async {
    final repository = _LessonSyncRepository(
      userId: 'user-a',
      acknowledged: true,
    );
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OnlineConnectivityMonitor(),
    );

    await manager.queueLessonCompletion('lesson-1');
    await manager.sync();

    expect(repository.lessonIds, ['lesson-1']);
    expect(manager.hasPendingLessonCompletion, isFalse);
  });

  test('aynı ders tamamlama kuyrukta bir kez durur', () async {
    final repository = _LessonSyncRepository(
      userId: 'user-a',
      acknowledged: false,
    );
    final manager = await SyncManager.initialize(
      repository,
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );

    await manager.queueLessonCompletion('lesson-1');
    await manager.queueLessonCompletion('lesson-1');

    expect(repository.lessonIds, isEmpty);
    expect(manager.pendingLessonCompletionCount, 1);
  });

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

  test('Supabase dışı depoda kuyruk sessizce silinmez', () async {
    // 2026-09: `_syncOnce` Supabase dışı depoda kuyruğu `clear()` ile
    // boşaltıyordu — çevrimdışı kazanılmış ödül kurtarılamaz biçimde
    // yok oluyordu. Kuyruk sahibinindir; depo Supabase'e dönünce aynı
    // kuyruk senkronize olur.
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    await manager.queueQuizReward(
      score: 100,
      correctCount: 1,
      bestStreak: 1,
      totalQuestions: 1,
    );
    await manager.sync();

    expect(manager.pendingCount, 1, reason: 'ödül kuyruktan düştü');
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

    // 2026-09 sözleşmesi: Supabase dışı depoda `sync()` kuyruğu silmez —
    // üç kayıt da korunur; ölçülen şey çöküşsüzlük, boşalma değil.
    expect(manager.pendingCount, 3);
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

    // 2026-09 sözleşmesi: Supabase dışı depoda `sync()` kuyruğu silmez.
    expect(manager.pendingCount, 1);
  });

  test('XP kuyruğu yalnız doğrulanmış oda kimliğini sunucuya taşır', () {
    final source = File('lib/src/data/sync_manager.dart').readAsStringSync();
    expect(source, isNot(contains('void queueXP(')));
    expect(source, isNot(contains('awardProfileXPDelta(')));
    expect(source, contains('queueXpAward'));
    expect(source, contains('Dropping unverified solo XP item'));
    expect(source, contains('final total = await repo.awardRoomXp(roomId)'));
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
  /// `_SyncStatusChip` de "İlerlemen kayıtlı" yazıyordu — oysa
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
