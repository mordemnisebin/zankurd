import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

class XPStore {
  XPStore._(this._preferences, this._totalXP);

  static const _totalXPKey = 'zankurd.xp.total';
  static XPStore? _instance;

  final SharedPreferences? _preferences;
  int _totalXP;

  int get totalXP => _totalXP;

  /// Toplam XP'ye göre kullanıcının seviyesini döner.
  int get currentLevel => calculateLevel(_totalXP);

  /// Mevcut seviyenin içinde kazanılmış olan XP miktarını döner.
  int get xpInCurrentLevel {
    final lvl = currentLevel;
    return _totalXP - xpRequiredForLevel(lvl);
  }

  /// Bir sonraki seviyeye atlamak için mevcut seviyede toplam gereken XP.
  int get xpNeededForNextLevel {
    final lvl = currentLevel;
    return xpRequiredForLevel(lvl + 1) - xpRequiredForLevel(lvl);
  }

  /// Mevcut seviyenin tamamlanma oranını döner (0.0 - 1.0).
  double get levelProgress {
    final needed = xpNeededForNextLevel;
    if (needed <= 0) return 1.0;
    return (xpInCurrentLevel / needed).clamp(0.0, 1.0);
  }

  static Future<XPStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'xp_store_load');
      preferences = null;
    }
    final total = preferences?.getInt(_totalXPKey) ?? 0;
    return _instance = XPStore._(preferences, total);
  }

  @visibleForTesting
  static Future<XPStore> loadForTest(int initialXP) async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'xp_store_persist');
      preferences = null;
    }
    return _instance = XPStore._(preferences, initialXP);
  }

  static void resetInstance() => _instance = null;

  /// XP barajı hesabı. Seviye L için gereken XP: (L - 1) * (250 * L + 500)
  static int xpRequiredForLevel(int level) {
    if (level <= 1) return 0;
    return (level - 1) * (250 * level + 500);
  }

  /// Toplam XP'den seviyeyi hesaplar.
  static int calculateLevel(int xp) {
    if (xp < 0) return 1;
    int level = 1;
    while (true) {
      final nextXP = xpRequiredForLevel(level + 1);
      if (xp >= nextXP) {
        level++;
      } else {
        break;
      }
    }
    return level;
  }

  /// Kullanıcıya XP ekler. Seviye atlama gerçekleştiyse true döner.
  Future<bool> addXP(int amount) async {
    if (amount <= 0) return false;
    final levelBefore = currentLevel;
    _totalXP += amount;
    await _preferences?.setInt(_totalXPKey, _totalXP);
    final levelAfter = currentLevel;
    return levelAfter > levelBefore;
  }
}
