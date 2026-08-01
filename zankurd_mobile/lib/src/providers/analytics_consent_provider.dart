import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Firebase Analytics yalnızca kullanıcı açıkça izin verdikten sonra çalışır.
/// Varsayılan kapalıdır; böylece ilk açılışta tercih yapılmadan ölçüm başlamaz.
class AnalyticsConsentProvider extends ChangeNotifier {
  AnalyticsConsentProvider({bool initialEnabled = false})
    : _enabled = initialEnabled;

  static const _storageKey = 'zankurd.analyticsConsent';

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
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, value);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'analytics_consent_persist');
    }
  }
}
