import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Firebase Analytics yalnızca kullanıcı açıkça izin verdikten sonra çalışır.
/// Varsayılan kapalıdır; böylece ilk açılışta tercih yapılmadan ölçüm başlamaz.
class AnalyticsConsentProvider extends ChangeNotifier {
  AnalyticsConsentProvider({bool initialEnabled = false})
    : _enabled = initialEnabled {
    isEnabled = initialEnabled;
    ErrorReporter.crashlyticsEnabled = initialEnabled;
  }

  static const _storageKey = 'zankurd.analyticsConsent';

  /// `SupabaseZanKurdRepository.logAnalyticsEvent` gibi veri katmanı
  /// sınıfları `BuildContext`i olmadığı için Provider ağacını okuyamaz.
  ///
  /// Anahtar kapalıyken (varsayılan da kapalı) yalnız Firebase Analytics
  /// durduruluyordu; ikinci ölçüm yolu — bu depo metodu — kullanıcı
  /// kimliğiyle birlikte Supabase'e yazmaya devam ediyordu. Her tur/ders/
  /// arkadaşlık isteği/turnuva olayı, anahtar kapalı olsa bile sunucuya
  /// gidiyordu (2026-08-14 denetimi). Bu statik bayrak tek boğaz
  /// noktasıdır; `load()` ve `setEnabled()` onu güncel tutar.
  static bool isEnabled = false;

  bool _enabled;
  Future<void> _writeTail = Future<void>.value();
  int _writeGeneration = 0;

  bool get enabled => _enabled;

  static Future<AnalyticsConsentProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AnalyticsConsentProvider(
        initialEnabled: prefs.getBool(_storageKey) ?? false,
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'analytics_consent_load');
      return AnalyticsConsentProvider();
    }
  }

  Future<bool> setEnabled(bool value) {
    final generation = ++_writeGeneration;
    final result = Completer<bool>();
    _writeTail = _writeTail.then((_) async {
      if (generation != _writeGeneration) {
        result.complete(false);
        return;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = await prefs.setBool(_storageKey, value);
        if (!saved) {
          await prefs.reload();
          result.complete(false);
          return;
        }
        // Bu yazım sürerken daha yeni bir seçim geldiyse diskteki ara değer
        // UI/ölçüm durumuna uygulanmaz. Kuyruktaki yeni seçim son değeri yazar.
        if (generation != _writeGeneration) {
          result.complete(false);
          return;
        }
        _enabled = value;
        isEnabled = value;
        notifyListeners();
        await ErrorReporter.setCollectionEnabled(value);
        result.complete(true);
      } catch (error, stack) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.reload();
        } catch (_) {}
        ErrorReporter.record(error, stack, reason: 'analytics_consent_persist');
        result.complete(false);
      }
    });
    return result.future;
  }
}
