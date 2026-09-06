import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../utils/error_reporter.dart';

/// Streak ve puan tabanlı rozet servisi.
/// Mevcut AchievementStore'u tamamlar; ek rozetleri yönetir.
class BadgeService {
  BadgeService._(this._preferences, this._unlockedBadges);

  static const _storageKey = 'zankurd.badges.unlocked';
  static BadgeService? _instance;

  /// Rozet tanımları: id → {titleKey, descKey, icon}. Metin [Tr] tablosunda.
  static const Map<String, Map<String, String>> badgeDefinitions = {
    'streak_30': {
      'titleKey': K.badgeStreak30Title,
      'descKey': K.badgeStreak30Desc,
      'icon': 'emoji_events',
    },
    'questions_500': {
      'titleKey': K.badgeQuestions500Title,
      'descKey': K.badgeQuestions500Desc,
      'icon': 'workspace_premium',
    },
    'questions_1000': {
      'titleKey': K.badgeQuestions1000Title,
      'descKey': K.badgeQuestions1000Desc,
      'icon': 'military_tech',
    },
    'perfect_game': {
      'titleKey': K.badgePerfectTitle,
      'descKey': K.badgePerfectDesc,
      'icon': 'stars',
    },
    'speed_demon': {
      'titleKey': K.badgeSpeedTitle,
      'descKey': K.badgeSpeedDesc,
      'icon': 'speed',
    },
  };

  static String titleFor(String id, bool isKu) {
    final key = badgeDefinitions[id]?['titleKey'];
    if (key == null) return '';
    return Tr.forKu(key, isKu);
  }

  static String descFor(String id, bool isKu) {
    final key = badgeDefinitions[id]?['descKey'];
    if (key == null) return '';
    return Tr.forKu(key, isKu);
  }

  static Future<BadgeService> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'badge_service');
      preferences = null;
    }
    final unlocked =
        preferences?.getStringList(_storageKey)?.toSet() ?? <String>{};
    return _instance = BadgeService._(preferences, unlocked);
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() => _instance = null;

  final SharedPreferences? _preferences;
  final Set<String> _unlockedBadges;

  Set<String> get unlockedBadges => Set.unmodifiable(_unlockedBadges);
  int get unlockedCount => _unlockedBadges.length;
  int get totalCount => badgeDefinitions.length;
  bool isUnlocked(String id) => _unlockedBadges.contains(id);

  /// Streak değerine göre rozetleri değerlendirir.
  Future<List<String>> evaluateStreakBadges(int currentStreak) async {
    final newlyUnlocked = <String>[];
    if (currentStreak >= 30 && !_unlockedBadges.contains('streak_30')) {
      _unlockedBadges.add('streak_30');
      newlyUnlocked.add('streak_30');
    }
    if (newlyUnlocked.isNotEmpty) await _persist();
    return newlyUnlocked;
  }

  /// Soru sayısına göre rozetleri değerlendirir.
  Future<List<String>> evaluateQuestionBadges(int totalAnswered) async {
    final newlyUnlocked = <String>[];
    if (totalAnswered >= 500 && !_unlockedBadges.contains('questions_500')) {
      _unlockedBadges.add('questions_500');
      newlyUnlocked.add('questions_500');
    }
    if (totalAnswered >= 1000 && !_unlockedBadges.contains('questions_1000')) {
      _unlockedBadges.add('questions_1000');
      newlyUnlocked.add('questions_1000');
    }
    if (newlyUnlocked.isNotEmpty) await _persist();
    return newlyUnlocked;
  }

  /// Mükemmel oyun rozetini değerlendirir.
  Future<bool> evaluatePerfectGame(int correct, int total) async {
    if (correct == total &&
        total > 0 &&
        !_unlockedBadges.contains('perfect_game')) {
      _unlockedBadges.add('perfect_game');
      await _persist();
      return true;
    }
    return false;
  }

  /// Hız canavarı rozetini değerlendirir.
  Future<bool> evaluateSpeedDemon(Duration elapsed) async {
    if (elapsed.inSeconds < 60 && !_unlockedBadges.contains('speed_demon')) {
      _unlockedBadges.add('speed_demon');
      await _persist();
      return true;
    }
    return false;
  }

  Future<void> _persist() async {
    await _preferences?.setStringList(_storageKey, _unlockedBadges.toList());
  }
}
