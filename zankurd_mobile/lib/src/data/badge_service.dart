import 'package:shared_preferences/shared_preferences.dart';

/// Streak ve puan tabanlı rozet servisi.
/// Mevcut AchievementStore'u tamamlar; ek rozetleri yönetir.
class BadgeService {
  BadgeService._(this._preferences, this._unlockedBadges);

  static const _storageKey = 'zankurd.badges.unlocked';
  static BadgeService? _instance;

  /// Rozet tanımları: id → {titleKu, titleTr, descKu, descTr, icon}
  static const Map<String, Map<String, String>> badgeDefinitions = {
    'streak_30': {
      'titleKu': '30 Roj Li Pey Hev',
      'titleTr': '30 Gün Streak',
      'descKu': 'Seriya rojane gihand 30 rojan.',
      'descTr': 'Günlük serini 30 güne taşıdın.',
      'icon': 'emoji_events',
    },
    'questions_500': {
      'titleKu': '500 Pirs',
      'titleTr': '500 Soru',
      'descKu': 'Bi giştî 500 pirs bersiv da.',
      'descTr': 'Toplam 500 soruya cevap verdin.',
      'icon': 'workspace_premium',
    },
    'questions_1000': {
      'titleKu': '1000 Pirs',
      'titleTr': '1000 Soru',
      'descKu': 'Bi giştî 1000 pirs bersiv da.',
      'descTr': 'Toplam 1000 soruya cevap verdin.',
      'icon': 'military_tech',
    },
    'perfect_game': {
      'titleKu': 'Lîstika Bêkêmasî',
      'titleTr': 'Mükemmel Oyun',
      'descKu': 'Di yek pêşbirkê de hemû pirsan rast bersiv da.',
      'descTr': 'Bir yarışta tüm soruları doğru cevapladın.',
      'icon': 'stars',
    },
    'speed_demon': {
      'titleKu': 'Leztir',
      'titleTr': 'Hız Canavarı',
      'descKu': 'Pêşbirkek di bin 60 çirkeyan de qedand.',
      'descTr': 'Bir yarışı 60 saniyenin altında bitirdin.',
      'icon': 'speed',
    },
  };

  static Future<BadgeService> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }
    final unlocked = preferences?.getStringList(_storageKey)?.toSet() ?? <String>{};
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
    if (correct == total && total > 0 && !_unlockedBadges.contains('perfect_game')) {
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
