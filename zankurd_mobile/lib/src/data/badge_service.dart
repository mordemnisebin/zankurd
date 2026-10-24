import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';

import '../l10n/strings.dart';
import '../models/achievement.dart';
import '../utils/error_reporter.dart';

/// Streak ve puan tabanlı rozet servisi.
/// Mevcut AchievementStore'u tamamlar; ek rozetleri yönetir.
class BadgeService {
  BadgeService._(this._preferences, this._unlockedBadges, this._unlockedAt);

  static String get _storageKey =>
      LocalProgressScope.physical('zankurd.badges.unlocked');
  static String get _unlockedAtKey =>
      LocalProgressScope.physical('zankurd.badges.unlockedAt');
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

  static Future<BadgeService>? _loading;
  static int _loadGeneration = 0;

  static Future<BadgeService> load() async {
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

  static Future<BadgeService> _loadFresh() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'badge_service');
      preferences = null;
    }
    final unlocked =
        preferences?.getStringList(_storageKey)?.toSet() ?? <String>{};
    return BadgeService._(
      preferences,
      unlocked,
      _decodeUnlockedAt(preferences?.getString(_unlockedAtKey)),
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
      return <String, String>{};
    }
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() {
    _loadGeneration++;
    _instance = null;
    _loading = null;
  }

  Future<void> clear() async {
    await removePersistedPreferenceKeys(_preferences, [
      _storageKey,
      _unlockedAtKey,
    ]);
    _unlockedBadges.clear();
    _unlockedAt.clear();
  }

  final SharedPreferences? _preferences;
  final Set<String> _unlockedBadges;

  /// Açılış günleri (`id -> yyyy-MM-dd`); eski rozetlerin tarihi yoktur.
  final Map<String, String> _unlockedAt;

  static String _dayString(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Tek giriş noktası: rozeti açar ve açılış gününü yazar.
  void _unlock(String id) {
    _unlockedBadges.add(id);
    _unlockedAt[id] = _dayString(DateTime.now());
  }

  /// Rozetin açıldığı gün; kayıt yoksa (eski rozet) null.
  DateTime? unlockedAt(String id) {
    final parts = (_unlockedAt[id] ?? '').split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// [id] rozetinin açılmasına ne kadar kaldığı.
  ///
  /// YALNIZ GÖSTERİM: açılma kuralları `evaluate*` içinde aynen durur.
  /// [answeredQuestions] `AchievementStore.answeredQuestions`, [dailyStreak]
  /// `StreakStore.effectiveStreak`. Beceri rozetleri (mükemmel oyun, hız)
  /// sayaçsızdır: `0/1`.
  RewardProgress? progressFor(
    String id, {
    required int answeredQuestions,
    required int dailyStreak,
  }) {
    final unlocked = isUnlocked(id);
    RewardProgress counted(int current, int target, RewardUnit unit) =>
        RewardProgress(
          current: unlocked ? target : current,
          target: target,
          unit: unit,
        );
    return switch (id) {
      'streak_30' => counted(dailyStreak, 30, RewardUnit.day),
      'questions_500' => counted(answeredQuestions, 500, RewardUnit.question),
      'questions_1000' => counted(answeredQuestions, 1000, RewardUnit.question),
      'perfect_game' || 'speed_demon' => counted(0, 1, RewardUnit.none),
      _ => null,
    };
  }

  Set<String> get unlockedBadges => Set.unmodifiable(_unlockedBadges);
  int get unlockedCount => _unlockedBadges.length;
  int get totalCount => badgeDefinitions.length;
  bool isUnlocked(String id) => _unlockedBadges.contains(id);

  /// Streak değerine göre rozetleri değerlendirir.
  Future<List<String>> evaluateStreakBadges(int currentStreak) async {
    final newlyUnlocked = <String>[];
    if (currentStreak >= 30 && !_unlockedBadges.contains('streak_30')) {
      _unlock('streak_30');
      newlyUnlocked.add('streak_30');
    }
    if (newlyUnlocked.isNotEmpty) await _persist();
    return newlyUnlocked;
  }

  /// Soru sayısına göre rozetleri değerlendirir.
  Future<List<String>> evaluateQuestionBadges(int totalAnswered) async {
    final newlyUnlocked = <String>[];
    if (totalAnswered >= 500 && !_unlockedBadges.contains('questions_500')) {
      _unlock('questions_500');
      newlyUnlocked.add('questions_500');
    }
    if (totalAnswered >= 1000 && !_unlockedBadges.contains('questions_1000')) {
      _unlock('questions_1000');
      newlyUnlocked.add('questions_1000');
    }
    if (newlyUnlocked.isNotEmpty) await _persist();
    return newlyUnlocked;
  }

  /// Bir turun beceri rozetlerine (mükemmel oyun, hız canavarı) sayılması
  /// için asgari soru sayısı.
  static const minSkillRoundQuestions = 5;

  /// Tur beceri rozetlerine sayılır mı?
  ///
  /// Kusur: `perfect_game`/`speed_demon` her turda değerlendiriliyordu.
  /// Yanlış tekrarı (alıştırma) turunda sorular zaten bilinen yanlışlardır;
  /// tek soruluk turda "hepsi doğru" ve "60 sn'den kısa" kendiliğinden
  /// sağlanır; süresi dolan sorular cevap süresine 0 katar, yani hiç
  /// cevaplamamak hız canavarı yapardı. Rozet ilk turda bedavaya açılıyordu
  /// ve sessizdi: açılması hata üretmez, yalnız rozeti değersizleştirir.
  ///
  /// Sayılan tur: alıştırma değil, en az [minSkillRoundQuestions] soru, hiçbir
  /// soru süre aşımıyla boş kalmamış.
  static bool isSkillRound({
    required bool practice,
    required int totalQuestions,
    required int unanswered,
  }) =>
      !practice && totalQuestions >= minSkillRoundQuestions && unanswered == 0;

  /// Mükemmel oyun rozetini değerlendirir.
  Future<bool> evaluatePerfectGame(int correct, int total) async {
    if (correct == total &&
        total > 0 &&
        !_unlockedBadges.contains('perfect_game')) {
      _unlock('perfect_game');
      await _persist();
      return true;
    }
    return false;
  }

  /// Hız canavarı rozetini değerlendirir.
  Future<bool> evaluateSpeedDemon(Duration elapsed) async {
    if (elapsed.inSeconds < 60 && !_unlockedBadges.contains('speed_demon')) {
      _unlock('speed_demon');
      await _persist();
      return true;
    }
    return false;
  }

  Future<void> _persist() async {
    await _preferences?.setStringList(_storageKey, _unlockedBadges.toList());
    await _preferences?.setString(_unlockedAtKey, jsonEncode(_unlockedAt));
  }
}
