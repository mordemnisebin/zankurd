import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Firebase Analytics yalnızca kullanıcı açıkça izin verdikten sonra çalışır.
/// Varsayılan kapalıdır; böylece ilk açılışta tercih yapılmadan ölçüm başlamaz.
class AnalyticsConsentProvider extends ChangeNotifier {
  AnalyticsConsentProvider({bool initialEnabled = false})
    : _enabled = initialEnabled {
    isEnabled = initialEnabled;
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

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    isEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, value);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'analytics_consent_persist');
    }
  }
}
