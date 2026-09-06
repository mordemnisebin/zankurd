import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

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
import 'question_bank_loader.dart';
import 'seen_question_store.dart';
import 'zankurd_repository.dart';
import '../config/subcategory_config.dart';
import '../config/category_visibility.dart';
import '../services/question_set_policy.dart';
import '../services/question_content_policy.dart';

class MockZanKurdRepository implements ZanKurdRepository {
  MockZanKurdRepository();

  static const _contentPolicy = QuestionContentPolicy();

  List<QuizQuestion> get _playableQuestions =>
      questions.where(_contentPolicy.isPlayable).toList(growable: false);

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
    // Çevrimdışı depoda sabit bir kod: ekranın kodu nasıl gösterdiği
    // testlerde ve turda görünür olsun, ama gerçek bir kodmuş gibi
    // davranmasın.
    return 'DEMO';
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
  List<QuizLevel> levelsForCategory(String category) {
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
    int limit = 10,
  }) async {
    final playable = _playableQuestions;
    final byCategoryAndDifficulty = playable
        .where(
          (question) =>
              question.category == category &&
              question.difficulty >= difficultyMin &&
              question.difficulty <= difficultyMax,
        )
        .toList();

    var pool = byCategoryAndDifficulty;
    if (subCategory != null) {
      final matched = byCategoryAndDifficulty
          .where((q) => SubcategoryConfig.getSubcategoryId(q) == subCategory)
          .toList();
      // Alt kategori etiketi gerçek bir alan değil, id hash'inden türetilir;
      // eşleşen sayı limit'in altında kalırsa aynı kategori+zorluktaki diğer
      // sorularla tamamla, seviyeyi eksik soruyla bitirme.
      if (matched.length < limit) {
        final matchedIds = matched.map((q) => q.id).toSet();
        final need = limit - matched.length;
        final fillers = byCategoryAndDifficulty
            .where((q) => !matchedIds.contains(q.id))
            .take(need * 3);
        pool = [...matched, ...fillers];
      } else {
        pool = matched;
      }
    }

    // İlk iki basamak (Destpêk / Bingeh) bir öğrenme yolunun girişidir:
    // bankadaki `difficulty` etiketi konu zorluğunu anlatır ama okuma
    // yükünü yansıtmaz — ölçümde zorluk 1'in şık uzunluğu medyanı tüm
    // seviyelerin en yükseğiydi (2026-07-25). Havuz, aynı zorluk bandı
    // içinde en hafif okunan sorular öne gelecek biçimde sıralanır.
    final ordered = difficultyMax <= 2
        ? QuestionSetPolicy.byReadingLoad(pool.isEmpty ? playable : pool)
        : (pool.isEmpty ? playable : pool);
    return _selectFresh(ordered, limit);
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    final playable = _playableQuestions;
    final pool = playable
        .where((question) => question.category == room.category)
        .toList(growable: false);
    return _selectFresh(pool.isEmpty ? playable : pool, room.questionCount);
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
    final pool = [...playable]..shuffle(Random(dailySeedFor(currentUserId)));
    return _withVisualBlend(pool.take(limit).toList(), playable, limit);
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
    final clean = QuestionSetPolicy.withoutLeaks(candidates, limit: limit);

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
  Future<void> reportQuestion(QuizQuestion question, String reason) async {}

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
  Future<int> awardXp(int delta) async {
    if (delta <= 0) return awardedXpTotal;
    awardedXpTotal += delta;
    return awardedXpTotal;
  }

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
        id: 'everyday_1',
        slug: 'everyday_1',
        titleKu: 'Silavkirin',
        titleTr: 'Selamlaşma',
        category: 'everyday',
        iconName: 'waving_hand',
        order: 1,
      ),
      Lesson(
        id: 'everyday_2',
        slug: 'everyday_2',
        titleKu: 'Nasandin',
        titleTr: 'Tanışma',
        category: 'everyday',
        iconName: 'handshake',
        order: 2,
      ),
      Lesson(
        id: 'everyday_3',
        slug: 'everyday_3',
        titleKu: 'Pratikên Rojane',
        titleTr: 'Günlük Pratik İfadeler',
        category: 'everyday',
        iconName: 'forum',
        order: 3,
      ),
    ],
    'grammar': [
      Lesson(
        id: 'grammar_1',
        slug: 'grammar_1',
        titleKu: 'Cînavkên Kesane',
        titleTr: 'Şahıs Zamirleri',
        category: 'grammar',
        iconName: 'g_translate',
        order: 1,
      ),
      Lesson(
        id: 'grammar_2',
        slug: 'grammar_2',
        titleKu: 'Tewandin',
        titleTr: 'Büküm (Hal Çekimi)',
        category: 'grammar',
        iconName: 'sort_by_alpha',
        order: 2,
      ),
    ],
    'culture': [
      Lesson(
        id: 'culture_1',
        slug: 'culture_1',
        titleKu: 'Folklor û Govend',
        titleTr: 'Folklor & Halay',
        category: 'culture',
        iconName: 'music_note',
        order: 1,
      ),
      Lesson(
        id: 'culture_2',
        slug: 'culture_2',
        titleKu: 'Cejn û Cejndarî',
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
        titleKu: 'Xwarinên Bingehîn',
        titleTr: 'Temel Yemekler',
        category: 'food',
        iconName: 'restaurant',
        order: 1,
      ),
      Lesson(
        id: 'food_2',
        slug: 'food_2',
        titleKu: 'Fêkî û Keskahî',
        titleTr: 'Meyve & Sebzeler',
        category: 'food',
        iconName: 'local_grocery_store',
        order: 2,
      ),
    ],
    'animals': [
      Lesson(
        id: 'animals_1',
        slug: 'animals_1',
        titleKu: 'Heywanên Malê',
        titleTr: 'Evcil Hayvanlar',
        category: 'animals',
        iconName: 'pets',
        order: 1,
      ),
      Lesson(
        id: 'animals_2',
        slug: 'animals_2',
        titleKu: 'Heywanên Kovî',
        titleTr: 'Yabani Hayvanlar',
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
        titleKu: 'Aliyên Erdnîgarî',
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
        titleKu: 'Hestên Erênî',
        titleTr: 'Olumlu Duygular',
        category: 'emotions',
        iconName: 'sentiment_very_satisfied',
        order: 1,
      ),
      Lesson(
        id: 'emotions_2',
        slug: 'emotions_2',
        titleKu: 'Hestên Neyînî',
        titleTr: 'Olumsuz Duygular',
        category: 'emotions',
        iconName: 'sentiment_very_dissatisfied',
        order: 2,
      ),
    ],
    'time': [
      Lesson(
        id: 'time_1',
        slug: 'time_1',
        titleKu: 'Roj û Meh',
        titleTr: 'Günler & Aylar',
        category: 'time',
        iconName: 'calendar_month',
        order: 1,
      ),
      Lesson(
        id: 'time_2',
        slug: 'time_2',
        titleKu: 'Serdem û Demjimêr',
        titleTr: 'Zaman Dilimleri',
        category: 'time',
        iconName: 'schedule',
        order: 2,
      ),
    ],
  };

  static const Map<String, List<LessonSlide>> _slidesData = {
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
            'Mehên serê salê:\n\n• Rêbendan (Ocak), Reşemeh (Şubat), Adar (Mart)\n• Nîsan (Nisan), Gulan (Mayıs), Hezîran (Haziran)',
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
