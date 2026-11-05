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

  /// Ekranda GERÇEKTEN koyu mu? `system` modunda cihazın parlaklığına bakar.
  ///
  /// 1.10 (Pro denetimi 2026-11-05): ayar anahtarı `isDark`a bağlıydı;
  /// kayıtlı tercih `system` ve cihaz koyuyken uygulama koyu çiziliyor ama
  /// anahtar "kapalı" gösteriyor, dokunuş da (kapalı → koyu) görünür bir
  /// değişiklik yapmıyordu. Sessiz kaldı çünkü yeni kurulumun varsayılanı
  /// `dark`, `system` yalnız eski kayıtlardan geliyor.
  bool isDarkFor(Brightness platformBrightness) => switch (_mode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system => platformBrightness == Brightness.dark,
  };

  /// Anahtarı görünen duruma göre çevirir ([isDarkFor]).
  Future<void> toggleDarkLightFor(Brightness platformBrightness) =>
      setMode(isDarkFor(platformBrightness) ? ThemeMode.light : ThemeMode.dark);

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
