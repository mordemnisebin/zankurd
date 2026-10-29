import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Ölçüm rızası: iki AYRI anahtar, ikisi de varsayılan KAPALI.
///
/// - Kullanım analizi ([enabled]): Firebase Analytics ve sunucu olayları
///   (`SupabaseZanKurdRepository.logAnalyticsEvent`). Ayarlar › Kullanım
///   analizi.
/// - Hata raporları ([crashReportsEnabled]): Crashlytics (fatal ve
///   non-fatal). Ayarlar › Hata raporları.
///
/// 2026-10-29 (Opus 5.5 + GPT-6 Astra ortak kararı, kullanıcının yetkisiyle):
/// 2026-10-23'te ikisi tek anahtarda ve varsayılan AÇIKTI; Ayarlar'dan
/// kapatılabilmesi ve gizlilik metninde yazması, ilk açılışta seçimden önce
/// giden veriye izin sayılmaz (KVKK/GDPR). Crashlytics'e "anonim" demek de
/// kurulum kimliği ve günlükler yüzünden kanıt değil. Bu yüzden ikisi de
/// seçim yokken kapalı; yerel SDK'lar da Info.plist/AndroidManifest'te
/// kapalı başlar, böylece kullanıcı seçmeden hiçbir şey gitmez.
///
/// Eski tek anahtarda (`zankurd.analyticsConsent`) AÇIKÇA saklanmış seçim
/// korunur; hata raporları anahtarı henüz yoksa o seçimi devralır (eski
/// anahtar ikisini birlikte yönetiyordu). Hiç seçim yapmamış kişi kapalı
/// başlar.
class AnalyticsConsentProvider extends ChangeNotifier {
  AnalyticsConsentProvider({
    bool initialEnabled = false,
    bool initialCrashReportsEnabled = false,
  }) : _enabled = initialEnabled,
       _crashReportsEnabled = initialCrashReportsEnabled {
    isEnabled = initialEnabled;
    ErrorReporter.crashlyticsEnabled = initialCrashReportsEnabled;
  }

  static const _storageKey = 'zankurd.analyticsConsent';
  static const _crashStorageKey = 'zankurd.crashReportsConsent';

  /// Diskte seçim yokken kullanılan değer (iki anahtar için de).
  static const defaultEnabled = false;

  /// `SupabaseZanKurdRepository.logAnalyticsEvent` gibi veri katmanı
  /// sınıfları `BuildContext`i olmadığı için Provider ağacını okuyamaz.
  ///
  /// Anahtar kapalıyken yalnız Firebase Analytics durduruluyordu; ikinci
  /// ölçüm yolu — bu depo metodu — kullanıcı kimliğiyle birlikte Supabase'e
  /// yazmaya devam ediyordu (2026-08-14 denetimi). Bu statik bayrak tek
  /// boğaz noktasıdır; `load()` ve `setEnabled()` onu güncel tutar.
  static bool isEnabled = false;

  bool _enabled;
  bool _crashReportsEnabled;
  bool _disposed = false;
  Future<void> _writeTail = Future<void>.value();
  final _writeGeneration = <String, int>{};

  /// Kullanım analizi rızası.
  bool get enabled => _enabled;

  /// Hata raporu (Crashlytics) rızası.
  bool get crashReportsEnabled => _crashReportsEnabled;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static Future<AnalyticsConsentProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analytics = prefs.getBool(_storageKey);
      var crashReports = prefs.getBool(_crashStorageKey);
      if (crashReports == null) {
        // Devralma yalnız bir kez: hata raporu anahtarı ilk yüklemede
        // yazılır, yoksa sonradan analizi açmak hata raporlarını da açardı.
        // Yazım burada başarısız olursa `setEnabled` analizi kaydetmeden
        // önce yeniden dener (bkz. `_ensureCrashChoiceStored`).
        crashReports = analytics ?? defaultEnabled;
        var stored = false;
        try {
          stored = await prefs.setBool(_crashStorageKey, crashReports);
        } catch (_) {}
        if (!stored) {
          // setBool önbelleği diskten önce günceller; başarısız yazımdan
          // sonra `containsKey` yalan söyleyebilir. Ayrı bayrak, kayıt
          // doğrulanana kadar analiz yazımını durdurur.
          _crashChoicePending = true;
          try {
            await prefs.reload();
          } catch (_) {}
        }
      }
      return AnalyticsConsentProvider(
        initialEnabled: analytics ?? defaultEnabled,
        initialCrashReportsEnabled: crashReports,
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'analytics_consent_load');
      return AnalyticsConsentProvider();
    }
  }

  /// Kullanım analizi anahtarı.
  Future<bool> setEnabled(bool value) => _persist(_storageKey, value, () {
    _enabled = value;
    isEnabled = value;
  });

  /// Hata raporları anahtarı.
  Future<bool> setCrashReportsEnabled(bool value) =>
      _persist(_crashStorageKey, value, () {
        _crashReportsEnabled = value;
        _crashChoicePending = false;
      }, after: () => ErrorReporter.setCollectionEnabled(value));

  /// Analiz anahtarı yazılmadan önce hata raporu seçimi diskte olmalı:
  /// yoksa bir sonraki açılışta eski tek anahtardan "devralma" yeni analiz
  /// seçimini hata raporlarına da taşırdı (Astra incelemesi, 2026-10-29).
  /// İlk yüklemedeki devralma yazımı başarısız olduysa true; başarılı bir
  /// yazım görülene kadar `containsKey`e güvenilmez.
  static bool _crashChoicePending = false;

  @visibleForTesting
  static void debugMarkCrashChoicePending() => _crashChoicePending = true;

  static Future<bool> _ensureCrashChoiceStored(
    SharedPreferences prefs,
    bool current,
  ) async {
    if (!_crashChoicePending && prefs.containsKey(_crashStorageKey)) {
      return true;
    }
    var stored = false;
    try {
      stored = await prefs.setBool(_crashStorageKey, current);
    } catch (_) {}
    if (!stored) {
      try {
        await prefs.reload();
      } catch (_) {}
      return false;
    }
    _crashChoicePending = false;
    return true;
  }

  Future<bool> _persist(
    String key,
    bool value,
    void Function() apply, {
    Future<void> Function()? after,
  }) {
    final generation = (_writeGeneration[key] ?? 0) + 1;
    _writeGeneration[key] = generation;
    final result = Completer<bool>();
    _writeTail = _writeTail.then((_) async {
      if (generation != _writeGeneration[key]) {
        result.complete(false);
        return;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        if (key == _storageKey &&
            !await _ensureCrashChoiceStored(prefs, _crashReportsEnabled)) {
          result.complete(false);
          return;
        }
        final saved = await prefs.setBool(key, value);
        if (!saved) {
          await prefs.reload();
          result.complete(false);
          return;
        }
        // Bu yazım sürerken aynı anahtar için daha yeni bir seçim geldiyse
        // diskteki ara değer uygulanmaz. Kuyruktaki yeni seçim son değeri yazar.
        if (generation != _writeGeneration[key]) {
          result.complete(false);
          return;
        }
        apply();
        if (!_disposed) {
          notifyListeners();
        }
        await after?.call();
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
