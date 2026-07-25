import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static SyncManager? _instance;

  final ZanKurdRepository _repository;
  final ConnectivityMonitor _connectivityMonitor;
  final List<Map<String, dynamic>> _queue = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Aynı anda tek bir senkronizasyon turu çalışır. İkinci bir tetikleme
  /// (connectivity olayı, yeni XP kaydı) turu iptal etmez; tur bitince bir
  /// kez daha çalışması için işaretlenir.
  bool _syncing = false;
  bool _resyncRequested = false;
  bool _disposed = false;

  @visibleForTesting
  int get pendingCount => _queue.length;

  static Future<SyncManager> initialize(
    ZanKurdRepository repository, {
    ConnectivityMonitor? connectivityMonitor,
  }) async {
    if (_instance != null) return _instance!;
    final manager = SyncManager._(
      repository,
      connectivityMonitor ?? _defaultConnectivityMonitor(),
    );
    await manager._loadQueue();
    manager.sync();
    return _instance = manager;
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
  /// kurulmaz — çevrimdışı XP senkronizasyonu uygulama ömrü boyunca ölür.
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

  /// Kazanılan XP farkını senkronizasyon kuyruğuna alır.
  ///
  /// [delta] sunucuya yazılacak olan farktır; [totalXP] yalnızca teşhis ve
  /// eski kayıtlarla uyumluluk için saklanır. Sunucu mutlak değeri kabul
  /// etmez (bkz. `supabase/2026-07-25_xp_server_authority.sql`).
  void queueXP(int totalXP, {int? delta}) {
    final playerId = _repository.currentUserId;
    final resolvedDelta = delta ?? 0;
    developer.log(
      'Queueing XP update offline: +$resolvedDelta XP (total $totalXP) '
      'for user: $playerId',
      name: 'SyncManager',
    );
    _queue.add({
      'type': 'sync_xp',
      'xp': totalXP,
      'delta': resolvedDelta,
      'playerId': playerId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
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
    try {
      do {
        _resyncRequested = false;
        await _syncOnce();
      } while (_resyncRequested && !_disposed);
    } finally {
      _syncing = false;
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
    // bir queueXP() çağrısı canlı liste üzerinde iterasyonu
    // ConcurrentModificationError ile düşürürdü.
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
        if (type == 'sync_xp') {
          final delta = (item['delta'] as num?)?.toInt() ?? 0;
          if (delta > 0) {
            final total = await repo.awardProfileXPDelta(delta);
            developer.log(
              'Successfully synced XP: +$delta (server total $total)',
              name: 'SyncManager',
            );
          } else {
            // Eski kayıtlarda yalnızca mutlak toplam vardı; sunucu bunu
            // kabul etmiyor. Sonsuz yeniden denemeyi önlemek için düşürülür.
            developer.log(
              'Dropping legacy absolute-XP item without delta: $item',
              name: 'SyncManager',
            );
          }
        }
      } catch (e, stack) {
        ErrorReporter.record(e, stack, reason: 'SyncManager process item');
        developer.log(
          'Failed to sync item ($item): $e. Keeping in queue.',
          name: 'SyncManager',
        );
        failedItems.add(item);
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
