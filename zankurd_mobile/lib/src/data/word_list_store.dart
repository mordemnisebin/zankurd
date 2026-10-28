import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';
import 'learner_lexicon.dart';
import 'local_data_storage.dart';
import 'local_progress_scope.dart';

/// Leitner kutuları: 5 kutu, aralıklar 1, 2, 4, 8, 16 gün.
///
/// ## Niçin Leitner (SM-2 değil)
///
/// Yanlış defteri (MistakeStore) SM-2 kullanır; orada her soru için zorluk
/// derecelendirmesi vardır. Kelime tekrarında kullanıcı yalnız şıkkı seçer
/// (doğru/yanlış), derecelendirme yoktur. Kutu sayısı küçük ve açıklanabilir
/// olsun diye düz Leitner: doğru -> bir üst kutu, yanlış -> 1. kutu.
class LeitnerSchedule {
  const LeitnerSchedule._();

  static const int boxCount = 5;
  static const List<int> intervalDays = [1, 2, 4, 8, 16];

  static int clampBox(int box) => box.clamp(1, boxCount);

  /// Cevaptan sonraki kutu: doğru -> bir üst (en çok 5), yanlış -> 1.
  static int boxAfter(int box, {required bool correct}) =>
      correct ? math.min(clampBox(box) + 1, boxCount) : 1;

  /// [box] kutusundaki bir kelimenin sonraki tekrara dek beklediği gün.
  static int intervalForBox(int box) => intervalDays[clampBox(box) - 1];
}

/// [from]a yerel TAKVİM günü ekler, duvar saati aynı kalır.
///
/// `Duration(days: n)` 24 saat ekler; yaz saati geçişini aşan bir aralıkta
/// vade bir saat kayar ve kelime "yarın sabah" yerine bir saat erken/geç
/// gelir. `DateTime(y, m, d + n, h, min)` gün taşmasını kendisi çözer.
DateTime addCalendarDays(DateTime from, int days) => DateTime(
  from.year,
  from.month,
  from.day + days,
  from.hour,
  from.minute,
  from.second,
);

/// Kullanıcının listesindeki tek kelime ve Leitner durumu.
@immutable
class SavedWord {
  const SavedWord({
    required this.entryId,
    required this.box,
    required this.dueAtMs,
    required this.addedAtMs,
    this.reviews = 0,
  });

  /// [LearnerLexiconEntry.id].
  final String entryId;
  final int box;

  /// Tekrar zamanı (epoch ms). Yeni eklenen kelime hemen tekrar edilebilir.
  final int dueAtMs;
  final int addedAtMs;
  final int reviews;

  bool isDue(DateTime now) => now.millisecondsSinceEpoch >= dueAtMs;

  SavedWord copyWith({int? box, int? dueAtMs, int? reviews}) => SavedWord(
    entryId: entryId,
    box: box ?? this.box,
    dueAtMs: dueAtMs ?? this.dueAtMs,
    addedAtMs: addedAtMs,
    reviews: reviews ?? this.reviews,
  );

  Map<String, Object> toJson() => {
    'box': box,
    'due': dueAtMs,
    'added': addedAtMs,
    'n': reviews,
  };
}

/// Kullanıcının kişisel kelime listesi ve aralıklı tekrar durumu.
///
/// Yerelde, KULLANICIYA BAĞLI tutulur ([LocalProgressScope.physical]);
/// çevrimdışı çalışır, sunucuya gitmez. Metni değil sözlük KİMLİĞİNİ saklar
/// ([LearnerLexicon.byId]).
///
/// ## Kullanıcı değişimi
///
/// Anahtar `load`da hesaplanır; `load` önbellekteki örneğin anahtarı güncel
/// kapsamla uyuşmuyorsa YENİDEN okur. Böylece hesap değişince eski
/// kullanıcının listesi yeni kullanıcıya sızmaz ve oturum katmanının
/// (auth_provider) ayrıca sıfırlama çağırması gerekmez.
class WordListStore extends ChangeNotifier {
  WordListStore._(this._storage, this._key, this._words);

  static const logicalKey = 'zankurd.wordList.v1';

  /// Bir tekrar oturumundaki en çok kelime.
  static const int sessionCap = 10;

  static WordListStore? _instance;
  static Future<WordListStore>? _loading;
  static String? _loadingKey;

  static Future<WordListStore> load({LocalDataStorage? storage}) async {
    final key = LocalProgressScope.physical(logicalKey);
    final cached = _instance;
    if (cached != null && cached._key == key) return cached;
    final inFlight = _loading;
    if (inFlight != null && _loadingKey == key) return inFlight;
    final loading = _loadFresh(storage, key).then((store) {
      if (_loadingKey == key) _instance = store;
      return store;
    });
    _loading = loading;
    _loadingKey = key;
    try {
      return await loading;
    } finally {
      if (identical(_loading, loading)) {
        _loading = null;
        _loadingKey = null;
      }
    }
  }

  static Future<WordListStore> _loadFresh(
    LocalDataStorage? storage,
    String key,
  ) async {
    var effective = storage;
    if (effective == null) {
      try {
        effective = SharedPrefsDataStorage(
          await SharedPreferences.getInstance(),
        );
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'word_list_preferences');
      }
    }
    final words = <String, SavedWord>{};
    final raw = effective?.getString(key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((id, value) {
          if (value is! Map<String, dynamic>) return;
          // Kayıt kayıt korunur: tek bozuk alan bütün döngüyü kesiyor,
          // sonraki kaydetme de kalan kelimeleri silerek listeyi
          // kısaltıyordu (2026-10-28 gece kod denetimi: GPT-6 Sol).
          try {
            words[id] = SavedWord(
              entryId: id,
              box: LeitnerSchedule.clampBox(
                (value['box'] as num?)?.toInt() ?? 1,
              ),
              dueAtMs: (value['due'] as num?)?.toInt() ?? 0,
              addedAtMs: (value['added'] as num?)?.toInt() ?? 0,
              reviews: (value['n'] as num?)?.toInt() ?? 0,
            );
          } catch (error, stack) {
            ErrorReporter.record(error, stack, reason: 'word_list_entry');
          }
        });
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'word_list_decode');
      }
    }
    return WordListStore._(effective, key, words);
  }

  /// Testlerde tekil örneği sıfırlamak için.
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
    _loading = null;
    _loadingKey = null;
  }

  final LocalDataStorage? _storage;
  final String _key;
  final Map<String, SavedWord> _words;

  /// Bu örneğin yazdığı fiziksel anahtar (kullanıcı kapsamını gösterir).
  String get physicalKey => _key;

  bool contains(String entryId) => _words.containsKey(entryId);

  /// Maddesi sözlükte hâlâ olan kayıtlı kelimeler, en son eklenen başta.
  List<SavedWord> get words {
    final list = [
      for (final word in _words.values)
        if (LearnerLexicon.byId(word.entryId) != null) word,
    ];
    list.sort((a, b) => b.addedAtMs.compareTo(a.addedAtMs));
    return List.unmodifiable(list);
  }

  int get count => words.length;

  SavedWord? wordFor(String entryId) => _words[entryId];

  /// Tekrar zamanı gelmiş kelimeler, en çok gecikenden başlayarak.
  List<SavedWord> dueWords({DateTime? now}) {
    final at = now ?? DateTime.now();
    final due = [
      for (final word in _words.values)
        if (word.isDue(at) && LearnerLexicon.byId(word.entryId) != null) word,
    ];
    due.sort((a, b) {
      final byDue = a.dueAtMs.compareTo(b.dueAtMs);
      return byDue != 0 ? byDue : a.addedAtMs.compareTo(b.addedAtMs);
    });
    return List.unmodifiable(due);
  }

  int dueCount({DateTime? now}) => dueWords(now: now).length;

  /// Bir oturumun kelimeleri: vadesi gelenlerden en çok [sessionCap].
  List<SavedWord> sessionWords({DateTime? now}) =>
      dueWords(now: now).take(sessionCap).toList(growable: false);

  /// Listeye ekler (zaten varsa dokunmaz). Yeni kelime 1. kutuda ve hemen
  /// tekrar edilebilir durumdadır.
  Future<bool> add(String entryId, {DateTime? now}) async {
    if (_words.containsKey(entryId)) return true;
    if (LearnerLexicon.byId(entryId) == null) return false;
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    _words[entryId] = SavedWord(
      entryId: entryId,
      box: 1,
      dueAtMs: at,
      addedAtMs: at,
    );
    notifyListeners();
    return _persist();
  }

  Future<bool> remove(String entryId) async {
    if (_words.remove(entryId) == null) return true;
    notifyListeners();
    return _persist();
  }

  /// Listede varsa çıkarır, yoksa ekler. Yeni durumu (`true` = listede)
  /// döndürür.
  Future<bool> toggle(String entryId, {DateTime? now}) async {
    if (contains(entryId)) {
      await remove(entryId);
      return false;
    }
    await add(entryId, now: now);
    return contains(entryId);
  }

  /// Bir tekrar cevabını işler: doğru -> bir üst kutu, yanlış -> 1. kutu;
  /// sonraki tekrar o kutunun aralığı kadar sonra.
  Future<bool> recordReview(
    String entryId, {
    required bool correct,
    DateTime? now,
  }) async {
    final word = _words[entryId];
    if (word == null) return false;
    final at = now ?? DateTime.now();
    final box = LeitnerSchedule.boxAfter(word.box, correct: correct);
    _words[entryId] = word.copyWith(
      box: box,
      dueAtMs: addCalendarDays(
        at,
        LeitnerSchedule.intervalForBox(box),
      ).millisecondsSinceEpoch,
      reviews: word.reviews + 1,
    );
    notifyListeners();
    return _persist();
  }

  Future<bool> clear() async {
    _words.clear();
    notifyListeners();
    return _persist();
  }

  /// Yazma kuyruğunun SON halkası. Her yazma öncekinin bitmesini bekler:
  /// örtüşen yazmalarda yavaş olan ilk yazma en son bitip diskte eski JSON'u
  /// bırakabiliyordu (kelime/ilerleme kaybı). JSON yazma anında, o ana dek
  /// birikmiş EN GÜNCEL durumdan üretilir.
  Future<bool> _writeChain = Future<bool>.value(true);

  /// Bekleyen yazmaların hepsi bitince tamamlanır; yazma başarısızsa tekrar
  /// denemek için de çağrılır (tekrar oturumunun "yeniden dene" düğmesi).
  Future<bool> persist() => _persist();

  Future<bool> _persist() {
    final next = _writeChain.then((_) => _write());
    _writeChain = next;
    return next;
  }

  Future<bool> _write() async {
    final storage = _storage;
    if (storage == null) return false;
    try {
      final saved = await storage.setString(
        _key,
        jsonEncode({
          for (final word in _words.values) word.entryId: word.toJson(),
        }),
      );
      if (!saved) {
        ErrorReporter.record(
          StateError('Local progress key was not persisted: $_key'),
          StackTrace.current,
          reason: 'word_list_persist',
        );
      }
      return saved;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'word_list_persist');
      return false;
    }
  }
}
