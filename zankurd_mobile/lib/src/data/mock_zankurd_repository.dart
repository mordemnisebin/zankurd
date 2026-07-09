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
import '../models/tournament.dart';
import '../utils/coin_calculator.dart';
import 'offline_question_bank.dart';
import 'seen_question_store.dart';
import 'zankurd_repository.dart';
import '../config/subcategory_config.dart';

class MockZanKurdRepository implements ZanKurdRepository {
  MockZanKurdRepository();

  @override
  List<String> get categories => const [
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
    'Siyaset',
    'Paradigma',
  ];

  @override
  List<QuizQuestion> get questions => offlineQuestionBank;

  @override
  String? get currentUserId => 'user';

  String _mockName = 'ZanKurd Oyuncusu';
  int _mockCoins = 2450;
  int _mockExtraSpins = 0;
  int _mockUsedExtraSpins = 0;
  final Set<String> _mockPurchases = {};

  final List<LeaderboardEntry> _mockLeaderboard = [
    const LeaderboardEntry(
      rank: 1,
      playerId: 'player_001',
      displayName: 'ZanKurd Champion',
      totalScore: 5000,
      bestStreak: 25,
      roomsPlayed: 50,
    ),
    const LeaderboardEntry(
      rank: 2,
      playerId: 'player_002',
      displayName: 'Kurmancî Master',
      totalScore: 4500,
      bestStreak: 20,
      roomsPlayed: 45,
    ),
    const LeaderboardEntry(
      rank: 3,
      playerId: 'player_003',
      displayName: 'Quiz Legend',
      totalScore: 4000,
      bestStreak: 18,
      roomsPlayed: 40,
    ),
  ];

  @override
  Future<void> ensureProfile() async {}

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
    return _mockLeaderboard.first;
  }

  @override
  Future<List<String>> loadCategories() async => categories;

  @override
  Future<List<QuizQuestion>> loadQuestions({
    String? categoryId,
    int limit = 10,
  }) async {
    final pool = categoryId == null
        ? questions
        : questions
              .where((question) => question.category == categoryId)
              .toList(growable: false);
    return _selectFresh(pool.isEmpty ? questions : pool, limit);
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
    final byCategoryAndDifficulty = questions
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

    return _selectFresh(pool.isEmpty ? questions : pool, limit);
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    final pool = questions
        .where((question) => question.category == room.category)
        .toList(growable: false);
    return _selectFresh(pool.isEmpty ? questions : pool, room.questionCount);
  }

  /// Gün bazlı sabit tohum: aynı gün herkes aynı sırayı görür.
  static int dailySeed() {
    final now = DateTime.now().toUtc();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  @override
  Future<List<QuizQuestion>> loadDailyQuestions({int limit = 10}) async {
    final pool = [...questions]..shuffle(Random(dailySeed()));
    return _withVisualBlend(pool.take(limit).toList(), questions, limit);
  }

  /// Görülmemiş soruları öne alan tekrar-önleyici seçim.
  Future<List<QuizQuestion>> _selectFresh(
    List<QuizQuestion> pool,
    int limit,
  ) async {
    if (pool.isEmpty || limit <= 0) return const [];
    final store = await SeenQuestionStore.load();
    final selected = store.preferUnseen(pool, limit);
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
        Player(name: 'Rojda', score: 1240, state: 'Hazır', streak: 4),
        Player(name: 'Baran', score: 1180, state: 'Cevapladı', streak: 3),
        Player(name: 'Dilan', score: 960, state: 'Bekliyor', streak: 2),
      ],
    );
  }

  @override
  GameRoom joinRoom(String code) {
    final cleanCode = code.trim().isEmpty
        ? 'ZK-4821'
        : code.trim().toUpperCase();
    return createRoom().copyWith(code: cleanCode);
  }

  @override
  Future<GameRoom> createOnlineRoom({String category = 'Ziman'}) async {
    return createRoom(category: category);
  }

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    return joinRoom(code);
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    return room.players;
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

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    final correctIndex = question.answers.indexOf(question.correctAnswer);
    final correctOptionKey = switch (correctIndex) {
      0 => 'A',
      1 => 'B',
      2 => 'C',
      _ => 'D',
    };

    final isCorrect = selectedOptionOptionKey == correctOptionKey;
    return {'is_correct': isCorrect, 'points': isCorrect ? 100 : 0};
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
  Future<void> updateProfileXP(int xp) async {
    // Mock modunda yerel XPStore güncelleniyor, sunucu güncellemesine gerek yok.
  }

  @override
  Future<int> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    final earned = _calculateCoinAward(
      score: score,
      correctCount: correctCount,
      bestStreak: bestStreak,
      totalQuestions: totalQuestions,
    );
    _mockCoins += earned;
    return earned;
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
    await Future.delayed(const Duration(milliseconds: 300));
    final all = [
      if (period == LeaderboardPeriod.daily) ...[
        const LeaderboardEntry(
          rank: 1,
          playerId: 'm1',
          displayName: 'Berfin',
          totalScore: 1240,
          bestStreak: 8,
          roomsPlayed: 3,
        ),
        const LeaderboardEntry(
          rank: 2,
          playerId: 'm2',
          displayName: 'Azad',
          totalScore: 980,
          bestStreak: 6,
          roomsPlayed: 2,
        ),
        const LeaderboardEntry(
          rank: 3,
          playerId: 'm3',
          displayName: 'Rojda',
          totalScore: 870,
          bestStreak: 5,
          roomsPlayed: 2,
        ),
        const LeaderboardEntry(
          rank: 4,
          playerId: 'm4',
          displayName: 'Baran',
          totalScore: 760,
          bestStreak: 4,
          roomsPlayed: 2,
        ),
        const LeaderboardEntry(
          rank: 5,
          playerId: 'm5',
          displayName: 'Dilan',
          totalScore: 640,
          bestStreak: 3,
          roomsPlayed: 1,
        ),
        const LeaderboardEntry(
          rank: 6,
          playerId: 'm6',
          displayName: 'Sero',
          totalScore: 580,
          bestStreak: 3,
          roomsPlayed: 1,
        ),
        const LeaderboardEntry(
          rank: 7,
          playerId: 'm7',
          displayName: 'Narin',
          totalScore: 520,
          bestStreak: 2,
          roomsPlayed: 1,
        ),
        const LeaderboardEntry(
          rank: 8,
          playerId: 'm8',
          displayName: 'Hogir',
          totalScore: 480,
          bestStreak: 2,
          roomsPlayed: 1,
        ),
        const LeaderboardEntry(
          rank: 9,
          playerId: 'm9',
          displayName: 'Çiçek',
          totalScore: 420,
          bestStreak: 2,
          roomsPlayed: 1,
        ),
        const LeaderboardEntry(
          rank: 10,
          playerId: 'ma',
          displayName: 'Welat',
          totalScore: 380,
          bestStreak: 1,
          roomsPlayed: 1,
        ),
      ] else if (period == LeaderboardPeriod.weekly) ...[
        const LeaderboardEntry(
          rank: 1,
          playerId: 'm1',
          displayName: 'Rojda',
          totalScore: 8420,
          bestStreak: 11,
          roomsPlayed: 14,
        ),
        const LeaderboardEntry(
          rank: 2,
          playerId: 'm2',
          displayName: 'Baran',
          totalScore: 7190,
          bestStreak: 9,
          roomsPlayed: 12,
        ),
        const LeaderboardEntry(
          rank: 3,
          playerId: 'm3',
          displayName: 'Dilan',
          totalScore: 6540,
          bestStreak: 8,
          roomsPlayed: 10,
        ),
        const LeaderboardEntry(
          rank: 4,
          playerId: 'm4',
          displayName: 'Azad',
          totalScore: 5870,
          bestStreak: 7,
          roomsPlayed: 9,
        ),
        const LeaderboardEntry(
          rank: 5,
          playerId: 'm5',
          displayName: 'Berfin',
          totalScore: 5320,
          bestStreak: 6,
          roomsPlayed: 8,
        ),
        const LeaderboardEntry(
          rank: 6,
          playerId: 'm6',
          displayName: 'Narin',
          totalScore: 4760,
          bestStreak: 5,
          roomsPlayed: 7,
        ),
        const LeaderboardEntry(
          rank: 7,
          playerId: 'm7',
          displayName: 'Sero',
          totalScore: 4180,
          bestStreak: 5,
          roomsPlayed: 6,
        ),
        const LeaderboardEntry(
          rank: 8,
          playerId: 'm8',
          displayName: 'Hogir',
          totalScore: 3640,
          bestStreak: 4,
          roomsPlayed: 5,
        ),
        const LeaderboardEntry(
          rank: 9,
          playerId: 'm9',
          displayName: 'Çiçek',
          totalScore: 3120,
          bestStreak: 3,
          roomsPlayed: 4,
        ),
        const LeaderboardEntry(
          rank: 10,
          playerId: 'ma',
          displayName: 'Welat',
          totalScore: 2680,
          bestStreak: 3,
          roomsPlayed: 4,
        ),
      ] else ...[
        const LeaderboardEntry(
          rank: 1,
          playerId: 'm1',
          displayName: 'Rojda',
          totalScore: 32840,
          bestStreak: 18,
          roomsPlayed: 54,
        ),
        const LeaderboardEntry(
          rank: 2,
          playerId: 'm2',
          displayName: 'Baran',
          totalScore: 28720,
          bestStreak: 15,
          roomsPlayed: 48,
        ),
        const LeaderboardEntry(
          rank: 3,
          playerId: 'm3',
          displayName: 'Dilan',
          totalScore: 24490,
          bestStreak: 13,
          roomsPlayed: 42,
        ),
        const LeaderboardEntry(
          rank: 4,
          playerId: 'm4',
          displayName: 'Azad',
          totalScore: 21360,
          bestStreak: 12,
          roomsPlayed: 38,
        ),
        const LeaderboardEntry(
          rank: 5,
          playerId: 'm5',
          displayName: 'Berfin',
          totalScore: 18840,
          bestStreak: 10,
          roomsPlayed: 34,
        ),
        const LeaderboardEntry(
          rank: 6,
          playerId: 'm6',
          displayName: 'Narin',
          totalScore: 16200,
          bestStreak: 9,
          roomsPlayed: 30,
        ),
        const LeaderboardEntry(
          rank: 7,
          playerId: 'm7',
          displayName: 'Sero',
          totalScore: 14100,
          bestStreak: 8,
          roomsPlayed: 26,
        ),
        const LeaderboardEntry(
          rank: 8,
          playerId: 'm8',
          displayName: 'Hogir',
          totalScore: 12400,
          bestStreak: 7,
          roomsPlayed: 22,
        ),
        const LeaderboardEntry(
          rank: 9,
          playerId: 'm9',
          displayName: 'Çiçek',
          totalScore: 10800,
          bestStreak: 6,
          roomsPlayed: 18,
        ),
        const LeaderboardEntry(
          rank: 10,
          playerId: 'ma',
          displayName: 'Welat',
          totalScore: 9300,
          bestStreak: 5,
          roomsPlayed: 16,
        ),
      ],
    ];
    return all.take(limit).toList();
  }

  static const _avatarIdentityKey = 'zankurd.avatarIdentity';

  @override
  Future<AvatarIdentity> loadAvatarIdentity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_avatarIdentityKey);
      if (raw == null || raw.isEmpty) return const AvatarIdentity();
      return AvatarIdentity.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AvatarIdentity();
    }
  }

  @override
  Future<void> updateAvatarIdentity(AvatarIdentity identity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarIdentityKey, jsonEncode(identity.toJson()));
    } catch (_) {
      // Offline/test ortamında sessizce yut; kozmetik veri kritik değil.
    }
  }

  @override
  Future<String> uploadAvatarPhoto(Uint8List bytes, String contentType) async {
    // Mock modda gerçek depolama yok; kalıcı olmayan yerel bir işaret döner.
    return 'mock://avatar/${bytes.length}';
  }

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    return const {'status': 'waiting'};
  }

  @override
  Future<void> cancelMatchmaking() async {}

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
      themeNameKu: 'Ziman Eksperi',
      themeDescriptionKu: 'Dil usta ol!',
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
    return const [
      ContestLeaderboardRow(
        userId: 'user1',
        displayName: 'Rojda',
        score: 1000,
        correctCount: 10,
        rank: 1,
      ),
      ContestLeaderboardRow(
        userId: 'user2',
        displayName: 'Baran',
        score: 900,
        correctCount: 9,
        rank: 2,
      ),
      ContestLeaderboardRow(
        userId: 'user3',
        displayName: 'Dilan',
        score: 800,
        correctCount: 8,
        rank: 3,
      ),
    ];
  }

  @override
  Future<List<UserContestBadge>> loadUserContestBadges() async {
    return const [];
  }

  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async {
    return [
      Lesson(
        id: 'lesson_1',
        slug: 'alphabet',
        titleKu: 'Alfabê',
        titleTr: 'Alfabe',
        category: category,
        iconName: 'abc',
      ),
      Lesson(
        id: 'lesson_2',
        slug: 'numbers',
        titleKu: 'Hejmar',
        titleTr: 'Sayılar',
        category: category,
        iconName: '123',
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>?> loadLesson(String lessonId) async {
    return {
      'id': lessonId,
      'slug': 'alphabet',
      'title_ku': 'Alfabê',
      'category': 'everyday',
    };
  }

  @override
  Future<List<LessonSlide>> loadLessonSlides(String lessonId) async {
    return [
      LessonSlide(
        id: 'slide_1',
        lessonId: lessonId,
        order: 1,
        contentKu: 'A, B, C, Ç, D, E, Ê, F, G, H',
      ),
      LessonSlide(
        id: 'slide_2',
        lessonId: lessonId,
        order: 2,
        contentKu: 'I, Î, J, K, L, M, N, O, Ö, P',
      ),
    ];
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
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    const pool = [
      PlayerSearchResult(
        id: 'search-user-1',
        displayName: 'Rojda',
        avatarColor: '#2AA6A1',
      ),
      PlayerSearchResult(
        id: 'search-user-2',
        displayName: 'Rojhat',
        avatarColor: '#E94560',
      ),
      PlayerSearchResult(
        id: 'search-user-3',
        displayName: 'Berçem',
        avatarColor: '#6F61C0',
      ),
    ];
    return pool.where((p) => p.displayName.toLowerCase().contains(q)).toList();
  }

  @override
  Future<List<Friend>> loadFriends() async {
    return [
      Friend(
        id: 'friend1',
        userId: 'user1',
        friendId: 'friend-user-1',
        friendName: 'ZanînBot',
        friendAvatarColor: '#E94560',
        createdAt: DateTime.now(),
      ),
      Friend(
        id: 'friend2',
        userId: 'user1',
        friendId: 'friend-user-2',
        friendName: 'KurdBot',
        friendAvatarColor: '#6F61C0',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async {
    return [
      FriendRequest(
        id: 'req1',
        fromUserId: 'friend-user-3',
        fromUserName: 'Diyar',
        toUserId: 'user1',
        createdAt: DateTime.now(),
        status: 'pending',
      ),
    ];
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
  Future<TournamentBracket> joinTournament() async {
    final rounds = TournamentConfig.generateBracket();
    final bracket = TournamentBracket(
      tournamentId: 'mock_tournament_${DateTime.now().toIso8601String()}',
      userId: 'mock_user_123',
      rounds: rounds,
      currentRound: 0,
      status: 'active',
      totalScore: 0,
      botWinners: [],
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
      botWinners: [],
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
}
