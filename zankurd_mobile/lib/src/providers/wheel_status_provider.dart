import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/zankurd_repository.dart';
import '../utils/error_reporter.dart';
import '../utils/network_error.dart';

/// Çark ekranı ve bütün giriş noktalarının ortak günlük hak durumu.
class WheelStatusProvider extends ChangeNotifier with WidgetsBindingObserver {
  WheelStatusProvider(this._repository) {
    WidgetsBinding.instance.addObserver(this);
  }

  ZanKurdRepository _repository;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _pending;
  bool canSpin = false;
  int extraSpins = 0;
  bool loading = true;
  Object? error;

  bool get ready => !loading && error == null && canSpin;
  bool get offline => error != null && isLikelyOfflineError(error!);

  void updateRepository(ZanKurdRepository repository) {
    if (identical(repository, _repository)) return;
    _repository = repository;
    _invalidate();
    // ProxyProvider güncellemesi build sırasında gerçekleşebilir.
    scheduleMicrotask(() {
      if (!_disposed) unawaited(refresh());
    });
  }

  void _invalidate() {
    _generation++;
    _pending = null;
    canSpin = false;
    extraSpins = 0;
    error = null;
  }

  Future<void> refresh() {
    if (_disposed) return Future<void>.value();
    final pending = _pending;
    if (pending != null) return pending;
    loading = true;
    canSpin = false;
    error = null;
    notifyListeners();
    final generation = _generation;
    return _pending = _load(generation);
  }

  Future<void> _load(int generation) async {
    final repository = _repository;
    try {
      final available = await repository.canSpinToday();
      var extra = 0;
      try {
        extra = await repository.unusedExtraSpins();
      } catch (_) {
        // Ek hak sayısı okunamasa da sunucunun çevrilebilirlik kararı geçerli.
      }
      if (_disposed || generation != _generation) return;
      canSpin = available;
      extraSpins = extra;
    } catch (failure, stack) {
      if (_disposed || generation != _generation) return;
      error = failure;
      ErrorReporter.record(failure, stack, reason: 'canSpinToday failed');
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _pending = null;
        notifyListeners();
      }
    }
  }

  Future<int> spin() async {
    final generation = _generation;
    final amount = await _repository.awardSpinCoins();
    if (_disposed || generation != _generation) return amount;
    // Ödül yazıldığı anda eski Hazır bilgisini kaldır. Önceden başlamış
    // bir durum sorgusu sonradan true dönse bile bu kararı geri alamaz.
    _invalidate();
    loading = false;
    notifyListeners();
    if (amount > 0) unawaited(refresh());
    return amount;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
