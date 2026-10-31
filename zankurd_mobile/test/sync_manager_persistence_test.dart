import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';

class _OfflineConnectivityMonitor implements ConnectivityMonitor {
  int checkCount = 0;
  bool online = false;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    checkCount++;
    return [online ? ConnectivityResult.wifi : ConnectivityResult.none];
  }
}

class _OwnedSupabaseRepository extends SupabaseZanKurdRepository {
  _OwnedSupabaseRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
        ),
      );

  @override
  String? get currentUserId => 'user-a';
}

class _FailingRewardRepository extends _OwnedSupabaseRepository {
  @override
  Future<QuizRewardClaim> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async => throw StateError('injected reward failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');

  setUp(() async {
    SharedPreferences.resetStatic();
    await SyncManager.resetForTesting();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
    await SyncManager.resetForTesting();
  });

  test('queueQuizReward kalıcı yazım bitmeden tamamlanmaz', () async {
    final writeStarted = Completer<void>();
    final allowWrite = Completer<void>();
    String? persistedValue;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getAll':
              return <String, Object>{};
            case 'setString':
              if (!writeStarted.isCompleted) writeStarted.complete();
              await allowWrite.future;
              final arguments = Map<String, Object?>.from(
                call.arguments as Map,
              );
              persistedValue = arguments['value'] as String;
              return true;
            default:
              throw StateError('Beklenmeyen SharedPreferences çağrısı');
          }
        });
    final manager = await SyncManager.initialize(
      _OwnedSupabaseRepository(),
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );

    var completed = false;
    final queued = manager.queueQuizReward(
      score: 720,
      correctCount: 8,
      bestStreak: 5,
      totalQuestions: 10,
      roomId: 'room-durable',
    );
    unawaited(
      queued.whenComplete(() {
        completed = true;
      }),
    );

    await writeStarted.future;
    expect(completed, isFalse);
    expect(persistedValue, isNull);

    allowWrite.complete();
    await queued;

    expect(completed, isTrue);
    expect(persistedValue, contains('room-durable'));
  });

  test('queueQuizReward yazım istisnasını taşır ve sync başlatmaz', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getAll':
              return <String, Object>{};
            case 'setString':
              throw StateError('injected: kalıcı yazım başarısız');
            default:
              throw StateError('Beklenmeyen SharedPreferences çağrısı');
          }
        });
    final connectivity = _OfflineConnectivityMonitor();
    final manager = await SyncManager.initialize(
      _OwnedSupabaseRepository(),
      connectivityMonitor: connectivity,
    );

    await expectLater(
      manager.queueQuizReward(
        score: 720,
        correctCount: 8,
        bestStreak: 5,
        totalQuestions: 10,
        roomId: 'room-write-throws',
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.message,
          'message',
          contains('injected: kalıcı yazım başarısız'),
        ),
      ),
    );

    expect(manager.pendingCount, 1);
    expect(connectivity.checkCount, 0, reason: 'Yazılmayan kayıt gönderildi.');
  });

  test('queueQuizReward false yazımı hata sayar ve sync başlatmaz', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getAll':
              return <String, Object>{};
            case 'setString':
              return false;
            default:
              throw StateError('Beklenmeyen SharedPreferences çağrısı');
          }
        });
    final connectivity = _OfflineConnectivityMonitor();
    final manager = await SyncManager.initialize(
      _OwnedSupabaseRepository(),
      connectivityMonitor: connectivity,
    );

    await expectLater(
      manager.queueQuizReward(
        score: 720,
        correctCount: 8,
        bestStreak: 5,
        totalQuestions: 10,
        roomId: 'room-write-false',
      ),
      throwsA(isA<StateError>()),
    );

    expect(manager.pendingCount, 1);
    expect(connectivity.checkCount, 0, reason: 'Yazılmayan kayıt gönderildi.');
  });

  test('legacy karantina hatası sağlam kullanıcı kuyruğunu ezmez', () async {
    final storage = <String, Object>{
      'flutter.zankurd.syncQueue': '{malformed',
      'flutter.zankurd.syncQueue.v2.user-a': jsonEncode([
        {
          'type': 'sync_quiz_reward',
          'score': 100,
          'correctCount': 1,
          'bestStreak': 1,
          'totalQuestions': 1,
          'roomId': 'room-old',
          'playerId': 'user-a',
          'timestamp': 1,
          'retries': 0,
        },
      ]),
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getAll':
              return storage;
            case 'setString':
              final arguments = Map<String, Object?>.from(
                call.arguments as Map,
              );
              final key = arguments['key'] as String;
              if (key.endsWith('legacyQuarantine')) {
                throw PlatformException(
                  code: 'injected',
                  message: 'karantina yazımı başarısız',
                );
              }
              storage[key] = arguments['value'] as String;
              return true;
            case 'remove':
              final arguments = Map<String, Object?>.from(
                call.arguments as Map,
              );
              storage.remove(arguments['key']);
              return true;
            default:
              throw StateError('Beklenmeyen SharedPreferences çağrısı');
          }
        });
    final manager = await SyncManager.initialize(
      _OwnedSupabaseRepository(),
      connectivityMonitor: _OfflineConnectivityMonitor(),
    );

    expect(manager.pendingCount, 1);
    await manager.queueQuizReward(
      score: 200,
      correctCount: 2,
      bestStreak: 2,
      totalQuestions: 2,
      roomId: 'room-new',
    );

    final persisted = storage['flutter.zankurd.syncQueue.v2.user-a'] as String;
    expect(persisted, contains('room-old'));
    expect(persisted, contains('room-new'));
  });

  test('hedefli kuyruk silme kalıcı depolama hatasını taşır', () async {
    final storage = <String, Object>{
      'flutter.zankurd.syncQueue.v2.user-b': '[]',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getAll':
              return storage;
            case 'remove':
            case 'setString':
              return false;
            default:
              throw StateError('Beklenmeyen SharedPreferences çağrısı');
          }
        });

    await expectLater(
      SyncManager.discardQueueForUser('user-b'),
      throwsStateError,
    );
  });

  test(
    'hesap silme yerel kuyruk hatasını çıkış sonunda çağırana taşır',
    () async {
      final storage = <String, Object>{
        'flutter.zankurd.syncQueue.v2.user-b': '[]',
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final arguments = call.arguments == null
                ? <String, Object?>{}
                : Map<String, Object?>.from(call.arguments as Map);
            switch (call.method) {
              case 'getAll':
                return storage;
              case 'remove':
                final key = arguments['key'] as String;
                if (key.endsWith('zankurd.syncQueue.v2.user-b')) return false;
                storage.remove(key);
                return true;
              case 'setString':
                final key = arguments['key'] as String;
                if (key.endsWith('zankurd.syncQueue.v2.user-b')) return false;
                storage[key] = arguments['value'] as String;
                return true;
              case 'setBool':
              case 'setInt':
              case 'setDouble':
              case 'setStringList':
                storage[arguments['key'] as String] = arguments['value']!;
                return true;
              default:
                throw StateError('Beklenmeyen SharedPreferences çağrısı');
            }
          });
      final auth = AuthProvider.test(authenticated: true);

      await expectLater(
        auth.signOut(
          discardPendingRewards: true,
          pendingRewardsOwnerId: 'user-b',
        ),
        throwsA(isA<AccountLocalCleanupException>()),
      );
      expect(auth.isAuthenticated, isFalse);
    },
  );
  for (final throwsOnWrite in [false, true]) {
    for (final transfer in ['exhausted', 'retry-destination', 'retry-source']) {
      test('$transfer yazımı ${throwsOnWrite ? "fırlatır" : "false döner"}: '
          'kayıt korunur ve yeniden denenebilir', () async {
        const queueKey = 'flutter.zankurd.syncQueue.v2.user-a';
        const failedKey = 'flutter.zankurd.syncQueue.failed.v1.user-a';
        final original = jsonEncode([
          {
            'queueId': 'durable-reward',
            'type': 'sync_quiz_reward',
            'score': 100,
            'correctCount': 1,
            'bestStreak': 1,
            'totalQuestions': 1,
            'roomId': 'durable-room',
            'playerId': 'user-a',
            'timestamp': 1,
            'retries': 4,
          },
        ]);
        final storage = <String, Object>{
          transfer == 'exhausted' ? queueKey : failedKey: original,
        };
        var rejectWrite = true;
        final rejectedKey = transfer == 'retry-destination'
            ? queueKey
            : failedKey;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'getAll') return Map.of(storage);
              if (call.method != 'setString') {
                throw StateError('Beklenmeyen çağrı: ${call.method}');
              }
              final args = Map<String, Object?>.from(call.arguments as Map);
              final key = args['key'] as String;
              if (rejectWrite && key == rejectedKey) {
                if (throwsOnWrite) {
                  throw PlatformException(code: 'injected-write-failure');
                }
                return false;
              }
              storage[key] = args['value'] as String;
              return true;
            });
        final connectivity = _OfflineConnectivityMonitor();
        final manager = await SyncManager.initialize(
          _FailingRewardRepository(),
          connectivityMonitor: connectivity,
        );
        await manager.sync();

        if (transfer == 'exhausted') {
          connectivity.online = true;
          await manager.sync();
          expect(manager.pendingCount, 1);
          expect(manager.failedCount, 0);
          expect(SyncManager.pendingCountNotifier.value, 1);
          expect(storage[queueKey], contains('durable-reward'));
        } else {
          await manager.retryFailedItems();
          expect(manager.failedCount, 1);
          expect(manager.pendingCount, 0);
          expect(SyncManager.failedCountNotifier.value, 1);
          expect(storage[failedKey], original);
        }

        // Diskten yeniden açmak, SharedPreferences'ın iyimser önbelleğinin
        // kayıp kalıcı kaydı gizlemediğini de doğrular.
        await SyncManager.resetForTesting();
        SharedPreferences.resetStatic();
        connectivity.online = false;
        if (transfer == 'retry-source') {
          await expectLater(
            SyncManager.initialize(
              _FailingRewardRepository(),
              connectivityMonitor: connectivity,
            ),
            throwsStateError,
          );
          rejectWrite = false;
        }
        final reloaded = await SyncManager.initialize(
          _FailingRewardRepository(),
          connectivityMonitor: connectivity,
        );
        await reloaded.sync();
        expect(reloaded.pendingCount + reloaded.failedCount, 1);
        rejectWrite = false;
        if (transfer == 'exhausted') {
          connectivity.online = true;
          await reloaded.sync();
          expect(reloaded.pendingCount, 0);
          expect(reloaded.failedCount, 1);
          expect(storage[failedKey], contains('durable-reward'));
        } else {
          await reloaded.retryFailedItems();
          expect(reloaded.pendingCount, 1);
          expect(reloaded.failedCount, 0);
          expect(storage[queueKey], contains('durable-reward'));
        }
      });
    }
  }
}
