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
/// * Seviye sınavı: iki tarafta da yazım zamanı (`placementAt`) varsa **en son
///   yazan kazanır** (düşük seviyeye yeniden sınav geri alınmasın); biri
///   zamansızsa (eski veri) daha yüksek seviye, seviye yoksa "geçildi"
///   bayrağı VEYA.
/// * Hikâye düğümü: hikâye başına, iki tarafta da zaman (`storyAt`) varsa
///   **en son yazan** (yeniden başlatma geri alınmasın); aksi hâlde yerelde
///   varsa yerel, yoksa uzak. "Bitirildi" kümesi (`storyDone`): **birleşim**.
/// * Öğrenme hedefi: yerelde varsa yerel, yoksa uzak.
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
    this.placementUpdatedAt,
    this.story = const {},
    this.storyUpdatedAt = const {},
    this.storyDone = const {},
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

  /// Seviye sınavının son yazım zamanı (ms); eski veride null.
  final int? placementUpdatedAt;

  /// Hikâye kimliği -> düğüm kimliği.
  final Map<String, String> story;

  /// Hikâye kimliği -> son yazım zamanı (ms); eski kayıtlarda yok.
  final Map<String, int> storyUpdatedAt;

  /// Sonuna ulaşılmış hikâyeler ("yeniden oyna" bunu silmez).
  final Set<String> storyDone;
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
      storyDone.isEmpty &&
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
    // ignore: use_null_aware_elements
    if (placementUpdatedAt != null) 'placementAt': placementUpdatedAt,
    if (story.isNotEmpty)
      'story': {for (final key in _sorted(story.keys)) key: story[key]},
    if (storyUpdatedAt.isNotEmpty)
      'storyAt': {
        for (final key in _sorted(storyUpdatedAt.keys))
          key: storyUpdatedAt[key],
      },
    if (storyDone.isNotEmpty) 'storyDone': _sorted(storyDone),
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
        placementUpdatedAt: raw['placementAt'] is num
            ? (raw['placementAt'] as num).toInt()
            : null,
        story: _stringMap(raw['story']),
        storyUpdatedAt: _intMap(raw['storyAt']),
        storyDone: _strings(raw['storyDone']),
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
    final story = _mergeStory(local, remote);
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
      placementUpdatedAt: placement.$3,
      story: story.$1,
      storyUpdatedAt: story.$2,
      storyDone: {...local.storyDone, ...remote.storyDone},
      learningGoal: local.learningGoal ?? remote.learningGoal,
    );
  }

  static (String?, bool, int?) _mergePlacement(
    ProgressSnapshot a,
    ProgressSnapshot b,
  ) {
    final ta = a.placementUpdatedAt;
    final tb = b.placementUpdatedAt;
    if (ta != null && tb != null) {
      // İkisi de zamanlı: son yazan kazanır (eşitlikte aşağıdaki kural).
      if (ta != tb) {
        final w = ta > tb ? a : b;
        return (
          PlacementLevel.fromStorageKey(w.placementLevel)?.storageKey,
          w.placementLevel == null && w.placementSkipped,
          w.placementUpdatedAt,
        );
      }
    }
    final stamp = ta == null ? tb : (tb == null ? ta : (ta > tb ? ta : tb));
    final la = PlacementLevel.fromStorageKey(a.placementLevel);
    final lb = PlacementLevel.fromStorageKey(b.placementLevel);
    if (la == null && lb == null) {
      return (null, a.placementSkipped || b.placementSkipped, stamp);
    }
    final best = (la?.index ?? -1) >= (lb?.index ?? -1) ? la : lb;
    return (best?.storageKey, false, stamp);
  }

  static (Map<String, String>, Map<String, int>) _mergeStory(
    ProgressSnapshot local,
    ProgressSnapshot remote,
  ) {
    final nodes = <String, String>{};
    final stamps = <String, int>{};
    for (final id in {...local.story.keys, ...remote.story.keys}) {
      final ln = local.story[id];
      final rn = remote.story[id];
      final lt = local.storyUpdatedAt[id];
      final rt = remote.storyUpdatedAt[id];
      final remoteWins =
          ln == null || (rn != null && lt != null && rt != null && rt > lt);
      nodes[id] = remoteWins ? rn! : ln;
      final t = remoteWins ? rt : lt;
      if (t != null) stamps[id] = t;
    }
    return (nodes, stamps);
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
    this.freezeAt,
    this.playedDays = const {},
    this.frozenDays = const {},
    this.repairMonth,
    this.firstSeen,
  });

  /// Takvimde tutulan en fazla gün sayısı (`StreakStore.maxHistoryDays`).
  static const maxHistoryDays = 400;

  static final RegExp _dayKeyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _monthKeyPattern = RegExp(r'^\d{4}-\d{2}$');

  static bool isValidDayKey(String? value) {
    if (value == null || !_dayKeyPattern.hasMatch(value)) return false;
    final y = int.tryParse(value.substring(0, 4));
    final m = int.tryParse(value.substring(5, 7));
    final d = int.tryParse(value.substring(8, 10));
    if (y == null || m == null || d == null) return false;
    if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) {
      return false;
    }
    final dt = DateTime.utc(y, m, d);
    return dt.year == y && dt.month == m && dt.day == d;
  }

  static bool isValidMonthKey(String? value) {
    if (value == null || !_monthKeyPattern.hasMatch(value)) return false;
    final y = int.tryParse(value.substring(0, 4));
    final m = int.tryParse(value.substring(5, 7));
    if (y == null || m == null) return false;
    return y >= 2000 && y <= 2100 && m >= 1 && m <= 12;
  }

  /// Kronolojik sıralı en yeni [maxHistoryDays] geçerli günü döner.
  static Set<String> trimDays(Iterable<String> days) {
    final sorted = days.where(isValidDayKey).toSet().toList()..sort();
    final trimmed = sorted.length <= maxHistoryDays
        ? sorted
        : sorted.sublist(sorted.length - maxHistoryDays);
    return Set<String>.unmodifiable(trimmed);
  }

  /// Oynanmış ve dondurulmuş günleri birlikte normalize eder:
  /// önce tam geçerli kümelerde `played` baskın kılınır, ardından toplam
  /// takvim penceresi en yeni [maxHistoryDays] güne kırpılır.
  static (Set<String> played, Set<String> frozen) normalizeCalendarDays(
    Iterable<String> rawPlayed,
    Iterable<String> rawFrozen,
  ) {
    final validPlayed = rawPlayed.where(isValidDayKey).toSet();
    final validFrozen = rawFrozen
        .where(isValidDayKey)
        .where((d) => !validPlayed.contains(d))
        .toSet();
    final allDays = {...validPlayed, ...validFrozen}.toList()..sort();
    if (allDays.length <= maxHistoryDays) {
      return (
        Set<String>.unmodifiable(validPlayed.toList()..sort()),
        Set<String>.unmodifiable(validFrozen.toList()..sort()),
      );
    }
    final window = allDays.sublist(allDays.length - maxHistoryDays).toSet();
    return (
      Set<String>.unmodifiable(
        validPlayed.where(window.contains).toList()..sort(),
      ),
      Set<String>.unmodifiable(
        validFrozen.where(window.contains).toList()..sort(),
      ),
    );
  }

  final int current;
  final int best;
  final String? lastDay;
  final int freeze;

  /// Jeton sayısının son değiştiği an (epoch ms). Birleştirmede en yeni
  /// değişiklik kazanır; eski kayıtlarda yoktur (o zaman büyük olan alınır).
  final int? freezeAt;
  final Set<String> playedDays;
  final Set<String> frozenDays;
  final String? repairMonth;
  final String? firstSeen;

  bool get isEmpty =>
      current == 0 &&
      best == 0 &&
      lastDay == null &&
      freeze == 0 &&
      freezeAt == null &&
      playedDays.isEmpty &&
      frozenDays.isEmpty &&
      repairMonth == null &&
      firstSeen == null;

  Map<String, dynamic> toJson() => {
    'current': current,
    'best': best,
    // ignore: use_null_aware_elements
    if (lastDay != null) 'lastDay': lastDay,
    'freeze': freeze,
    // ignore: use_null_aware_elements
    if (freezeAt != null) 'freezeAt': freezeAt,
    if (playedDays.isNotEmpty) 'playedDays': _sorted(playedDays),
    if (frozenDays.isNotEmpty) 'frozenDays': _sorted(frozenDays),
    // ignore: use_null_aware_elements
    if (repairMonth != null) 'repairMonth': repairMonth,
    // ignore: use_null_aware_elements
    if (firstSeen != null) 'firstSeen': firstSeen,
  };

  static SnapshotStreak fromJson(Object? raw) {
    if (raw is! Map) return const SnapshotStreak();
    final day = raw['lastDay'];
    final (played, frozen) = normalizeCalendarDays(
      _strings(raw['playedDays']),
      _strings(raw['frozenDays']),
    );
    final rawRepairMonth = raw['repairMonth'];
    final rawFirstSeen = raw['firstSeen'];
    return SnapshotStreak(
      current: _int(raw['current']),
      best: _int(raw['best']),
      lastDay: day is String && day.isNotEmpty ? day : null,
      freeze: _int(raw['freeze']),
      freezeAt: raw['freezeAt'] is num && (raw['freezeAt'] as num) > 0
          ? (raw['freezeAt'] as num).toInt()
          : null,
      playedDays: played,
      frozenDays: frozen,
      repairMonth: rawRepairMonth is String && isValidMonthKey(rawRepairMonth)
          ? rawRepairMonth
          : null,
      firstSeen: rawFirstSeen is String && isValidDayKey(rawFirstSeen)
          ? rawFirstSeen
          : null,
    );
  }

  /// Son oynama günü yeni olan kayıt kazanır; aynı gündeyse büyük seri.
  /// Takvim geçmişi (`playedDays`, `frozenDays`) birleşir; aynı gün hem
  /// oynanmış hem dondurulmuşsa `playedDays` baskındır.
  static SnapshotStreak merge(SnapshotStreak a, SnapshotStreak b) {
    final cmp = _compareDays(a.lastDay, b.lastDay);
    final winner = cmp > 0
        ? a
        : cmp < 0
        ? b
        : (a.current >= b.current ? a : b);
    final current = winner.current;
    final best = [a.best, b.best, current].reduce((x, y) => x > y ? x : y);
    final (played, frozen) = normalizeCalendarDays(
      {...a.playedDays, ...b.playedDays},
      {...a.frozenDays, ...b.frozenDays},
    );
    final rmA = isValidMonthKey(a.repairMonth) ? a.repairMonth : null;
    final rmB = isValidMonthKey(b.repairMonth) ? b.repairMonth : null;
    final repairMonth = _compareDays(rmA, rmB) >= 0 ? rmA : rmB;
    final fsCandidates = <String>[
      if (isValidDayKey(a.firstSeen)) a.firstSeen!,
      if (isValidDayKey(b.firstSeen)) b.firstSeen!,
      ...played,
      ...frozen,
    ];
    // Jeton: max() harcanan jetonu geri getiriyor, satın alınanı da
    // kaybettirebiliyordu (2026-10-26). Zaman damgası olan en yeni
    // değişiklik kazanır; ikisinde de yoksa (eski kayıt) büyük olan.
    final int freeze;
    final int? freezeAt;
    if (a.freezeAt != null || b.freezeAt != null) {
      final aAt = a.freezeAt ?? -1;
      final bAt = b.freezeAt ?? -1;
      final newer = aAt >= bAt ? a : b;
      freeze = newer.freeze;
      freezeAt = newer.freezeAt;
    } else {
      freeze = a.freeze > b.freeze ? a.freeze : b.freeze;
      freezeAt = null;
    }
    String? firstSeen;
    if (fsCandidates.isNotEmpty) {
      fsCandidates.sort();
      firstSeen = fsCandidates.first;
    }
    return SnapshotStreak(
      current: current,
      best: best,
      lastDay: winner.lastDay,
      freeze: freeze,
      freezeAt: freezeAt,
      playedDays: played,
      frozenDays: frozen,
      repairMonth: repairMonth,
      firstSeen: firstSeen,
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
        // Önce yanlış döngüsü: kaçırma sayısı büyük olan daha yeni bir
        // yanlışı taşır, kazanır. Eşitse kuyruktan çıkmış (graduated) taraf
        // kazanır; yoksa sunucudaki eski anlık görüntü, ustalaşılan soruyu
        // "erken vade" kuralıyla kuyruğa geri getiriyordu (2026-10-25).
        // Eşit sayaçlı eşzamanlı yeni yanlış bu alanlarla ayırt edilemez.
        //
        // Sonra daha erken vade: tekrar kuyruğunda öne alınan, unutulmayan
        // kazanır. Eşitlikte tekrar sayısı büyük olan (daha çok emek), o da
        // eşitse kararlı bir sıra için JSON dizgisi küçük olan.
        final missA = _int(ma['missCount']);
        final missB = _int(mb['missCount']);
        final gradA = ma['graduated'] == true;
        final gradB = mb['graduated'] == true;
        final da = _due(ma);
        final db = _due(mb);
        if (missA != missB) {
          meta[key] = missA > missB ? ma : mb;
        } else if (gradA != gradB) {
          meta[key] = gradA ? ma : mb;
        } else if (da != db) {
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
      ids: {
        for (final id in {...a.ids, ...b.ids})
          if (meta[id]?['graduated'] != true) id,
      },
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

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return <String, int>{};
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
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
