import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @visibleForTesting
  static Future<void> resetForTesting() async {
    await _instance?._connectivitySubscription?.cancel();
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
      developer.log('Failed to load sync queue: $e', name: 'SyncManager');
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueKey, jsonEncode(_queue));
    } catch (e) {
      developer.log('Failed to save sync queue: $e', name: 'SyncManager');
    }
  }

  void queueXP(int xp) {
    developer.log('Queueing XP update offline: $xp XP', name: 'SyncManager');
    _queue.add({
      'type': 'sync_xp',
      'xp': xp,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    _saveQueue();
    sync();
  }

  Future<void> sync() async {
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

    developer.log(
      'Syncing ${_queue.length} pending updates to Supabase...',
      name: 'SyncManager',
    );
    final List<Map<String, dynamic>> failedItems = [];

    for (final item in _queue) {
      final type = item['type'] as String?;
      try {
        if (type == 'sync_xp') {
          final xp = item['xp'] as int;
          await repo.updateProfileXP(xp);
          developer.log('Successfully synced XP: $xp', name: 'SyncManager');
        }
      } catch (e) {
        developer.log(
          'Failed to sync item ($item): $e. Keeping in queue.',
          name: 'SyncManager',
        );
        failedItems.add(item);
      }
    }

    _queue.clear();
    _queue.addAll(failedItems);
    await _saveQueue();
  }

  Future<List<ConnectivityResult>> _checkConnectivity() async {
    try {
      return await _connectivityMonitor.checkConnectivity();
    } catch (error, stack) {
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
