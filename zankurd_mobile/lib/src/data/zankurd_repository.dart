import '../models/leaderboard_entry.dart';
import '../models/leaderboard_period.dart';
import '../models/player.dart';
import '../models/quiz_level.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';

abstract class ZanKurdRepository {
  List<String> get categories;
  List<QuizQuestion> get questions;

  Future<void> ensureProfile();
  Future<String> getProfileName();
  Future<void> updateProfileName(String name);
  Future<void> deleteMyAccount();
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

  /// Aynı gün içinde herkese aynı soru setini verir (tarih tohumlu seçim).
  Future<List<QuizQuestion>> loadDailyQuestions({int limit = 10});

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
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
  });
  Future<bool> toggleFavoriteQuestion(QuizQuestion question, bool favorite);
  Future<void> reportQuestion(QuizQuestion question, String reason);
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  });
  Future<List<QuizQuestion>> loadFavoriteQuestions();
  Future<int> loadCoinBalance();

  /// Oyuncunun coin bakiyesinden [amount] kadar düşer.
  /// Bakiye yeterli değilse false, başarılıysa true döner.
  Future<bool> spendCoins(int amount, String reason);

  /// Oyuncunun coin bakiyesine [amount] kadar ekler (görev ödülü vb.).
  Future<void> addCoins(int amount, String reason);

  /// Oyuncunun profil XP değerini sunucuda günceller.
  Future<void> updateProfileXP(int xp);

  /// Günlük çark: bugün çevrilebilir mi?
  Future<bool> canSpinToday();

  /// Günlük çark ödülünü coin olarak yazar, kazanılan miktarı döner.
  ///
  /// Gerçek backend bu miktarı sunucuda belirlemelidir; istemci yalnızca
  /// dönen miktara göre animasyonu hedefler.
  Future<int> awardSpinCoins();
  Future<int> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  });
}
