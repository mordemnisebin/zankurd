import 'dart:async';

import 'local_progress_scope.dart';

/// Seri ile bulut anlık görüntüsünün aynı hesaba yazımları sıraya girer.
/// İç içe store çağrıları aynı zone içinde aynı kilidi yeniden alabilir.
class LocalProgressWriteLock {
  LocalProgressWriteLock._();
  static final Object _zoneKey = Object();
  static final Map<String?, Future<void>> _tails = {};

  static String physical(String logical) {
    final captured = Zone.current[_zoneKey] as _Owner?;
    final owner = captured == null || !captured.active
        ? LocalProgressScope.activeUserId
        : captured.id;
    return owner == null
        ? logical
        : LocalProgressScope.physicalFor(owner, logical);
  }

  static Future<T> run<T>(String? owner, Future<T> Function() action) async {
    final held = Zone.current[_zoneKey] as _Owner?;
    if (held != null && held.active && held.id == owner) return action();
    final previous = _tails[owner] ?? Future<void>.value();
    final release = Completer<void>();
    _tails[owner] = release.future;
    await previous;
    final token = _Owner(owner);
    try {
      if (LocalProgressScope.activeUserId != owner) {
        throw StateError('Local progress owner changed before write.');
      }
      return await runZoned(action, zoneValues: {_zoneKey: token});
    } finally {
      token.active = false;
      release.complete();
      if (identical(_tails[owner], release.future)) _tails.remove(owner);
    }
  }
}

class _Owner {
  _Owner(this.id);
  bool active = true;
  final String? id;
}
