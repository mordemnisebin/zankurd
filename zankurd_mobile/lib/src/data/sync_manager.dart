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
  SyncManager._(
    this._repository,
    this._connectivityMonitor,
    this._ownerUserId,
  ) {
    _startConnectivityListener();
  }

  static const _legacyQueueKey = 'zankurd.syncQueue';
  static const _legacyQuarantineKey = 'zankurd.syncQueue.legacyQuarantine';
  static const _queueKeyPrefix = 'zankurd.syncQueue.v2.';
  static const _maxRetries = 5;
  static int _queueSequence = 0;
  static SyncManager? _instance;

  final ZanKurdRepository _repository;
  final ConnectivityMonitor _connectivityMonitor;
  final String? _ownerUserId;
  final List<Map<String, dynamic>> _queue = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Aynı anda tek bir senkronizasyon turu çalışır. İkinci bir tetikleme
  /// (connectivity olayı, yeni kuyruk kaydı) turu iptal etmez; tur bitince bir
  /// kez daha çalışması için işaretlenir.
  bool _syncing = false;
  bool _resyncRequested = false;
  bool _disposed = false;
  bool _acceptingItems = true;
  Future<void>? _syncFuture;

  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> syncingNotifier = ValueNotifier<bool>(false);

  @visibleForTesting
  int get pendingCount => _queue.length;

  String get _queueKey => _queueKeyForUser(_ownerUserId ?? 'signed-out');

  static String _queueKeyForUser(String userId) =>
      '$_queueKeyPrefix${Uri.encodeComponent(userId)}';

  static String _queueItemIdentity(dynamic value) {
    if (value is! Map) return jsonEncode(value);
    final item = Map<String, dynamic>.from(value);
    final queueId = item['queueId'];
    if (queueId is String && queueId.trim().isNotEmpty) {
      return 'id:${queueId.trim()}';
    }
    // Eski kayıtlarda queueId yoktur. Yalnız sabit alanları sabit sırayla
    // imzalamak hem mutable retries'i hem de JSON anahtar sırası farkını
    // dışarıda bırakır.
    return jsonEncode([
      item['type'],
      item['playerId'],
      item['roomId'],
      item['timestamp'],
      item['score'],
      item['correctCount'],
      item['bestStreak'],
      item['totalQuestions'],
      item['xp'],
      item['delta'],
    ]);
  }

  static String? _normalizedUserId(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  void _notifyNotifiers() {
    pendingCountNotifier.value = _queue.length;
    syncingNotifier.value = _syncing;
  }

  /// [restart] için saklanır: `shutdown` singleton'ı boşaltır ama
  /// uygulamanın deposu ve bağlantı gözlemcisi aynı kalır.
  static ZanKurdRepository? _lastRepository;
  static ConnectivityMonitor? _lastConnectivityMonitor;
  static Future<void> _lifecycleTail = Future<void>.value();

  static Future<T> _serializeLifecycle<T>(Future<T> Function() action) async {
    final previous = _lifecycleTail;
    final release = Completer<void>();
    _lifecycleTail = release.future;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }

  static Future<SyncManager> initialize(
    ZanKurdRepository repository, {
    ConnectivityMonitor? connectivityMonitor,
  }) => _serializeLifecycle(
    () => _initializeUnlocked(
      repository,
      connectivityMonitor: connectivityMonitor,
    ),
  );

  static Future<SyncManager> _initializeUnlocked(
    ZanKurdRepository repository, {
    ConnectivityMonitor? connectivityMonitor,
  }) async {
    _lastRepository = repository;
    _lastConnectivityMonitor = connectivityMonitor;
    final ownerUserId = _normalizedUserId(repository.currentUserId);
    final existing = _instance;
    if (existing != null &&
        identical(existing._repository, repository) &&
        existing._ownerUserId == ownerUserId &&
        !existing._disposed) {
      return existing;
    }
    if (existing != null) {
      await _shutdownUnlocked();
    }
    final manager = SyncManager._(
      repository,
      connectivityMonitor ?? _defaultConnectivityMonitor(),
      ownerUserId,
    );
    try {
      await manager._loadQueue();
    } catch (_) {
      manager.dispose();
      rethrow;
    }
    _instance = manager;
    unawaited(manager.sync());
    return manager;
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
  static Future<void> restart() => _serializeLifecycle(_restartUnlocked);

  static Future<void> _restartUnlocked() async {
    final repository = _lastRepository;
    if (repository == null) return;
    final existing = _instance;
    final ownerUserId = _normalizedUserId(repository.currentUserId);
    if (existing != null &&
        identical(existing._repository, repository) &&
        existing._ownerUserId == ownerUserId &&
        !existing._disposed) {
      return;
    }
    await _initializeUnlocked(
      repository,
      connectivityMonitor: _lastConnectivityMonitor,
    );
  }

  static ConnectivityMonitor _defaultConnectivityMonitor() {
    if (kIsWeb) return const AlwaysOnlineConnectivityMonitor();
    return PluginConnectivityMonitor();
  }

  void dispose() {
    _acceptingItems = false;
    _disposed = true;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Oturum kapanışında çağrılır: bekleyen kayıtları sunucuya göndermeyi
  /// son bir kez dener ve singleton'ı serbest bırakır. Normal çıkışta
  /// çevrimdışı kayıtlar kendi kullanıcı kuyruğunda korunur. Yalnız hesap
  /// başarıyla silindiyse [discardQueue] açıkça `true` verilmelidir.
  ///
  /// [dispose] tek başına çağrılırsa `_instance` dolu kaldığı için bir
  /// sonraki [initialize] erken döner ve connectivity dinleyicisi bir daha
  /// kurulmaz — çevrimdışı ödül senkronizasyonu uygulama ömrü boyunca ölür.
  /// Çıkış akışı bu yüzden [dispose] değil bu metodu kullanmalıdır.
  static Future<void> shutdown({
    bool flush = true,
    bool discardQueue = false,
  }) => _serializeLifecycle(
    () => _shutdownUnlocked(flush: flush, discardQueue: discardQueue),
  );

  static Future<void> _shutdownUnlocked({
    bool flush = true,
    bool discardQueue = false,
  }) async {
    final inst = _instance;
    _instance = null;
    if (inst == null) return;
    inst._acceptingItems = false;
    if (flush) {
      try {
        await inst.sync();
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'SyncManager flush');
      }
    } else {
      await inst._syncFuture;
    }
    inst.dispose();
    if (discardQueue && inst._ownerUserId != null) {
      await _removeStoredQueueForUser(inst._ownerUserId);
    }
    pendingCountNotifier.value = 0;
    syncingNotifier.value = false;
  }

  /// Sunucuda başarıyla silinen hesabın yalnız kendi kalıcı kuyruğunu atar.
  /// Aktif manager başka bir kullanıcıya ait olsa bile hedef kimlik açıktır;
  /// o kullanıcının verisi korunur ve yalnız belirtilen anahtar kaldırılır.
  static Future<void> discardQueueForUser(String userId) =>
      _serializeLifecycle(() async {
        final normalized = _normalizedUserId(userId);
        if (normalized == null) {
          throw ArgumentError.value(userId, 'userId', 'must not be empty');
        }
        await _shutdownUnlocked(flush: false);
        final prefs = await SharedPreferences.getInstance();
        try {
          await _migrateLegacyQueue(prefs);
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'SyncManager legacy migration before account discard',
          );
        }
        Object? cleanupError;
        StackTrace? cleanupStack;
        try {
          await _discardLegacyItemsForUser(prefs, normalized);
        } catch (error, stack) {
          cleanupError = error;
          cleanupStack = stack;
          ErrorReporter.record(
            error,
            stack,
            reason: 'SyncManager discard user legacy queue failed',
          );
        }
        try {
          await _removeStoredQueueForUser(normalized, prefs: prefs);
        } catch (error, stack) {
          cleanupError ??= error;
          cleanupStack ??= stack;
        }
        try {
          await _removeStorageKeyDurably(_legacyQuarantineKey, prefs: prefs);
        } catch (error, stack) {
          cleanupError ??= error;
          cleanupStack ??= stack;
        }
        if (cleanupError != null) {
          Error.throwWithStackTrace(cleanupError, cleanupStack!);
        }
      });

  @visibleForTesting
  static Future<void> resetForTesting() =>
      _serializeLifecycle(_resetForTestingUnlocked);

  static Future<void> _resetForTestingUnlocked() async {
    final inst = _instance;
    _instance = null;
    if (inst != null) {
      inst._acceptingItems = false;
      await inst._syncFuture;
      inst.dispose();
    }
    _lastRepository = null;
    _lastConnectivityMonitor = null;
    _queueSequence = 0;
    pendingCountNotifier.value = 0;
    syncingNotifier.value = false;
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
    final prefs = await SharedPreferences.getInstance();
    try {
      await _migrateLegacyQueue(prefs);
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'SyncManager legacy queue migration failed',
      );
      developer.log(
        'Legacy sync queue migration failed: $error',
        name: 'SyncManager',
      );
    }

    // Legacy taşıma/karantina başarısız olsa bile sağlam kullanıcı kuyruğu
    // mutlaka yüklenir. Bu bölümdeki hata ise manager'ın yayımlanmasını
    // engeller; boş bir manager eski kalıcı kaydı ezemez.
    final dataStr = prefs.getString(_queueKey);
    if (dataStr != null) {
      final decoded = jsonDecode(dataStr);
      if (decoded is! List || decoded.any((item) => item is! Map)) {
        throw const FormatException('Invalid user-scoped sync queue.');
      }
      _queue
        ..clear()
        ..addAll(decoded.map((item) => Map<String, dynamic>.from(item as Map)));
    }
    _notifyNotifiers();
  }

  static Future<void> _migrateLegacyQueue(SharedPreferences prefs) async {
    final legacy = prefs.getString(_legacyQueueKey);
    if (legacy == null) return;
    if (legacy.trim() == '[]' || legacy.trim().isEmpty) {
      final removed = await prefs.remove(_legacyQueueKey);
      if (!removed) throw StateError('Legacy sync queue was not removed.');
      return;
    }

    late final List<dynamic> decoded;
    try {
      final value = jsonDecode(legacy);
      if (value is! List) {
        throw const FormatException('Legacy queue is not a list.');
      }
      decoded = value;
    } catch (_) {
      await _appendLegacyQuarantine(prefs, [legacy]);
      final removed = await prefs.remove(_legacyQueueKey);
      if (!removed) throw StateError('Malformed legacy queue was not removed.');
      return;
    }

    final byOwner = <String, List<Map<String, dynamic>>>{};
    final unattributed = <dynamic>[];
    for (final value in decoded) {
      if (value is! Map) {
        unattributed.add(value);
        continue;
      }
      final item = Map<String, dynamic>.from(value);
      final rawPlayerId = item['playerId'];
      final playerId = rawPlayerId is String
          ? _normalizedUserId(rawPlayerId)
          : null;
      if (playerId == null) {
        unattributed.add(item);
      } else {
        byOwner.putIfAbsent(playerId, () => []).add(item);
      }
    }

    // Her sahip kendi anahtarına taşınır. Legacy anahtar ancak bütün
    // yazımlar başarıyla kalıcılaştıktan sonra kaldırılır; yarım kalan bir
    // geçiş sonraki açılışta içerik imzasıyla tekrar güvenle denenir.
    for (final entry in byOwner.entries) {
      await _mergeStoredQueue(prefs, entry.key, entry.value);
    }
    if (unattributed.isNotEmpty) {
      await _appendLegacyQuarantine(prefs, unattributed);
    }
    final removed = await prefs.remove(_legacyQueueKey);
    if (!removed) throw StateError('Legacy sync queue was not removed.');
  }

  static Future<void> _mergeStoredQueue(
    SharedPreferences prefs,
    String userId,
    List<Map<String, dynamic>> additions,
  ) async {
    final key = _queueKeyForUser(userId);
    final existingRaw = prefs.getString(key);
    final existing = existingRaw == null
        ? <dynamic>[]
        : jsonDecode(existingRaw);
    if (existing is! List) {
      throw const FormatException('Invalid user-scoped sync queue.');
    }
    final combined = <dynamic>[...existing];
    final signatures = combined.map(_queueItemIdentity).toSet();
    for (final item in additions) {
      if (signatures.add(_queueItemIdentity(item))) combined.add(item);
    }
    final saved = await prefs.setString(key, jsonEncode(combined));
    if (!saved) throw StateError('Migrated sync queue was not persisted.');
  }

  static Future<void> _appendLegacyQuarantine(
    SharedPreferences prefs,
    List<dynamic> additions,
  ) async {
    final previousRaw = prefs.getString(_legacyQuarantineKey);
    List<dynamic> combined;
    if (previousRaw == null || previousRaw.isEmpty) {
      combined = <dynamic>[];
    } else {
      try {
        final previous = jsonDecode(previousRaw);
        combined = previous is List ? <dynamic>[...previous] : [previousRaw];
      } catch (_) {
        combined = [previousRaw];
      }
    }
    final signatures = combined.map(_queueItemIdentity).toSet();
    for (final item in additions) {
      if (signatures.add(_queueItemIdentity(item))) combined.add(item);
    }
    final saved = await prefs.setString(
      _legacyQuarantineKey,
      jsonEncode(combined),
    );
    if (!saved) throw StateError('Legacy quarantine was not persisted.');
  }

  static Future<void> _discardLegacyItemsForUser(
    SharedPreferences prefs,
    String userId,
  ) async {
    final raw = prefs.getString(_legacyQueueKey);
    if (raw == null) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! List) return;
    final remaining = decoded
        .where((value) {
          if (value is! Map) return true;
          final playerId = value['playerId'];
          return playerId is! String || _normalizedUserId(playerId) != userId;
        })
        .toList(growable: false);
    if (remaining.length == decoded.length) return;
    if (remaining.isEmpty) {
      final removed = await prefs.remove(_legacyQueueKey);
      if (!removed) throw StateError('Deleted account legacy queue remained.');
      return;
    }
    final saved = await prefs.setString(_legacyQueueKey, jsonEncode(remaining));
    if (!saved) throw StateError('Deleted account legacy queue remained.');
  }

  static Future<void> _removeStoredQueueForUser(
    String userId, {
    SharedPreferences? prefs,
  }) => _removeStorageKeyDurably(_queueKeyForUser(userId), prefs: prefs);

  static Future<void> _removeStorageKeyDurably(
    String key, {
    SharedPreferences? prefs,
  }) async {
    final preferences = prefs ?? await SharedPreferences.getInstance();
    late Object lastError;
    late StackTrace lastStack;
    try {
      if (await preferences.remove(key)) return;
      lastError = StateError('Sync queue remove returned false.');
      lastStack = StackTrace.current;
    } catch (error, stack) {
      lastError = error;
      lastStack = stack;
    }

    // Bazı platformlarda remove başarısızken üzerine boş liste yazmak veri
    // sızıntısını engelleyebilir; ardından anahtarı bir kez daha kaldırmayı
    // deneriz. UUID içeren boş anahtarı da başarı saymayız.
    try {
      final cleared = await preferences.setString(key, '[]');
      if (cleared && await preferences.remove(key)) return;
      lastError = StateError('Sync queue could not be durably removed.');
      lastStack = StackTrace.current;
    } catch (error, stack) {
      lastError = error;
      lastStack = stack;
    }
    ErrorReporter.record(
      lastError,
      lastStack,
      reason: 'SyncManager discard user queue failed',
    );
    throw StateError('Sync queue could not be durably removed.');
  }

  Future<void> _saveQueue({bool propagateFailure = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(_queueKey, jsonEncode(_queue));
      if (!saved) {
        throw StateError('Sync queue was not persisted.');
      }
    } catch (e, stack) {
      ErrorReporter.record(e, stack, reason: 'SyncManager save queue');
      developer.log('Failed to save sync queue: $e', name: 'SyncManager');
      if (propagateFailure) rethrow;
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
  ///
  /// Dönen [Future], kayıt kalıcı kuyruğa yazılmadan tamamlanmaz; kalıcı
  /// yazım başarısızsa hata verir ve senkronizasyonu başlatmaz.
  Future<void> queueQuizReward({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    String? roomId,
  }) async {
    final currentUserId = _normalizedUserId(_repository.currentUserId);
    if (!_acceptingItems ||
        _ownerUserId == null ||
        currentUserId != _ownerUserId) {
      throw StateError(
        'Sync queue owner does not match the authenticated user.',
      );
    }
    _queue.add({
      'queueId': '${DateTime.now().microsecondsSinceEpoch}-${_queueSequence++}',
      'type': 'sync_quiz_reward',
      'score': score,
      'correctCount': correctCount,
      'bestStreak': bestStreak,
      'totalQuestions': totalQuestions,
      'roomId': roomId,
      'playerId': _ownerUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'retries': 0,
    });
    _notifyNotifiers();
    await _saveQueue(propagateFailure: true);
    unawaited(sync());
  }

  Future<void> sync() {
    // Yeniden girişe karşı koruma: iki eşzamanlı tur aynı kaydı iki kez
    // göndermez. İkinci çağıran aynı Future'ı bekler; böylece shutdown,
    // sürmekte olan tur bitmeden kuyruğu kapatamaz.
    final running = _syncFuture;
    if (running != null) {
      _resyncRequested = true;
      return running;
    }

    late final Future<void> future;
    future = _runSync().whenComplete(() {
      if (identical(_syncFuture, future)) {
        _syncFuture = null;
      }
    });
    _syncFuture = future;
    return future;
  }

  Future<void> _runSync() async {
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
    final ownerUserId = _ownerUserId;
    final currentUserId = _normalizedUserId(_repository.currentUserId);
    if (ownerUserId == null || currentUserId != ownerUserId) {
      developer.log(
        'Sync queue owner no longer matches the authenticated user.',
        name: 'SyncManager',
      );
      return;
    }
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
    if (_normalizedUserId(repo.currentUserId) != ownerUserId) {
      developer.log(
        'Authenticated user changed during connectivity check.',
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

    for (var index = 0; index < batch.length; index++) {
      final item = batch[index];
      if (_normalizedUserId(repo.currentUserId) != ownerUserId) {
        failedItems.addAll(batch.skip(index));
        break;
      }
      final rawType = item['type'];
      final type = rawType is String ? rawType : null;
      final rawPlayerId = item['playerId'];
      final itemPlayerId = rawPlayerId is String ? rawPlayerId : null;

      if (_normalizedUserId(itemPlayerId) != ownerUserId) {
        ErrorReporter.record(
          StateError('Unattributed or mismatched sync queue item.'),
          StackTrace.current,
          reason: 'SyncManager rejected queue item with invalid owner.',
        );
        developer.log(
          'Dropping sync item with missing or mismatched owner.',
          name: 'SyncManager',
        );
        continue;
      }

      try {
        if (type == 'sync_quiz_reward') {
          final room = (item['roomId'] as String?) == null
              ? null
              : repo.createRoom().copyWith(id: item['roomId'] as String?);
          // Bu kontrol ile aşağıdaki çağrı arasında await yoktur; hesap
          // değişimi event loop'a dönmeden RPC'ye sızamaz.
          if (_normalizedUserId(repo.currentUserId) != ownerUserId) {
            failedItems.addAll(batch.skip(index));
            break;
          }
          final amount = await repo.awardQuizCoins(
            score: (item['score'] as num?)?.toInt() ?? 0,
            correctCount: (item['correctCount'] as num?)?.toInt() ?? 0,
            bestStreak: (item['bestStreak'] as num?)?.toInt() ?? 0,
            totalQuestions: (item['totalQuestions'] as num?)?.toInt() ?? 0,
            room: room,
          );
          if (_normalizedUserId(repo.currentUserId) != ownerUserId) {
            // RPC tamamlandıktan sonra kimlik değiştiyse sonucu güvenle
            // atfedemeyiz. Oda ödülü idempotent olduğu için kaydı korumak,
            // yanlış hesaptan silmekten daha güvenlidir.
            failedItems.addAll(batch.skip(index));
            break;
          }
          // Gerçek hata `awardQuizCoins` tarafından yeniden fırlatılır.
          // Başarılı 0 yanıtı (ödül yok veya daha önce talep edilmiş) normal
          // sonuçtur ve aynı kayıt yeniden kuyruğa alınmamalıdır.
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
    _notifyNotifiers();
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
