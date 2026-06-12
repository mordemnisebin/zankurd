import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/player.dart';

class AchievementIds {
  static const firstGame = 'first_game';
  static const tenStreak = 'ten_streak';
  static const hundredQuestions = 'hundred_questions';
  static const allCategories = 'all_categories';
  static const sevenDayStreak = 'seven_day_streak';
  static const mistakesCleared = 'mistakes_cleared';
  static const botWinner = 'bot_winner';
  static const dailyQuizFive = 'daily_quiz_five';
}

/// Yerel rozet ilerlemesini ve açılan rozetleri saklar.
class AchievementStore {
  AchievementStore._(
    this._preferences,
    this._unlockedIds,
    this._answeredQuestions,
    this._playedCategories,
    this._dailyQuizCompletions,
  );

  static const requiredCategories = [
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
  ];

  static const _unlockedKey = 'zankurd.achievements.unlocked';
  static const _answeredKey = 'zankurd.achievements.answeredQuestions';
  static const _categoriesKey = 'zankurd.achievements.playedCategories';
  static const _dailyQuizKey = 'zankurd.achievements.dailyQuizCompletions';

  static AchievementStore? _instance;

  static final List<Achievement> definitions = [
    const Achievement(
      id: AchievementIds.firstGame,
      titleKu: 'Lîstika Yekem',
      titleTr: 'İlk Oyun',
      descriptionKu: 'Pêşbirka xwe ya yekem qedand.',
      descriptionTr: 'İlk yarışını tamamladın.',
      icon: Icons.flag_outlined,
    ),
    const Achievement(
      id: AchievementIds.tenStreak,
      titleKu: '10 Rast Li Pey Hev',
      titleTr: '10 Doğru Üst Üste',
      descriptionKu: 'Di yek pêşbirkê de rêza 10 rast çêkir.',
      descriptionTr: 'Tek yarışta 10 doğru seri yaptın.',
      icon: Icons.local_fire_department_outlined,
    ),
    const Achievement(
      id: AchievementIds.hundredQuestions,
      titleKu: '100 Pirs',
      titleTr: '100 Soru',
      descriptionKu: 'Bi giştî 100 pirs bersiv da.',
      descriptionTr: 'Toplam 100 soruya cevap verdin.',
      icon: Icons.psychology_outlined,
    ),
    const Achievement(
      id: AchievementIds.allCategories,
      titleKu: 'Hemû Kategorî',
      titleTr: 'Her Kategoride Oyun',
      descriptionKu: 'Di hemû kategoriyan de lîst.',
      descriptionTr: 'Tüm kategorilerde yarış oynadın.',
      icon: Icons.grid_view_rounded,
    ),
    const Achievement(
      id: AchievementIds.sevenDayStreak,
      titleKu: '7 Roj Li Pey Hev',
      titleTr: '7 Gün Streak',
      descriptionKu: 'Seriya rojane gihand 7 rojan.',
      descriptionTr: 'Günlük serini 7 güne taşıdın.',
      icon: Icons.calendar_month_outlined,
    ),
    const Achievement(
      id: AchievementIds.mistakesCleared,
      titleKu: 'Şaşî Paqij Kir',
      titleTr: 'Yanlışlarını Temizledi',
      descriptionKu: 'Di moda şaşiyan de hemû pirsgirêk paqij kir.',
      descriptionTr: 'Yanlışlar modunda tüm hatalarını temizledin.',
      icon: Icons.school_outlined,
    ),
    const Achievement(
      id: AchievementIds.botWinner,
      titleKu: 'Bot Têk Bir',
      titleTr: 'Bot’u Yendi',
      descriptionKu: 'Di pêşbirka botan de serket.',
      descriptionTr: 'Bot yarışını birinci bitirdin.',
      icon: Icons.smart_toy_outlined,
    ),
    const Achievement(
      id: AchievementIds.dailyQuizFive,
      titleKu: '5 Pêşbirkên Rojê',
      titleTr: 'Günlük Quiz x5',
      descriptionKu: 'Pênc caran pêşbirka rojê qedand.',
      descriptionTr: 'Günün yarışmasını 5 kez tamamladın.',
      icon: Icons.bolt_rounded,
    ),
  ];

  static Future<AchievementStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }
    return _instance = AchievementStore._(
      preferences,
      preferences?.getStringList(_unlockedKey)?.toSet() ?? <String>{},
      preferences?.getInt(_answeredKey) ?? 0,
      preferences?.getStringList(_categoriesKey)?.toSet() ?? <String>{},
      preferences?.getInt(_dailyQuizKey) ?? 0,
    );
  }

  static void resetInstance() => _instance = null;

  final SharedPreferences? _preferences;
  final Set<String> _unlockedIds;
  int _answeredQuestions;
  final Set<String> _playedCategories;
  int _dailyQuizCompletions;

  Set<String> get unlockedIds => Set.unmodifiable(_unlockedIds);
  List<Achievement> get unlockedAchievements => definitions
      .where((achievement) => _unlockedIds.contains(achievement.id))
      .toList(growable: false);

  bool isUnlocked(String id) => _unlockedIds.contains(id);

  Future<List<Achievement>> recordQuizResult({
    required String category,
    required int totalQuestions,
    required int correctCount,
    required int bestStreak,
    required int dailyStreak,
    required int userScore,
    bool dailyQuiz = false,
    bool practice = false,
    int remainingMistakes = 0,
    List<Player> opponents = const [],
  }) async {
    _answeredQuestions += totalQuestions;
    if (requiredCategories.contains(category)) {
      _playedCategories.add(category);
    }
    if (dailyQuiz) _dailyQuizCompletions += 1;

    final newlyUnlocked = <Achievement>[];
    void unlockWhen(bool condition, String id) {
      if (!condition || _unlockedIds.contains(id)) return;
      _unlockedIds.add(id);
      newlyUnlocked.add(definitions.firstWhere((item) => item.id == id));
    }

    unlockWhen(totalQuestions > 0, AchievementIds.firstGame);
    unlockWhen(bestStreak >= 10, AchievementIds.tenStreak);
    unlockWhen(_answeredQuestions >= 100, AchievementIds.hundredQuestions);
    unlockWhen(
      requiredCategories.every(_playedCategories.contains),
      AchievementIds.allCategories,
    );
    unlockWhen(dailyStreak >= 7, AchievementIds.sevenDayStreak);
    unlockWhen(
      practice && remainingMistakes == 0,
      AchievementIds.mistakesCleared,
    );
    unlockWhen(
      opponents.isNotEmpty &&
          opponents.every((opponent) => userScore > opponent.score),
      AchievementIds.botWinner,
    );
    unlockWhen(_dailyQuizCompletions >= 5, AchievementIds.dailyQuizFive);

    await _persist();
    return newlyUnlocked;
  }

  Future<void> _persist() async {
    await _preferences?.setStringList(_unlockedKey, _unlockedIds.toList());
    await _preferences?.setInt(_answeredKey, _answeredQuestions);
    await _preferences?.setStringList(
      _categoriesKey,
      _playedCategories.toList(),
    );
    await _preferences?.setInt(_dailyQuizKey, _dailyQuizCompletions);
  }
}
