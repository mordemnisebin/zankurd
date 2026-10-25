import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Kullanım analizi (Firebase Analytics, Crashlytics ve sunucu olayları) tek
/// anahtara bağlıdır; Ayarlar › Kullanım analizi ile kapatılır.
///
/// Diskte seçim yoksa AÇIK başlar (2026-10-23, sahibin kararı). Önceden
/// varsayılan kapalıydı ve anahtarı kimse açmıyordu: 2.1.0'ın ilk gecesi
/// 17 kişi oynadı, Firebase 0 etkin kullanıcı gösterdi, çökme raporları da
/// aynı anahtara bağlı olduğu için "çökme yok" verisi boştu. Anahtarı bilerek
/// kapatmış kişinin `false` seçimi diskte kalır ve korunur.
class AnalyticsConsentProvider extends ChangeNotifier {
  AnalyticsConsentProvider({bool initialEnabled = false})
    : _enabled = initialEnabled {
    isEnabled = initialEnabled;
    ErrorReporter.crashlyticsEnabled = initialEnabled;
  }

  static const _storageKey = 'zankurd.analyticsConsent';

  /// Diskte seçim yokken kullanılan değer.
  static const defaultEnabled = true;

  /// `SupabaseZanKurdRepository.logAnalyticsEvent` gibi veri katmanı
  /// sınıfları `BuildContext`i olmadığı için Provider ağacını okuyamaz.
  ///
  /// Anahtar kapalıyken (varsayılan açık; bkz. [defaultEnabled]) yalnız Firebase Analytics
  /// durduruluyordu; ikinci ölçüm yolu — bu depo metodu — kullanıcı
  /// kimliğiyle birlikte Supabase'e yazmaya devam ediyordu. Her tur/ders/
  /// arkadaşlık isteği/turnuva olayı, anahtar kapalı olsa bile sunucuya
  /// gidiyordu (2026-08-14 denetimi). Bu statik bayrak tek boğaz
  /// noktasıdır; `load()` ve `setEnabled()` onu güncel tutar.
  static bool isEnabled = false;

  bool _enabled;
  bool _disposed = false;
  Future<void> _writeTail = Future<void>.value();
  int _writeGeneration = 0;

  bool get enabled => _enabled;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static Future<AnalyticsConsentProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AnalyticsConsentProvider(
        initialEnabled: prefs.getBool(_storageKey) ?? defaultEnabled,
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
        if (!_disposed) {
          notifyListeners();
        }
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
