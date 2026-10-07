import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/async_duel.dart';
import '../models/avatar_identity.dart';
import '../models/contest.dart';
import '../models/friend.dart';
import '../models/lesson.dart';
import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/player.dart';
import '../models/quiz_level.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../game/speed_score.dart';
import '../models/room_message.dart';
import '../utils/error_reporter.dart';
import '../models/tournament.dart';
import '../models/referral_result.dart';
import '../utils/coin_calculator.dart';
import 'curated_question_bank.dart';
import 'learning_assessment_bank.dart';
import 'learning_lesson_aliases.dart';
import 'question_bank_loader.dart';
import 'seen_question_store.dart';
import 'subcategory_level_plan.dart';
import 'durable_write.dart';
import 'zankurd_repository.dart';
import '../config/category_visibility.dart';
import '../services/question_set_policy.dart';
import '../services/question_content_policy.dart';

/// [MockZanKurdRepository.addPendingAsyncDuelForTesting] ile kurulan, henüz
/// kimse tarafından alınmamış "açık" düello.
///
/// Gerçek üründe bekleyen taraf başka bir kullanıcının cihazıdır. Tek
/// kullanıcılı sahte depoda gerçek bir ikinci oyuncu yok; bu kayıt testin
/// önceden "oynanmış" saydığı rakip tarafı temsil eder — sonraki
/// `startAsyncDuel` çağrısı bunu tüketir ve çağıranı `opponent` yapar.
class _MockPendingAsyncDuel {
  _MockPendingAsyncDuel({
    required this.category,
    required this.opponentName,
    required this.questions,
    required this.opponentCorrect,
    required this.opponentMs,
  });

  final String? category;
  final String opponentName;
  final List<QuizQuestion> questions;
  final int opponentCorrect;
  final int opponentMs;
}

/// Tek bir sırayla düellonun bellek içi durumu.
///
/// Sahte depo tek bir yerel oyuncuyu temsil eder; sunucudaki simetrik
/// creator/opponent satırları yerine yalnız "ben" (bu düelloda benim
/// oynadığım taraf, [myCorrect]/[myMs]) ve "öteki" (rakip, [otherCorrect]/
/// [otherMs]) tutulur. [questions] GERÇEK doğru cevaplarla tutulur ve asla
/// dışarı verilmez — [hiddenQuestions] her zaman gizli kopyayı döner.
class _MockAsyncDuel {
  _MockAsyncDuel({
    required this.id,
    required this.role,
    required this.category,
    required this.questions,
    required this.opponentName,
    required this.createdAt,
    required this.expiresAt,
    this.otherCorrect,
    this.otherMs,
  });

  final String id;
  final AsyncDuelRole role;
  final String? category;
  final List<QuizQuestion> questions;
  final String? opponentName;
  final DateTime createdAt;
  final DateTime expiresAt;

  final Set<int> answeredIndices = {};
  int myCorrect = 0;
  int myMs = 0;

  /// Rakip bitirmeden `null`dır. `role == opponent` olan düellolarda testin
  /// önceden kurduğu (`addPendingAsyncDuelForTesting`) değerle, oluşumda
  /// hemen dolu gelir — bu yüzden opponent akışı ilk sorudan itibaren
  /// "eşleşmiş", son cevapta "tamamlanmış" görünür.
  int? otherCorrect;
  int? otherMs;

  DateTime? completedAt;
  bool seen = false;
  bool xpAwarded = false;

  bool get myFinished => answeredIndices.length >= questions.length;
  bool get otherFinished => otherCorrect != null && otherMs != null;

  AsyncDuelStatus get status {
    if (myFinished && otherFinished) return AsyncDuelStatus.completed;
    if (DateTime.now().toUtc().isAfter(expiresAt)) {
      return AsyncDuelStatus.expired;
    }
    if (otherFinished) return AsyncDuelStatus.matched;
    return AsyncDuelStatus.open;
  }

  List<QuizQuestion> get hiddenQuestions =>
      questions.map((q) => q.copyWith(correctAnswer: '')).toList();

  /// Son soru cevaplandığında `answerAsyncDuel`ın gömdüğü karşılaştırma.
  AsyncDuelResult buildResult() {
    final correctOther = otherCorrect;
    final msOther = otherMs;
    if (correctOther == null || msOther == null) {
      return AsyncDuelResult(waiting: true, myCorrect: myCorrect, myMs: myMs);
    }
    return AsyncDuelResult(
      waiting: false,
      myCorrect: myCorrect,
      myMs: myMs,
      opponentCorrect: correctOther,
      opponentMs: msOther,
      outcome: _asyncDuelOutcome(
        myCorrect: myCorrect,
        myMs: myMs,
        otherCorrect: correctOther,
        otherMs: msOther,
      ),
    );
  }
}

/// Sırayla düello kazananı: sunucu kuralıyla birebir aynı (bkz.
/// `sirayla_duello_tasarim.md` § KESİN SÖZLEŞME) — çok doğru kazanır,
/// eşitlikte toplam süresi kısa olan, o da eşitse berabere.
AsyncDuelOutcome _asyncDuelOutcome({
  required int myCorrect,
  required int myMs,
  required int otherCorrect,
  required int otherMs,
}) {
  if (myCorrect != otherCorrect) {
    return myCorrect > otherCorrect
        ? AsyncDuelOutcome.win
        : AsyncDuelOutcome.loss;
  }
  if (myMs != otherMs) {
    return myMs < otherMs ? AsyncDuelOutcome.win : AsyncDuelOutcome.loss;
  }
  return AsyncDuelOutcome.draw;
}

class MockZanKurdRepository implements ZanKurdRepository {
  /// [levelSeed] alt konu seviyelerinin dolgu karıştırma tohumudur; verilmezse
  /// her depo (= her oturum) kendi rastgele tohumunu alır: dolgu oturum
  /// içinde kararlı, oturumlar arasında farklıdır. Testler sabit verir.
  MockZanKurdRepository({int? levelSeed})
    : _levelSeed = levelSeed ?? Random().nextInt(0x7fffffff);

  final int _levelSeed;

  /// Alt konu planları (kategori|alt konu → plan). Plan, soru listesi
  /// değişmedikçe aynıdır; `build` her çizimde çağrıldığı için ağır planı
  /// yeniden kurmamak gerekir. Kaynak liste özdeş değilse (testler her
  /// çağrıda yeni liste döndürür) önbellek atılır.
  Object? _plansSource;
  final Map<String, SubcategoryLevelPlan> _plans = {};

  SubcategoryLevelPlan _subcategoryPlan(String category, String subCategory) {
    final source = questions;
    if (!identical(source, _plansSource)) {
      _plans.clear();
      _plansSource = source;
    }
    return _plans.putIfAbsent(
      '$category|$subCategory',
      () => SubcategoryLevelPlan.build(
        standardLevels: levelsForCategory(category),
        categoryPool: [
          for (final q in _playableQuestions)
            if (q.category == category) q,
        ],
        subCategory: subCategory,
        seed: _levelSeed,
      ),
    );
  }

  /// "Bu kategorinin tamamı" satırı ([SubcategoryScreen] alt konusu
  /// kalmayan kategoriler için gösterir); gerçek bir alt konu değildir,
  /// kategori yolunu kullanır.
  static const _wholeCategoryId = 'gisti';

  static bool _isRealSubcategory(String? subCategory) =>
      subCategory != null &&
      subCategory.isNotEmpty &&
      subCategory != _wholeCategoryId;

  static const _contentPolicy = QuestionContentPolicy();

  /// Oynanabilir havuz, kaynak liste DEĞİŞMEDİKÇE bir kez hesaplanır.
  ///
  /// Eskiden getter her çağrıda ~3.000 soruyu `isPlayable`den geçirip yeni
  /// bir liste kuruyordu (ölçüm: JIT'te ~2 ms/çağrı). Çağıranlar yalnız
  /// olay işleyicileri değil: `SubcategoryScreen.build` her yeniden çizimde
  /// çağırıyordu. Kusur sessizdi — sonuç doğruydu, yalnız her çağrı aynı işi
  /// baştan yapıyordu.
  ///
  /// Anahtar kaynak listenin KİMLİĞİDİR (`identical`): yükleyici
  /// `_questions`ı yeni bir liste ile değiştirdiğinde (`load`,
  /// `setQuestionsForTest`) ya da bir test `questions`ı geçersiz kıldığında
  /// kimlik değişir ve önbellek kendiliğinden düşer. `isPlayable` saftır
  /// (sabit gizli-kategori kümesi, sabit emekli kimlik kümesi, değişmez
  /// soru) — aynı liste aynı sonucu verir.
  List<QuizQuestion>? _playableCache;
  List<QuizQuestion>? _playableCacheSource;

  List<QuizQuestion> get _playableQuestions {
    final source = questions;
    final cached = _playableCache;
    if (cached != null && identical(_playableCacheSource, source)) {
      return cached;
    }
    final playable = List<QuizQuestion>.unmodifiable(
      source.where(_contentPolicy.isPlayable),
    );
    _playableCache = playable;
    _playableCacheSource = source;
    return playable;
  }

  static const _allCategories = <String>[
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
    'Siyaset',
    'Paradigma',
    // Topluluk katkısı soru setiyle açılan yeni kategori: Kürt sineması.
    'Sînema',
    // 2026-07-26: içeriği hazırlanınca açıldı (12 → 40 soru). Ürünün amacı
    // yalnız Kürtçe değil genel dünya bilgisi de olduğu için kategori
    // kapatılmak yerine dolduruldu; sorular kavramla birlikte kavramın
    // Kurmancî karşılığını da öğretiyor.
    'Teknolojî',
    // 2026-09-30: Kürt kategorilerinden SONRA gelir. Kürtlerle bağı olmayan
    // nötr genel bilgi (dünya sineması/coğrafyası/tarih) kendi adıyla ayrı
    // durur; ürünün ~%70'i Kürt içeriği, ~%30'u bu tür genel bilgidir.
    'Cîhan',
  ];

  @override
  List<String> get categories => visibleCategories(_allCategories);

  @override
  List<QuizQuestion> get questions {
    // Üretimde QuestionBankLoader JSON assetleri yükler.
    // Test ortamında loader henüz çağrılmadığından curatedQuestionBank ile
    // çalışır; soru sayısına bağlı testler doğrudan fixture kullanıyor.
    if (QuestionBankLoader.instance.isLoaded) {
      return QuestionBankLoader.instance.allQuestions;
    }
    return curatedQuestionBank;
  }

  @override
  List<QuizQuestion> get playableQuestions => _playableQuestions;

  @override
  String? get currentUserId => 'user';

  @override
  bool get usesServerHiddenAnswers => false;

  String _mockName = 'ZanKurd Oyuncusu';

  // Mağaza kataloğunun toplamı ~4.800 coin. 2.450 ile açılan bir demo
  // oturumu daha ilk saniyede kataloğun yarısını satın alabiliyor ve coin
  // kazanma döngüsü hiç denenmeden anlamsızlaşıyordu (2026-07-25 canlı
  // denetimi). Üretimde bakiye sunucudan gelir; burası yalnız demo/mock
  // başlangıcıdır ve yeni bir oyuncuya benzemesi gerekir.
  int _mockCoins = 0;
  int _mockExtraSpins = 0;
  int _mockUsedExtraSpins = 0;
  final Set<String> _mockPurchases = {};

  /// Solo tavanı gün bazında tutulur; gün dönünce sıfırlanır.
  DateTime? _mockSoloDay;
  int _mockSoloEarnedToday = 0;

  @override
  Future<void> ensureProfile() async {}

  @override
  Future<String?> getPlayerTag() async {
    // 2026-09-29 doğallık (K10): burada sabit 'DEMO' dönüyordu ve arkadaş
    // ekranı onu paylaşılabilir bir davet kodu düğmesi olarak ("DEMO")
    // çiziyordu; profil de "ZK-DEMO" yazıyordu. Kimsenin kullanamayacağı
    // bir kod, gerçek bir kod gibi sunuluyordu. Sunucu kimliği olmayan
    // depo kod üretmez (`OfflineZanKurdRepository` gibi): düğme görünmez,
    // "Davet kodu gir" kalır. Kodun nasıl göründüğünü ekran turu kendi
    // hikâyesiyle gösterir (`tool/screenshots/screen_tour_test.dart`).
    return null;
  }

  @override
  Future<String> getProfileName() async => _mockName;

  @override
  Future<void> updateProfileName(String name) async {
    _mockName = name;
  }

  @override
  Future<void> deleteMyAccount() async {
    _mockName = 'ZanKurd Oyuncusu';
    _mockCoins = 0;
  }

  @override
  Future<LeaderboardEntry?> getPlayerStats() async {
    // "Benim istatistiğim" olarak tablonun **birincisi** döndürülüyordu:
    // çevrimdışı açan yeni bir oyuncu, sıralamanın altına sabitlenen kendi
    // satırında "ZanKurd Champion · 1. · 5000 puan · 50 oda · 25 seri"
    // görüyordu — aynı ekranda profili "Ast 1 · 0/1000 XP" derken
    // (2026-07-27, simülatörde görüldü).
    //
    // Profil ekranı bu kusuru 2026-07-25'te kendi içinde bir kapıyla
    // (`_hasServerScore`) örtmüştü; sıralamada öyle bir kapı yoktu ve yalan
    // olduğu gibi göründü. Kaynağı düzeltmek iki ekranı da düzeltir: hiç
    // oynamamış oyuncunun sunucu satırı yoktur.
    return null;
  }

  @override
  Future<LeaderboardEntry?> getMyLeaderboardRank(
    LeaderboardPeriod period,
  ) async {
    // Sahte depoda biten çevrimiçi oda yok; `loadLeaderboard` de boş
    // liste verdiği için dönemin sıralamasında satır yoktur. Sabit satır
    // ancak gerçekten dönem puanı geldiğinde çizilir (2026-09-30).
    return null;
  }

  @override
  Future<List<String>> loadCategories() async => categories;

  @override
  Future<List<String>> loadMatchmakingCategories() => loadCategories();

  @override
  Future<Map<String, int>> loadCategoryQuestionCounts() async {
    final counts = <String, int>{};
    for (final question in _playableQuestions) {
      counts[question.category] = (counts[question.category] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<List<QuizQuestion>> loadQuestions({
    String? categoryId,
    int limit = 10,
  }) async {
    final playable = _playableQuestions;
    final pool = categoryId == null
        ? playable
        : playable
              .where((question) => question.category == categoryId)
              .toList(growable: false);
    return _selectFresh(pool.isEmpty ? playable : pool, limit);
  }

  @override
  List<QuizLevel> levelsForCategory(String category, {String? subCategory}) {
    if (_isRealSubcategory(subCategory)) {
      // Alt konu yolu: kart GERÇEK boyutu ve zorluk aralığını gösterir
      // (bkz. [SubcategoryLevelPlan]).
      return [
        for (final level in _subcategoryPlan(category, subCategory!).levels)
          level.toQuizLevel(),
      ];
    }
    return [
      QuizLevel(
        number: 1,
        title: 'Destpêk',
        category: category,
        // 2026-07-05: canlı zorluk=1 havuzu (Ziman 90, Çand 27, Müzik 16,
        // Coğrafya 15, Dîrok 10, Edebiyat 9) düzeltme+içerik senkronuyla
        // büyütüldü, ama Edebiyat gibi bazı kategoriler tam 10'a çok az
        // farkla yaklaşıyor. Zorluk 2'yi de kapsamak güvenli bir pay
        // bırakıyor; Siyaset/Paradigma zaten kasıtlı olarak "az kolay
        // soru" tasarımıyla düşük kalıyor (bkz. question_bank_test.dart
        // isMature eşiği).
        difficultyMin: 1,
        difficultyMax: 2,
        questionCount: 10,
      ),
      QuizLevel(
        number: 2,
        title: 'Bingeh',
        category: category,
        difficultyMin: 1,
        difficultyMax: 2,
        questionCount: 10,
      ),
      QuizLevel(
        number: 3,
        title: 'Navîn',
        category: category,
        difficultyMin: 2,
        difficultyMax: 3,
        questionCount: 12,
      ),
      QuizLevel(
        number: 4,
        title: 'Pêşketî',
        category: category,
        difficultyMin: 3,
        difficultyMax: 4,
        questionCount: 12,
      ),
      QuizLevel(
        number: 5,
        title: 'Mamoste',
        category: category,
        difficultyMin: 4,
        difficultyMax: 5,
        questionCount: 15,
      ),
    ];
  }

  @override
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    String? subCategory,
    int? levelNumber,
    int limit = 10,
  }) async {
    if (_isRealSubcategory(subCategory)) {
      // Alt konu yolu zorluk BANDIYLA değil, havuzun zorluğa göre
      // bölünmüş çakışmasız DİLİMİYLE çalışır (bkz. [SubcategoryLevelPlan]);
      // bu yüzden hangi seviye olduğu bilinmelidir. Seviye numarası
      // verilmeyen eski çağrılar bandından çıkarılır.
      final plan = _subcategoryPlan(category, subCategory!);
      final planned = plan.level(
        levelNumber ?? plan.numberFor(difficultyMin, difficultyMax),
      );
      // Plan bu alt konu için en az bir soru kuruyorsa SON SÖZÜ o söyler:
      // boş kalan bir seviye kategori havuzuna düşmez (eskiden `pool.isEmpty
      // ? playable` her şeyi geri getiriyor, seviyeler arası tekrarı ve
      // konu dışı soruyu sessizce geri sokuyordu). Alt konunun hiç sorusu
      // yoksa (bilinmeyen kimlik) kategori yoluna düşülür.
      final hasQuestions = plan.levels.any(
        (level) => level.candidates.isNotEmpty,
      );
      if (hasQuestions) {
        return _selectFresh(planned?.candidates ?? const [], limit);
      }
    }

    final playable = _playableQuestions;
    final pool = playable
        .where(
          (question) =>
              question.category == category &&
              question.difficulty >= difficultyMin &&
              question.difficulty <= difficultyMax,
        )
        .toList();

    // İlk iki basamak (Destpêk / Bingeh) bir öğrenme yolunun girişidir:
    // bankadaki `difficulty` etiketi konu zorluğunu anlatır ama okuma
    // yükünü yansıtmaz — ölçümde zorluk 1'in şık uzunluğu medyanı tüm
    // seviyelerin en yükseğiydi (2026-07-25). Havuz, aynı zorluk bandı
    // içinde en hafif okunan sorular öne gelecek biçimde sıralanır.
    final ordered = difficultyMax <= 2
        ? QuestionSetPolicy.byReadingLoad(pool.isEmpty ? playable : pool)
        : (pool.isEmpty ? playable : pool);
    final selected = await _selectFresh(ordered, limit);
    // `byReadingLoad` üretim sorularını (boşluk doldurma, cümle kurma) bilerek
    // sona iter; tanıma sorusu havuzu turu doldurduğu için yeni başlayan hiç
    // yazmalı/sıralamalı soru GÖRMÜYORDU (2026-10-06, başlangıç yolu geri
    // bildirimi). İlk iki basamakta derse bağlı bir cümle kurma (ve 10
    // soruluk turda bir boşluk doldurma) üçüncü sıradan sonra eklenir.
    return difficultyMax <= 2
        ? _withBeginnerProduction(selected, pool, limit, Random())
        : selected;
  }

  @override
  Future<List<QuizQuestion>> loadLearningQuizQuestions({
    required String category,
    required String learningLessonId,
    int limit = 5,
  }) async {
    // Sunucu dersi slug'ı (`silav-u-nasin`) bir ya da birkaç yerel ders
    // kimliğine açılır; yerel kimlik kendisidir (bkz. LearningLessonAliases).
    final bankIds = LearningLessonAliases.bankIdsFor(learningLessonId);
    final exact = _playableQuestions
        .where(
          (question) =>
              question.category == category &&
              bankIds.contains(question.metadata?.learningLessonId),
        )
        .toList(growable: false);

    // Açık ders etiketli sorular önce gelir; eksik kalan yer yalnız aynı
    // dersin yerel, editoryal sözlük çiftlerinden üretilen ölçme sorularıyla
    // doldurulur. Geniş kategori havuzu fallback değildir: mini-quiz dersle
    // ilgisiz genel kategori sorularını "ders sorusu" gibi gösterebiliyordu.
    //
    // 2026-09-30: etiketli soru varken dolgu yapılmıyordu; bir etiketli
    // sorusu olan ders (grammar_1, animals_2) tek soruluk bir quiz
    // açıyordu, yani bir derse soru etiketlemek o dersi KISALTIYORDU.
    var tagged = exact.isEmpty
        ? const <QuizQuestion>[]
        : await _selectLessonMix(exact, limit);
    // Aynı cümle/terimi sordurmayan tur: tekrar eden soru, aynı türden (yoksa
    // herhangi) tekrarsız bir etiketli soruyla yerinde değiştirilir.
    tagged = await _replaceSameTarget(tagged, exact);
    if (tagged.length >= limit) return tagged;
    final taggedIds = tagged.map((q) => q.id).toSet();
    // Birden çok bankalı ders (Selamlaşma ve Tanışma) için dolgu sırayla
    // karıştırılır; yoksa ilk bankanın beş sorusu ikincisini hiç göstermezdi.
    final perBank = [
      for (final bankId in bankIds)
        LearningAssessmentBank.questionsFor(
          lessonId: bankId,
          category: category,
          limit: limit,
        ),
    ];
    final fillers = <QuizQuestion>[
      for (var i = 0; i < limit; i++)
        for (final bank in perBank)
          if (i < bank.length) bank[i],
    ].where((q) => !taggedIds.contains(q.id));
    return _dropSameTarget([...tagged, ...fillers], limit);
  }

  /// [chosen] içinde aynı cümle/terimi sordurandan yalnız ilkini tutar; atılan
  /// her soru [pool]'dan, kalanlarla hedefi çakışmayan ve seçilmemiş bir
  /// soruyla (önce aynı tür) AYNI SIRAYA konur. Çakışmayan aday yoksa soru
  /// yerinde kalır: kural tercihtir, turu kısaltmaz.
  Future<List<QuizQuestion>> _replaceSameTarget(
    List<QuizQuestion> chosen,
    List<QuizQuestion> pool,
  ) async {
    final result = [...chosen];
    for (var i = 0; i < result.length; i++) {
      final others = [
        for (var j = 0; j < result.length; j++)
          if (j != i) result[j],
      ];
      // Yalnız ÖNCEKİ sorularla çakışan atılır (ilki kalır).
      final earlier = others.take(i).toList(growable: false);
      if (!earlier.any(
        (q) => QuestionSetPolicy.sharesTargetText(q, result[i]),
      )) {
        continue;
      }
      final used = result.map((q) => q.id).toSet();
      final candidates = pool
          .where(
            (c) =>
                !used.contains(c.id) &&
                !result.any((q) => QuestionSetPolicy.sharesTargetText(q, c)),
          )
          .toList(growable: false);
      if (candidates.isEmpty) continue;
      final sameType = candidates
          .where((c) => c.type == result[i].type)
          .toList(growable: false);
      final pick = await _selectFresh(
        sameType.isEmpty ? candidates : sameType,
        1,
      );
      if (pick.isNotEmpty) result[i] = pick.first;
    }
    return result;
  }

  /// Aynı cümle/terimi sordurandan yalnız ilkini tutar; tur eksik kalırsa
  /// atılanlar sırayla geri eklenir (kural tercihtir, turu kısaltmaz).
  List<QuizQuestion> _dropSameTarget(List<QuizQuestion> ordered, int limit) {
    final kept = <QuizQuestion>[];
    final dropped = <QuizQuestion>[];
    for (final q in ordered) {
      if (kept.any((k) => QuestionSetPolicy.sharesTargetText(k, q))) {
        dropped.add(q);
      } else {
        kept.add(q);
      }
    }
    return [...kept, ...dropped].take(limit).toList(growable: false);
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    final playable = _playableQuestions;
    final pool = playable
        .where((question) => question.category == room.category)
        .toList(growable: false);
    return _selectFresh(pool.isEmpty ? playable : pool, room.questionCount);
  }

  // ─── Sırayla düello (async 1v1) ──────────────────────────────────────
  //
  // Bellek içi tam bir uygulama: gerçek bir ikinci oyuncu yok, ama sözleşme
  // (bkz. `lib/src/models/async_duel.dart`) sunucudakiyle aynı davranır.
  // Normal akışta her `startAsyncDuel` çağrısı yeni bir düello açar (creator)
  // — sahte depo kendi kendini rakip yapmaz. Bir "opponent" akışını
  // sınamak için test önce [addPendingAsyncDuelForTesting] ile bekleyen bir
  // düello kurar; bir SONRAKİ `startAsyncDuel` bunu tüketir.

  static const _asyncDuelQuestionCount = 7;
  static const _asyncDuelDuration = Duration(hours: 48);

  int _asyncDuelSeq = 0;
  final Map<String, _MockAsyncDuel> _asyncDuels = {};
  final List<_MockPendingAsyncDuel> _pendingAsyncDuels = [];

  String? _normalizedAsyncDuelCategory(String? category) {
    final trimmed = category?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// 7 oynanabilir soru seçer: `option_a`..`d` şık anahtarına dökülemeyen
  /// türler (cümle kurma, boşluk doldurma) elenir — `QuestionContentPolicy`
  /// hileyi gizli-cevap yoluna aynı gerekçeyle kapatır (bkz.
  /// `isPlayableWithHiddenAnswer`, oda RPC'sinin uyguladığı süzgeç).
  List<QuizQuestion> _pickAsyncDuelQuestions(String? category) {
    final playable = _playableQuestions;
    final byCategory = category == null
        ? playable
        : playable
              .where((question) => question.category == category)
              .toList(growable: false);
    final pool = byCategory.isEmpty ? playable : byCategory;
    final shuffled = [...pool]..shuffle(Random());

    final picked = <QuizQuestion>[];
    final chosenIds = <String>{};
    for (final question in shuffled) {
      if (picked.length >= _asyncDuelQuestionCount) break;
      if (!chosenIds.add(question.id)) continue;
      final hiddenPreview = question.copyWith(correctAnswer: '');
      if (_contentPolicy.isPlayableWithHiddenAnswer(hiddenPreview)) {
        picked.add(question);
      }
    }
    // Sunucu tarafı `No questions` diye fırlatır (bkz. sözleşme); yerel
    // banka yeterli soru sunmuyorsa aynı hatayla düşer — sahte bir kısa
    // tur uydurmak (7 yerine 3 soru) sonucu sessizce bozardı.
    if (picked.length < _asyncDuelQuestionCount) {
      throw StateError('No questions');
    }
    return picked;
  }

  int _clampAsyncDuelResponseMs(int responseMs) {
    if (responseMs < 0) return 0;
    if (responseMs > 120000) return 120000;
    return responseMs;
  }

  @override
  Future<AsyncDuelStart> startAsyncDuel({String? category}) async {
    final normalizedCategory = _normalizedAsyncDuelCategory(category);
    final pendingIndex = _pendingAsyncDuels.indexWhere(
      (pending) =>
          normalizedCategory == null ||
          pending.category == null ||
          pending.category == normalizedCategory,
    );

    final now = DateTime.now().toUtc();
    final id = 'mock_async_duel_${++_asyncDuelSeq}';

    if (pendingIndex != -1) {
      final pending = _pendingAsyncDuels.removeAt(pendingIndex);
      final duel = _MockAsyncDuel(
        id: id,
        role: AsyncDuelRole.opponent,
        category: pending.category,
        questions: pending.questions,
        opponentName: pending.opponentName,
        createdAt: now,
        expiresAt: now.add(_asyncDuelDuration),
        otherCorrect: pending.opponentCorrect,
        otherMs: pending.opponentMs,
      );
      _asyncDuels[id] = duel;
      return AsyncDuelStart(
        duelId: id,
        role: AsyncDuelRole.opponent,
        opponentName: pending.opponentName,
        expiresAt: duel.expiresAt,
        questions: duel.hiddenQuestions,
      );
    }

    final questions = _pickAsyncDuelQuestions(normalizedCategory);
    final duel = _MockAsyncDuel(
      id: id,
      role: AsyncDuelRole.creator,
      category: normalizedCategory,
      questions: questions,
      opponentName: null,
      createdAt: now,
      expiresAt: now.add(_asyncDuelDuration),
    );
    _asyncDuels[id] = duel;
    return AsyncDuelStart(
      duelId: id,
      role: AsyncDuelRole.creator,
      expiresAt: duel.expiresAt,
      questions: duel.hiddenQuestions,
    );
  }

  @override
  Future<AsyncDuelAnswer> answerAsyncDuel({
    required String duelId,
    required int questionIndex,
    required String choice,
    required int responseMs,
  }) async {
    final duel = _asyncDuels[duelId];
    if (duel == null) throw StateError('Duel not found');
    if (DateTime.now().toUtc().isAfter(duel.expiresAt)) {
      throw StateError('Duel expired');
    }
    if (questionIndex < 0 || questionIndex >= duel.questions.length) {
      throw StateError('Invalid index');
    }
    // 'TIMEOUT': süre dolunca istemcinin gönderdiği anahtar. Sunucu onu
    // geçerli ama YANLIŞ bir cevap sayar — soru kilitlenir, süre toplama
    // eklenir. Reddedilseydi süresi dolan oyuncu o soruda takılı kalırdı.
    const validChoices = {'A', 'B', 'C', 'D', 'TIMEOUT'};
    if (!validChoices.contains(choice)) {
      throw StateError('Invalid choice');
    }
    // İlk cevap kilitlenir — sunucudaki `(duel_id, player_id, question_index)`
    // birincil anahtarıyla aynı davranış: aynı soru ikinci kez oynanamaz.
    if (duel.answeredIndices.contains(questionIndex)) {
      throw StateError('Already answered');
    }

    final question = duel.questions[questionIndex];
    const letters = ['A', 'B', 'C', 'D'];
    final correctIndex = question.answers.indexOf(question.correctAnswer);
    final correctOption = (correctIndex >= 0 && correctIndex < letters.length)
        ? letters[correctIndex]
        : 'A';
    final isCorrect = choice == correctOption;

    duel.answeredIndices.add(questionIndex);
    if (isCorrect) duel.myCorrect++;
    duel.myMs += _clampAsyncDuelResponseMs(responseMs);

    final answered = duel.answeredIndices.length;
    final total = duel.questions.length;
    final finished = answered == total;
    if (finished && duel.otherFinished) {
      duel.completedAt = DateTime.now().toUtc();
    }

    return AsyncDuelAnswer(
      correct: isCorrect,
      correctOption: correctOption,
      answered: answered,
      total: total,
      finished: finished,
      result: finished ? duel.buildResult() : null,
    );
  }

  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() async {
    final entries = _asyncDuels.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final duel in entries)
        AsyncDuelSummary(
          duelId: duel.id,
          status: duel.status,
          role: duel.role,
          opponentName: duel.opponentName,
          categoryName: duel.category,
          myCorrect: duel.myFinished ? duel.myCorrect : null,
          opponentCorrect: duel.otherCorrect,
          outcome: (duel.myFinished && duel.otherFinished)
              ? _asyncDuelOutcome(
                  myCorrect: duel.myCorrect,
                  myMs: duel.myMs,
                  otherCorrect: duel.otherCorrect!,
                  otherMs: duel.otherMs!,
                )
              : null,
          createdAt: duel.createdAt,
          completedAt: duel.completedAt,
          seen: duel.seen,
        ),
    ];
  }

  @override
  Future<void> markAsyncDuelSeen(String duelId) async {
    _asyncDuels[duelId]?.seen = true;
  }

  @override
  Future<int> claimAsyncDuelXp(String duelId) async {
    final duel = _asyncDuels[duelId];
    if (duel == null) throw StateError('Duel not found');
    // Sunucuda sonuç satırı yalnız 7 soruyu bitirene yazılır; süresi dolmuş
    // bir düelloda bile turunu bitirmeyen oyuncuya XP yazılmaz.
    if (!duel.myFinished) throw StateError('Duel not finished');
    final status = duel.status;
    if (status != AsyncDuelStatus.completed &&
        status != AsyncDuelStatus.expired) {
      throw StateError('Duel not finished');
    }
    if (duel.xpAwarded) return awardedXpTotal;

    final otherCorrect = duel.otherCorrect;
    final otherMs = duel.otherMs;
    final outcome = (otherCorrect != null && otherMs != null)
        ? _asyncDuelOutcome(
            myCorrect: duel.myCorrect,
            myMs: duel.myMs,
            otherCorrect: otherCorrect,
            otherMs: otherMs,
          )
        : null;
    // Doğru başına 20 XP + galibiyet 30 XP (bkz. sözleşme). Rakip hiç
    // çıkmadan süresi dolan düelloda `outcome` `null` kalır — galibiyet
    // bonusu YOKTUR, yalnız kendi doğruların sayılır.
    final amount =
        duel.myCorrect * 20 + (outcome == AsyncDuelOutcome.win ? 30 : 0);
    duel.xpAwarded = true;
    return awardXp(amount);
  }

  /// Testin, sanki başka biri düello açıp yedi soruyu bitirmiş gibi bir
  /// "açık düello" kurmasını sağlar. Bunu tüketen sonraki `startAsyncDuel`
  /// çağrısı `opponent` rolüyle döner ve anında karşılaştırma yapılabilir
  /// hâle gelir — gerçek üründe bu, başka bir kullanıcının cihazında daha
  /// önce oynanmış bir düellodur.
  @visibleForTesting
  void addPendingAsyncDuelForTesting({
    String? category,
    String opponentName = 'Heval',
    required int opponentCorrect,
    required int opponentMs,
  }) {
    final normalizedCategory = _normalizedAsyncDuelCategory(category);
    _pendingAsyncDuels.add(
      _MockPendingAsyncDuel(
        category: normalizedCategory,
        opponentName: opponentName,
        questions: _pickAsyncDuelQuestions(normalizedCategory),
        opponentCorrect: opponentCorrect,
        opponentMs: opponentMs,
      ),
    );
  }

  /// Gün bazlı sabit tohum: aynı gün herkes aynı sırayı görür.
  static int dailySeed() {
    final now = DateTime.now().toUtc();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  /// Gün tohumunu kullanıcıya özg varyasyonla birleştirir: aynı kullanıcı
  /// aynı gün aynı soru setini görür ama farklı kullanıcılar (ve tekrar
  /// koşuları farklı günlerde) farklı sıralar alır. Yalnızca seçim
  /// sırasını etkiler; veri kaynağına dokunmaz (2026-07-19 denetim P1:
  /// aynı gün iki koşuda Q1 aynı soruydu).
  static int dailySeedFor(String? userId) {
    final base = dailySeed();
    if (userId == null || userId.isEmpty) return base;
    var hash = 0;
    for (final unit in userId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return base ^ hash;
  }

  @override
  Future<List<QuizQuestion>> loadDailyQuestions({int limit = 10}) async {
    final playable = _playableQuestions;
    final seed = dailySeedFor(currentUserId);
    final pool = [...playable]..shuffle(Random(seed));
    final daily = _withVisualBlend(pool.take(limit).toList(), playable, limit);
    // Günlük ders rastgele havuzdan çekilir; üretim soruları bankanın ~%3'ü
    // olduğundan yeni başlayan günlük derste hiç cümle kurma görmeyebilirdi.
    return _withBeginnerProduction(daily, playable, limit, Random(seed));
  }

  /// Dersin kısa testi: etiketli tanıma sorularının arasına, dersin etiketli
  /// cümle kurma ve boşluk doldurma soruları da girer.
  ///
  /// ## Kusur
  ///
  /// `_selectFresh(exact, limit)` türden habersizdi ve etiketli havuz çoğunlukla
  /// çoktan seçmeliydi; bir derse bağlanmış cümle kurma/boşluk doldurma
  /// sorusu sıfır ya da yok denecek kadar az şansla çıkıyordu. "Kelimeleri
  /// sürükleyip basit cümle kur" isteyen yeni başlayan, dersin sonunda yine
  /// yalnız şık işaretliyordu.
  ///
  /// ## Kural
  ///
  /// [limit] 3 ve üstündeyse ve derste üretim sorusu varsa turun 1 (limit 5 ve
  /// üstünde 2) sorusu üretim sorusudur: önce cümle kurma (dokunmayla, daha
  /// kolay), sonra boşluk doldurma. Tanıma soruları turu açar; üretim soruları
  /// 3. ve 5. sıraya girer. Havuzda tanıma sorusu yoksa eski davranış.
  Future<List<QuizQuestion>> _selectLessonMix(
    List<QuizQuestion> exact,
    int limit,
  ) async {
    final production = exact
        .where(QuestionSetPolicy.isProductionTask)
        .toList(growable: false);
    final recognition = exact
        .where((question) => !QuestionSetPolicy.isProductionTask(question))
        .toList(growable: false);
    if (production.isEmpty || recognition.isEmpty || limit < 3) {
      return _selectFresh(exact, limit);
    }
    final wanted = limit >= 5 ? 2 : 1;
    final ordering = production
        .where((q) => q.type == QuestionType.wordOrdering)
        .toList(growable: false);
    final fill = production
        .where((q) => q.type == QuestionType.fillInBlank)
        .toList(growable: false);
    final orderingPick = await _selectFresh(ordering, 1);
    // Cümle kurma ile boşluk doldurma da aynı cümleyi sordurmasın.
    final fillSafe = fill
        .where(
          (q) => !orderingPick.any(
            (o) => QuestionSetPolicy.sharesTargetText(o, q),
          ),
        )
        .toList(growable: false);
    final picks = <QuizQuestion>[
      ...orderingPick,
      ...await _selectFresh(fillSafe.isEmpty ? fill : fillSafe, 1),
    ];
    if (picks.length < wanted) {
      final chosen = picks.map((q) => q.id).toSet();
      final more = (ordering.length >= fill.length ? ordering : fill)
          .where((q) => !chosen.contains(q.id))
          .take(wanted - picks.length);
      picks.addAll(more);
    }
    final production2 = picks.take(wanted).toList();
    // Isınma soruları üretim sorusuyla aynı cümleyi/terimi sormasın (ayrı
    // havuzlardan seçildikleri için birbirlerini görmezlerdi). Süzgeç turu
    // doldurmaya yetmiyorsa eski havuza dönülür: kural tercihtir.
    final freshRecognition = recognition
        .where(
          (q) =>
              !production2.any((p) => QuestionSetPolicy.sharesTargetText(p, q)),
        )
        .toList(growable: false);
    final warmup = await _selectFresh(
      freshRecognition.length >= limit - production2.length
          ? freshRecognition
          : recognition,
      limit - production2.length,
    );
    final mixed = [...warmup];
    for (final (index, pick) in production2.indexed) {
      mixed.insert((2 + index * 2).clamp(0, mixed.length), pick);
    }
    return mixed.take(limit).toList(growable: false);
  }

  /// Turda hiç cümle kurma / boşluk doldurma yoksa, derse bağlı kolay (zorluk
  /// <= 2) bir tanesini ÜÇÜNCÜ sıradan sonraya koyar. [limit] 5'ten azsa
  /// dokunmaz; 10 ve üstünde ayrıca bir boşluk doldurma da ekler.
  List<QuizQuestion> _withBeginnerProduction(
    List<QuizQuestion> selected,
    List<QuizQuestion> pool,
    int limit,
    Random random,
  ) {
    if (limit < 5 || selected.isEmpty) return selected;
    final result = [...selected];
    final used = result.map((q) => q.id).toSet();

    bool has(QuestionType type) => result.any((q) => q.type == type);
    void insertOne(QuestionType type) {
      if (has(type)) return;
      final candidates = pool
          .where(
            (q) =>
                q.type == type &&
                q.difficulty <= 2 &&
                q.metadata?.learningLessonId != null &&
                !used.contains(q.id),
          )
          .toList(growable: false);
      if (candidates.isEmpty) return;
      final pick = candidates[random.nextInt(candidates.length)];
      // İlk iki soru ısınmadır; değiştirilecek soru üretim sorusu ve görselli
      // olmayan, en sondaki tanıma sorusudur.
      final replaceAt = result.lastIndexWhere(
        (q) => !QuestionSetPolicy.isProductionTask(q) && !q.hasImage,
      );
      if (replaceAt < 2) {
        if (result.length < limit) result.add(pick);
        used.add(pick.id);
        return;
      }
      result[replaceAt] = pick;
      used.add(pick.id);
    }

    insertOne(QuestionType.wordOrdering);
    if (limit >= 10) insertOne(QuestionType.fillInBlank);
    return _recognitionFirst(result);
  }

  /// İlk iki soru tanıma sorusudur: yeni öğrenenin ilk teması yazmak ya da
  /// sıralamak olmamalı (bkz. `QuestionSetPolicy.byReadingLoad`). Havuzdaki
  /// üretim sorusu seçimde baştan gelmişse sonraki tanıma sorularıyla yer
  /// değiştirir; geri kalan sıra korunur.
  List<QuizQuestion> _recognitionFirst(List<QuizQuestion> questions) {
    final result = [...questions];
    for (var slot = 0; slot < 2 && slot < result.length; slot++) {
      if (!QuestionSetPolicy.isProductionTask(result[slot])) continue;
      final swapWith = result.indexWhere(
        (q) => !QuestionSetPolicy.isProductionTask(q),
        slot + 1,
      );
      if (swapWith == -1) break;
      final moved = result.removeAt(swapWith);
      result.insert(slot, moved);
    }
    return result;
  }

  /// Görülmemiş soruları öne alan tekrar-önleyici seçim.
  Future<List<QuizQuestion>> _selectFresh(
    List<QuizQuestion> pool,
    int limit,
  ) async {
    if (pool.isEmpty || limit <= 0) return const [];
    final store = await SeenQuestionStore.load();
    // Havuzdan limitten fazlası istenir: sızıntı süzgeci bir kısmını
    // eleyeceği için tam limitte istemek turu eksik bırakırdı.
    final candidates = store.preferUnseen(pool, limit * 3);
    final clean = QuestionSetPolicy.diverseWithoutLeaks(
      candidates,
      limit: limit,
    );

    // Süzgeç limiti dolduramazsa elde kalanla devam edilir: eksik bir tur,
    // kendi cevabını ele veren bir turdan iyidir. Ama "eksik"in de bir
    // tabanı olmalı.
    //
    // ## Kusur
    //
    // Eskiden yalnız `clean` BOŞSA yedeğe düşülüyordu. `clean` bir tek soru
    // döndürdüğünde o tek soru turun tamamı oluyordu: "Dil › Kelime Bilgisi ›
    // 1. Seviye" kartı "10 soru" yazıyor, oyuncu tek soru cevaplıyor ve
    // ekranda "Yarış tamamlandı" çıkıyordu (2026-08-16 simülatör taraması).
    //
    // Sebep havuzun küçüklüğü değil, süzgeçlerin üst üste binmesi: bir
    // kelime bilgisi havuzunda soruların neredeyse hepsi çeviri sorusudur,
    // `_dedupeByTranslationPair` aynı kelime çiftini toplar, ardından
    // sızıntı süzgeci kalanların birbirini ele verenlerini atar. Otuz
    // adaydan geriye bir tane kalabiliyor.
    //
    // ## Kural
    //
    // Sızıntısız sorular her zaman önce gelir; tur onlarla dolmuyorsa
    // elenmiş adaylarla, o da yetmezse havuzun geri kalanıyla tamamlanır.
    // Tekrar eden bir soru, tek soruluk bir turdan iyidir.
    final selected = <QuizQuestion>[...clean];
    if (selected.length < limit) {
      final chosen = selected.map((q) => q.id).toSet();
      for (final source in [candidates, pool]) {
        for (final question in source) {
          if (selected.length >= limit) break;
          if (chosen.add(question.id)) selected.add(question);
        }
      }
    }
    return _withVisualBlend(selected, pool, limit);
  }

  List<QuizQuestion> _withVisualBlend(
    List<QuizQuestion> selected,
    List<QuizQuestion> pool,
    int limit,
  ) {
    if (selected.length >= limit &&
        selected.where((q) => q.hasImage).length >= 2) {
      return selected;
    }
    final ids = selected.map((question) => question.id).toSet();
    final visualCandidates = pool.where(
      (question) => question.hasImage && !ids.contains(question.id),
    );
    final blended = [...selected];
    for (final question in visualCandidates) {
      if (blended.where((q) => q.hasImage).length >= 2) break;
      if (blended.length >= limit) {
        final replaceAt = blended.lastIndexWhere((q) => !q.hasImage);
        if (replaceAt == -1) break;
        blended[replaceAt] = question;
      } else {
        blended.add(question);
      }
    }
    return blended.take(limit).toList(growable: false);
  }

  @override
  GameRoom createRoom({String category = 'Ziman'}) {
    return GameRoom(
      name: 'Hevalên Zanînê',
      code: generateRoomCode(),
      category: category,
      questionCount: 10,
      status: RoomStatus.lobby,
      players: const [
        Player(name: 'Tu', score: 0, state: 'Hazır', streak: 0),
        Player(name: 'Heval', score: 0, state: 'Hazır', streak: 0),
      ],
    );
  }

  @override
  GameRoom joinRoom(String code) {
    final cleanCode = normalizeRoomCode(code);
    if (!isSupportedRoomCode(cleanCode)) {
      throw const FormatException('Invalid room code');
    }
    return createRoom().copyWith(code: cleanCode);
  }

  @override
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
    int questionCount = 10,
    int entryFee = 0,
  }) async {
    return createRoom(category: category).copyWith(
      secondsPerQuestion: secondsPerQuestion,
      questionCount: questionCount,
      entryFee: entryFee,
    );
  }

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    return joinRoom(code);
  }

  @override
  Future<GameRoom> loadRoomSnapshot(String roomId) async {
    return createRoom().copyWith(id: roomId);
  }

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async => null;

  @override
  Future<RoomResultSnapshot?> loadMyPendingRoomResult() async => null;

  @override
  Future<RoomResultSnapshot?> loadRoomResult(GameRoom room) async => null;

  @override
  Future<void> acknowledgeRoomResult(GameRoom room) async {}

  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) async => null;

  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) async => null;

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    return RoomLeaveOutcome(
      status: room.status.name,
      reason: room.status == RoomStatus.finished ? 'completed' : 'left',
      forfeitedBy: null,
    );
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    return room.players;
  }

  @override
  Future<RoomStatus> loadRoomStatus(GameRoom room) async {
    return room.status;
  }

  @override
  Future<RoomEndState> loadRoomEndState(GameRoom room) async {
    return RoomEndState(
      status: room.status,
      endedReason: null,
      forfeitedBy: null,
    );
  }

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    return Stream.value(room.players);
  }

  @override
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room) {
    return Stream.value(room.status);
  }

  @override
  Future<void> updateReady(GameRoom room, bool isReady) async {}

  @override
  Future<void> startGame(GameRoom room) async {}

  @override
  Future<void> finishGame(GameRoom room) async {}

  final List<RoomMessage> _roomMessages = [];
  final Map<String, StreamController<List<RoomMessage>>> _roomChatControllers =
      {};

  @override
  Future<void> sendRoomMessage({
    required String roomId,
    required String text,
  }) async {
    final msg = RoomMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      roomId: roomId,
      senderId: 'user1',
      senderName: _mockName,
      senderAvatarColor: '#E94560',
      text: text.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    _roomMessages.add(msg);
    _roomChatControllers[roomId]?.add(List.of(_roomMessages));
  }

  @override
  Stream<List<RoomMessage>> subscribeRoomMessages(String roomId) {
    final existing = _roomChatControllers[roomId];
    if (existing != null && !existing.isClosed) return existing.stream;
    final controller = StreamController<List<RoomMessage>>.broadcast(
      onCancel: () => _roomChatControllers.remove(roomId),
    );
    _roomChatControllers[roomId] = controller;
    controller.add(List.of(_roomMessages));
    return controller.stream;
  }

  @override
  Future<List<RoomMessage>> loadRoomMessages(String roomId) async {
    return List.of(_roomMessages);
  }

  // ─── Sohbet moderasyonu ─────────────────────────────────────────────
  // Çevrimdışı depoda engelleme cihazda tutulur; bildirme yerel olarak
  // yalnız mesajı gizler (gönderilecek bir sunucu yok).
  final Set<String> _blockedPlayerIds = <String>{};
  final Set<String> _reportedMessageIds = <String>{};

  @override
  Future<bool> reportRoomMessage({
    required String messageId,
    required String reason,
  }) async {
    _reportedMessageIds.add(messageId);
    return true;
  }

  @override
  Future<bool> blockPlayer(String playerId) async {
    _blockedPlayerIds.add(playerId);
    return true;
  }

  @override
  Future<bool> unblockPlayer(String playerId) async {
    _blockedPlayerIds.remove(playerId);
    return true;
  }

  @override
  Future<Set<String>> loadBlockedPlayerIds() async => Set.of(_blockedPlayerIds);

  @override
  Future<List<PlayerSearchResult>> loadBlockedPlayers() async => [
    for (final id in _blockedPlayerIds)
      PlayerSearchResult(id: id, displayName: 'Oyuncu', playerTag: null),
  ];

  /// Testlerin bildirimin gerçekten gönderildiğini görebilmesi için.
  final List<String> reportedProfileIds = <String>[];

  @override
  Future<bool> reportPlayerProfile({
    required String playerId,
    required String reason,
  }) async {
    reportedProfileIds.add(playerId);
    return true;
  }

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    bool isCorrect;
    if (question.type == QuestionType.wordOrdering) {
      // Cümle kurmada `answers` şık listesi değil kelime havuzudur; A-D
      // indeks eşlemesi burada anlamsız — `correctAnswer` (birleştirilmiş
      // doğru cümle) hiçbir zaman tek bir kelimeye eşit olmadığından
      // `indexOf` hep -1'e, dolayısıyla eşleme hep 'D'ye düşüyordu. Gelen
      // cevap da (bkz. `optionKeyForAnswer`) zaten boş dizeye
      // indirgendiği için karşılaştırma hep başarısızdı: bu tip sorular
      // yerel modda HİÇ doğru işaretlenemiyordu (2026-08-14 denetimi).
      // Doğruluk artık gönderilen cümlenin `correctAnswer`la birebir
      // (kenar boşlukları dışında) eşleşmesiyle ölçülür.
      isCorrect =
          selectedOptionOptionKey.trim() == question.correctAnswer.trim();
    } else {
      final correctIndex = question.answers.indexOf(question.correctAnswer);
      final correctOptionKey = switch (correctIndex) {
        0 => 'A',
        1 => 'B',
        2 => 'C',
        _ => 'D',
      };
      isCorrect = selectedOptionOptionKey == correctOptionKey;
    }
    return {
      'is_correct': isCorrect,
      'points': SpeedScore.calculate(
        responseMs: responseMs,
        limitSeconds: room.secondsPerQuestion,
        correct: isCorrect,
      ),
    };
  }

  final Set<String> _mockFavorites = {};

  @override
  Future<bool> toggleFavoriteQuestion(
    QuizQuestion question,
    bool favorite,
  ) async {
    if (favorite) {
      _mockFavorites.add(question.id);
    } else {
      _mockFavorites.remove(question.id);
    }
    return favorite;
  }

  @override
  Future<bool> isFavoriteQuestion(QuizQuestion question) async {
    return _mockFavorites.contains(question.id);
  }

  @override
  Future<void> reportQuestion(QuizQuestion question, String reason) async {
    reportedQuestions.add((id: question.id, reason: reason));
  }

  final reportedQuestions = <({String id, String reason})>[];

  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async {
    return questions.take(3).toList();
  }

  @override
  Future<int> loadCoinBalance() async => _mockCoins;

  DateTime? _lastSpin;

  @override
  Future<bool> canSpinToday() async {
    final last = _lastSpin;
    final now = DateTime.now().toUtc();
    final freeSpinAvailable =
        last == null ||
        last.year != now.year ||
        last.month != now.month ||
        last.day != now.day;
    if (freeSpinAvailable) return true;

    return _mockExtraSpins > _mockUsedExtraSpins;
  }

  /// Sahte depoda sunucu XP'si tutulmaz; yalnız çağrının yapıldığı görülür.
  int awardedXpTotal = 0;

  @override
  bool get xpAwardIsServerTotal => false;

  @override
  Future<int?> loadServerXp() async => null;

  @override
  Future<int> awardXp(int delta) async {
    if (delta <= 0) return awardedXpTotal;
    awardedXpTotal += delta;
    return awardedXpTotal;
  }

  @override
  Future<ServerXpWrite> awardXpDurable(int delta, String idempotencyKey) async {
    final total = await awardXp(delta);
    return ServerXpWrite(total: total, retryable: false);
  }

  @override
  Future<int> awardRoomXp(String roomId) async {
    if (roomId.trim().isEmpty) return awardedXpTotal;
    awardedRoomXpCalls.add(roomId);
    return awardedXpTotal;
  }

  final awardedRoomXpCalls = <String>[];

  @override
  Future<int> awardSpinCoins() async {
    const rewards = [10, 25, 50, 15, 75, 20, 100, 30];
    final amount = rewards[Random().nextInt(rewards.length)];
    final now = DateTime.now().toUtc();

    final last = _lastSpin;
    final freeSpinAvailable =
        last == null ||
        last.year != now.year ||
        last.month != now.month ||
        last.day != now.day;

    if (freeSpinAvailable) {
      _lastSpin = now;
    } else if (_mockExtraSpins > _mockUsedExtraSpins) {
      _mockUsedExtraSpins++;
    }

    _mockCoins += amount;
    return amount;
  }

  /// Anahtar başına en fazla bir kez tahsil eden sahte idempotent yol.
  final Set<String> _streakFreezeKeys = {};

  @override
  Future<StreakFreezeChargeResult> spendStreakFreeze({
    required String idempotencyKey,
  }) async {
    if (_streakFreezeKeys.contains(idempotencyKey)) {
      return const StreakFreezeChargeResult(
        outcome: StreakFreezeChargeOutcome.alreadyCharged,
        idempotent: true,
      );
    }
    if (_mockCoins < 50) {
      return const StreakFreezeChargeResult(
        outcome: StreakFreezeChargeOutcome.insufficient,
        idempotent: true,
      );
    }
    _mockCoins -= 50;
    _streakFreezeKeys.add(idempotencyKey);
    return const StreakFreezeChargeResult(
      outcome: StreakFreezeChargeOutcome.charged,
      idempotent: true,
    );
  }

  @override
  Future<DurableCoinSpend> spendCoinsDurable(
    int amount,
    String reason,
    String idempotencyKey,
  ) async {
    final success = await spendCoins(amount, reason);
    return DurableCoinSpend(success: success, retryable: false);
  }

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    if (_mockCoins < amount) return false;
    _mockCoins -= amount;
    if (reason == 'purchase_spin_wheel_extra') {
      _mockExtraSpins++;
    }
    if (reason.startsWith('purchase_')) {
      _mockPurchases.add(reason.replaceFirst('purchase_', ''));
    }
    return true;
  }

  @override
  Future<bool> hasPurchased(String itemId) async {
    return _mockPurchases.contains(itemId);
  }

  @override
  Future<int> claimMissionReward({
    required String missionKey,
    required int fallbackReward,
  }) async {
    if (fallbackReward > 0) _mockCoins += fallbackReward;
    return fallbackReward;
  }

  @override
  Future<int> claimTournamentReward() async {
    _mockCoins += 200;
    return 200;
  }

  @override
  Future<QuizRewardClaim> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    // Solo tur üretimde ayrı bir RPC'ye gider (`claim_solo_reward`): küçük
    // formül + günlük tavan. Çevrimdışı yol aynı davranışı göstermeli,
    // yoksa mock'ta oynanan ekonomi üretimdekiyle ilgisiz olur.
    if (room?.id == null) {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      if (_mockSoloDay != day) {
        _mockSoloDay = day;
        _mockSoloEarnedToday = 0;
      }
      final remaining = CoinCalculator.soloDailyCap - _mockSoloEarnedToday;
      // Çevrimdışı yol da tavanı SEBEBİYLE bildirir; aksi hâlde mock'ta
      // "+0 jeton"un niçin sıfır olduğu görünmez ve arayüzün tavan
      // mesajı hiçbir zaman sınanamaz.
      if (remaining <= 0) return (amount: 0, dailyCapReached: true);
      final earned = CoinCalculator.soloAward(
        correctCount: correctCount,
        bestStreak: bestStreak,
      ).clamp(0, remaining);
      _mockSoloEarnedToday += earned;
      _mockCoins += earned;
      return (
        amount: earned,
        dailyCapReached: _mockSoloEarnedToday >= CoinCalculator.soloDailyCap,
      );
    }

    final earned = _calculateCoinAward(
      score: score,
      correctCount: correctCount,
      bestStreak: bestStreak,
      totalQuestions: totalQuestions,
    );
    _mockCoins += earned;
    return (amount: earned, dailyCapReached: false);
  }

  int _calculateCoinAward({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
  }) => CoinCalculator.award(
    score: score,
    correctCount: correctCount,
    bestStreak: bestStreak,
    totalQuestions: totalQuestions,
  );

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const [];
  }

  static const _avatarIdentityKey = 'zankurd.avatarIdentity';

  @override
  Future<AvatarIdentity> loadAvatarIdentity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_avatarIdentityKey);
      if (raw == null || raw.isEmpty) return const AvatarIdentity();
      return AvatarIdentity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'mock_load_avatar_identity');
      return const AvatarIdentity();
    }
  }

  @override
  Future<void> updateAvatarIdentity(AvatarIdentity identity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarIdentityKey, jsonEncode(identity.toJson()));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'mock_update_avatar_identity');
      // Offline/test ortamında sessizce yut; kozmetik veri kritik değil.
    }
  }

  @override
  Future<String> uploadAvatarPhoto(Uint8List bytes, String contentType) async {
    // Mock modda gerçek depolama yok; kalıcı olmayan yerel bir işaret döner.
    avatarPhotoDeleted = false;
    return 'mock://avatar/${bytes.length}';
  }

  /// Testlerin "depodan silme gerçekten çağrıldı mı" sorusunu sorabilmesi
  /// için. Kusur tam olarak bu çağrının HİÇ yapılmamasıydı (2026-08-02).
  bool avatarPhotoDeleted = false;

  @override
  Future<void> deleteAvatarPhoto() async {
    // Çevrimdışı/mock modda silinecek uzak nesne yok; çağrının YAPILDIĞINI
    // kaydetmek yeterlidir — bekçi test bunu doğrular.
    avatarPhotoDeleted = true;
  }

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    return const {'status': 'waiting'};
  }

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async {
    return const {'status': 'cancelled'};
  }

  @override
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue() {
    return const Stream.empty();
  }

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) {
    return const Stream.empty();
  }

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {}

  @override
  Future<Contest?> loadTodayContest() async {
    // Mock: statik hergün Ziman teması
    return Contest(
      id: 'contest_mock_today',
      dayKey: DateTime.now(),
      // "Ziman Eksperi" ne tam Kurmancî ne Türkçeydi ve iki arayüzde de aynı
      // görünüyordu. Her dil kendi metnini alır.
      themeNameKu: 'Pisporê Ziman',
      themeDescriptionKu: 'Bibe hostayê ziman!',
      themeNameTr: 'Dil Uzmanı',
      themeDescriptionTr: 'Dilin ustası ol!',
      category: 'Ziman',
      difficultyMin: 1,
      difficultyMax: 3,
      participationReward: 10,
      rank1Reward: 500,
      rank2Reward: 300,
      rank3Reward: 100,
      questionCount: 10,
    );
  }

  @override
  Future<ContestEntry?> submitContestEntry({
    required String contestId,
    required int correctCount,
  }) async {
    final score = correctCount * 100;
    return ContestEntry(
      id: 'entry_mock',
      contestId: contestId,
      userId: 'user_mock',
      score: score,
      correctCount: correctCount,
      finishedAt: DateTime.now(),
      rank: 1,
      rewardClaimed: false,
    );
  }

  @override
  Future<Map<String, dynamic>?> claimContestReward(String contestId) async {
    return {
      'claimed': true,
      'rank_reward': 500,
      'badge_awarded': 'contest_20260705_champion',
    };
  }

  @override
  Future<List<ContestLeaderboardRow>> getContestLeaderboard({
    required String contestId,
    int limit = 10,
  }) async {
    return const [];
  }

  @override
  Future<List<UserContestBadge>> loadUserContestBadges() async {
    return const [];
  }

  static const Map<String, List<Lesson>> _lessonsData = {
    'everyday': [
      Lesson(
        id: 'alphabet_1',
        slug: 'alphabet_1',
        titleKu: 'Alfabe',
        titleTr: 'Alfabe',
        descriptionKu: 'Tîpên Kurmancî û dengên wan',
        category: 'everyday',
        iconName: 'sort_by_alpha',
        order: 1,
      ),
      Lesson(
        id: 'everyday_1',
        slug: 'everyday_1',
        titleKu: 'Silavkirin',
        titleTr: 'Selamlaşma',
        category: 'everyday',
        iconName: 'waving_hand',
        order: 2,
      ),
      Lesson(
        id: 'greetings_2',
        slug: 'greetings_2',
        titleKu: 'Silav û rêzdarî 2',
        titleTr: 'Selamlaşma ve nezaket 2',
        descriptionKu: 'Silav, spas û xatirxwestin',
        category: 'everyday',
        iconName: 'forum',
        order: 3,
      ),
      Lesson(
        id: 'everyday_2',
        slug: 'everyday_2',
        titleKu: 'Nasandin',
        titleTr: 'Tanışma',
        category: 'everyday',
        iconName: 'handshake',
        order: 4,
      ),
      Lesson(
        id: 'intro_1',
        slug: 'intro_1',
        titleKu: 'Xwe nasandin',
        titleTr: 'Kendini tanıtma',
        descriptionKu: 'Nav, temen, welat û pîşe',
        category: 'everyday',
        iconName: 'badge',
        order: 5,
      ),
      Lesson(
        id: 'family_1',
        slug: 'family_1',
        titleKu: 'Malbat',
        titleTr: 'Aile',
        descriptionKu: 'Endamên malbatê',
        category: 'everyday',
        iconName: 'family_restroom',
        order: 6,
      ),
      Lesson(
        id: 'everyday_3',
        slug: 'everyday_3',
        titleKu: 'Pratikên rojane',
        titleTr: 'Günlük pratik ifadeler',
        category: 'everyday',
        iconName: 'forum',
        order: 7,
      ),
    ],
    'grammar': [
      Lesson(
        id: 'grammar_1',
        slug: 'grammar_1',
        titleKu: 'Cînavkên kesane',
        titleTr: 'Şahıs zamirleri',
        category: 'grammar',
        iconName: 'g_translate',
        order: 1,
      ),
      Lesson(
        id: 'grammar_2',
        slug: 'grammar_2',
        titleKu: 'Tewandin',
        titleTr: 'Büküm (hal çekimi)',
        category: 'grammar',
        iconName: 'sort_by_alpha',
        order: 2,
      ),
    ],
    'culture': [
      Lesson(
        id: 'culture_1',
        slug: 'culture_1',
        titleKu: 'Folklor û govend',
        titleTr: 'Folklor & halay',
        category: 'culture',
        iconName: 'music_note',
        order: 1,
      ),
      Lesson(
        id: 'culture_2',
        slug: 'culture_2',
        titleKu: 'Cejn û cejndarî',
        titleTr: 'Bayramlar',
        category: 'culture',
        iconName: 'celebration',
        order: 2,
      ),
    ],
    'food': [
      Lesson(
        id: 'food_1',
        slug: 'food_1',
        titleKu: 'Xwarinên bingehîn',
        titleTr: 'Temel yemekler',
        category: 'food',
        iconName: 'restaurant',
        order: 1,
      ),
      Lesson(
        id: 'food_2',
        slug: 'food_2',
        titleKu: 'Fêkî û keskahî',
        titleTr: 'Meyve & sebzeler',
        category: 'food',
        iconName: 'local_grocery_store',
        order: 2,
      ),
    ],
    'animals': [
      Lesson(
        id: 'animals_1',
        slug: 'animals_1',
        titleKu: 'Heywanên malê',
        titleTr: 'Evcil hayvanlar',
        category: 'animals',
        iconName: 'pets',
        order: 1,
      ),
      Lesson(
        id: 'animals_2',
        slug: 'animals_2',
        titleKu: 'Heywanên kovî',
        titleTr: 'Yabani hayvanlar',
        category: 'animals',
        iconName: 'forest',
        order: 2,
      ),
    ],
    'geography': [
      Lesson(
        id: 'geography_1',
        slug: 'geography_1',
        titleKu: 'Erdnîgarîya Kurdistanê',
        titleTr: 'Coğrafya',
        category: 'geography',
        iconName: 'map',
        order: 1,
      ),
      Lesson(
        id: 'geography_2',
        slug: 'geography_2',
        titleKu: 'Aliyên erdnîgarî',
        titleTr: 'Yönler',
        category: 'geography',
        iconName: 'explore',
        order: 2,
      ),
    ],
    'emotions': [
      Lesson(
        id: 'emotions_1',
        slug: 'emotions_1',
        titleKu: 'Hestên erênî',
        titleTr: 'Olumlu duygular',
        category: 'emotions',
        iconName: 'sentiment_very_satisfied',
        order: 1,
      ),
      Lesson(
        id: 'emotions_2',
        slug: 'emotions_2',
        titleKu: 'Hestên neyînî',
        titleTr: 'Olumsuz duygular',
        category: 'emotions',
        iconName: 'sentiment_very_dissatisfied',
        order: 2,
      ),
    ],
    'time': [
      Lesson(
        id: 'time_1',
        slug: 'time_1',
        titleKu: 'Roj û meh',
        titleTr: 'Günler & aylar',
        category: 'time',
        iconName: 'calendar_month',
        order: 1,
      ),
      Lesson(
        id: 'time_2',
        slug: 'time_2',
        titleKu: 'Serdem û demjimêr',
        titleTr: 'Zaman dilimleri',
        category: 'time',
        iconName: 'schedule',
        order: 2,
      ),
    ],
  };

  static const Map<String, List<LessonSlide>> _slidesData = {
    'alphabet_1': [
      LessonSlide(
        id: 'alphabet_1_s1',
        lessonId: 'alphabet_1',
        order: 1,
        contentKu:
            'Alfabeya Kurmancî (Hawar) 31 tîp e:\n\nA B C Ç D E Ê F G H I Î J K L M N O P Q R S Ş T U Û V W X Y Z\n\nHeşt tîp dengdêr in, bîst û sê tîp dengdar in.\n\n• Alfabe: Alfabe\n• Tîp: Harf\n• Dengdêr: Ünlü harf\n• Dengdar: Ünsüz harf',
        contentTr:
            'Kurmancî (Hawar) alfabesi 31 harftir: 8 ünlü ve 23 ünsüz harf. Hawar alfabesi Latin harflerini kullanır.',
        exampleKu: 'A, B, C, Ç, D...',
      ),
      LessonSlide(
        id: 'alphabet_1_s2',
        lessonId: 'alphabet_1',
        order: 2,
        contentKu:
            'Dengdêr (ünlü) tîp:\n\na — av\ne — ez\nê — êvar\ni — dil\nî — îro\no — ode\nu — kur\nû — dûr',
        contentTr:
            'Sekiz ünlü: a, e, ê, i, î, o, u, û. Kısa ve uzun ünlüler ayrı harflerdir: i kısa ve gevşek bir i\'dir (Türkçedeki ı değildir), î uzun i\'dir; u kısa, û uzun u\'dur; e açık ve kısa, ê kapalı ve uzun bir e\'dir.',
        exampleKu: 'Av, ez, êvar, dil, îro, ode, kur, dûr.',
      ),
      LessonSlide(
        id: 'alphabet_1_s3',
        lessonId: 'alphabet_1',
        order: 3,
        contentKu:
            'Tîpên taybet 1:\n\nç — wekî di tirkî de: çay\nş — wekî di tirkî de: şev\nc — wekî di tirkî de: cil\nj — wekî di tirkî de: jin\nw — wekî "w" a îngilîzî (water): welat',
        contentTr:
            'Özel harfler 1: ç ve ş Türkçedeki gibi okunur. w, İngilizce water kelimesindeki w gibidir (Türkçede yoktur). c ve j de Türkçedeki gibidir.',
        exampleKu: 'Çay, şev, welat, cil, jin.',
      ),
      LessonSlide(
        id: 'alphabet_1_s4',
        lessonId: 'alphabet_1',
        order: 4,
        contentKu:
            'Tîpên taybet 2:\n\nx — dengê qirikê (mîna "خ" ya erebî), di tirkî de tune ye: xal\nq — dengekî "k" yê kûr ji qirikê: qelem\nê — dengê "e" yê dirêj: êvar\nî — dengê "i" yê dirêj: îro\nû — dengê "u" yê dirêj: dûr',
        contentTr:
            'Özel harfler 2: x boğazdan çıkan, Türkçede olmayan bir sestir (Arapça خ ya da Almanca Bach\'taki ch gibi; Türkçe ğ ile aynı değildir). q boğazdan çıkan derin bir k\'dır (Arapça ق gibi). ê, î, û uzun ünlülerdir.',
        exampleKu: 'Xal, qelem, êvar, îro, dûr.',
      ),
      LessonSlide(
        id: 'alphabet_1_s5',
        lessonId: 'alphabet_1',
        order: 5,
        contentKu:
            'Peyv û tîp (C–H):\n\n• Cil: Giysi\n• Çay: Çay\n• Dar: Ağaç\n• Fêkî: Meyve\n• Gul: Gül\n• Heval: Arkadaş',
        contentTr: 'Harflerle örnek kelimeler: c, ç, d, f, g, h.',
        exampleKu: 'Ev gul e. Ew heval e.',
      ),
      LessonSlide(
        id: 'alphabet_1_s6',
        lessonId: 'alphabet_1',
        order: 6,
        contentKu:
            'Peyv û tîp (K–W) û çend peyvên din:\n\n• Ker: Eşek\n• Lêv: Dudak\n• Mal: Ev\n• Ode: Oda\n• Qelem: Kalem\n• Roj: Gün / Güneş\n• Welat: Ülke\n• Dil: Kalp\n• Dûr: Uzak\n• Ev: Bu',
        contentTr:
            'Harflerle örnek kelimeler: k, l, m, o, q, r, w. "Mal" ev (bina), "ev" ise "bu" demektir; ikisini karıştırma.',
        exampleKu: 'Ev qelem e. Ev ode ye.',
      ),
    ],
    'greetings_2': [
      LessonSlide(
        id: 'greetings_2_s1',
        lessonId: 'greetings_2',
        order: 1,
        contentKu:
            'Silav û bi xêr hatin:\n\n• Silav: Selam\n• Bi xêr hatî: Hoş geldin\n• Sibeha te bi xêr: Günaydın\n• Êvara te bi xêr: İyi akşamlar\n• Şeva te bi xêr: İyi geceler',
        contentTr:
            'Selamlaşma kalıpları. "Xêr" hayır/iyilik demektir; "Sibeha te bi xêr" sabahın hayırlı olsun anlamındadır.',
        exampleKu: 'Silav heval! Bi xêr hatî!',
      ),
      LessonSlide(
        id: 'greetings_2_s2',
        lessonId: 'greetings_2',
        order: 2,
        contentKu:
            'Hal pirsîn:\n\n• Hûn çawa ne?: Nasılsınız?\n• Ez baş im: İyiyim\n• Ez gelek baş im: Çok iyiyim\n• Çawa: Nasıl\n• Baş: İyi\n• Gelek: Çok',
        contentTr:
            'Hal hatır sorma. "Tu çawa yî?" tek kişiye, "Hûn çawa ne?" birden çok kişiye ya da saygıyla sorulur.',
        exampleKu: 'Tu çawa yî? Ez gelek baş im, spas.',
      ),
      LessonSlide(
        id: 'greetings_2_s3',
        lessonId: 'greetings_2',
        order: 3,
        contentKu:
            'Spas, lêborîn û gotin:\n\n• Gelek spas: Çok teşekkürler\n• Bibore: Özür dilerim / Pardon\n• Gotin: Söylemek',
        contentTr: 'Teşekkür ve özür. "Spas" tek başına da kullanılır.',
        exampleKu: 'Gelek spas, heval!',
      ),
      LessonSlide(
        id: 'greetings_2_s4',
        lessonId: 'greetings_2',
        order: 4,
        contentKu:
            'Xatirxwestin:\n\n• Bi xatirê te: Hoşça kal\n• Bi xatirê we: Hoşça kalın\n• Oxir be: Güle güle\n• Xêr: Hayır / İyilik\n• We: Size / Sizin (tewandî hal)',
        contentTr:
            'Vedalaşma. "Te" tek kişiye, "we" birden çok kişiye ya da saygıyla söylenir.',
        exampleKu: 'Bi xatirê te, heval. — Oxir be!',
      ),
    ],
    'intro_1': [
      LessonSlide(
        id: 'intro_1_s1',
        lessonId: 'intro_1',
        order: 1,
        contentKu:
            'Nav:\n\n• Nav: Ad / İsim\n• Navê min Rojîn e: Benim adım Rojîn.\n• Rojîn: Kız ismi\n• Çi: Ne\n• Navê te çi ye?: Adın ne?',
        contentTr: 'Adını söyleme. "Navê min ... e" = benim adım ...',
        exampleKu: 'Navê min Rojîn e. Navê te çi ye?',
      ),
      LessonSlide(
        id: 'intro_1_s2',
        lessonId: 'intro_1',
        order: 2,
        contentKu:
            'Temen:\n\n• Tu çend salî yî?: Kaç yaşındasın?\n• Ez bîst salî me: Yirmi yaşındayım.\n• Sal: Yıl\n• Çend: Kaç',
        contentTr: 'Yaşı söyleme: "Ez ... salî me." (sal + î = yaşında).',
        exampleKu: 'Ez deh salî me. Tu çend salî yî?',
      ),
      LessonSlide(
        id: 'intro_1_s3',
        lessonId: 'intro_1',
        order: 3,
        contentKu:
            'Welat û bajar:\n\n• Ez ji Wanê me: Vanlıyım.\n• Ji: -den / -dan\n• Ku: Nerede / Nere\n• Der: Yer (ku derê = nere)\n• Wan: Van\n• Mêrdîn: Mardin\n• Stenbol: İstanbul\n• Kurd: Kürt',
        contentTr:
            'Nerelisin? sorusu ve cevabı. "ji" ile dişil şehir adlarının sonuna -ê eklenir: Wan → Wanê, Mêrdîn → Mêrdînê, Stenbol → Stenbolê.',
        exampleKu: 'Tu ji ku derê yî? Ez ji Mêrdînê me.',
      ),
      LessonSlide(
        id: 'intro_1_s4',
        lessonId: 'intro_1',
        order: 4,
        contentKu:
            'Pîşe:\n\n• Pîşe: Meslek\n• Xwendekar: Öğrenci\n• Mamoste: Öğretmen\n• Doktor: Doktor\n• Karker: İşçi',
        contentTr:
            'Meslek söyleme: "Ez ... im" (ünsüzden sonra) ya da "Ez ... me" (ünlüden sonra).',
        exampleKu: 'Ez xwendekar im. Ez mamoste me.',
      ),
      LessonSlide(
        id: 'intro_1_s5',
        lessonId: 'intro_1',
        order: 5,
        contentKu:
            'Ziman:\n\n• Kurdî: Kürtçe\n• Kurmancî: Kurmancî (Kürtçenin bir lehçesi)\n• Tirkî: Türkçe\n• Zanîn: Bilmek\n• Bi: İle / -le / -ce (dil)',
        contentTr: 'Dil bilme: "Ez bi Kurmancî dizanim" = Kurmancî biliyorum.',
        exampleKu: 'Ez bi Kurmancî dizanim. Tu bi Tirkî dizanî?',
      ),
    ],
    'family_1': [
      LessonSlide(
        id: 'family_1_s1',
        lessonId: 'family_1',
        order: 1,
        contentKu:
            'Malbata nêzîk:\n\n• Malbat: Aile\n• Dê: Anne\n• Bav: Baba\n• Bira: Erkek kardeş\n• Xwişk: Kız kardeş\n• Kur: Oğul / Erkek çocuk\n• Keç: Kız (çocuk)',
        contentTr: 'Yakın aile üyeleri. "Bavê min" = benim babam (bav + -ê).',
        exampleKu: 'Ev dê ye. Ev bavê min e.',
      ),
      LessonSlide(
        id: 'family_1_s2',
        lessonId: 'family_1',
        order: 2,
        contentKu:
            'Malbata mezin:\n\n• Dapîr: Büyükanne\n• Bapîr: Büyükbaba\n• Mam: Amca\n• Met: Hala\n• Xal: Dayı\n• Xaltî: Teyze',
        contentTr:
            'Geniş aile. Amca (mam) ve hala (met) baba tarafı, dayı (xal) ve teyze (xaltî) anne tarafıdır.',
        exampleKu: 'Dapîra min li malê ye.',
      ),
      LessonSlide(
        id: 'family_1_s3',
        lessonId: 'family_1',
        order: 3,
        contentKu:
            'Kes û zarok:\n\n• Jin: Kadın / Eş\n• Mêr: Erkek / Koca\n• Zarok: Çocuk',
        contentTr: 'İnsan ve çocuk sözcükleri.',
        exampleKu: 'Bapîr mêr e. Dapîr jin e.',
      ),
      LessonSlide(
        id: 'family_1_s4',
        lessonId: 'family_1',
        order: 4,
        contentKu:
            'Hevok:\n\n• Ev dê ye: Bu anne.\n• Ev bavê min e: Bu benim babam.\n• Dê û bav li malê ne: Anne ve baba evde.\n• Û: Ve\n• Li: -de / -da (yer)',
        contentTr:
            'Basit aile cümleleri. "ye" ünlüyle biten sözcükten sonra, "e" ünsüzle bitenden sonra gelir.',
        exampleKu: 'Bira û xwişk li malê ne.',
      ),
    ],
    'everyday_1': [
      LessonSlide(
        id: 'everyday_1_s1',
        lessonId: 'everyday_1',
        order: 1,
        contentKu:
            'Di Kurmancî de silavên bingehîn:\n\n• Rojbaş: Günaydın / İyi günler\n• Êvarbaş: İyi akşamlar\n• Şevbaş: İyi geceler',
        contentTr: 'Kürtçede temel selamlaşma ifadeleri.',
      ),
      LessonSlide(
        id: 'everyday_1_s2',
        lessonId: 'everyday_1',
        order: 2,
        contentKu:
            'Rewş pirsîn:\n\n• Tu çawa yî?: Nasılsın?\n• Ez baş im, spas dikim: İyiyim, teşekkür ederim.',
        contentTr: 'Hal hatır sorma kalıpları.',
      ),
    ],
    'everyday_2': [
      LessonSlide(
        id: 'everyday_2_s1',
        lessonId: 'everyday_2',
        order: 1,
        contentKu:
            'Nav pirsîn:\n\n• Navê te çi ye?: Adın ne?\n• Navê min Azad e: Benim adım Azad.',
        contentTr: 'İsim sorma ve kendini tanıtma.',
      ),
      LessonSlide(
        id: 'everyday_2_s2',
        lessonId: 'everyday_2',
        order: 2,
        contentKu:
            'Welat / Cî pirsîn:\n\n• Tu ji ku derê yî?: Nerelisin?\n• Ez ji Amedê me: Amedliyim.',
        contentTr: 'Memleket sorma ve belirtme.',
      ),
    ],
    'everyday_3': [
      LessonSlide(
        id: 'everyday_3_s1',
        lessonId: 'everyday_3',
        order: 1,
        contentKu:
            'Gotinên pratîk ên jiyana rojane:\n\n• Fermo: Buyurun\n• Kerem bike: Buyur / Geç\n• Spas: Teşekkürler / Sağ ol',
        contentTr: 'Günlük hayatta en çok kullanılan pratik hitaplar.',
      ),
      LessonSlide(
        id: 'everyday_3_s2',
        lessonId: 'everyday_3',
        order: 2,
        contentKu:
            'Daxwaz û lêborîn:\n\n• Ji kerema xwe: Lütfen\n• Bibexşîne: Özür dilerim / Affet',
        contentTr: 'Rica ve özür dileme kalıpları.',
      ),
    ],
    'grammar_1': [
      LessonSlide(
        id: 'grammar_1_s1',
        lessonId: 'grammar_1',
        order: 1,
        contentKu:
            'Cînavkên kesane yên xwerû:\n\n• Ez: Ben\n• Tu: Sen\n• Ew: O',
        contentTr: 'Yalın hal şahıs zamirleri.',
      ),
      LessonSlide(
        id: 'grammar_1_s2',
        lessonId: 'grammar_1',
        order: 2,
        contentKu:
            'Cînavkên kesane yên pirjimar:\n\n• Em: Biz\n• Hûn: Siz\n• Ew: Onlar',
        contentTr: 'Çoğul şahıs zamirleri.',
      ),
    ],
    'grammar_2': [
      LessonSlide(
        id: 'grammar_2_s1',
        lessonId: 'grammar_2',
        order: 1,
        contentKu:
            'Cînavkên tewandî:\n\n• Min: Beni / Bana / Benim\n• Te: Seni / Sana / Senin\n• Wî (nêr) / Wê (mê): Onu / Ona / Onun',
        contentTr: 'Bükümlü hal şahıs zamirleri.',
      ),
      LessonSlide(
        id: 'grammar_2_s2',
        lessonId: 'grammar_2',
        order: 2,
        contentKu:
            'Mînak:\n\n• Ez nan dixwim (Şimdiki zaman - yalın zamir)\n• Min nan xwar (Geçmiş zaman - bükümlü zamir)',
        contentTr: 'Ergatif yapı örneği.',
      ),
    ],
    'culture_1': [
      LessonSlide(
        id: 'culture_1_s1',
        lessonId: 'culture_1',
        order: 1,
        contentKu:
            'Kevneşopiya Govendê:\n\n• Govend: Halay\n• Dilan: Düğün / Eğlence\n• Şahî: Şenlik',
        contentTr: 'Kürt halk kültürü ve halay gelenekleri.',
      ),
      LessonSlide(
        id: 'culture_1_s2',
        lessonId: 'culture_1',
        order: 2,
        contentKu:
            'Dengbêjî:\n\nDengbêjî, parastin û ragihandina dîrok û çanda kurdî ya bi riya stran û kilaman e.',
        contentTr: 'Dengbêjlik kültürü hakkında bilgi.',
      ),
      LessonSlide(
        id: 'culture_1_s3',
        lessonId: 'culture_1',
        order: 3,
        contentKu: 'Dawet:\n\n• Dawet: Düğün',
        contentTr: 'Düğün ziyafeti anlamında bir sözcük.',
        exampleKu: 'Dawet li malê ye.',
      ),
    ],
    'culture_2': [
      LessonSlide(
        id: 'culture_2_s1',
        lessonId: 'culture_2',
        order: 1,
        contentKu:
            'Newroz:\n\nNewroz cejna neteweyî û nûbûna xwezayê ye ku di 21ê Adarê de tê pîrozkirin.',
        contentTr: 'Newroz bayramı ve önemi.',
      ),
      LessonSlide(
        id: 'culture_2_s2',
        lessonId: 'culture_2',
        order: 2,
        contentKu:
            'Cejnên olî:\n\n• Cejna Remezanê: Ramazan Bayramı\n• Cejna Qurbanê: Kurban Bayramı',
        contentTr: 'Kültürdeki dini bayramlar.',
      ),
    ],
    'food_1': [
      LessonSlide(
        id: 'food_1_s1',
        lessonId: 'food_1',
        order: 1,
        contentKu:
            'Xwarin û vexwarinên bingehîn:\n\n• Nan: Ekmek\n• Av: Su\n• Goşt: Et\n• Mast: Yoğurt',
        contentTr: 'Temel gıdalar ve anlamları.',
      ),
      LessonSlide(
        id: 'food_1_s2',
        lessonId: 'food_1',
        order: 2,
        contentKu:
            'Danên xwarinê:\n\n• Taştê: Kahvaltı\n• Firavîn: Öğle yemeği\n• Şîv: Akşam yemeği',
        contentTr: 'Öğün isimleri.',
      ),
      LessonSlide(
        id: 'food_1_s3',
        lessonId: 'food_1',
        order: 3,
        contentKu:
            'Xwarin û vexwarin:\n\n• Xwarin: Yemek yemek\n• Vexwarin: İçmek',
        contentTr:
            'Yemek yemek (xwarin) ve içmek (vexwarin) fiilleri. "Ez nan dixwim" = ekmek yiyorum, "Ez av vedixwim" = su içiyorum.',
        exampleKu: 'Ez nan dixwim. Ez av vedixwim.',
      ),
    ],
    'food_2': [
      LessonSlide(
        id: 'food_2_s1',
        lessonId: 'food_2',
        order: 1,
        contentKu:
            'Fêkiyên sereke:\n\n• Sêv: Elma\n• Hinar: Nar\n• Tirî: Üzüm\n• Hejîr: İncir',
        contentTr: 'Meyve isimleri.',
      ),
      LessonSlide(
        id: 'food_2_s2',
        lessonId: 'food_2',
        order: 2,
        contentKu:
            'Keskahî û sebze:\n\n• Pîvaz: Soğan\n• Sîr: Sarımsak\n• Bacan: Patlıcan / Domates',
        contentTr: 'Sebze isimleri.',
      ),
    ],
    'animals_1': [
      LessonSlide(
        id: 'animals_1_s1',
        lessonId: 'animals_1',
        order: 1,
        contentKu:
            'Heywanên kedî:\n\n• Kûçik / Seg: Köpek\n• Pisîk: Kedi\n• Hesp: At',
        contentTr: 'Evcil hayvanlar.',
      ),
      LessonSlide(
        id: 'animals_1_s2',
        lessonId: 'animals_1',
        order: 2,
        contentKu:
            'Heywanên çandiniyê:\n\n• Çêlek: İnek\n• Mîh: Koyun\n• Bizin: Keçi',
        contentTr: 'Çiftlik hayvanları.',
      ),
    ],
    'animals_2': [
      LessonSlide(
        id: 'animals_2_s1',
        lessonId: 'animals_2',
        order: 1,
        contentKu:
            'Heywanên kovî:\n\n• Şêr: Aslan\n• Gur: Kurt\n• Rûvî: Tilki\n• Hirç: Ayı',
        contentTr: 'Yabani hayvanlar.',
      ),
      LessonSlide(
        id: 'animals_2_s2',
        lessonId: 'animals_2',
        order: 2,
        contentKu:
            'Balindeyên esmanî:\n\n• Eylo: Kartal\n• Kevok: Güvercin\n• Qijak: Karga',
        contentTr: 'Kuş türleri.',
      ),
    ],
    'geography_1': [
      LessonSlide(
        id: 'geography_1_s1',
        lessonId: 'geography_1',
        order: 1,
        contentKu:
            'Çiyayên navdar:\n\n• Çiyayê Cudî\n• Çiyayê Agirî\n• Çiyayê Sîpan',
        contentTr: 'Bölgedeki önemli dağlar.',
      ),
      LessonSlide(
        id: 'geography_1_s2',
        lessonId: 'geography_1',
        order: 2,
        contentKu:
            'Çemên sereke:\n\n• Çemê Dîcle: Dicle Nehri\n• Çemê Firat: Fırat Nehri',
        contentTr: 'Bölgedeki önemli akarsular.',
      ),
    ],
    'geography_2': [
      LessonSlide(
        id: 'geography_2_s1',
        lessonId: 'geography_2',
        order: 1,
        contentKu:
            'Aliyên sereke:\n\n• Bakur: Kuzey\n• Başûr: Güney\n• Rojhilat: Doğu\n• Rojava: Batı',
        contentTr: 'Ana coğrafi yönler.',
      ),
      LessonSlide(
        id: 'geography_2_s2',
        lessonId: 'geography_2',
        order: 2,
        contentKu:
            'Aliyên din:\n\n• Jor / Jorîn: Yukarı\n• Jêr / Jêrîn: Aşağı\n• Navîn: Orta',
        contentTr: 'Diğer yön ve konum ifadeleri.',
      ),
    ],
    'emotions_1': [
      LessonSlide(
        id: 'emotions_1_s1',
        lessonId: 'emotions_1',
        order: 1,
        contentKu:
            'Hestên erênî:\n\n• Kêfxweş: Mutlu\n• Dilşad: Sevinçli\n• Evîndar: Aşık',
        contentTr: 'Olumlu duygu durumları.',
      ),
      LessonSlide(
        id: 'emotions_1_s2',
        lessonId: 'emotions_1',
        order: 2,
        contentKu:
            'Hestên civakî:\n\n• Aştî: Barış\n• Hêvî: Umut\n• Bawerî: İnanç / Güven',
        contentTr: 'Toplumsal olumlu kavramlar.',
      ),
    ],
    'emotions_2': [
      LessonSlide(
        id: 'emotions_2_s1',
        lessonId: 'emotions_2',
        order: 1,
        contentKu:
            'Hestên neyênî:\n\n• Xemgîn: Üzgün\n• Hêrsbûyî: Öfkeli\n• Tirsiyayî: Korkmuş',
        contentTr: 'Olumsuz duygu durumları.',
      ),
      LessonSlide(
        id: 'emotions_2_s2',
        lessonId: 'emotions_2',
        order: 2,
        contentKu:
            'Mînakên din:\n\n• Bêhêvî: Umutsuz\n• Dilşikestî: Kalbi kırık',
        contentTr: 'Diğer olumsuz duygu ifadeleri.',
      ),
    ],
    'time_1': [
      LessonSlide(
        id: 'time_1_s1',
        lessonId: 'time_1',
        order: 1,
        contentKu:
            'Rojên hefteyê:\n\n• Duşem (Pzt), Sêşem (Salı), Çarşem (Çar)\n• Pêncşem (Per), În (Cuma)\n• Şemî (Cmt), Yekşem (Paz)',
        contentTr: 'Haftanın günleri.',
      ),
      LessonSlide(
        id: 'time_1_s2',
        lessonId: 'time_1',
        order: 2,
        contentKu:
            'Mehên serê salê:\n\n• Rêbendan: Ocak, Reşemeh: Şubat, Adar: Mart\n• Nîsan: Nisan, Gulan: Mayıs, Hezîran: Haziran',
        contentTr: 'Yılın ilk 6 ayı.',
      ),
    ],
    'time_2': [
      LessonSlide(
        id: 'time_2_s1',
        lessonId: 'time_2',
        order: 1,
        contentKu:
            'Demên rojê:\n\n• Sibeh: Sabah\n• Nîvro: Öğle\n• Êvar: Akşam\n• Şev: Gece',
        contentTr: 'Günün bölümleri.',
      ),
      LessonSlide(
        id: 'time_2_s2',
        lessonId: 'time_2',
        order: 2,
        contentKu: 'Demên nêzîk:\n\n• Duh: Dün\n• Îro: Bugün\n• Sibe: Yarın',
        contentTr: 'Zaman belirteçleri.',
      ),
      LessonSlide(
        id: 'time_2_s3',
        lessonId: 'time_2',
        order: 3,
        contentKu: 'Çûn:\n\n• Çûn: Gitmek',
        contentTr: '"Ez diçim malê" = eve gidiyorum.',
        exampleKu: 'Îro ez diçim malê.',
      ),
    ],
  };

  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async {
    return _lessonsData[category] ?? const [];
  }

  @override
  Future<Map<String, dynamic>?> loadLesson(String lessonId) async {
    for (final list in _lessonsData.values) {
      for (final lesson in list) {
        if (lesson.id == lessonId) {
          return lesson.toJson();
        }
      }
    }
    return null;
  }

  @override
  Future<List<LessonSlide>> loadLessonSlides(String lessonId) async {
    return _slidesData[lessonId] ?? const [];
  }

  @override
  Future<bool> markLessonCompleted(String lessonId) async {
    _completedLessonIds.add(lessonId);
    return true;
  }

  final Set<String> _completedLessonIds = {};

  @override
  Future<Set<String>> loadCompletedLessonIds() async =>
      Set.of(_completedLessonIds);

  @override
  Future<bool> addFriend(String friendId, String friendName) async {
    return true;
  }

  String? lastFcmToken;

  @override
  Future<void> setFcmToken(String token) async {
    lastFcmToken = token;
  }

  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    return true;
  }

  @override
  Future<bool> rejectFriendRequest(String requestId) async {
    return true;
  }

  @override
  Future<List<PlayerSearchResult>> searchPlayers(String query) async {
    // `SupabaseZanKurdRepository.searchPlayers` düşer buraya gerçek RPC
    // hata verdiğinde (bkz. "searchPlayers failed" _recordError). Sahte
    // "Rojda/Rojhat/Berçem" havuzu, ağ hıçkırığı yaşayan gerçek bir
    // oyuncuya arkadaş olarak eklenebilecek üç hayalet profil gösteriyordu
    // — aynı sınıftan kusur `loadFriends`/`loadPendingFriendRequests`'te
    // zaten düzeltilmişti (2026-07-31 Antigravity eklentisi denetimi).
    return const [];
  }

  @override
  Future<List<Friend>> loadFriends() async {
    return const [];
  }

  @override
  Future<List<Friend>> loadFriendsLeaderboard() async {
    final friends = await loadFriends();
    friends.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    return friends;
  }

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async {
    return const [];
  }

  @override
  Future<bool> syncMissionCompletion(
    String missionKey,
    int coinReward,
    int xpReward,
  ) async => true;

  @override
  Future<bool> logAnalyticsEvent(
    String eventName,
    Map<String, dynamic>? params,
  ) async => true;

  @override
  Future<bool> saveTournamentProgress(
    String stage,
    int userScore,
    int opponentScore,
    List<String> botWinners,
  ) async => true;

  @override
  /// Sahte depoda gerçek turnuva yoktur: `null` döner ve ekran bot
  /// benzetimine düşer.
  @override
  Future<TournamentBracket?> joinRealTournament() async => null;

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => null;

  @override
  Future<TournamentBracket> joinTournament() async {
    final rounds = TournamentConfig.generateBracket();
    final bracket = TournamentBracket(
      tournamentId: 'mock_tournament_${DateTime.now().toIso8601String()}',
      userId: 'mock_user_123',
      rounds: rounds,
      currentRound: 0,
      status: 'active',
      totalScore: 0,
      botWinners: const [],
      createdAt: DateTime.now(),
    );
    return bracket;
  }

  @override
  Future<TournamentBracket?> loadTournamentBracket() async {
    final rounds = TournamentConfig.generateBracket();
    return TournamentBracket(
      tournamentId: 'mock_tournament_today',
      userId: 'mock_user_123',
      rounds: rounds,
      currentRound: 0,
      status: 'active',
      totalScore: 0,
      botWinners: const [],
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<TournamentMatch> submitTournamentMatch({
    required String matchId,
    required int playerScore,
    required int opponentScore,
  }) async {
    final winner = playerScore > opponentScore ? 'player' : 'opponent';
    return TournamentMatch(
      id: matchId,
      playerOneId: 'player_123',
      playerOneName: 'You',
      playerTwoId: 'bot_opponent',
      playerTwoName: 'Bot Opponent',
      playerOneScore: playerScore,
      playerTwoScore: opponentScore,
      status: 'completed',
      winnerId: winner == 'player' ? 'player_123' : 'bot_opponent',
      questionCategory: 'Ziman',
      questionsAnswered: 4,
    );
  }

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async {
    return [
      const TournamentStandings(
        rank: 1,
        playerId: 'player_001',
        playerName: 'Şampyon',
        totalScore: 400,
        status: 'champion',
      ),
      const TournamentStandings(
        rank: 2,
        playerId: 'player_002',
        playerName: 'İkinci',
        totalScore: 300,
        status: 'finalist',
      ),
      const TournamentStandings(
        rank: 3,
        playerId: 'player_003',
        playerName: 'Üçüncü',
        totalScore: 200,
        status: 'finalist',
      ),
    ];
  }

  @override
  Future<int> claimTournamentChampionReward() async {
    _mockCoins += TournamentConfig.coinBonusChampion;
    return TournamentConfig.coinBonusChampion;
  }

  @override
  Future<bool> submitSuggestedQuestion({
    required String category,
    required String prompt,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctOption,
    String? explanation,
    int difficulty = 3,
  }) async {
    // Mock: her zaman başarılı olarak dön.
    // Canlı ortamda Supabase 'suggested_questions' tablosuna yazılır.
    return true;
  }

  bool _mockReferralUsed = false;

  @override
  Future<ReferralResult> redeemReferralCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      return const ReferralResult(
        status: ReferralStatus.notFound,
        message: 'Invalid code',
      );
    }
    if (_mockReferralUsed) {
      return const ReferralResult(
        status: ReferralStatus.alreadyRedeemed,
        message: 'Already redeemed',
      );
    }
    if (clean == 'ZK-TEST' || clean == 'ZK-ME') {
      return const ReferralResult(
        status: ReferralStatus.ownCode,
        message: 'Cannot use own code',
      );
    }
    _mockReferralUsed = true;
    _mockCoins += 100;
    return const ReferralResult(
      status: ReferralStatus.success,
      coinsAwarded: 100,
      referrerName: 'ZanKurd Heval',
    );
  }
}
