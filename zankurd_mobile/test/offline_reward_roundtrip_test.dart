import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';

/// Uçak modunda bitirilen turun ödülü: ne kaybolur, ne iki kez verilir.
///
/// ## Kusur (kapsam boşluğu)
///
/// `sync_manager_test` kuyruğun YAŞAM DÖNGÜSÜNÜ çok iyi ölçüyor — sahiplik,
/// eski kuyruk göçü, çıkış/yeniden giriş, hesap değişimi, hesap silme,
/// retry tükenmesi, eşzamanlı `initialize`. Hepsi mekanizma testleri.
///
/// Ölçülmeyen şey kullanıcının yaşadığı ZİNCİRDİ: uçak modunda tur biter →
/// ödül kuyruğa yazılır (sunucuya GİTMEZ) → ağ geri gelir → kuyruk boşalır ve
/// ödül sunucuya TAM BİR KEZ gider. Zincirin iki ucu iki ayrı kusur sınıfıdır
/// ve ikisi de para: bir uçta kazanılan jeton kaybolur, öbür uçta aynı tur
/// iki kez ödüllendirilir (2026-08-17).
///
/// ## Harness: depo GERÇEK olmak zorunda
///
/// İlk denemede bu test `MockZanKurdRepository` ile yazıldı ve kayıt kuyruktan
/// gönderilmeden, hataya da düşmeden kayboldu. Sebep `SyncManager.sync()`
/// içinde duruyor:
///
/// ```dart
/// if (repo is! SupabaseZanKurdRepository) {
///   _queue.clear();
///   await _saveQueue();
///   return;
/// }
/// ```
///
/// Yani senkron yolu yalnız gerçek depo ile çalışır; mock depoda kuyruk
/// bilerek boşaltılır. Ağa çıkmadan gerçek depo kullanmanın yolu, enjekte
/// edilmiş bir HTTP client'tır — `sync_manager_test`in kurduğu desen budur ve
/// burada da o kullanılır. Bu tuzağı bir kez yaşamadan görmek imkânsız
/// olduğu için buraya yazıldı.
class _FailingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw Exception('injected: ağ erişilemez');
  }
}

/// Ödül çağrısını sayan gerçek depo. Sunucuya gerçekten gitmez; ölçülen şey
/// `SyncManager`in ÇAĞIRIP çağırmadığıdır.
class _CountingRewardRepository extends SupabaseZanKurdRepository {
  _CountingRewardRepository()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _FailingHttpClient(),
        ),
      );

  int awardCalls = 0;
  final List<int> scores = [];

  @override
  String? get currentUserId => 'user-offline';

  @override
  Future<QuizRewardClaim> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    awardCalls += 1;
    scores.add(score);
    return (amount: 30, dailyCapReached: false);
  }
}

class _SwitchableMonitor implements ConnectivityMonitor {
  _SwitchableMonitor(this.result);

  ConnectivityResult result;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [result];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SyncManager.resetForTesting();
  });

  tearDown(() => SyncManager.resetForTesting());

  /// Uçuştaki turu bekleyip ağ dönmüş hâliyle yeni bir tur koşturur.
  ///
  /// İki çağrı gerekiyor ve sebebi kurgu değil, gerçek davranış:
  /// `queueQuizReward` sonunda `unawaited(sync())` ile bir tur başlatır ve o
  /// tur ÇEVRİMDIŞI kararını çoktan vermiştir. Yeniden giriş koruması, tur
  /// sürerken gelen çağırana aynı Future'ı verir. Üretimde ikinci turu
  /// bağlantı dinleyicisi ve ön plana dönüş tetikler; testte açıkça yazılır.
  Future<void> drain(SyncManager sync) async {
    await sync.sync();
    await sync.sync();
  }

  test('uçak modu → kuyruk → ağ döndü → ödül tam bir kez gider', () async {
    final repository = _CountingRewardRepository();
    final monitor = _SwitchableMonitor(ConnectivityResult.none);
    final sync = await SyncManager.initialize(
      repository,
      connectivityMonitor: monitor,
    );

    // 1) Uçak modunda tur biter.
    await sync.queueQuizReward(
      score: 240,
      correctCount: 8,
      bestStreak: 4,
      totalQuestions: 10,
    );

    expect(
      repository.awardCalls,
      0,
      reason: 'Çevrimdışıyken ödül sunucuya gitmemeli.',
    );
    expect(
      SyncManager.pendingCountNotifier.value,
      1,
      reason:
          'Ödül kuyrukta beklemeli; yoksa uçak modunda kazanılan tur '
          'sessizce kaybolur.',
    );

    // 2) Ağ geri gelir.
    monitor.result = ConnectivityResult.wifi;
    await drain(sync);

    expect(
      repository.awardCalls,
      1,
      reason: 'Ağ dönünce kuyruktaki ödül sunucuya gitmeliydi.',
    );
    expect(repository.scores, [240], reason: 'Kuyruktaki skor bozulmuş.');
    expect(
      SyncManager.pendingCountNotifier.value,
      0,
      reason: 'Gönderilen kayıt kuyrukta kalmamalı.',
    );

    // 3) Sonraki turlar ödülü ÇOĞALTMAMALI. Uygulama ön plana her gelişinde
    //    senkron tetiklenir; kayıt kuyrukta kalsaydı oyuncu aynı turdan iki
    //    kez jeton alırdı.
    await drain(sync);
    expect(
      repository.awardCalls,
      1,
      reason: 'Sonraki senkron turu aynı ödülü tekrar gönderdi.',
    );
  });

  test('çevrimdışı biriken iki tur, ağ dönünce ikisi de gider', () async {
    final repository = _CountingRewardRepository();
    final monitor = _SwitchableMonitor(ConnectivityResult.none);
    final sync = await SyncManager.initialize(
      repository,
      connectivityMonitor: monitor,
    );

    for (final score in [100, 200]) {
      await sync.queueQuizReward(
        score: score,
        correctCount: 5,
        bestStreak: 2,
        totalQuestions: 10,
      );
    }
    expect(SyncManager.pendingCountNotifier.value, 2);
    expect(repository.awardCalls, 0);

    monitor.result = ConnectivityResult.wifi;
    await drain(sync);

    expect(
      repository.awardCalls,
      2,
      reason:
          'Çevrimdışı biriken turların hepsi gitmeli; biri düşerse oyuncu '
          'kazandığı jetonu hiç göremez.',
    );
    expect(
      repository.scores,
      containsAll([100, 200]),
      reason: 'Turlardan biri yanlış skorla gitti.',
    );
    expect(SyncManager.pendingCountNotifier.value, 0);
  });

  test('ağ hâlâ kapalıysa kuyruk korunur, ödül kaybolmaz', () async {
    final repository = _CountingRewardRepository();
    final monitor = _SwitchableMonitor(ConnectivityResult.none);
    final sync = await SyncManager.initialize(
      repository,
      connectivityMonitor: monitor,
    );

    await sync.queueQuizReward(
      score: 90,
      correctCount: 3,
      bestStreak: 1,
      totalQuestions: 10,
    );

    // Çevrimdışıyken kaç tur denenirse denensin kayıt yerinde durmalı.
    await drain(sync);
    await drain(sync);

    expect(repository.awardCalls, 0);
    expect(
      SyncManager.pendingCountNotifier.value,
      1,
      reason:
          'Çevrimdışı senkron denemeleri kuyruğu boşaltmamalı; boşaltırsa '
          'oyuncu ağa çıktığında ödülünü hiç almaz.',
    );
  });
}
