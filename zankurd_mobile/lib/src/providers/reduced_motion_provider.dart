import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// "Hareketi azalt" tercihini yönetir ve tüm uygulamaya sunar.
///
/// Etkin değer, kullanıcı tercihi VEYA sistemin `disableAnimations` tercihiyle
/// birlikte çalışır (ikisinden biri açıksa hareket azaltılır). İşlevsel geri
/// bildirim tamamen kaybolmaz; yalnız uzun giriş/scale/bounce animasyonları ve
/// yoğun konfeti kısaltılır. [motionDuration] bunun için yardımcıdır.
class ReducedMotionProvider extends ChangeNotifier {
  ReducedMotionProvider({bool initialUserReduce = false})
    : _userReduce = initialUserReduce,
      _persisted = initialUserReduce;

  static const _storageKey = 'zankurd.reduceMotion';

  bool _userReduce;

  /// Diske YAZILMIŞ son değer; yazım reddedilirse ekran bu değere döner.
  bool _persisted;
  bool _systemReduce = false;

  bool get userReduce => _userReduce;
  bool get systemReduce => _systemReduce;

  /// Kullanıcı ayarı veya sistem tercihi açıksa hareket azaltılır.
  bool get reduceMotion => _userReduce || _systemReduce;

  static Future<ReducedMotionProvider> load() async {
    bool value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getBool(_storageKey) ?? false;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'reduced_motion_load');
    }
    return ReducedMotionProvider(initialUserReduce: value);
  }

  Future<void> setUserReduce(bool value) async {
    if (_userReduce == value && _persisted == value) return;
    if (_userReduce != value) {
      _userReduce = value;
      notifyListeners();
    }
    var saved = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = await prefs.setBool(_storageKey, value);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'reduced_motion_persist');
    }
    if (saved) {
      _persisted = value;
    } else if (_userReduce == value) {
      ErrorReporter.record(
        StateError('Reduced motion preference was not persisted.'),
        StackTrace.current,
        reason: 'reduced_motion_persist',
      );
      _userReduce = _persisted;
      notifyListeners();
    }
  }

  /// Sistem `MediaQuery.disableAnimations` değerinden beslenir.
  void setSystemReduce(bool value) {
    if (_systemReduce == value) return;
    _systemReduce = value;
    notifyListeners();
  }

  /// Ağaçta sağlayıcı yoksa `false` döner.
  ///
  /// Hareket azaltma bir İYİLEŞTİRMEDİR: widget'lar onu okuyabilmek için
  /// sağlayıcı zorunlu kılmamalı. Aksi hâlde aynı widget bir ekran
  /// görüntüsü aracında ya da izole bir testte kullanıldığında
  /// `ProviderNotFoundException` ile çöker — 2026-07-31'de eşleşme
  /// ekranının dört testi tam bu yüzden düştü.
  ///
  /// Sağlayıcı yoksa güvenli varsayılan "hareket açık"tır: mevcut
  /// davranış korunur.
  static bool isReducedIn(BuildContext context) {
    try {
      return Provider.of<ReducedMotionProvider>(
        context,
        listen: false,
      ).reduceMotion;
    } on ProviderNotFoundException {
      return false;
    }
  }

  /// Hareket azaltıldığında verilen süreyi kısaltır (sıfırlamaz ki işlevsel
  /// geri bildirim kaybolmasın); aksi halde [base] döner.
  Duration motionDuration(Duration base) {
    if (!reduceMotion) return base;
    // En fazla 80ms: geçiş hissi kalır ama uzun animasyon/bounce gider.
    return base > const Duration(milliseconds: 80)
        ? const Duration(milliseconds: 80)
        : base;
  }
}
