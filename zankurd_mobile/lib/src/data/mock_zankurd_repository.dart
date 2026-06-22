import 'dart:async';
import 'dart:math';

import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/player.dart';
import '../models/quiz_level.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../utils/coin_calculator.dart';
import 'offline_question_bank.dart';
import 'seen_question_store.dart';
import 'zankurd_repository.dart';

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

  String _mockName = 'ZanKurd Oyuncusu';
  int _mockCoins = 2450;

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
        difficultyMin: 1,
        difficultyMax: 1,
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
    int limit = 10,
  }) async {
    final filtered = questions
        .where(
          (question) =>
              question.category == category &&
              question.difficulty >= difficultyMin &&
              question.difficulty <= difficultyMax,
        )
        .toList();

    return _selectFresh(filtered.isEmpty ? questions : filtered, limit);
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
      code: 'ZK-${DateTime.now().millisecond.toString().padLeft(3, '0')}',
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

  @override
  Future<bool> toggleFavoriteQuestion(
    QuizQuestion question,
    bool favorite,
  ) async {
    return favorite;
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
    if (last == null) return true;
    final now = DateTime.now().toUtc();
    return last.year != now.year ||
        last.month != now.month ||
        last.day != now.day;
  }

  @override
  Future<int> awardSpinCoins() async {
    const rewards = [10, 25, 50, 15, 75, 20, 100, 30];
    final amount = rewards[Random().nextInt(rewards.length)];
    _lastSpin = DateTime.now().toUtc();
    _mockCoins += amount;
    return amount;
  }

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    if (_mockCoins < amount) return false;
    _mockCoins -= amount;
    return true;
  }

  @override
  Future<void> addCoins(int amount, String reason) async {
    if (amount > 0) _mockCoins += amount;
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
        const LeaderboardEntry(rank: 1, playerId: 'm1', displayName: 'Berfin',   totalScore: 1240, bestStreak: 8,  roomsPlayed: 3),
        const LeaderboardEntry(rank: 2, playerId: 'm2', displayName: 'Azad',     totalScore: 980,  bestStreak: 6,  roomsPlayed: 2),
        const LeaderboardEntry(rank: 3, playerId: 'm3', displayName: 'Rojda',    totalScore: 870,  bestStreak: 5,  roomsPlayed: 2),
        const LeaderboardEntry(rank: 4, playerId: 'm4', displayName: 'Baran',    totalScore: 760,  bestStreak: 4,  roomsPlayed: 2),
        const LeaderboardEntry(rank: 5, playerId: 'm5', displayName: 'Dilan',    totalScore: 640,  bestStreak: 3,  roomsPlayed: 1),
        const LeaderboardEntry(rank: 6, playerId: 'm6', displayName: 'Sero',     totalScore: 580,  bestStreak: 3,  roomsPlayed: 1),
        const LeaderboardEntry(rank: 7, playerId: 'm7', displayName: 'Narin',    totalScore: 520,  bestStreak: 2,  roomsPlayed: 1),
        const LeaderboardEntry(rank: 8, playerId: 'm8', displayName: 'Hogir',    totalScore: 480,  bestStreak: 2,  roomsPlayed: 1),
        const LeaderboardEntry(rank: 9, playerId: 'm9', displayName: 'Çiçek',    totalScore: 420,  bestStreak: 2,  roomsPlayed: 1),
        const LeaderboardEntry(rank:10, playerId: 'ma', displayName: 'Welat',    totalScore: 380,  bestStreak: 1,  roomsPlayed: 1),
      ] else if (period == LeaderboardPeriod.weekly) ...[
        const LeaderboardEntry(rank: 1, playerId: 'm1', displayName: 'Rojda',    totalScore: 8420, bestStreak: 11, roomsPlayed: 14),
        const LeaderboardEntry(rank: 2, playerId: 'm2', displayName: 'Baran',    totalScore: 7190, bestStreak: 9,  roomsPlayed: 12),
        const LeaderboardEntry(rank: 3, playerId: 'm3', displayName: 'Dilan',    totalScore: 6540, bestStreak: 8,  roomsPlayed: 10),
        const LeaderboardEntry(rank: 4, playerId: 'm4', displayName: 'Azad',     totalScore: 5870, bestStreak: 7,  roomsPlayed: 9),
        const LeaderboardEntry(rank: 5, playerId: 'm5', displayName: 'Berfin',   totalScore: 5320, bestStreak: 6,  roomsPlayed: 8),
        const LeaderboardEntry(rank: 6, playerId: 'm6', displayName: 'Narin',    totalScore: 4760, bestStreak: 5,  roomsPlayed: 7),
        const LeaderboardEntry(rank: 7, playerId: 'm7', displayName: 'Sero',     totalScore: 4180, bestStreak: 5,  roomsPlayed: 6),
        const LeaderboardEntry(rank: 8, playerId: 'm8', displayName: 'Hogir',    totalScore: 3640, bestStreak: 4,  roomsPlayed: 5),
        const LeaderboardEntry(rank: 9, playerId: 'm9', displayName: 'Çiçek',    totalScore: 3120, bestStreak: 3,  roomsPlayed: 4),
        const LeaderboardEntry(rank:10, playerId: 'ma', displayName: 'Welat',    totalScore: 2680, bestStreak: 3,  roomsPlayed: 4),
      ] else ...[
        const LeaderboardEntry(rank: 1, playerId: 'm1', displayName: 'Rojda',    totalScore: 32840, bestStreak: 18, roomsPlayed: 54),
        const LeaderboardEntry(rank: 2, playerId: 'm2', displayName: 'Baran',    totalScore: 28720, bestStreak: 15, roomsPlayed: 48),
        const LeaderboardEntry(rank: 3, playerId: 'm3', displayName: 'Dilan',    totalScore: 24490, bestStreak: 13, roomsPlayed: 42),
        const LeaderboardEntry(rank: 4, playerId: 'm4', displayName: 'Azad',     totalScore: 21360, bestStreak: 12, roomsPlayed: 38),
        const LeaderboardEntry(rank: 5, playerId: 'm5', displayName: 'Berfin',   totalScore: 18840, bestStreak: 10, roomsPlayed: 34),
        const LeaderboardEntry(rank: 6, playerId: 'm6', displayName: 'Narin',    totalScore: 16200, bestStreak: 9,  roomsPlayed: 30),
        const LeaderboardEntry(rank: 7, playerId: 'm7', displayName: 'Sero',     totalScore: 14100, bestStreak: 8,  roomsPlayed: 26),
        const LeaderboardEntry(rank: 8, playerId: 'm8', displayName: 'Hogir',    totalScore: 12400, bestStreak: 7,  roomsPlayed: 22),
        const LeaderboardEntry(rank: 9, playerId: 'm9', displayName: 'Çiçek',    totalScore: 10800, bestStreak: 6,  roomsPlayed: 18),
        const LeaderboardEntry(rank:10, playerId: 'ma', displayName: 'Welat',    totalScore:  9300, bestStreak: 5,  roomsPlayed: 16),
      ],
    ];
    return all.take(limit).toList();
  }
}
