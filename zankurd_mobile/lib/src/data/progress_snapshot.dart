import 'dart:convert';

import '../services/placement_scoring.dart';

/// Hesaba bağlı, sürümlü ilerleme anlık görüntüsü (saf Dart, G/Ç yok).
///
/// ## Niçin var
///
/// Seri, rozet, seviye yolu, ustalık ve aralıklı tekrar kuyruğu yalnız
/// cihazdaki SharedPreferences'ta yaşıyordu: çıkış, telefon değişimi ya da
/// yeniden kurulum hepsini siliyor, premium'un sattığı "seri koruma" hesabı
/// izlemiyordu. Bu sınıf yerel durumun SUNUCUYA taşınabilir kompakt halidir;
/// sunucu (`player_progress`) yalnız saklar, birleştirmeyi istemci yapar.
///
/// ## Kapsam (bilerek)
///
/// Dahil: XP, seri (+dondurma), rozetler, başarılar, seviye yolu, ustalık,
/// yanlış/tekrar kuyruğu + günlük performans, seviye sınavı, hikâye düğümü,
/// öğrenme hedefi. Hariç: görülmüş soru kimlikleri (binlerce uuid; 256 KB
/// sınırını tek başına zorlar), günlük görevler (günlük, atılır), makbuzlar
/// (cihaza özel), ders tamamlama (zaten sunucuda: `mark_lesson_completed`).
///
/// ## Birleştirme kuralları ([merge]) — deterministik
///
/// * XP, sayaçlar (`answered`, ustalık `c/a/e`), seviye: **en yüksek**.
/// * Rozetler, başarılar, oynanan seviye düğümleri, oynanan kategoriler:
///   **birleşim**.
/// * Seri: **son oynama günü yeni olan kayıt** (`current`, `lastDay`);
///   `best` iki tarafın en yükseği; dondurma jetonu **en yüksek** (jeton
///   coin'le satın alınır, birleştirmede kaybolması kullanıcıya haksızlıktır).
/// * Tekrar kuyruğu: soru kimliği **birleşimi**; aynı kimlikte **daha erken
///   vade** (`nextReview`) kazanır; günlük performans günü gün **en yüksek**.
/// * Seviye sınavı: daha yüksek seviye; seviye yoksa "geçildi" bayrağı VEYA.
/// * Hikâye düğümü ve öğrenme hedefi: yerelde varsa yerel, yoksa uzak
///   (çatışmada yerel kazanır; tek simetrik olmayan kural).
class ProgressSnapshot {
  const ProgressSnapshot({
    this.xp = 0,
    this.streak = const SnapshotStreak(),
    this.badges = const {},
    this.achievements = const SnapshotAchievements(),
    this.levelPlayed = const {},
    this.mastery = const {},
    this.mistakes = const SnapshotMistakes(),
    this.placementLevel,
    this.placementSkipped = false,
    this.story = const {},
    this.learningGoal,
  });

  /// Biçim sürümü. Daha YENİ bir sürüm okunursa istemci ne birleştirir ne
  /// yazar (eski istemci yeni alanları silmesin).
  static const currentVersion = 1;

  /// Sunucu sınırı 256 KB; JSON bunun altında kalmalı.
  static const maxEncodedBytes = 240 * 1024;

  final int xp;
  final SnapshotStreak streak;
  final Set<String> badges;
  final SnapshotAchievements achievements;
  final Set<String> levelPlayed;

  /// Kategori -> ustalık sayaçları.
  final Map<String, SnapshotMastery> mastery;
  final SnapshotMistakes mistakes;
  final String? placementLevel;
  final bool placementSkipped;

  /// Hikâye kimliği -> düğüm kimliği.
  final Map<String, String> story;
  final String? learningGoal;

  bool get isEmpty =>
      xp == 0 &&
      streak.isEmpty &&
      badges.isEmpty &&
      achievements.isEmpty &&
      levelPlayed.isEmpty &&
      mastery.isEmpty &&
      mistakes.isEmpty &&
      placementLevel == null &&
      !placementSkipped &&
      story.isEmpty &&
      learningGoal == null;

  Map<String, dynamic> toJson() => {
    'v': currentVersion,
    'xp': xp,
    'streak': streak.toJson(),
    'badges': _sorted(badges),
    'achievements': achievements.toJson(),
    'levelPlayed': _sorted(levelPlayed),
    'mastery': {
      for (final key in _sorted(mastery.keys)) key: mastery[key]!.toJson(),
    },
    'mistakes': mistakes.toJson(),
    // ignore: use_null_aware_elements
    if (placementLevel != null) 'placementLevel': placementLevel,
    if (placementSkipped) 'placementSkipped': true,
    if (story.isNotEmpty)
      'story': {for (final key in _sorted(story.keys)) key: story[key]},
    // ignore: use_null_aware_elements
    if (learningGoal != null) 'goal': learningGoal,
  };

  /// Kararlı (anahtarları sıralı) JSON dizgisi: eşitlik karşılaştırması ve
  /// boyut ölçümü için.
  String encode() => jsonEncode(toJson());

  /// Anlık görüntüyü JSON'dan okur. Bozuk girdide ya da daha yeni sürümde
  /// `null` döner (çağıran yerel durumu korur).
  static ProgressSnapshot? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['v'];
    if (version is! int || version < 1 || version > currentVersion) {
      return null;
    }
    try {
      return ProgressSnapshot(
        xp: _int(raw['xp']),
        streak: SnapshotStreak.fromJson(raw['streak']),
        badges: _strings(raw['badges']),
        achievements: SnapshotAchievements.fromJson(raw['achievements']),
        levelPlayed: _strings(raw['levelPlayed']),
        mastery: _masteryFrom(raw['mastery']),
        mistakes: SnapshotMistakes.fromJson(raw['mistakes']),
        placementLevel: PlacementLevel.fromStorageKey(
          raw['placementLevel'] as String?,
        )?.storageKey,
        placementSkipped: raw['placementSkipped'] == true,
        story: _stringMap(raw['story']),
        learningGoal:
            raw['goal'] is String && (raw['goal'] as String).isNotEmpty
            ? raw['goal'] as String
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// [local] ile [remote] kümesini birleştirir (kurallar sınıf belgesinde).
  static ProgressSnapshot merge(
    ProgressSnapshot local,
    ProgressSnapshot remote,
  ) {
    final masteryKeys = {...local.mastery.keys, ...remote.mastery.keys};
    final placement = _mergePlacement(local, remote);
    return ProgressSnapshot(
      xp: local.xp > remote.xp ? local.xp : remote.xp,
      streak: SnapshotStreak.merge(local.streak, remote.streak),
      badges: {...local.badges, ...remote.badges},
      achievements: SnapshotAchievements.merge(
        local.achievements,
        remote.achievements,
      ),
      levelPlayed: {...local.levelPlayed, ...remote.levelPlayed},
      mastery: {
        for (final key in masteryKeys)
          key: SnapshotMastery.merge(
            local.mastery[key] ?? const SnapshotMastery(),
            remote.mastery[key] ?? const SnapshotMastery(),
          ),
      },
      mistakes: SnapshotMistakes.merge(local.mistakes, remote.mistakes),
      placementLevel: placement.$1,
      placementSkipped: placement.$2,
      story: {...remote.story, ...local.story},
      learningGoal: local.learningGoal ?? remote.learningGoal,
    );
  }

  static (String?, bool) _mergePlacement(
    ProgressSnapshot a,
    ProgressSnapshot b,
  ) {
    final la = PlacementLevel.fromStorageKey(a.placementLevel);
    final lb = PlacementLevel.fromStorageKey(b.placementLevel);
    if (la == null && lb == null) {
      return (null, a.placementSkipped || b.placementSkipped);
    }
    final best = (la?.index ?? -1) >= (lb?.index ?? -1) ? la : lb;
    return (best?.storageKey, false);
  }

  @override
  bool operator ==(Object other) =>
      other is ProgressSnapshot && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

/// Seri kaydı. `lastDay` yerel takvim günü (`yyyy-MM-dd`).
class SnapshotStreak {
  const SnapshotStreak({
    this.current = 0,
    this.best = 0,
    this.lastDay,
    this.freeze = 0,
  });

  final int current;
  final int best;
  final String? lastDay;
  final int freeze;

  bool get isEmpty =>
      current == 0 && best == 0 && lastDay == null && freeze == 0;

  Map<String, dynamic> toJson() => {
    'current': current,
    'best': best,
    // ignore: use_null_aware_elements
    if (lastDay != null) 'lastDay': lastDay,
    'freeze': freeze,
  };

  static SnapshotStreak fromJson(Object? raw) {
    if (raw is! Map) return const SnapshotStreak();
    final day = raw['lastDay'];
    return SnapshotStreak(
      current: _int(raw['current']),
      best: _int(raw['best']),
      lastDay: day is String && day.isNotEmpty ? day : null,
      freeze: _int(raw['freeze']),
    );
  }

  /// Son oynama günü yeni olan kayıt kazanır; aynı gündeyse büyük seri.
  static SnapshotStreak merge(SnapshotStreak a, SnapshotStreak b) {
    final cmp = _compareDays(a.lastDay, b.lastDay);
    final winner = cmp > 0
        ? a
        : cmp < 0
        ? b
        : (a.current >= b.current ? a : b);
    final current = winner.current;
    final best = [a.best, b.best, current].reduce((x, y) => x > y ? x : y);
    return SnapshotStreak(
      current: current,
      best: best,
      lastDay: winner.lastDay,
      freeze: a.freeze > b.freeze ? a.freeze : b.freeze,
    );
  }

  /// `yyyy-MM-dd` dizgileri sözlük sırasıyla zaman sırasındadır; null en eski.
  static int _compareDays(String? a, String? b) {
    if (a == b) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }
}

class SnapshotAchievements {
  const SnapshotAchievements({
    this.unlocked = const {},
    this.answered = 0,
    this.categories = const {},
    this.dailyQuiz = 0,
    this.dailyQuizDay,
  });

  final Set<String> unlocked;
  final int answered;
  final Set<String> categories;
  final int dailyQuiz;
  final String? dailyQuizDay;

  bool get isEmpty =>
      unlocked.isEmpty &&
      answered == 0 &&
      categories.isEmpty &&
      dailyQuiz == 0 &&
      dailyQuizDay == null;

  Map<String, dynamic> toJson() => {
    'unlocked': _sorted(unlocked),
    'answered': answered,
    'categories': _sorted(categories),
    'dailyQuiz': dailyQuiz,
    // ignore: use_null_aware_elements
    if (dailyQuizDay != null) 'dailyQuizDay': dailyQuizDay,
  };

  static SnapshotAchievements fromJson(Object? raw) {
    if (raw is! Map) return const SnapshotAchievements();
    final day = raw['dailyQuizDay'];
    return SnapshotAchievements(
      unlocked: _strings(raw['unlocked']),
      answered: _int(raw['answered']),
      categories: _strings(raw['categories']),
      dailyQuiz: _int(raw['dailyQuiz']),
      dailyQuizDay: day is String && day.isNotEmpty ? day : null,
    );
  }

  /// Günlük sınav sayacı en yeni güne ait kayıttan; aynı günde büyük olan.
  static SnapshotAchievements merge(
    SnapshotAchievements a,
    SnapshotAchievements b,
  ) {
    final cmp = SnapshotStreak._compareDays(a.dailyQuizDay, b.dailyQuizDay);
    final dq = cmp > 0
        ? a
        : cmp < 0
        ? b
        : (a.dailyQuiz >= b.dailyQuiz ? a : b);
    return SnapshotAchievements(
      unlocked: {...a.unlocked, ...b.unlocked},
      answered: a.answered > b.answered ? a.answered : b.answered,
      categories: {...a.categories, ...b.categories},
      dailyQuiz: dq.dailyQuiz,
      dailyQuizDay: dq.dailyQuizDay,
    );
  }
}

/// Bir kategorinin ustalık sayaçları: doğru (`c`), cevaplanan (`a`),
/// kanıttaki doğru (`e`).
class SnapshotMastery {
  const SnapshotMastery({
    this.correct = 0,
    this.answered = 0,
    this.evidence = 0,
  });

  final int correct;
  final int answered;
  final int evidence;

  Map<String, dynamic> toJson() => {'c': correct, 'a': answered, 'e': evidence};

  static SnapshotMastery fromJson(Object? raw) {
    if (raw is! Map) return const SnapshotMastery();
    return SnapshotMastery(
      correct: _int(raw['c']),
      answered: _int(raw['a']),
      evidence: _int(raw['e']),
    );
  }

  static SnapshotMastery merge(SnapshotMastery a, SnapshotMastery b) =>
      SnapshotMastery(
        correct: a.correct > b.correct ? a.correct : b.correct,
        answered: a.answered > b.answered ? a.answered : b.answered,
        evidence: a.evidence > b.evidence ? a.evidence : b.evidence,
      );
}

/// Yanlış/tekrar kuyruğu: kimlikler, SM-2 üst verisi, günlük performans.
class SnapshotMistakes {
  const SnapshotMistakes({
    this.ids = const {},
    this.meta = const {},
    this.history = const {},
  });

  final Set<String> ids;

  /// Soru kimliği -> `{nextReview, intervalDays, repetitions, easeFactor,
  /// category?, graduated?}` (MistakeStore'un yerel biçimi aynen).
  final Map<String, Map<String, dynamic>> meta;

  /// Gün (`yyyy-MM-dd`) -> `{correct, wrong}`.
  final Map<String, Map<String, int>> history;

  bool get isEmpty => ids.isEmpty && meta.isEmpty && history.isEmpty;

  Map<String, dynamic> toJson() => {
    'ids': _sorted(ids),
    'meta': {
      for (final key in _sorted(meta.keys))
        key: Map<String, dynamic>.fromEntries(
          meta[key]!.entries.toList()..sort((x, y) => x.key.compareTo(y.key)),
        ),
    },
    'history': {
      for (final key in _sorted(history.keys))
        key: {
          'correct': history[key]!['correct'] ?? 0,
          'wrong': history[key]!['wrong'] ?? 0,
        },
    },
  };

  static SnapshotMistakes fromJson(Object? raw) {
    if (raw is! Map) return const SnapshotMistakes();
    final meta = <String, Map<String, dynamic>>{};
    final rawMeta = raw['meta'];
    if (rawMeta is Map) {
      rawMeta.forEach((key, value) {
        if (key is String && value is Map) {
          meta[key] = Map<String, dynamic>.from(value);
        }
      });
    }
    final history = <String, Map<String, int>>{};
    final rawHistory = raw['history'];
    if (rawHistory is Map) {
      rawHistory.forEach((key, value) {
        if (key is String && value is Map) {
          history[key] = {
            'correct': _int(value['correct']),
            'wrong': _int(value['wrong']),
          };
        }
      });
    }
    return SnapshotMistakes(
      ids: _strings(raw['ids']),
      meta: meta,
      history: history,
    );
  }

  static int _due(Map<String, dynamic>? meta) =>
      (meta?['nextReview'] as num?)?.toInt() ?? 0;

  static SnapshotMistakes merge(SnapshotMistakes a, SnapshotMistakes b) {
    final metaKeys = {...a.meta.keys, ...b.meta.keys};
    final meta = <String, Map<String, dynamic>>{};
    for (final key in metaKeys) {
      final ma = a.meta[key];
      final mb = b.meta[key];
      if (ma == null) {
        meta[key] = mb!;
      } else if (mb == null) {
        meta[key] = ma;
      } else {
        // Daha erken vade: tekrar kuyruğunda öne alınan, unutulmayan kazanır.
        // Eşitlikte tekrar sayısı büyük olan (daha çok emek), o da eşitse
        // kararlı bir sıra için JSON dizgisi küçük olan.
        final da = _due(ma);
        final db = _due(mb);
        if (da != db) {
          meta[key] = da < db ? ma : mb;
        } else {
          final ra = (ma['repetitions'] as num?)?.toInt() ?? 0;
          final rb = (mb['repetitions'] as num?)?.toInt() ?? 0;
          if (ra != rb) {
            meta[key] = ra > rb ? ma : mb;
          } else {
            meta[key] = jsonEncode(ma).compareTo(jsonEncode(mb)) <= 0 ? ma : mb;
          }
        }
      }
    }
    final days = {...a.history.keys, ...b.history.keys};
    final history = <String, Map<String, int>>{
      for (final day in days)
        day: {
          'correct': _max(
            a.history[day]?['correct'] ?? 0,
            b.history[day]?['correct'] ?? 0,
          ),
          'wrong': _max(
            a.history[day]?['wrong'] ?? 0,
            b.history[day]?['wrong'] ?? 0,
          ),
        },
    };
    return SnapshotMistakes(
      ids: {...a.ids, ...b.ids},
      meta: meta,
      history: history,
    );
  }

  static int _max(int a, int b) => a > b ? a : b;
}

int _int(Object? value) {
  if (value is num) return value.toInt() < 0 ? 0 : value.toInt();
  return 0;
}

Set<String> _strings(Object? value) {
  if (value is! List) return <String>{};
  return {
    for (final item in value)
      if (item is String && item.isNotEmpty) item,
  };
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return <String, String>{};
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  };
}

Map<String, SnapshotMastery> _masteryFrom(Object? value) {
  if (value is! Map) return <String, SnapshotMastery>{};
  return {
    for (final entry in value.entries)
      if (entry.key is String)
        entry.key as String: SnapshotMastery.fromJson(entry.value),
  };
}

List<String> _sorted(Iterable<String> values) => values.toList()..sort();
