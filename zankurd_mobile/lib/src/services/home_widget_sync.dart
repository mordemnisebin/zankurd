import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../l10n/strings.dart';
import '../utils/error_reporter.dart';

/// Ana ekran widget'ının (iOS WidgetKit + Android AppWidget) veri köprüsü.
///
/// Widget'ın yerel tarafında hiç çeviri yoktur: bütün görünür metinler
/// (etiketler dahil) burada, uygulamanın seçili diliyle çözülüp ortak
/// depoya yazılır. Böylece Kurmancî metin tek yerde (`strings.dart`) kalır
/// ve widget uygulamayla aynı dili konuşur.
///
/// Yazılan anahtarlar (iOS: `group.com.zankurd.app` UserDefaults, Android:
/// home_widget SharedPreferences) — yerel taraf bu adlara bağlıdır:
/// `streak` (int), `dailyPrompt` (String, boş olabilir), `labelStreak`,
/// `labelUnit`, `labelDaily`, `updatedAt` (UTC epoch ms).
class HomeWidgetSync {
  const HomeWidgetSync._();

  static const appGroupId = 'group.com.zankurd.app';
  static const iosWidgetKind = 'ZanKurdWidget';
  static const androidWidgetName = 'ZanKurdWidgetProvider';
  static const maxPromptLength = 140;

  /// Testte platformu taklit etmek için; üretimde yalnız iOS ve Android.
  @visibleForTesting
  static bool Function()? supportedOverride;

  static bool get _supported {
    final override = supportedOverride;
    if (override != null) return override();
    if (kIsWeb) return false;
    // iOS widget eklentisi 2.1.1'de yok: App Group imzası (geliştirici
    // hesabında yeni kimlik + profil) bu makineden açılamadı. Eklenti
    // hazır olana dek iOS'ta App Group'suz yazmak boşa iş (2026-10-28).
    return Platform.isAndroid;
  }

  /// Widget verisini yazar ve widget'ı yeniden çizdirir. Asla fırlatmaz:
  /// desteklenmeyen platformda ve eklentisiz testte sessizce döner, kanal
  /// hatasını [ErrorReporter]a bildirir.
  static Future<void> sync({
    required int streak,
    required bool isKu,
    String? dailyPrompt,
    DateTime? now,
  }) async {
    if (!_supported) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      final data = <String, Object>{
        'streak': streak < 0 ? 0 : streak,
        'dailyPrompt': _clip(dailyPrompt),
        'labelStreak': Tr.forKu(K.streakLabel, isKu),
        'labelUnit': Tr.forKu(K.streakDayUnit, isKu),
        'labelDaily': Tr.forKu(K.widgetDailyQuestion, isKu),
        'updatedAt': (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
      };
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<Object>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(
        iOSName: iosWidgetKind,
        androidName: androidWidgetName,
        qualifiedAndroidName: 'com.zankurd.app.$androidWidgetName',
      );
    } on MissingPluginException {
      // Eklenti yok (test / masaüstü): widget zaten yok, yapılacak iş yok.
    } on PlatformException catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home_widget_sync');
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'home_widget_sync');
    }
  }

  static String _clip(String? text) {
    final t = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= maxPromptLength) return t;
    return '${t.substring(0, maxPromptLength - 1).trimRight()}…';
  }
}
