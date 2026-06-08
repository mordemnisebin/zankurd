import 'dart:async';

import '../models/leaderboard_entry.dart';
import '../models/player.dart';
import '../models/quiz_level.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
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
  ];

  @override
  List<QuizQuestion> get questions => const [
    QuizQuestion(
      id: 'q_001',
      category: 'Ziman',
      prompt: 'Di Kurmancî de peyva "zanîn" bi Tirkî çi ye?',
      answers: ['Bilmek', 'Gitmek', 'Okumak', 'Yazmak'],
      correctAnswer: 'Bilmek',
      explanation: '"Zanîn" bilgi ve bilmek anlamına gelir.',
      difficulty: 1,
    ),
    QuizQuestion(
      id: 'q_002',
      category: 'Çand',
      prompt: 'Newroz bi gelemperî kîjan rojê tê pîroz kirin?',
      answers: ['21 Adar', '1 Gulan', '15 Hezîran', '29 Cotmeh'],
      correctAnswer: '21 Adar',
      explanation: 'Newroz baharın gelişini simgeleyen 21 Mart günüdür.',
      type: QuestionType.visual,
      imageUrl: 'https://placehold.co/900x520/png?text=Newroz',
      difficulty: 1,
    ),
    QuizQuestion(
      id: 'q_003',
      category: 'Edebiyat',
      prompt: 'Mem û Zîn kimin eseri olarak bilinir?',
      answers: ['Ehmedê Xanî', 'Cegerxwîn', 'Melayê Cizîrî', 'Feqiyê Teyran'],
      correctAnswer: 'Ehmedê Xanî',
      explanation: 'Mem û Zîn, Ehmedê Xanî ile özdeşleşmiş klasik eserdir.',
      difficulty: 2,
    ),
    QuizQuestion(
      id: 'q_004',
      category: 'Dîrok',
      prompt: 'Medler Mezopotamya tarihinde önemli bir halktır.',
      answers: ['Rast', 'Şaş'],
      correctAnswer: 'Rast',
      explanation: 'Medler bölge tarihinin önemli siyasi topluluklarındandır.',
      type: QuestionType.trueFalse,
      difficulty: 2,
    ),
    QuizQuestion(
      id: 'q_005',
      category: 'Cografya',
      prompt: 'Görseldeki dağlık coğrafya en çok hangi bölge tipini anlatır?',
      answers: ['Çiya', 'Deşt', 'Gol', 'Daristan'],
      correctAnswer: 'Çiya',
      explanation: 'Çiya Kurmancîde dağ anlamına gelir.',
      type: QuestionType.visual,
      imageUrl: 'https://placehold.co/900x520/png?text=%C3%87iya',
      difficulty: 1,
    ),
    QuizQuestion(
      id: 'q_006',
      category: 'Muzîk',
      prompt: 'Dengbêj geleneği daha çok sözlü anlatım ve ezgiyle ilişkilidir.',
      answers: ['Rast', 'Şaş'],
      correctAnswer: 'Rast',
      explanation: 'Dengbêjlik sözlü kültür ve ezgili anlatım geleneğidir.',
      type: QuestionType.trueFalse,
      difficulty: 1,
    ),
  ];

  String _mockName = 'ZanKurd Oyuncusu';

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
    return questions.take(limit).toList();
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

    return (filtered.isEmpty ? questions : filtered).take(limit).toList();
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    return questions.take(room.questionCount).toList();
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
  Future<List<LeaderboardEntry>> loadLeaderboard({int limit = 50}) async {
    const entries = [
      LeaderboardEntry(
        rank: 1,
        playerId: 'mock_rojda',
        displayName: 'Rojda',
        totalScore: 12840,
        bestStreak: 11,
        roomsPlayed: 18,
      ),
      LeaderboardEntry(
        rank: 2,
        playerId: 'mock_baran',
        displayName: 'Baran',
        totalScore: 11720,
        bestStreak: 9,
        roomsPlayed: 16,
      ),
      LeaderboardEntry(
        rank: 3,
        playerId: 'mock_dilan',
        displayName: 'Dilan',
        totalScore: 10490,
        bestStreak: 8,
        roomsPlayed: 14,
      ),
      LeaderboardEntry(
        rank: 4,
        playerId: 'mock_azad',
        displayName: 'Azad',
        totalScore: 9360,
        bestStreak: 7,
        roomsPlayed: 12,
      ),
      LeaderboardEntry(
        rank: 5,
        playerId: 'mock_berfin',
        displayName: 'Berfin',
        totalScore: 8840,
        bestStreak: 6,
        roomsPlayed: 11,
      ),
    ];

    return entries.take(limit).toList();
  }
}
