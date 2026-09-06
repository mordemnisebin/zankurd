import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Sessizce yutulan hataları Crashlytics'e non-fatal olarak kaydeder.
///
/// Web'de ve Crashlytics yapılandırılmamış ortamlarda (masaüstü/test)
/// sessizce no-op kalır; çağıran akışın davranışını asla değiştirmez.
class ErrorReporter {
  const ErrorReporter._();

  /// Ayarlar > Gizlilik kapalıyken Crashlytics yazılmaz.
  /// [AnalyticsConsentProvider] ile aynı anahtar; döngüsel import yok.
  static bool crashlyticsEnabled = false;

  static Future<void> setCollectionEnabled(bool enabled) async {
    crashlyticsEnabled = enabled;
    if (kIsWeb) return;
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
    } catch (_) {}
  }

  static void record(Object error, StackTrace stack, {String? reason}) {
    if (kIsWeb || !crashlyticsEnabled) return;
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
    } catch (_) {
      // Crashlytics yapılandırılmamış olabilir (masaüstü/test ortamı).
    }
  }
}
