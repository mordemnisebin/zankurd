import 'dart:math';

import '../config/subcategory_config.dart';
import '../models/quiz_level.dart';
import '../models/quiz_question.dart';
import '../services/question_set_policy.dart';
import 'seen_question_store.dart';

/// Bir alt konunun beş seviyesi: havuz zorluğa göre sıralanıp ÇAKIŞMAYAN
/// beş dilime bölünür; yalnız havuz küçükse alıntı (dolgu) eklenir.
///
/// ## Kusur (2026-10-02 denge denetimi)
///
/// Alt konu yolu kategori yolunun seviye bantlarını (1–2, 1–2, 2–3, 3–4,
/// 4–5) alt konunun KENDİ havuzuna uyguluyordu. Görünürlük eşiği
/// (`kMinSubcategoryQuestions` = 20) bütün zorlukları saydığı için bantlar
/// çoğunlukla küçüktü ve iki şey sessizce bozuluyordu:
///
/// * 16 alt konuda Bingeh (2. seviye) Destpêk'in (1.) 10 sorusundan 6–10'unu
///   TEKRAR ediyordu: ikisi de zorluk 1–2 bandından, aynı havuzdan çekiliyordu.
/// * Mamoste (5. seviye) çoğu alt konuda ilgisiz dolgudan ibaretti (15
///   sorunun 9–14'ü); dolgu `general.take(need * 3)` ile KARIŞTIRILMADAN
///   alındığı için her oyuncu hep aynı ilk genel soruları görüyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Her seviye tek tek tam uzunlukta, sızıntısız ve tekrarsızdı; tekrar
/// SEVİYELER ARASINDAydı ve hiçbir test aynı yolun beş seviyesini birlikte
/// görmemişti. Seviyeler ayrı çağrılarda yüklendiği için çakışmayı bir çağrı
/// göremezdi: çözüm, çakışmazlığı çağrılar arasında durum tutmadan, planın
/// KENDİSİNİN saf bir fonksiyon olmasıyla sağlamak.
///
/// ## Kural
///
/// 1. Havuz = kategorideki oynanabilir, bu alt konuya eşleşen sorular;
///    prompt ve çeviri çifti tekilleştirilmiş ([SeenQuestionStore.dedupePool]).
/// 2. Sıralama: zorluk, sonra tanıma sorusu önce / okuma yükü az önce,
///    sonra kararlı kimlik. Bölme sırasıyla yapılır: 1. seviye en kolay
///    beşte biri, 5. seviye en zor beşte biri; hiçbir soru iki dilimde yok.
/// 3. Seviye boyutu = min(normal boyut, max(5, havuz ~/ 5)). Havuz 25 ve
///    üstündeyse dilim her zaman boyutu karşılar: dolgu YOK.
/// 3b. Konu çeşitliliği: bir dilimde aynı kişi/terim hakkında birden çok
///    soru ya da neredeyse aynı metinli iki soru varsa, fazlalık bitişik
///    dilimlerdeki konusu çakışmayan, zorluğu en çok 1 (yoksa 2) farklı bir soruyla
///    TAKAS edilir (bkz. [_spreadSubjects]). Takas dilim boyutlarını ve
///    ayrıklığı korur; uygun takas yoksa dilim olduğu gibi kalır.
/// 4. Havuz 25'ten küçükse eksik, aynı kategoriden dolguyla tamamlanır:
///    önce genel (alt konusu olmayan) sorular, yetmezse başka alt konu;
///    seviyenin zorluk bandında (yetmezse ±1), tohumlu karıştırılmış
///    sırayla ve hiçbir soru iki seviyede kullanılmaz.
class SubcategoryLevelPlan {
  SubcategoryLevelPlan._(this.levels);

  /// Bu sayının altındaki havuzlar dolguyla tamamlanır.
  static const int fillerBelow = 25;

  /// Seviyenin en küçük boyutu (havuz ne kadar küçük olursa olsun).
  static const int minLevelSize = 5;

  final List<PlannedLevel> levels;

  /// [number]. seviye; planda yoksa `null`.
  PlannedLevel? level(int number) {
    for (final level in levels) {
      if (level.number == number) return level;
    }
    return null;
  }

  /// Seviye numarası verilmeyen eski çağrılar için: zorluk bandı AYNI olan
  /// ilk standart seviye (1. ve 2. seviye aynı bandı paylaşır → 1).
  int numberFor(int difficultyMin, int difficultyMax) {
    for (final level in levels) {
      if (level.baseDifficultyMin == difficultyMin &&
          level.baseDifficultyMax == difficultyMax) {
        return level.number;
      }
    }
    return 1;
  }

  /// [standardLevels] kategori yolunun seviye tanımları, [categoryPool] o
  /// kategorideki OYNANABİLİR sorular. [seed] dolgunun karıştırma tohumu:
  /// aynı tohum aynı planı, farklı tohum (yeni oturum) farklı dolguyu verir.
  static SubcategoryLevelPlan build({
    required List<QuizLevel> standardLevels,
    required List<QuizQuestion> categoryPool,
    required String subCategory,
    required int seed,
  }) {
    final matchedRaw = [
      for (final q in categoryPool)
        if (SubcategoryConfig.getSubcategoryId(q) == subCategory) q,
    ];
    final matched = SeenQuestionStore.dedupePool(_byDifficulty(matchedRaw));
    final count = matched.length;
    final levelCount = standardLevels.length;
    final base = count ~/ levelCount;
    final remainder = count % levelCount;

    final bands = <List<QuizQuestion>>[];
    var start = 0;
    for (var i = 0; i < levelCount; i++) {
      final end = start + base + (i < remainder ? 1 : 0);
      bands.add(matched.sublist(start, end));
      start = end;
    }
    _spreadSubjects(bands);

    final sizes = [
      for (final level in standardLevels)
        min(level.questionCount, max(minLevelSize, base)),
    ];

    final fillers = List.generate(levelCount, (_) => <QuizQuestion>[]);
    if (count < fillerBelow) {
      _fill(
        standardLevels: standardLevels,
        categoryPool: categoryPool,
        subCategory: subCategory,
        matched: matched,
        matchedIds: {for (final q in matchedRaw) q.id},
        bands: bands,
        sizes: sizes,
        fillers: fillers,
        seed: seed,
      );
    }

    return SubcategoryLevelPlan._([
      for (var i = 0; i < levelCount; i++)
        PlannedLevel._(
          standard: standardLevels[i],
          band: bands[i],
          fillers: fillers[i],
          size: sizes[i],
        ),
    ]);
  }

  /// Dilimlerdeki konu tekrarlarını komşu dilimlerle soru takasıyla giderir.
  ///
  /// ## Kusur (2026-10-02)
  ///
  /// "Edebiyat › Helbest › 1. Seviye" dokuz sorunun üçünde Cegerxwîn'i
  /// soruyor, ikisi de neredeyse aynı kafiye sorusuydu. Dilim tam boyda
  /// (9 soru, 9 aday) olduğundan tur seçimi (`_selectFresh`) yer değiştirecek
  /// başka aday bulamıyordu: tekrar PLANDA, yani dilimin bileşiminde
  /// doğuyordu, seçimde değil.
  ///
  /// ## Kural
  ///
  /// Her dilimde, kendinden önceki bir soruyla aynı konuyu ([QuestionSetPolicy
  /// .repeatsSubject]) paylaşan soru için, başka bir dilimden çakışmayan ve
  /// zorluğu en çok 1 (yoksa 2) farklı bir soru bulunur; ikisi yer değiştirir. Dilim
  /// boyları değişmez, hiçbir soru iki dilimde olmaz. Karşılık yoksa dilim
  /// bozulmaz (küçük havuzda kural vazgeçer, seviye asla kısalmaz).
  static void _spreadSubjects(List<List<QuizQuestion>> bands) {
    for (var pass = 0; pass < 4; pass++) {
      var swapped = false;
      for (var i = 0; i < bands.length; i++) {
        var k = 1;
        while (k < bands[i].length) {
          final q = bands[i][k];
          if (!QuestionSetPolicy.repeatsAny(q, bands[i].take(k))) {
            k++;
            continue;
          }
          if (_swapOut(bands, i, k)) {
            swapped = true;
            // Yeni gelen soru da denetlenmeli: aynı k'da kal.
          } else {
            k++;
          }
        }
      }
      if (!swapped) break;
    }
  }

  /// `bands[i][k]` için komşu dilimlerden uygun bir karşılık bulup takas eder.
  /// Önce zorluğu en çok 1, bulunamazsa en çok 2 farklı karşılık aranır.
  static bool _swapOut(List<List<QuizQuestion>> bands, int i, int k) {
    for (final tolerance in const [1, 2]) {
      if (_swapOutWithin(bands, i, k, tolerance)) return true;
    }
    return false;
  }

  static bool _swapOutWithin(
    List<List<QuizQuestion>> bands,
    int i,
    int k,
    int tolerance,
  ) {
    final q = bands[i][k];
    final restOfI = [
      for (var n = 0; n < bands[i].length; n++)
        if (n != k) bands[i][n],
    ];
    final order = [
      for (var j = 0; j < bands.length; j++)
        if (j != i) j,
    ]..sort((a, b) => (a - i).abs().compareTo((b - i).abs()));
    for (final j in order) {
      final candidates = [for (var m = 0; m < bands[j].length; m++) m]
        ..sort(
          (a, b) => (bands[j][a].difficulty - q.difficulty).abs().compareTo(
            (bands[j][b].difficulty - q.difficulty).abs(),
          ),
        );
      for (final m in candidates) {
        final r = bands[j][m];
        if ((r.difficulty - q.difficulty).abs() > tolerance) break;
        if (QuestionSetPolicy.repeatsAny(r, restOfI)) continue;
        final restOfJ = [
          for (var n = 0; n < bands[j].length; n++)
            if (n != m) bands[j][n],
        ];
        if (QuestionSetPolicy.repeatsAny(q, restOfJ)) continue;
        bands[i][k] = r;
        bands[j][m] = q;
        return true;
      }
    }
    return false;
  }

  static List<QuizQuestion> _byDifficulty(List<QuizQuestion> questions) {
    int tier(QuizQuestion q) => QuestionSetPolicy.isProductionTask(q) ? 1 : 0;
    return [...questions]..sort((a, b) {
      final byDifficulty = a.difficulty.compareTo(b.difficulty);
      if (byDifficulty != 0) return byDifficulty;
      final byTier = tier(a).compareTo(tier(b));
      if (byTier != 0) return byTier;
      final byLoad = QuestionSetPolicy.readingLoad(
        a,
      ).compareTo(QuestionSetPolicy.readingLoad(b));
      return byLoad != 0 ? byLoad : a.id.compareTo(b.id);
    });
  }

  static void _fill({
    required List<QuizLevel> standardLevels,
    required List<QuizQuestion> categoryPool,
    required String subCategory,
    required List<QuizQuestion> matched,
    required Set<String> matchedIds,
    required List<List<QuizQuestion>> bands,
    required List<int> sizes,
    required List<List<QuizQuestion>> fillers,
    required int seed,
  }) {
    // Adaylar: alt konunun kendi (ham) soruları değil, kategorinin geri
    // kalanı; alt konunun elenmiş kopyası da dolgu olarak geri sızmasın
    // diye tekilleştirme eşleşenlerle BİRLİKTE yapılır.
    final others = [
      for (final q in categoryPool)
        if (!matchedIds.contains(q.id)) q,
    ]..sort((a, b) => a.id.compareTo(b.id));
    final matchedKept = matched.map((q) => q.id).toSet();
    final candidates = [
      for (final q in SeenQuestionStore.dedupePool([...matched, ...others]))
        if (!matchedKept.contains(q.id)) q,
    ];
    final general = [
      for (final q in candidates)
        if (SubcategoryConfig.getSubcategoryId(q).isEmpty) q,
    ];
    final otherSub = [
      for (final q in candidates)
        if (SubcategoryConfig.getSubcategoryId(q).isNotEmpty) q,
    ];

    final used = <String>{};
    for (var i = 0; i < standardLevels.length; i++) {
      var need = sizes[i] - bands[i].length;
      if (need <= 0) continue;
      final level = standardLevels[i];
      final random = Random(_mix(seed, subCategory, level.number));
      for (final source in [general, otherSub]) {
        for (final tolerance in const [0, 1]) {
          if (need <= 0) break;
          final eligible = [
            for (final q in source)
              if (!used.contains(q.id) &&
                  q.difficulty >= level.difficultyMin - tolerance &&
                  q.difficulty <= level.difficultyMax + tolerance)
                q,
          ]..shuffle(random);
          // Konu çeşitliliği: her adımda dilim ve önceki dolguyla çakışmayan
          // ilk aday alınır; hepsi çakışıyorsa ilki (seviye kısalmaz).
          while (need > 0 && eligible.isNotEmpty) {
            final taken = [...bands[i], ...fillers[i]];
            final index = eligible.indexWhere(
              (q) => !QuestionSetPolicy.repeatsAny(q, taken),
            );
            final q = eligible.removeAt(index < 0 ? 0 : index);
            used.add(q.id);
            fillers[i].add(q);
            need--;
          }
        }
      }
    }
  }

  /// Dart'ın `String.hashCode`una (sürüme göre değişebilir) güvenmeyen,
  /// kararlı küçük bir karıştırma.
  static int _mix(int seed, String subCategory, int levelNumber) {
    var hash = seed & 0x7fffffff;
    for (final unit in subCategory.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return (hash * 31 + levelNumber * 7919) & 0x7fffffff;
  }
}

/// Planın tek bir seviyesi.
class PlannedLevel {
  PlannedLevel._({
    required QuizLevel standard,
    required this.band,
    required this.fillers,
    required this.size,
  }) : number = standard.number,
       title = standard.title,
       category = standard.category,
       baseDifficultyMin = standard.difficultyMin,
       baseDifficultyMax = standard.difficultyMax;

  final int number;
  final String title;
  final String category;
  final int baseDifficultyMin;
  final int baseDifficultyMax;

  /// Alt konunun kendi dilimi (bu seviyeye ayrılmış, başka seviyede yok).
  final List<QuizQuestion> band;

  /// Yalnız küçük havuzda: aynı kategoriden, başka seviyede kullanılmayan
  /// tamamlayıcı sorular.
  final List<QuizQuestion> fillers;

  /// Seviyenin vaat ettiği soru sayısı.
  final int size;

  /// Bu seviyeden seçilebilecek bütün sorular (dilim + dolgu).
  List<QuizQuestion> get candidates => [...band, ...fillers];

  /// Seviyenin kartta gösterilecek hâli: gerçek boyut ve gerçek zorluk
  /// aralığı ("10 soru" sabiti değil). Dilim boş ve dolgu yoksa standart
  /// bant korunur.
  QuizLevel toQuizLevel() {
    final all = candidates;
    var minDifficulty = baseDifficultyMin;
    var maxDifficulty = baseDifficultyMax;
    if (all.isNotEmpty) {
      minDifficulty = all.map((q) => q.difficulty).reduce(min);
      maxDifficulty = all.map((q) => q.difficulty).reduce(max);
    }
    return QuizLevel(
      number: number,
      title: title,
      category: category,
      difficultyMin: minDifficulty,
      difficultyMax: maxDifficulty,
      questionCount: min(size, all.length),
    );
  }
}
