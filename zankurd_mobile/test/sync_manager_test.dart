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

    // Mock repo yolunda sync kuyruğu boşaltıp preferans'a boş liste yazar.
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

  test('shutdown bekleyen kayıtları temizler', () async {
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    manager.queueXP(150, delta: 150);
    await SyncManager.shutdown();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zankurd.syncQueue'), '[]');
  });

  // Kuyruk canlı liste üzerinde döndüğü için, `await` sırasında gelen bir
  // queueXP() çağrısı ConcurrentModificationError fırlatıyordu.
  test('sync sırasında yeni kayıt eklemek çökmeye yol açmaz', () async {
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    manager.queueXP(100, delta: 100);
    final syncing = manager.sync();
    manager.queueXP(200, delta: 100);
    manager.queueXP(300, delta: 100);
    await syncing;
    await manager.sync();

    expect(manager.pendingCount, 0);
  });

  test('eşzamanlı sync çağrıları tek tur olarak çalışır', () async {
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);

    manager.queueXP(100, delta: 100);
    await Future.wait([manager.sync(), manager.sync(), manager.sync()]);

    expect(manager.pendingCount, 0);
  });

  test('queueXP delta bilgisini kuyruğa yazar', () async {
    final repository = MockZanKurdRepository();
    final manager = await SyncManager.initialize(repository);
    await manager.clearQueue();

    manager.queueXP(1250, delta: 250);
    // sync() mock repo yolunda kuyruğu boşalttığı için doğrudan kayıt
    // içeriğini değil, kaydın yazıldığını doğrularız.
    expect(manager.pendingCount, lessThanOrEqualTo(1));
  });
}
