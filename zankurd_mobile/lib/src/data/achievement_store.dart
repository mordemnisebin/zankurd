import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';

import '../models/achievement.dart';
import '../models/contest.dart';
import '../models/player.dart';
import '../utils/error_reporter.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
    this._dailyQuizLastDay,
    this._unlockedAt,
    this._bestRoundStreak,
  );

  static const requiredCategories = [
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
    'Siyaset',
    'Paradigma',
  ];

  static String get _unlockedKey =>
      LocalProgressScope.physical('zankurd.achievements.unlocked');
  static String get _answeredKey =>
      LocalProgressScope.physical('zankurd.achievements.answeredQuestions');
  static String get _categoriesKey =>
      LocalProgressScope.physical('zankurd.achievements.playedCategories');
  static String get _dailyQuizKey =>
      LocalProgressScope.physical('zankurd.achievements.dailyQuizCompletions');

  static String get _dailyQuizDayKey =>
      LocalProgressScope.physical('zankurd.achievements.dailyQuizLastDay');

  /// Açılış günleri (`id -> yyyy-MM-dd`, JSON). Rozet ekranı "Kazanıldı:
  /// 24.10.2026" yazsın diye tutulur; bu anahtar eklenmeden önce açılan
  /// rozetlerin tarihi yoktur (gösterilmez, uydurulmaz).
  static String get _unlockedAtKey =>
      LocalProgressScope.physical('zankurd.achievements.unlockedAt');

  /// Bir turda yapılmış en uzun doğru serisi ("10 doğru üst üste" ilerlemesi).
  static String get _bestRoundStreakKey =>
      LocalProgressScope.physical('zankurd.achievements.bestRoundStreak');

  static AchievementStore? _instance;

  /// 2026-09-30 simülatör: başarı adları cümle düzeninde (Title Case yok) ve
  /// sözlükteki terimlerle yazılır: konu / mijar, günün soruları / pirsên
  /// rojê (yasak: kategori, etkinlik). Bekçi: `copy_language_test.dart`.
  static final List<Achievement> definitions = [
    const Achievement(
      id: AchievementIds.firstGame,
      titleKu: 'Lîstika yekem',
      titleTr: 'İlk oyun',
      descriptionKu: 'Pêşbirka xwe ya yekem qedand.',
      descriptionTr: 'İlk yarışını tamamladın.',
      icon: AppIcons.flag,
    ),
    const Achievement(
      id: AchievementIds.tenStreak,
      titleKu: '10 rast li pey hev',
      titleTr: '10 doğru üst üste',
      descriptionKu: 'Di yek pêşbirkê de rêza 10 rast çêkir.',
      descriptionTr: 'Tek yarışta 10 doğru seri yaptın.',
      icon: AppIcons.fire,
    ),
    const Achievement(
      id: AchievementIds.hundredQuestions,
      titleKu: '100 pirs',
      titleTr: '100 soru',
      descriptionKu: 'Bi giştî 100 pirs bersiv da.',
      descriptionTr: 'Toplam 100 soruya cevap verdin.',
      icon: AppIcons.brain,
    ),
    const Achievement(
      id: AchievementIds.allCategories,
      titleKu: 'Hemû mijar',
      titleTr: 'Her konuda oyun',
      descriptionKu: 'Di hemû mijaran de lîst.',
      descriptionTr: 'Tüm konularda yarış oynadın.',
      icon: AppIcons.tableCells,
    ),
    const Achievement(
      id: AchievementIds.sevenDayStreak,
      titleKu: '7 roj li pey hev',
      titleTr: '7 günlük seri',
      // Günlük seri zincîr'dir; `Seriya` tur içi Rêz ile karışır.
      // 30 günlük rozet (`K.badgeStreak30Desc`) aynı kökü kullanır.
      descriptionKu: 'Zincîra rojane gihand 7 rojan.',
      descriptionTr: 'Günlük serini 7 güne taşıdın.',
      icon: AppIcons.calendarDays,
    ),
    const Achievement(
      id: AchievementIds.mistakesCleared,
      titleKu: 'Şaşî paqij kir',
      titleTr: 'Yanlışlarını temizledi',
      descriptionKu: 'Di moda şaşiyan de hemû pirsgirêk paqij kir.',
      descriptionTr: 'Yanlışlar modunda tüm hatalarını temizledin.',
      icon: AppIcons.graduationCap,
    ),
    const Achievement(
      id: AchievementIds.botWinner,
      titleKu: 'Bot têk bir',
      titleTr: "Bot'u yendi",
      descriptionKu: 'Di pêşbirka botan de serket.',
      descriptionTr: 'Bot yarışını birinci bitirdin.',
      icon: AppIcons.robot,
    ),
    const Achievement(
      id: AchievementIds.dailyQuizFive,
      titleKu: 'Gera rojê ×5',
      titleTr: 'Günün turu ×5',
      descriptionKu: 'Te gera rojê pênc caran qedandiye.',
      descriptionTr: 'Günün turunu 5 kez tamamladın.',
      icon: AppIcons.bolt,
    ),
  ];

  static Future<AchievementStore>? _loading;
  static int _loadGeneration = 0;

  static Future<AchievementStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    final inFlight = _loading;
    if (inFlight != null) return inFlight;

    final generation = _loadGeneration;
    final loading = _loadFresh().then((store) {
      if (_loadGeneration == generation) {
        return _instance ??= store;
      }
      return store;
    });
    _loading = loading;
    try {
      return await loading;
    } finally {
      if (identical(_loading, loading)) _loading = null;
    }
  }

  static Future<AchievementStore> _loadFresh() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'achievement_store');
      preferences = null;
    }
    return AchievementStore._(
      preferences,
      preferences?.getStringList(_unlockedKey)?.toSet() ?? <String>{},
      preferences?.getInt(_answeredKey) ?? 0,
      preferences?.getStringList(_categoriesKey)?.toSet() ?? <String>{},
      preferences?.getInt(_dailyQuizKey) ?? 0,
      preferences?.getString(_dailyQuizDayKey),
      _decodeUnlockedAt(preferences?.getString(_unlockedAtKey)),
      preferences?.getInt(_bestRoundStreakKey) ?? 0,
    );
  }

  static Map<String, String> _decodeUnlockedAt(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } catch (_) {
      // Bozuk kayıt rozeti kaybettirmez; yalnız tarih gösterilmez.
      return <String, String>{};
    }
  }

  static void resetInstance() {
    _loadGeneration++;
    _instance = null;
    _loading = null;
  }

  Future<void> clear() async {
    await removePersistedPreferenceKeys(_preferences, [
      _unlockedKey,
      _answeredKey,
      _categoriesKey,
      _dailyQuizKey,
      _dailyQuizDayKey,
      _unlockedAtKey,
      _bestRoundStreakKey,
    ]);
    _unlockedIds.clear();
    _answeredQuestions = 0;
    _playedCategories.clear();
    _dailyQuizCompletions = 0;
    _dailyQuizLastDay = null;
    _unlockedAt.clear();
    _bestRoundStreak = 0;
  }

  final SharedPreferences? _preferences;
  final Set<String> _unlockedIds;
  int _answeredQuestions;
  final Set<String> _playedCategories;
  int _dailyQuizCompletions;
  String? _dailyQuizLastDay;
  final Map<String, String> _unlockedAt;
  int _bestRoundStreak;

  static String _dayString(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Günün soruları turu [day] günü BİTİRİLDİ mi?
  ///
  /// 2026-09-30 canlı: tur bittikten sonra Yarış > Pirsên rojê sayfası hâlâ
  /// "Bugün" ve "Başla" diyordu, çünkü tamamlanma hiçbir yerde günle
  /// birlikte tutulmuyordu; yalnız toplam sayaç ([_dailyQuizCompletions],
  /// "5 kez" rozeti için) vardı. Gün, İstanbul takvim günüdür
  /// ([contestDayKey]; sunucu sıralaması ve soru tohumuyla aynı); yarım bırakılan tur sonuç ekranına varmadığı için
  /// yazılmaz.
  bool dailyQuizDoneOn(DateTime day) =>
      _dailyQuizLastDay == contestDayString(day);

  Set<String> get unlockedIds => Set.unmodifiable(_unlockedIds);
  List<Achievement> get unlockedAchievements => definitions
      .where((achievement) => _unlockedIds.contains(achievement.id))
      .toList(growable: false);

  /// Tüm oturumlar boyunca cevaplanan toplam soru sayısı.
  ///
  /// `BadgeService.evaluateQuestionBadges` bu değeri ister — ayrı bir
  /// sayaç tutmak yerine burada zaten birikmiş olan tek kaynağa bağlanır.
  int get answeredQuestions => _answeredQuestions;

  bool isUnlocked(String id) => _unlockedIds.contains(id);

  /// Başarının açıldığı gün; tarih kaydı yoksa (eski rozet) null.
  DateTime? unlockedAt(String id) {
    final raw = _unlockedAt[id];
    if (raw == null) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Bir turda yapılmış en uzun doğru serisi.
  int get bestRoundStreak => _bestRoundStreak;

  /// Günün turunun (İstanbul gününde en çok bir kez sayılan) tamamlanma sayısı.
  int get dailyQuizCompletions => _dailyQuizCompletions;

  /// Oynanmış gerekli konu sayısı.
  int get playedRequiredCategoryCount =>
      requiredCategories.where(_playedCategories.contains).length;

  /// [id] başarısının açılmasına ne kadar kaldığı.
  ///
  /// YALNIZ GÖSTERİM: açılma kuralları [recordQuizResult] içinde aynen
  /// durur; buradaki hedefler onlarla aynı sayıdır (100 soru, 10 seri, 8
  /// konu, 7 gün, 5 tur). [dailyStreak] günlük zincir uzunluğudur
  /// (`StreakStore.effectiveStreak`); depo bilmediği için çağıran verir.
  /// Sayaç tutulmayan tek seferlik başarılar `0/1` olur.
  RewardProgress? progressFor(String id, {int dailyStreak = 0}) {
    final unlocked = isUnlocked(id);
    RewardProgress done(int target, RewardUnit unit) =>
        RewardProgress(current: target, target: target, unit: unit);
    switch (id) {
      case AchievementIds.firstGame:
        return RewardProgress(current: unlocked ? 1 : 0, target: 1);
      case AchievementIds.tenStreak:
        return unlocked
            ? done(10, RewardUnit.none)
            : RewardProgress(current: _bestRoundStreak, target: 10);
      case AchievementIds.hundredQuestions:
        return unlocked
            ? done(100, RewardUnit.question)
            : RewardProgress(
                current: _answeredQuestions,
                target: 100,
                unit: RewardUnit.question,
              );
      case AchievementIds.allCategories:
        final total = requiredCategories.length;
        return unlocked
            ? done(total, RewardUnit.topic)
            : RewardProgress(
                current: playedRequiredCategoryCount,
                target: total,
                unit: RewardUnit.topic,
              );
      case AchievementIds.sevenDayStreak:
        return unlocked
            ? done(7, RewardUnit.day)
            : RewardProgress(
                current: dailyStreak,
                target: 7,
                unit: RewardUnit.day,
              );
      case AchievementIds.mistakesCleared:
      case AchievementIds.botWinner:
        return RewardProgress(current: unlocked ? 1 : 0, target: 1);
      case AchievementIds.dailyQuizFive:
        return unlocked
            ? done(5, RewardUnit.round)
            : RewardProgress(
                current: _dailyQuizCompletions,
                target: 5,
                unit: RewardUnit.round,
              );
    }
    return null;
  }

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
    DateTime? now,
  }) async {
    _answeredQuestions += totalQuestions;
    if (bestStreak > _bestRoundStreak) _bestRoundStreak = bestStreak;
    if (requiredCategories.contains(category)) {
      _playedCategories.add(category);
    }
    if (dailyQuiz) {
      // Günün soruları aynı gün tekrar oynanabilir; sayaç İstanbul gününde EN
      // ÇOK bir kez artar, yoksa "5 kez" rozeti tek günde açılırdı (bkz.
      // test/daily_quiz_badge_once_per_day_test.dart).
      // Yalnız kayıtlı son günden İLERİ tarih sayılır: saat 24→23→24
      // oynatılınca `!=` kontrolü aynı takvim gününü yeniden sayıyordu.
      final today = contestDayString(now ?? DateTime.now());
      final last = _dailyQuizLastDay;
      if (last == null || today.compareTo(last) > 0) {
        _dailyQuizCompletions += 1;
        _dailyQuizLastDay = today;
      }
    }

    final newlyUnlocked = <Achievement>[];
    void unlockWhen(bool condition, String id) {
      if (!condition || _unlockedIds.contains(id)) return;
      _unlockedIds.add(id);
      _unlockedAt[id] = _dayString(now ?? DateTime.now());
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
      // Yalnızca GERÇEK bot rakipler sayılır: gerçek insan rakibi yenince
      // "Bot Têk Bir" rozeti açılmamalı (2026-07 canlı denetim bulgusu).
      // Botlar BotRace.toPlayers() ile state=='Bot' üretir; online oyuncular
      // 'Hazır'/'Bekliyor'/'Cevapladı' durumlarında gelir.
      opponents.isNotEmpty &&
          opponents.every((opponent) => opponent.state == 'Bot') &&
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
    await _preferences?.setInt(_bestRoundStreakKey, _bestRoundStreak);
    await _preferences?.setString(_unlockedAtKey, jsonEncode(_unlockedAt));
    final lastDay = _dailyQuizLastDay;
    if (lastDay != null) {
      await _preferences?.setString(_dailyQuizDayKey, lastDay);
    }
  }
}
