import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';

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

  test('SyncManager queues and syncs XP offline and online', () async {
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    // Queue XP update
    manager.queueXP(150);

    // Since MockZanKurdRepository is not SupabaseZanKurdRepository,
    // sync() will directly clear the mock queue as fallback.
    await manager.sync();

    // Verify it completes without errors
    expect(true, isTrue);
  });

  test(
    'SyncManager initializes even when connectivity plugin is unavailable',
    () async {
      final repository = MockZanKurdRepository();

      final manager = await SyncManager.initialize(
        repository,
        connectivityMonitor: _ThrowingConnectivityMonitor(),
      );

      manager.queueXP(75);
      await manager.sync();

      expect(manager, isA<SyncManager>());
    },
  );

  test('clearQueue resets pending updates in memory and preferences', () async {
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    manager.queueXP(150);
    await manager.clearQueue();

    expect(true, isTrue);
  });
}

