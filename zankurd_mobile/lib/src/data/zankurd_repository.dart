import '../models/player.dart';
import '../models/quiz_level.dart';
import '../models/quiz_question.dart';
import '../models/leaderboard_entry.dart';
import '../models/room.dart';

abstract class ZanKurdRepository {
  List<String> get categories;
  List<QuizQuestion> get questions;

  Future<void> ensureProfile();
  Future<String> getProfileName();
  Future<void> updateProfileName(String name);
  Future<LeaderboardEntry?> getPlayerStats();
  Future<List<String>> loadCategories();
  Future<List<QuizQuestion>> loadQuestions({
    String? categoryId,
    int limit = 10,
  });
  List<QuizLevel> levelsForCategory(String category);
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    int limit = 10,
  });
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room);

  GameRoom createRoom({String category = 'Ziman'});
  GameRoom joinRoom(String code);
  Future<GameRoom> createOnlineRoom({String category = 'Ziman'});
  Future<GameRoom> joinOnlineRoom(String code);
  Future<List<Player>> loadRoomPlayers(GameRoom room);

  Stream<List<Player>> subscribeRoomPlayers(GameRoom room);
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room);
  Future<void> updateReady(GameRoom room, bool isReady);
  Future<void> startGame(GameRoom room);
  Future<void> finishGame(GameRoom room);
  Future<int> getProfileCoins();
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    int responseMs = 2000,
  });
  Future<bool> toggleFavoriteQuestion(QuizQuestion question, bool favorite);
  Future<void> reportQuestion(QuizQuestion question, String reason);
  Future<List<LeaderboardEntry>> loadLeaderboard({int limit = 50});
  Future<List<QuizQuestion>> loadFavoriteQuestions();
}

