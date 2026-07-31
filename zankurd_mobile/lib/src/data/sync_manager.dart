import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/utils/error_reporter.dart';
import 'zankurd_repository.dart';
import 'supabase_zankurd_repository.dart';

abstract class ConnectivityMonitor {
  Stream<List<ConnectivityResult>> get onConnectivityChanged;
  Future<List<ConnectivityResult>> checkConnectivity();
}

class PluginConnectivityMonitor implements ConnectivityMonitor {
  PluginConnectivityMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() =>
      _connectivity.checkConnectivity();
}

class AlwaysOnlineConnectivityMonitor implements ConnectivityMonitor {
  const AlwaysOnlineConnectivityMonitor();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => const [
    ConnectivityResult.wifi,
  ];
}

class SyncManager {
  SyncManager._(this._repository, this._connectivityMonitor) {
    _startConnectivityListener();
  }

  static const _queueKey = 'zankurd.syncQueue';
  static const _maxRetries = 5;
  static SyncManager? _instance;

  final ZanKurdRepository _repository;
  final ConnectivityMonitor _connectivityMonitor;
  final List<Map<String, dynamic>> _queue = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Aynı anda tek bir senkronizasyon turu çalışır. İkinci bir tetikleme
  /// (connectivity olayı, yeni kuyruk kaydı) turu iptal etmez; tur bitince bir
  /// kez daha çalışması için işaretlenir.
  bool _syncing = false;
  bool _resyncRequested = false;
  bool _disposed = false;

  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> syncingNotifier = ValueNotifier<bool>(false);

  @visibleForTesting
  int get pendingCount => _queue.length;

  void _notifyNotifiers() {
    pendingCountNotifier.value = _queue.length;
    syncingNotifier.value = _syncing;
  }

  /// [restart] için saklanır: `shutdown` singleton'ı boşaltır ama
  /// uygulamanın deposu ve bağlantı gözlemcisi aynı kalır.
  static ZanKurdRepository? _lastRepository;
  static ConnectivityMonitor? _lastConnectivityMonitor;

  static Future<SyncManager> initialize(
    ZanKurdRepository repository, {
    ConnectivityMonitor? connectivityMonitor,
  }) async {
    _lastRepository = repository;
    _lastConnectivityMonitor = connectivityMonitor;
    if (_instance != null) return _instance!;
    final manager = SyncManager._(
      repository,
      connectivityMonitor ?? _defaultConnectivityMonitor(),
    );
    await manager._loadQueue();
    manager.sync();
    return _instance = manager;
  }

  /// Oturum yeniden açıldığında kuyruğu ayağa kaldırır.
  ///
  /// [initialize] uygulama ömrü boyunca yalnız `main()` içinde bir kez
  /// çağrılıyordu; [shutdown] ise her `signOut()`ta singleton'ı
  /// boşaltıyor ve hiçbir yer onu geri kurmuyordu. Sonuç: aynı oturumda
  /// çıkıp tekrar giren kullanıcıda çevrimdışı ödül kuyruğu o oturum
  /// boyunca tamamen ölü kalıyordu (2026-07-31 denetimi).
  ///
  /// Kurulu ise hiçbir şey yapmaz; hiç `initialize` edilmemişse (test
  /// ortamı) sessizce döner.
  static Future<void> restart() async {
    if (_instance != null) return;
    final repository = _lastRepository;
    if (repository == null) return;
    await initialize(repository, connectivityMonitor: _lastConnectivityMonitor);
  }

  static ConnectivityMonitor _defaultConnectivityMonitor() {
    if (kIsWeb) return const AlwaysOnlineConnectivityMonitor();
    return PluginConnectivityMonitor();
  }

  void dispose() {
    _disposed = true;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Oturum kapanışında çağrılır: bekleyen kayıtları sunucuya göndermeyi
  /// son bir kez dener, kuyruğu temizler ve singleton'ı serbest bırakır.
  ///
  /// [dispose] tek başına çağrılırsa `_instance` dolu kaldığı için bir
  /// sonraki [initialize] erken döner ve connectivity dinleyicisi bir daha
  /// kurulmaz — çevrimdışı ödül senkronizasyonu uygulama ömrü boyunca ölür.
  /// Çıkış akışı bu yüzden [dispose] değil bu metodu kullanmalıdır.
  static Future<void> shutdown({bool flush = true}) async {
    final inst = _instance;
    _instance = null;
    if (inst == null) return;
    if (flush) {
      try {
        await inst.sync();
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'SyncManager flush');
      }
    }
    await inst.clearQueue();
    inst.dispose();
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    _instance?.dispose();
    _instance = null;
    _lastRepository = null;
    _lastConnectivityMonitor = null;
  }

  void _startConnectivityListener() {
    try {
      _connectivitySubscription = _connectivityMonitor.onConnectivityChanged
          .listen(
            (result) {
              if (result.isNotEmpty &&
                  result.first != ConnectivityResult.none) {
                developer.log(
                  'Network back online. Triggering synchronization...',
                  name: 'SyncManager',
                );
                sync();
              }
            },
            onError: (Object error, StackTrace stack) {
              developer.log(
                'Connectivity listener unavailable: $error',
                name: 'SyncManager',
                error: error,
                stackTrace: stack,
              );
            },
          );
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'SyncManager connectivity listener',
      );
      developer.log(
        'Connectivity listener unavailable: $error',
        name: 'SyncManager',
        error: error,
        stackTrace: stack,
      );
    }
  }

  static SyncManager get instance {
    final inst = _instance;
    if (inst == null) {
      throw StateError(
        'SyncManager has not been initialized. Call initialize first.',
      );
    }
    return inst;
  }

  /// Kurulu değilse `null` — fırlatmayan erişim.
  ///
  /// [initialize] uygulama ömrü boyunca yalnız `main()` içinde bir kez
  /// çağrılıyor, ama [shutdown] her `signOut()`ta `_instance`ı boşaltıyor
  /// ve hiçbir yer onu yeniden kurmuyordu. Aynı oturumda çıkıp tekrar
  /// giren kullanıcıda [instance] `StateError` fırlatıyordu.
  ///
  /// Bu, ödül kuyruğa alınırken oluyordu ve çağrı `try` bloğunun DIŞINDA
  /// duruyordu: istisna yukarı kaçıyor, `Navigator.pushReplacement`
  /// satırına hiç ulaşılmıyordu. Oyuncu son soruda, düğmesi kilitli
  /// hâlde takılı kalıyor; turunun sonucunu, XP'sini, rozetlerini hiç
  /// görmüyordu (2026-07-31 denetimi).
  ///
  /// Ödül kuyruğa alınamasa bile sonuç ekranı açılmalıdır: kuyruk bir
  /// iyileştirmedir, turun kendisi değil.
  static SyncManager? get maybeInstance => _instance;

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_queueKey);
      if (dataStr != null) {
        final decoded = jsonDecode(dataStr) as List;
        _queue.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _queue.add(item);
          }
        }
      }
    } catch (e) {
      ErrorReporter.record(
        e,
        StackTrace.current,
        reason: 'SyncManager load queue',
      );
      developer.log('Failed to load sync queue: $e', name: 'SyncManager');
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueKey, jsonEncode(_queue));
    } catch (e) {
      ErrorReporter.record(
        e,
        StackTrace.current,
        reason: 'SyncManager save queue',
      );
      developer.log('Failed to save sync queue: $e', name: 'SyncManager');
    }
  }

  /// Sunucuya ulaşamadığı için verilemeyen tur ödülünü kuyruğa alır.
  ///
  /// Çevrimdışı bitirilen bir turda `claim_quiz_reward` çağrısı düşüyor ve
  /// coin **sessizce kayboluyordu**: ne yeniden deneme, ne bir ileti. XP
  /// aynı durumda kuyruğa giriyordu; coin girmiyordu (2026-07-26).
  ///
  /// Kuyruğa giren şey miktar değil, **turun olguları**. Ödülü yine sunucu
  /// hesaplar; istemci hiçbir zaman "şu kadar coin ver" demez. Yani
  /// bekletmek, çağrının o an yapılmasından fazla bir güven istemez.
  ///
  /// Oda turlarında sunucu aynı odanın ödülünü ikinci kez vermez
  /// (`coin_transactions` içinde oda kimliğine göre arar), bu yüzden
  /// yeniden gönderim güvenlidir.
  void queueQuizReward({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    String? roomId,
  }) {
    _queue.add({
      'type': 'sync_quiz_reward',
      'score': score,
      'correctCount': correctCount,
      'bestStreak': bestStreak,
      'totalQuestions': totalQuestions,
      'roomId': roomId,
      'playerId': _repository.currentUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'retries': 0,
    });
    unawaited(_saveQueue());
    unawaited(sync());
  }

  Future<void> sync() async {
    // Yeniden girişe karşı koruma: iki eşzamanlı tur aynı kaydı iki kez
    // gönderir ve tur sonundaki kuyruk yazımında birbirini ezerdi.
    if (_syncing) {
      _resyncRequested = true;
      return;
    }
    _syncing = true;
    _notifyNotifiers();
    try {
      do {
        _resyncRequested = false;
        await _syncOnce();
      } while (_resyncRequested && !_disposed);
    } finally {
      _syncing = false;
      _notifyNotifiers();
    }
  }

  Future<void> _syncOnce() async {
    if (_queue.isEmpty) return;
    final repo = _repository;
    if (repo is! SupabaseZanKurdRepository) {
      _queue.clear();
      await _saveQueue();
      return;
    }

    final connectivity = await _checkConnectivity();
    if (connectivity.isEmpty || connectivity.first == ConnectivityResult.none) {
      developer.log('Device is offline. Skipping sync.', name: 'SyncManager');
      return;
    }

    final currentUserId = repo.currentUserId;
    if (currentUserId == null) {
      developer.log(
        'No authenticated user. Skipping sync.',
        name: 'SyncManager',
      );
      return;
    }

    // Kuyruğun anlık kopyası üzerinde dönülür: `await` sırasında gelen yeni
    // bir kayıt canlı liste üzerinde iterasyonu ConcurrentModificationError
    // ile düşürmemelidir.
    final batch = List<Map<String, dynamic>>.of(_queue);
    developer.log(
      'Syncing ${batch.length} pending updates to Supabase...',
      name: 'SyncManager',
    );
    final List<Map<String, dynamic>> failedItems = [];

    for (final item in batch) {
      final type = item['type'] as String?;
      final itemPlayerId = item['playerId'] as String?;

      if (itemPlayerId != null && itemPlayerId != currentUserId) {
        developer.log(
          'Skipping sync item: belongs to different user ($itemPlayerId), current is $currentUserId',
          name: 'SyncManager',
        );
        failedItems.add(item);
        continue;
      }

      try {
        if (type == 'sync_quiz_reward') {
          final amount = await repo.awardQuizCoins(
            score: (item['score'] as num?)?.toInt() ?? 0,
            correctCount: (item['correctCount'] as num?)?.toInt() ?? 0,
            bestStreak: (item['bestStreak'] as num?)?.toInt() ?? 0,
            totalQuestions: (item['totalQuestions'] as num?)?.toInt() ?? 0,
            room: (item['roomId'] as String?) == null
                ? null
                : repo.createRoom().copyWith(id: item['roomId'] as String?),
          );
          // `awardQuizCoins` başarısızlıkta da 0 döner (istisna sızdırmaz),
          // dolayısıyla 0 "verildi" sayılamaz: öyle sayılsaydı kayıt
          // kuyruktan düşer ve ödül yine sessizce kaybolurdu — düzeltilen
          // kusurun ta kendisi. Sunucunun "bu tur zaten ödendi" yanıtı da
          // 0'dır; o durumda kayıt boşuna birkaç kez denenip düşürülür.
          // Boş yere deneme, kaybolmuş coinden ucuzdur.
          if (amount <= 0) {
            throw StateError('quiz reward not granted yet (amount 0)');
          }
          developer.log(
            'Successfully synced quiz reward: +$amount coin',
            name: 'SyncManager',
          );
        } else if (type == 'sync_xp') {
          // XP artık yalnızca cihazda tutulur. Eski sürümlerin bıraktığı XP
          // kayıtlarını sunucuya yazılmış gibi göstermeden kuyruktan düşür.
          developer.log(
            'Dropping unsupported legacy XP item; XP is device-local.',
            name: 'SyncManager',
          );
        }
      } on PostgrestException catch (e, stack) {
        // 42883 = function does not exist → migration henüz uygulanmamış.
        // Sonsuz döngüyü önlemek için anında düşür ve bir kez raporla.
        if (e.code == '42883') {
          ErrorReporter.record(
            e,
            stack,
            reason:
                'SyncManager: RPC does not exist (migration missing). '
                'Dropping item permanently.',
          );
          developer.log(
            'RPC not found (42883). Dropping item: $item',
            name: 'SyncManager',
          );
          continue;
        }
        final retries = ((item['retries'] as num?) ?? 0).toInt() + 1;
        if (retries >= _maxRetries) {
          ErrorReporter.record(
            e,
            stack,
            reason:
                'SyncManager: max retries ($_maxRetries) exceeded. '
                'Dropping item.',
          );
          developer.log(
            'Max retries reached for item ($item): $e. Dropping.',
            name: 'SyncManager',
          );
        } else {
          item['retries'] = retries;
          failedItems.add(item);
        }
      } catch (e, stack) {
        final retries = ((item['retries'] as num?) ?? 0).toInt() + 1;
        if (retries >= _maxRetries) {
          ErrorReporter.record(
            e,
            stack,
            reason:
                'SyncManager: max retries ($_maxRetries) exceeded. '
                'Dropping item.',
          );
          developer.log(
            'Max retries reached for item ($item): $e. Dropping.',
            name: 'SyncManager',
          );
        } else {
          item['retries'] = retries;
          failedItems.add(item);
          developer.log(
            'Failed to sync item ($item): $e. Retry $retries/$_maxRetries.',
            name: 'SyncManager',
          );
        }
      }
    }

    // `clear()` yerine yalnızca bu turda işlenenler düşürülür; tur sırasında
    // eklenen yeni kayıtlar korunur.
    for (final item in batch) {
      _queue.remove(item);
    }
    _queue.insertAll(0, failedItems);
    await _saveQueue();
  }

  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
    developer.log('Sync queue cleared.', name: 'SyncManager');
  }

  Future<List<ConnectivityResult>> _checkConnectivity() async {
    try {
      return await _connectivityMonitor.checkConnectivity();
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'SyncManager connectivity check',
      );
      developer.log(
        'Connectivity check unavailable; continuing as online: $error',
        name: 'SyncManager',
        error: error,
        stackTrace: stack,
      );
      return const [ConnectivityResult.wifi];
    }
  }
}
