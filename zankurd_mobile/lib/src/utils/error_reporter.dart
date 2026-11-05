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

  static bool _fatalHandlersInstalled = false;
  static FlutterExceptionHandler? _previousFlutterHandler;
  static bool Function(Object, StackTrace)? _previousPlatformHandler;
  static FlutterExceptionHandler? _installedFlutterHandler;
  static bool Function(Object, StackTrace)? _installedPlatformHandler;

  /// Crashlytics çağrıları `Future` döndürür ve `try/catch` yalnız SENKRON
  /// fırlatmayı yakalar. Beklenmeyen/atlanan Future'ın asenkron hatası
  /// yakalanmamış istisna olup bu raporlayıcının kendi işleyicisine (hata
  /// raporlayıcıyı raporlayan döngü) geri dönerdi (2026-11-06, G-09).
  static void _swallowAsync(Future<void> pending) {
    pending.catchError((Object _) {});
  }

  static void _installFatalHandlers() {
    if (kIsWeb) return;

    final flutterHandlerStillInstalled =
        _fatalHandlersInstalled &&
        identical(FlutterError.onError, _installedFlutterHandler);
    final platformHandlerStillInstalled =
        _fatalHandlersInstalled &&
        identical(
          PlatformDispatcher.instance.onError,
          _installedPlatformHandler,
        );
    if (flutterHandlerStillInstalled && platformHandlerStillInstalled) return;

    final previousFlutterHandler = flutterHandlerStillInstalled
        ? _previousFlutterHandler
        : FlutterError.onError;
    final previousPlatformHandler = platformHandlerStillInstalled
        ? _previousPlatformHandler
        : PlatformDispatcher.instance.onError;
    _previousFlutterHandler = previousFlutterHandler;
    _previousPlatformHandler = previousPlatformHandler;

    void flutterHandler(FlutterErrorDetails details) {
      previousFlutterHandler?.call(details);
      if (!crashlyticsEnabled) return;
      try {
        _swallowAsync(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        );
      } catch (_) {}
    }

    bool platformHandler(Object error, StackTrace stack) {
      final handledByPrevious =
          previousPlatformHandler?.call(error, stack) ?? false;
      if (!crashlyticsEnabled) return handledByPrevious;
      try {
        _swallowAsync(
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
        );
        return true;
      } catch (_) {
        return handledByPrevious;
      }
    }

    FlutterError.onError = flutterHandler;
    PlatformDispatcher.instance.onError = platformHandler;
    _installedFlutterHandler = flutterHandler;
    _installedPlatformHandler = platformHandler;
    _fatalHandlersInstalled = true;
  }

  @visibleForTesting
  static void resetFatalHandlersForTesting() {
    if (!_fatalHandlersInstalled) return;
    if (identical(FlutterError.onError, _installedFlutterHandler)) {
      FlutterError.onError = _previousFlutterHandler;
    }
    if (identical(
      PlatformDispatcher.instance.onError,
      _installedPlatformHandler,
    )) {
      PlatformDispatcher.instance.onError = _previousPlatformHandler;
    }
    _previousFlutterHandler = null;
    _previousPlatformHandler = null;
    _installedFlutterHandler = null;
    _installedPlatformHandler = null;
    _fatalHandlersInstalled = false;
  }

  static Future<void> setCollectionEnabled(bool enabled) async {
    crashlyticsEnabled = enabled;
    if (kIsWeb) return;
    if (enabled) _installFatalHandlers();
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
    } catch (_) {}
  }

  static void record(Object error, StackTrace stack, {String? reason}) {
    if (kIsWeb || !crashlyticsEnabled) return;
    try {
      _swallowAsync(
        FirebaseCrashlytics.instance.recordError(error, stack, reason: reason),
      );
    } catch (_) {
      // Crashlytics yapılandırılmamış olabilir (masaüstü/test ortamı).
    }
  }
}
