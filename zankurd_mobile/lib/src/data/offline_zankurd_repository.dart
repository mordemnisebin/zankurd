import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/async_duel.dart';
import '../models/contest.dart';
import '../models/player.dart';
import '../models/quiz_question.dart';
import '../models/referral_result.dart';
import '../models/room.dart';
import '../models/tournament.dart';
import 'local_progress_scope.dart';
import 'mock_zankurd_repository.dart';
import 'zankurd_repository.dart';

/// Üretimde uzak servis başlatılamadığında kullanılan yerel depo.
///
/// [MockZanKurdRepository] soru bankası ve çevrimdışı öğrenme davranışını
/// olgunlaştırdığı için onları yeniden kullanır; fakat test/demoya özgü uzak
/// kimlikleri ve sunucu yazımlarındaki sahte başarıları özellikle kapatır.
class OfflineZanKurdRepository extends MockZanKurdRepository {
  static String get _completedLessonIdsKey =>
      LocalProgressScope.physical('zankurd.offline.completedLessonIds');
  static String get _favoriteQuestionIdsKey =>
      LocalProgressScope.physical('zankurd.offline.favoriteQuestionIds');
  static String get _profileNameKey =>
      LocalProgressScope.physical('zankurd.offline.profileName');

  @override
  String? get currentUserId => null;

  @override
  Future<String> getProfileName() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_profileNameKey) ?? 'ZanKurd Oyuncusu';
  }

  @override
  Future<String?> getPlayerTag() async => null;

  @override
  Future<void> updateProfileName(String name) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_profileNameKey, name.trim());
    if (!saved) throw StateError('Offline profile name was not persisted.');
  }

  @override
  Future<void> deleteMyAccount() async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<List<String>> loadMatchmakingCategories() async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
    int questionCount = 10,
    int entryFee = 0,
  }) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<AsyncDuelStart> startAsyncDuel({String? category}) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<AsyncDuelAnswer> answerAsyncDuel({
    required String duelId,
    required int questionIndex,
    required String choice,
    required int responseMs,
  }) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<void> markAsyncDuelSeen(String duelId) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<int> claimAsyncDuelXp(String duelId) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<GameRoom> loadRoomSnapshot(String roomId) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<RoomStatus> loadRoomStatus(GameRoom room) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<RoomEndState> loadRoomEndState(GameRoom room) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<void> acknowledgeRoomResult(GameRoom room) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<void> updateReady(GameRoom room, bool isReady) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<void> startGame(GameRoom room) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<void> finishGame(GameRoom room) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<TournamentBracket> joinTournament() async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<TournamentBracket?> loadTournamentBracket() async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<TournamentMatch> submitTournamentMatch({
    required String matchId,
    required int playerScore,
    required int opponentScore,
  }) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => const [];

  @override
  Future<bool> addFriend(String friendId, String friendName) async => false;

  @override
  Future<void> setFcmToken(String token) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<bool> acceptFriendRequest(String requestId) async => false;

  @override
  Future<bool> rejectFriendRequest(String requestId) async => false;

  @override
  Future<void> sendRoomMessage({
    required String roomId,
    required String text,
  }) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<bool> blockPlayer(String playerId) async => false;

  @override
  Future<bool> unblockPlayer(String playerId) async => false;

  @override
  Future<bool> reportRoomMessage({
    required String messageId,
    required String reason,
  }) async => false;

  @override
  Future<bool> reportPlayerProfile({
    required String playerId,
    required String reason,
  }) async => false;

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
  }) async => false;

  @override
  Future<bool> saveTournamentProgress(
    String stage,
    int userScore,
    int opponentScore,
    List<String> botWinners,
  ) async => false;

  @override
  Future<bool> syncMissionCompletion(
    String missionKey,
    int coinReward,
    int xpReward,
  ) async => false;

  @override
  Future<bool> logAnalyticsEvent(
    String eventName,
    Map<String, dynamic>? params,
  ) async => false;

  @override
  Future<bool> toggleFavoriteQuestion(
    QuizQuestion question,
    bool favorite,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final ids = List<String>.of(
      preferences.getStringList(_favoriteQuestionIdsKey) ?? const <String>[],
    )..remove(question.id);
    if (favorite) ids.insert(0, question.id);
    final saved = await preferences.setStringList(_favoriteQuestionIdsKey, ids);
    if (!saved) throw StateError('Offline favorite was not persisted.');
    return favorite;
  }

  @override
  Future<bool> isFavoriteQuestion(QuizQuestion question) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_favoriteQuestionIdsKey) ??
            const <String>[])
        .contains(question.id);
  }

  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async {
    final preferences = await SharedPreferences.getInstance();
    final ids =
        preferences.getStringList(_favoriteQuestionIdsKey) ?? const <String>[];
    final byId = {for (final question in questions) question.id: question};
    return ids
        .map((id) => byId[id])
        .whereType<QuizQuestion>()
        .toList(growable: false);
  }

  @override
  Future<int> awardXp(int delta) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<int> awardRoomXp(String roomId) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<StreakFreezeChargeResult> spendStreakFreeze({
    required String idempotencyKey,
  }) async {
    return const StreakFreezeChargeResult(
      outcome: StreakFreezeChargeOutcome.failed,
      idempotent: true,
    );
  }

  @override
  Future<int> claimMissionReward({
    required String missionKey,
    required int fallbackReward,
  }) async => 0;

  @override
  Future<int> claimTournamentReward() async => 0;

  @override
  Future<int> claimTournamentChampionReward() async => 0;

  @override
  Future<ContestEntry?> submitContestEntry({
    required String contestId,
    required int correctCount,
  }) async => null;

  @override
  Future<Contest?> loadTodayContest() async => null;

  @override
  Future<Map<String, dynamic>?> claimContestReward(String contestId) async =>
      null;

  @override
  Future<int> loadCoinBalance() async {
    // Çevrimdışı güvenli dönüş: kırmızı ekran yerine 0 bakiye.
    // Joker satırı zaten "çevrimdışı kapalı" dilini banner ile gösteriyor.
    return 0;
  }

  @override
  Future<bool> canSpinToday() async {
    return false;
  }

  @override
  Future<int> awardSpinCoins() async {
    return 0;
  }

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    return false;
  }

  @override
  Future<QuizRewardClaim> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    return (amount: 0, dailyCapReached: false);
  }

  @override
  Future<ReferralResult> redeemReferralCode(String code) async {
    return const ReferralResult(status: ReferralStatus.networkError);
  }

  @override
  Future<String> uploadAvatarPhoto(Uint8List bytes, String contentType) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<void> deleteAvatarPhoto() async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<void> reportQuestion(QuizQuestion question, String reason) async {
    throw StateError('Remote service unavailable.');
  }

  @override
  Future<bool> markLessonCompleted(String lessonId) async {
    final preferences = await SharedPreferences.getInstance();
    final ids =
        preferences.getStringList(_completedLessonIdsKey)?.toSet() ??
        <String>{};
    ids.add(lessonId);
    final sortedIds = ids.toList()..sort();
    return preferences.setStringList(_completedLessonIdsKey, sortedIds);
  }

  @override
  Future<Set<String>> loadCompletedLessonIds() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(_completedLessonIdsKey) ??
            const <String>[])
        .toSet();
  }
}
