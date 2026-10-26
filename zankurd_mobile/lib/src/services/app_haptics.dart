import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulamanın bütün dokunsal geri bildirimi tek kapıdan geçer.
///
/// 2026-10-27: titreşim 12 dosyada doğrudan `HapticFeedback` ile
/// çağrılıyordu ve kapatmanın yolu yoktu (rakiplerde Ayarlar'da durur;
/// titreşimden rahatsız olan ya da sessiz ortamda oynayan kullanıcı için).
/// Ayar kapalıyken hiçbir çağrı platforma gitmez.
class AppHaptics {
  const AppHaptics._();

  static const prefsKey = 'zankurd.haptics.enabled';

  static bool _enabled = true;
  static bool get enabled => _enabled;

  /// Açılışta kayıtlı ayarı okur (yoksa açık).
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(prefsKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
  }

  static void selection() {
    if (_enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (_enabled) HapticFeedback.heavyImpact();
  }

  static void vibrate() {
    if (_enabled) HapticFeedback.vibrate();
  }
}
