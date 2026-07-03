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
    String? subCategory,
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
    required int responseMs,
  });
  Future<bool> toggleFavoriteQuestion(QuizQuestion question, bool favorite);

  /// Sorunun oyuncunun favorilerinde olup olmadığını döner.
  Future<bool> isFavoriteQuestion(QuizQuestion question);
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

  /// Belirli bir ürün kimliğinin daha önce satın alınıp alınmadığını kontrol eder.
  Future<bool> hasPurchased(String itemId);

  /// Günlük görev ödülünü talep eder; kazanılan miktarı döner.
  ///
  /// Miktarı sunucu tarifesi belirler ([missionKey] üzerinden);
  /// [fallbackReward] yalnızca çevrimdışı/mock modda kullanılır.
  Future<int> claimMissionReward({
    required String missionKey,
    required int fallbackReward,
  });

  /// Turnuva şampiyonluğu ödülünü talep eder (sunucuda günde 1 kez).
  Future<int> claimTournamentReward();

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

  Future<Map<String, dynamic>> joinMatchmaking(String categoryName);
  Future<void> cancelMatchmaking();
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue();
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId);
  Future<void> sendRoomBroadcast(String roomId, Map<String, dynamic> payload);
}
