import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import '../utils/error_reporter.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider({ThemeMode initialMode = ThemeMode.dark})
    : _mode = initialMode,
      _persisted = initialMode;

  static const _storageKey = 'zankurd.themeMode';

  static Future<ThemeProvider> load() async {
    final preferences = await SharedPreferences.getInstance();
    return ThemeProvider(
      initialMode: _decode(preferences.getString(_storageKey)),
    );
  }

  ThemeMode _mode;

  /// Diske YAZILMIŞ son tema; yazım reddedilirse ekran bu temaya döner.
  ThemeMode _persisted;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> toggleDarkLight() async {
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    await setMode(next);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode && _persisted == mode) return;
    if (_mode != mode) {
      _mode = mode;
      notifyListeners();
      AnalyticsService.instance.logThemeChange(_encode(mode));
    }
    var saved = false;
    try {
      final preferences = await SharedPreferences.getInstance();
      saved = await preferences.setString(_storageKey, _encode(mode));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'theme_persist');
    }
    if (saved) {
      _persisted = mode;
    } else if (_mode == mode) {
      ErrorReporter.record(
        StateError('Theme preference was not persisted.'),
        StackTrace.current,
        reason: 'theme_persist',
      );
      _mode = _persisted;
      notifyListeners();
    }
  }

  static ThemeMode _decode(String? value) {
    return switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      // Şahnê gece öncelikli bir kimliktir (2026-09-29): tercihi hiç
      // kaydedilmemiş oyuncu gece sahnesiyle açılır. Açık temayı seçmiş
      // olanın kaydı korunur.
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
