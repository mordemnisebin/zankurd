import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  // Marka kimliği koyu tema üzerine kurulu (mat antrasit/yeşil); kayıtlı bir
  // tercih yoksa uygulama koyu açılır, açık tema seçilebilir kalır.
  ThemeProvider({ThemeMode initialMode = ThemeMode.dark}) : _mode = initialMode;

  static const _storageKey = 'zankurd.themeMode';

  static Future<ThemeProvider> load() async {
    final preferences = await SharedPreferences.getInstance();
    return ThemeProvider(
      initialMode: _decode(preferences.getString(_storageKey)),
    );
  }

  ThemeMode _mode;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> toggleDarkLight() async {
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, _encode(mode));
  }

  static ThemeMode _decode(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  static String _encode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
  }
}
