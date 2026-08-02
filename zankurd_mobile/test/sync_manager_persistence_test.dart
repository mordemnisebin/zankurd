import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';

class _OfflineConnectivityMonitor implements ConnectivityMonitor {
  int checkCount = 0;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    checkCount++;
    return const [ConnectivityResult.none];
  }
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
      SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
        ),
      ),
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
      SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
        ),
      ),
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
      SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
        ),
      ),
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
}
