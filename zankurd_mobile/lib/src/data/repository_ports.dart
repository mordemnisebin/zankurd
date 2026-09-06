part of 'zankurd_repository.dart';

/// Solo öğrenme/quiz yüzeyi. Yeni öğrenme kodu tam depoya değil buna bağlanır.
abstract interface class SoloQuizPort {
  List<String> get categories;
  List<QuizQuestion> get questions;
  List<QuizQuestion> get playableQuestions;

  Future<List<String>> loadCategories();
  Future<Map<String, int>> loadCategoryQuestionCounts();
  Future<List<QuizQuestion>> loadQuestions({
    String? categoryId,
    int limit = 10,
  });
  List<QuizLevel> levelsForCategory(String category);
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    String? subCategory,
    int limit = 10,
  });
  Future<List<QuizQuestion>> loadDailyQuestions({int limit = 10});
  Future<bool> toggleFavoriteQuestion(QuizQuestion question, bool favorite);
  Future<bool> isFavoriteQuestion(QuizQuestion question);
  Future<void> reportQuestion(QuizQuestion question, String reason);
  Future<List<QuizQuestion>> loadFavoriteQuestions();
  Future<QuizRewardClaim> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  });
  Future<int> awardXp(int delta);
  Future<List<Lesson>> loadLessonsByCategory(String category);
  Future<Map<String, dynamic>?> loadLesson(String lessonId);
  Future<List<LessonSlide>> loadLessonSlides(String lessonId);
  Future<bool> markLessonCompleted(String lessonId);
  Future<Set<String>> loadCompletedLessonIds();
}

/// Oda, eşleştirme ve turnuva yüzeyi. Yeni yarış kodu buna bağlanır.
abstract interface class LivePlayPort {
  List<String> get categories;
  Future<List<String>> loadMatchmakingCategories();
  Future<int> loadCoinBalance();
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room);
  GameRoom createRoom({String category = 'Ziman'});
  GameRoom joinRoom(String code);
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
    int questionCount = 10,
    int entryFee = 0,
  });
  Future<GameRoom> joinOnlineRoom(String code);
  Future<GameRoom> loadRoomSnapshot(String roomId);
  Future<RoomResumeSnapshot?> loadMyResumableRoom();
  Future<RoomResultSnapshot?> loadMyPendingRoomResult();
  Future<RoomResultSnapshot?> loadRoomResult(GameRoom room);
  Future<void> acknowledgeRoomResult(GameRoom room);
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room);
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  });
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room);
  Future<List<Player>> loadRoomPlayers(GameRoom room);
  Future<RoomStatus> loadRoomStatus(GameRoom room);
  Future<RoomEndState> loadRoomEndState(GameRoom room);
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room);
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room);
  Future<void> updateReady(GameRoom room, bool isReady);
  Future<void> startGame(GameRoom room);
  Future<void> finishGame(GameRoom room);
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  });
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName);
  Future<Map<String, dynamic>> cancelMatchmaking();
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue();
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId);
  Future<void> sendRoomBroadcast(String roomId, Map<String, dynamic> payload);
  Future<void> sendRoomMessage({required String roomId, required String text});
  Stream<List<RoomMessage>> subscribeRoomMessages(String roomId);
  Future<List<RoomMessage>> loadRoomMessages(String roomId);
  Future<TournamentBracket?> joinRealTournament();
  Future<TournamentBracket?> loadRealTournamentBracket();
  Future<TournamentBracket> joinTournament();
  Future<TournamentBracket?> loadTournamentBracket();
  Future<TournamentMatch> submitTournamentMatch({
    required String matchId,
    required int playerScore,
    required int opponentScore,
  });
  Future<List<TournamentStandings>> loadTournamentStandings({int limit = 16});
  Future<int> claimTournamentChampionReward();
  Future<int> claimTournamentReward();
}
