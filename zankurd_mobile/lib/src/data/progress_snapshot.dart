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
///   `best` iki tarafın en yükseği. Dondurma jetonu bir **cihaz defteridir**
///   (`freezeLedger`: cihaz -> kazanılan/harcanan sayaçları, yalnız artar;
///   birleşim cihaz başına en büyük). Bakiye = taban + kazanılan − harcanan
///   (0..2). Eskiden bakiye son zaman damgalı MUTLAK sayıydı: iki cihaz aynı
///   sıfırdan birer jeton satın alınca ikisi de `1` yazıyor, biri kayboluyordu.
/// * Tekrar kuyruğu: soru kimliği **birleşimi**; aynı kimlikte **daha erken
///   vade** (`nextReview`) kazanır; günlük performans günü gün **en yüksek**.
/// * Seviye sınavı: iki tarafta da yazım zamanı (`placementAt`) varsa **en son
///   yazan kazanır** (düşük seviyeye yeniden sınav geri alınmasın); biri
///   zamansızsa (eski veri) daha yüksek seviye, seviye yoksa "geçildi"
///   bayrağı VEYA.
/// * Hikâye düğümü: hikâye başına, iki tarafta da zaman (`storyAt`) varsa
///   **en son yazan** (yeniden başlatma geri alınmasın); aksi hâlde yerelde
///   varsa yerel, yoksa uzak. "Bitirildi" kümesi (`storyDone`): **birleşim**.
/// * Öğrenme hedefi: iki tarafta da değişiklik zamanı (`goalAt`) varsa **en
///   son seçen**; yalnız birinde varsa damgalı olan; ikisinde de yoksa (eski
///   veri) yerel. Eskiden yerel HER ZAMAN kazanıyordu: eski hedefi taşıyan
///   cihaz, öbür cihazda yeni seçilen hedefi geri alıyordu.
/// * Kelimelerim: kelime birleşimi + **silme işaretleri** (`wordsGone`: kimlik
///   -> silinme anı). Silme anı, kelimenin son tekrarından/eklenişinden yeni
///   ya da eşitse kelime silinir; kelime sonradan yeniden eklendi/tekrar
///   edildiyse işaret düşer. Eskiden birleşim hiçbir kelimeyi silmiyordu:
///   bir cihazda silinen kelime eski cihazın kopyasıyla geri geliyordu.
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
    this.learningGoalAt,
    this.words = const {},
    this.wordsRemoved = const {},
  });

  /// Biçim sürümü. Daha YENİ bir sürüm okunursa istemci ne birleştirir ne
  /// yazar (eski istemci yeni alanları silmesin).
  ///
  /// * 1: ilk biçim. `words` (Kelimelerim) sürüm artmadan eklendi; alanı
  ///   bilmeyen v1 istemci bütün görüntüyü yeniden yazıp kelime yedeğini
  ///   siliyordu (2026-11-04 denetimi).
  /// * 2 (2.1.2): seri dondurma defteri (`freezeBase`/`freezeLedger`), öğrenme
  ///   hedefi zamanı (`goalAt`), kelime silme işaretleri (`wordsGone`).
  ///   Bu alanları bilmeyen istemci onları silerdi; bu yüzden v1 istemci v2
  ///   kaydı okuyunca ne birleştirir ne yazar (yerel kullanım sürer, yalnız
  ///   bulut yedeği güncellemeye kadar durur) ve sunucu eski sürümün yeniyi
  ///   ezmesini reddeder (`save_my_progress_v3` + `player_progress` tetikleyicisi).
  static const currentVersion = 2;

  /// Sunucu sınırı 256 KB; JSON bunun altında kalmalı.
  static const maxEncodedBytes = 240 * 1024;

  /// Sunucunun ölçtüğü boyut: `octet_length(jsonb::text)`. jsonb metni
  /// `"anahtar": değer` ve `, ` ayraçlarıyla yazar (her ayraçta +1 bayt) ve
  /// karakterler UTF-8 sayılır.
  static int serverBytes(Object? value) {
    if (value is Map) {
      if (value.isEmpty) return 2;
      var total = 2; // { }
      var first = true;
      value.forEach((k, v) {
        if (!first) total += 2; // ", "
        first = false;
        total += utf8.encode(jsonEncode('$k')).length + 2 + serverBytes(v);
      });
      return total;
    }
    if (value is Iterable) {
      var total = 2;
      var first = true;
      for (final item in value) {
        if (!first) total += 2;
        first = false;
        total += serverBytes(item);
      }
      return total;
    }
    return utf8.encode(jsonEncode(value)).length;
  }

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

  /// Hedefin son seçildiği an (ms); eski veride null.
  final int? learningGoalAt;

  /// "Kelimelerim" (Leitner) durumu: sözlük kimliği -> kutu/vade/zaman damgası.
  ///
  /// Eskiden yalnız cihazdaydı; telefon değişince ya da yeniden kurulumda
  /// kullanıcının elle topladığı liste ve tekrar ilerlemesi sessizce giderdi.
  final Map<String, SnapshotWord> words;

  /// Silinen kelimeler: sözlük kimliği -> silinme anı (ms). Bkz. sınıf belgesi.
  final Map<String, int> wordsRemoved;

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
      words.isEmpty &&
      wordsRemoved.isEmpty &&
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
    // ignore: use_null_aware_elements
    if (learningGoalAt != null) 'goalAt': learningGoalAt,
    if (wordsRemoved.isNotEmpty)
      'wordsGone': {
        for (final key in _sorted(wordsRemoved.keys)) key: wordsRemoved[key],
      },
    if (words.isNotEmpty)
      'words': {
        for (final key in _sorted(words.keys)) key: words[key]!.toJson(),
      },
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
        learningGoalAt: raw['goalAt'] is num && (raw['goalAt'] as num) > 0
            ? (raw['goalAt'] as num).toInt()
            : null,
        words: SnapshotWord.mapFrom(raw['words']),
        wordsRemoved: _intMap(raw['wordsGone']),
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
    final goal = _mergeGoal(local, remote);
    final (words, wordsRemoved) = SnapshotWord.mergeWithTombstones(
      local.words,
      local.wordsRemoved,
      remote.words,
      remote.wordsRemoved,
    );
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
      learningGoal: goal.$1,
      learningGoalAt: goal.$2,
      words: words,
      wordsRemoved: wordsRemoved,
    );
  }

  /// Öğrenme hedefi: iki tarafta da zaman varsa SON SEÇEN (eşitlikte yerel);
  /// yalnız birinde varsa damgalı olan; ikisinde de yoksa yerel, o da yoksa uzak.
  static (String?, int?) _mergeGoal(ProgressSnapshot a, ProgressSnapshot b) {
    final ga = a.learningGoal;
    final gb = b.learningGoal;
    if (ga == null) return (gb, b.learningGoalAt);
    if (gb == null) return (ga, a.learningGoalAt);
    final ta = a.learningGoalAt;
    final tb = b.learningGoalAt;
    if (ta != null && tb != null) {
      return tb > ta ? (gb, tb) : (ga, ta);
    }
    if (tb != null) return (gb, tb);
    return (ga, ta);
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

/// Tek kelimenin Leitner durumu (yerel `SavedWord`un kompakt hali).
class SnapshotWord {
  const SnapshotWord({
    this.box = 1,
    this.due = 0,
    this.added = 0,
    this.reviews = 0,
    this.reviewedAt = 0,
  });

  final int box;
  final int due;
  final int added;
  final int reviews;

  /// Son tekrar zamanı (ms); 0 = yok / damgadan önceki kayıt.
  final int reviewedAt;

  /// Karşılaştırma için etkin son tekrar zamanı. Damgasız (eski) kayıtta
  /// tekrar edilmişse vade ve kutu aralığından geri hesaplanır; hiç tekrar
  /// edilmediyse eklenme anıdır.
  int get effectiveReviewedAt {
    if (reviewedAt > 0) return reviewedAt;
    if (reviews > 0 && due > 0) {
      final days = const [1, 2, 4, 8, 16][box.clamp(1, 5) - 1];
      return due - days * Duration.millisecondsPerDay;
    }
    return added;
  }

  Map<String, dynamic> toJson() => {
    'box': box,
    'due': due,
    'added': added,
    'n': reviews,
    if (reviewedAt > 0) 'r': reviewedAt,
  };

  static Map<String, SnapshotWord> mapFrom(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, SnapshotWord>{};
    raw.forEach((key, value) {
      if (key is! String || value is! Map) return;
      out[key] = SnapshotWord(
        box: _int(value['box']).clamp(1, 5),
        due: _int(value['due']),
        added: _int(value['added']),
        reviews: _int(value['n']),
        reviewedAt: _int(value['r']),
      );
    });
    return out;
  }

  /// İki taraf da aynı kelimeyi taşıyorsa son tekrarı YENİ olan kazanır
  /// (eşitlikte daha çok tekrar, sonra daha yüksek kutu); eklenme zamanı
  /// ikisinin en erkeni. Tek tarafta olan kelime AYNEN korunur: birleşim, hiçbir
  /// kelime kaybolmaz (kaldırma cihazlar arasında yayılmaz — bilinçli).
  static SnapshotWord merge(SnapshotWord a, SnapshotWord b) {
    final ta = a.effectiveReviewedAt;
    final tb = b.effectiveReviewedAt;
    SnapshotWord winner;
    if (ta != tb) {
      winner = ta > tb ? a : b;
    } else if (a.reviews != b.reviews) {
      winner = a.reviews > b.reviews ? a : b;
    } else {
      winner = a.box >= b.box ? a : b;
    }
    final added = a.added == 0
        ? b.added
        : (b.added == 0 ? a.added : (a.added < b.added ? a.added : b.added));
    return SnapshotWord(
      box: winner.box,
      due: winner.due,
      added: added,
      reviews: winner.reviews,
      reviewedAt: winner.reviewedAt,
    );
  }

  static Map<String, SnapshotWord> mergeAll(
    Map<String, SnapshotWord> a,
    Map<String, SnapshotWord> b,
  ) {
    return {
      for (final id in {...a.keys, ...b.keys})
        id: a[id] == null
            ? b[id]!
            : (b[id] == null ? a[id]! : merge(a[id]!, b[id]!)),
    };
  }

  /// Kelime birleşimi + silme işaretleri. Silme işaretleri kimlik başına en
  /// yenisiyle birleşir; sonra kelimeyle yarıştırılır: işaret kelimenin son
  /// etkinliğinden (tekrar ya da eklenme) yeni ya da eşitse kelime silinir,
  /// değilse (silindikten SONRA yeniden eklendi/tekrar edildi) işaret düşer.
  static (Map<String, SnapshotWord>, Map<String, int>) mergeWithTombstones(
    Map<String, SnapshotWord> aWords,
    Map<String, int> aGone,
    Map<String, SnapshotWord> bWords,
    Map<String, int> bGone, {
    int? nowMs,
  }) {
    final words = Map<String, SnapshotWord>.of(mergeAll(aWords, bWords));
    final gone = <String, int>{};
    for (final id in {...aGone.keys, ...bGone.keys}) {
      final at = [
        aGone[id] ?? 0,
        bGone[id] ?? 0,
      ].reduce((x, y) => x > y ? x : y);
      final word = words[id];
      if (word == null) {
        gone[id] = at;
        continue;
      }
      final activity = word.effectiveReviewedAt > word.added
          ? word.effectiveReviewedAt
          : word.added;
      if (at >= activity) {
        words.remove(id);
        gone[id] = at;
      }
    }
    return (words, _pruneTombstones(gone, nowMs));
  }

  /// Yerel sınırın (`WordListStore.removedRetention` 180 gün /
  /// `removedCap` 500) bulut birleşiminde de uygulanması: eskiden yalnız
  /// yerel depo budanıyor, birleşim sınırsız işaret taşıyıp yedeği şişiriyor,
  /// yerel yükleme de sonra bunları sessizce atıyordu (alan 3 #21). Değerler
  /// `word_list_store_test`te depodakilerle eşitliği için bekçilenir.
  static const tombstoneRetentionMs = 180 * 24 * 60 * 60 * 1000;
  static const tombstoneCap = 500;

  static Map<String, int> _pruneTombstones(Map<String, int> gone, int? nowMs) {
    final cutoff =
        (nowMs ?? DateTime.now().millisecondsSinceEpoch) - tombstoneRetentionMs;
    final kept = <String, int>{
      for (final entry in gone.entries)
        if (entry.value >= cutoff) entry.key: entry.value,
    };
    if (kept.length <= tombstoneCap) return kept;
    final newest = kept.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      for (final entry in newest.take(tombstoneCap)) entry.key: entry.value,
    };
  }
}

/// Bir cihazın dondurma jetonu sayaçları (yalnız artar).
class SnapshotFreezeEntry {
  const SnapshotFreezeEntry({this.gained = 0, this.spent = 0});

  /// Bu cihazın satın aldığı jeton sayısı.
  final int gained;

  /// Bu cihazın harcadığı jeton sayısı.
  final int spent;

  /// Cihaz satırı sayısı bu sınırı aşan (bozuk ya da saldırgan) kayıtta
  /// fazlası okunmaz; gerçek kullanımda bir kişinin birkaç cihazı olur.
  static const maxDevices = 64;

  static Map<String, SnapshotFreezeEntry> mapFrom(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, SnapshotFreezeEntry>{};
    final keys = raw.keys.whereType<String>().toList()..sort();
    for (final id in keys) {
      if (out.length >= maxDevices) break;
      final value = raw[id];
      if (id.isEmpty || id.length > 40 || value is! List || value.length < 2) {
        continue;
      }
      final g = value[0];
      final s = value[1];
      if (g is! num || s is! num) continue;
      out[id] = SnapshotFreezeEntry(
        gained: g.toInt() < 0 ? 0 : g.toInt(),
        spent: s.toInt() < 0 ? 0 : s.toInt(),
      );
    }
    return Map.unmodifiable(out);
  }
}

/// Seri kaydı. `lastDay` yerel takvim günü (`yyyy-MM-dd`).
class SnapshotStreak {
  const SnapshotStreak({
    this.current = 0,
    this.best = 0,
    this.lastDay,
    this.freeze = 0,
    this.freezeAt,
    this.freezeBase,
    this.freezeLedger = const {},
    this.playedDays = const {},
    this.frozenDays = const {},
    this.repairMonth,
    this.firstSeen,
  });

  /// Takvimde tutulan en fazla gün sayısı (`StreakStore.maxHistoryDays`).
  static const maxHistoryDays = 400;

  /// Aynı anda tutulabilecek en fazla jeton (`StreakStore.maxFreeze`; bir
  /// test ikisinin eşitliğini bekler).
  static const maxFreeze = 2;

  /// Defterde cihaz kimliği olmayan düzeltme satırı: birleşimde bakiye 0..2
  /// dışına taşarsa fazlalığı burada eritilir (bkz. [merge]).
  static const absorberId = '~';

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

  /// Etkin jeton bakiyesi. [freezeBase] doluysa her zaman defterden türetilir
  /// ([balanceOf]); doluysa bu alan yalnız okunabilirlik içindir.
  final int freeze;

  /// Jeton sayısının son değiştiği an (epoch ms). Bilgi amaçlı; defter modunda
  /// iki tarafın en büyüğü. Eski (defter öncesi) kayıtlarda birleştirmeyi o
  /// belirler: en yeni değişiklik kazanır, damga yoksa büyük olan.
  final int? freezeAt;

  /// Defter öncesi MUTLAK bakiye (taban). null = bu kayıt defter modunda
  /// DEĞİL (eski istemci ya da henüz hiç jeton işlemi yok). İki cihaz aynı
  /// eşitlenmiş tabanı taşır; birleşimde büyük olan alınır (tek yönlü eski
  /// kayıt harcanmışı geri getirebilir ama satın alınanı asla kaybettirmez).
  final int? freezeBase;

  /// Cihaz kimliği -> kazanılan/harcanan sayaçları. Her cihaz YALNIZ kendi
  /// satırını ve yalnız ARTIRARAK yazar; birleşim satır başına en büyük
  /// sayaçtır, bu yüzden eşzamanlı alımlar toplanır, hiçbiri kaybolmaz.
  final Map<String, SnapshotFreezeEntry> freezeLedger;

  /// Defter modunda bakiye: taban + kazanılan - harcanan, 0..[maxFreeze].
  static int balanceOf(int base, Map<String, SnapshotFreezeEntry> ledger) {
    var raw = base;
    for (final e in ledger.values) {
      raw += e.gained - e.spent;
    }
    return raw < 0
        ? 0
        : raw > maxFreeze
        ? maxFreeze
        : raw;
  }

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
      (freezeBase ?? 0) == 0 &&
      freezeLedger.isEmpty &&
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
    // ignore: use_null_aware_elements
    if (freezeBase != null) 'freezeBase': freezeBase,
    if (freezeLedger.isNotEmpty)
      'freezeLedger': {
        for (final key in _sorted(freezeLedger.keys))
          key: [freezeLedger[key]!.gained, freezeLedger[key]!.spent],
      },
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
    final rawBase = raw['freezeBase'];
    final freezeBase = rawBase is num && rawBase >= 0
        ? rawBase.toInt().clamp(0, maxFreeze)
        : null;
    final ledger = SnapshotFreezeEntry.mapFrom(raw['freezeLedger']);
    return SnapshotStreak(
      current: _int(raw['current']),
      best: _int(raw['best']),
      lastDay: day is String && day.isNotEmpty ? day : null,
      freezeBase: freezeBase,
      freezeLedger: ledger,
      freeze: freezeBase != null
          ? balanceOf(freezeBase, ledger)
          : _int(raw['freeze']),
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
    final (played, frozen) = normalizeCalendarDays(
      {...a.playedDays, ...b.playedDays},
      {...a.frozenDays, ...b.frozenDays},
    );
    // Birleşmiş takvim kesintisiz bir oynama zinciri gösteriyorsa seri onun
    // uzunluğundan KISA olamaz: ortak tabandan A ertesi gün, eski verili B
    // sonraki gün çevrimdışı oynayınca `current` yalnız son günü yeni olan
    // cihazdan alınıp 7 yerine 1 kalıyordu (2026-11-04 denetimi). Yalnız
    // OYNANMIŞ günlerin ardışık zinciri sayılır (alt sınır; dondurma
    // köprüleri ve onarımlar kendi sayaçlarından gelir).
    final current = [
      winner.current,
      _playedRunEndingAt(winner.lastDay, played),
    ].reduce((x, y) => x > y ? x : y);
    final best = [a.best, b.best, current].reduce((x, y) => x > y ? x : y);
    final rmA = isValidMonthKey(a.repairMonth) ? a.repairMonth : null;
    final rmB = isValidMonthKey(b.repairMonth) ? b.repairMonth : null;
    final repairMonth = _compareDays(rmA, rmB) >= 0 ? rmA : rmB;
    final fsCandidates = <String>[
      if (isValidDayKey(a.firstSeen)) a.firstSeen!,
      if (isValidDayKey(b.firstSeen)) b.firstSeen!,
      ...played,
      ...frozen,
    ];
    final fz = _mergeFreeze(a, b);
    final freeze = fz.freeze;
    final freezeAt = fz.freezeAt;
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
      freezeBase: fz.base,
      freezeLedger: fz.ledger,
      playedDays: played,
      frozenDays: frozen,
      repairMonth: repairMonth,
      firstSeen: firstSeen,
    );
  }

  /// Jeton birleşimi.
  ///
  /// * Taraflardan hiçbiri defter modunda değilse (eski kayıtlar): en yeni
  ///   değişiklik kazanır (`freezeAt`), damga yoksa büyük olan (v1 davranışı).
  /// * Aksi hâlde DEFTER: taban = iki tabanın büyüğü (defter öncesi taraf
  ///   tabanını mutlak bakiyesinden alır), satırlar cihaz başına en büyük
  ///   sayaç. Bakiye 0..2 dışına taşarsa (iki cihaz eşzamanlı satın aldı ve
  ///   toplam üst sınırı aştı ya da iki cihaz aynı jetonu harcadı) fazlalık
  ///   [absorberId] satırında ERİTİLİR; böylece sonraki işlem bakiyeye
  ///   yansır (yalnız kıstırma yapılsaydı taşan bir jetonun harcanması
  ///   görünmez kalırdı).
  static ({
    int freeze,
    int? freezeAt,
    int? base,
    Map<String, SnapshotFreezeEntry> ledger,
  })
  _mergeFreeze(SnapshotStreak a, SnapshotStreak b) {
    final at = a.freezeAt == null && b.freezeAt == null
        ? null
        : [a.freezeAt ?? 0, b.freezeAt ?? 0].reduce((x, y) => x > y ? x : y);
    final ledgerMode =
        a.freezeBase != null ||
        b.freezeBase != null ||
        a.freezeLedger.isNotEmpty ||
        b.freezeLedger.isNotEmpty;
    if (!ledgerMode) {
      if (a.freezeAt != null || b.freezeAt != null) {
        final newer = (a.freezeAt ?? -1) >= (b.freezeAt ?? -1) ? a : b;
        return (
          freeze: newer.freeze,
          freezeAt: newer.freezeAt,
          base: null,
          ledger: const {},
        );
      }
      return (
        freeze: a.freeze > b.freeze ? a.freeze : b.freeze,
        freezeAt: null,
        base: null,
        ledger: const {},
      );
    }
    int baseOf(SnapshotStreak s) =>
        s.freezeBase ?? (s.freezeLedger.isEmpty ? s.freeze : 0);
    final base = baseOf(a) > baseOf(b) ? baseOf(a) : baseOf(b);
    final ledger = <String, SnapshotFreezeEntry>{};
    for (final id in {...a.freezeLedger.keys, ...b.freezeLedger.keys}) {
      final ea = a.freezeLedger[id] ?? const SnapshotFreezeEntry();
      final eb = b.freezeLedger[id] ?? const SnapshotFreezeEntry();
      ledger[id] = SnapshotFreezeEntry(
        gained: ea.gained > eb.gained ? ea.gained : eb.gained,
        spent: ea.spent > eb.spent ? ea.spent : eb.spent,
      );
    }
    var raw = base;
    for (final e in ledger.values) {
      raw += e.gained - e.spent;
    }
    if (raw < 0 || raw > maxFreeze) {
      final current = ledger[absorberId] ?? const SnapshotFreezeEntry();
      ledger[absorberId] = raw < 0
          ? SnapshotFreezeEntry(
              gained: current.gained - raw,
              spent: current.spent,
            )
          : SnapshotFreezeEntry(
              gained: current.gained,
              spent: current.spent + (raw - maxFreeze),
            );
    }
    return (
      freeze: balanceOf(base, ledger),
      freezeAt: at,
      base: base,
      ledger: Map.unmodifiable(ledger),
    );
  }

  static int _playedRunEndingAt(String? lastDay, Set<String> played) {
    if (!isValidDayKey(lastDay) || !played.contains(lastDay)) return 0;
    var day = DateTime.utc(
      int.parse(lastDay!.substring(0, 4)),
      int.parse(lastDay.substring(5, 7)),
      int.parse(lastDay.substring(8, 10)),
    );
    var run = 0;
    while (true) {
      final key =
          '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      if (!played.contains(key)) return run;
      run++;
      day = day.subtract(const Duration(days: 1));
    }
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

  /// Günlük sınav sayacı KÜMÜLATİFTİR (tamamlanan gün sayısı): iki cihazdan
  /// büyüğü alınır, son gün ise en yenisidir. Eskiden sayaç "tarihi yeni olan
  /// cihazdan bütünüyle" seçiliyordu; beş tamamlamalı cihaz, tek ama daha yeni
  /// tamamlamalı cihazla birleşince sayaç 5'ten 1'e düşüyor, günlük başarı
  /// geriliyordu (2026-11 denetimi).
  static SnapshotAchievements merge(
    SnapshotAchievements a,
    SnapshotAchievements b,
  ) {
    final cmp = SnapshotStreak._compareDays(a.dailyQuizDay, b.dailyQuizDay);
    final newestDay = cmp >= 0 ? a.dailyQuizDay : b.dailyQuizDay;
    final dq = a.dailyQuiz >= b.dailyQuiz ? a.dailyQuiz : b.dailyQuiz;
    return SnapshotAchievements(
      unlocked: {...a.unlocked, ...b.unlocked},
      answered: a.answered > b.answered ? a.answered : b.answered,
      categories: {...a.categories, ...b.categories},
      dailyQuiz: dq,
      dailyQuizDay: newestDay,
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
        } else if (_int(ma['correctSessions']) != _int(mb['correctSessions'])) {
          // Aynı yanlış döngüsünde başarılı tekrar ilerlemesi eski, daha
          // erken vadeli kayıtla silinmez (Codex denetimi 2026-10-29): ilk
          // doğru tekrar vadeyi ileri taşır ama sunucudaki eski kaydın
          // vadesi daha erkendir; "erken vade kazanır" kuralı ilerlemeyi
          // geri alıp soruyu tekrar kuyruğuna çağırıyordu.
          meta[key] = _int(ma['correctSessions']) > _int(mb['correctSessions'])
              ? ma
              : mb;
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
