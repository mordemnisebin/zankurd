import 'package:shared_preferences/shared_preferences.dart';

/// All local (on-device) persistence goes through this service.
/// Works without any network connection.
class LocalDataService {
  LocalDataService._(this._prefs);

  final SharedPreferences _prefs;

  static LocalDataService? _instance;

  static Future<LocalDataService> getInstance() async {
    _instance ??= LocalDataService._(await SharedPreferences.getInstance());
    return _instance!;
  }

  // ─── Keys ───────────────────────────────────────────────────────────────────

  static const _keyPlayerName = 'player_name';
  static const _keyCoins = 'coins';
  static const _keyLastSpinDate = 'last_spin_date';
  static const _keyLastSpinPrize = 'last_spin_prize';
  static const _keyDailyQuizDate = 'daily_quiz_date';
  static const _keyFirstLaunch = 'first_launch_done';
  static const _keyTotalScore = 'total_score';
  static const _keyRoomsPlayed = 'rooms_played';
  static const _keyBestStreak = 'best_streak';

  // ─── First Launch ────────────────────────────────────────────────────────────

  bool get isFirstLaunch => !(_prefs.getBool(_keyFirstLaunch) ?? false);

  Future<void> markLaunchDone() => _prefs.setBool(_keyFirstLaunch, true);

  // ─── Player Name ─────────────────────────────────────────────────────────────

  String get playerName => _prefs.getString(_keyPlayerName) ?? '';

  bool get hasPlayerName => playerName.isNotEmpty;

  Future<void> savePlayerName(String name) =>
      _prefs.setString(_keyPlayerName, name.trim());

  // ─── Coins ───────────────────────────────────────────────────────────────────

  int get coins => _prefs.getInt(_keyCoins) ?? 500; // start with 500

  Future<void> setCoins(int amount) =>
      _prefs.setInt(_keyCoins, amount.clamp(0, 9999999));

  Future<void> addCoins(int amount) => setCoins(coins + amount);

  Future<void> spendCoins(int amount) => setCoins(coins - amount);

  // ─── Daily Spin ──────────────────────────────────────────────────────────────

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  bool get hasSpunToday => _prefs.getString(_keyLastSpinDate) == _todayKey;

  int get lastSpinPrize => _prefs.getInt(_keyLastSpinPrize) ?? 0;

  Future<void> recordSpin(int prize) async {
    await _prefs.setString(_keyLastSpinDate, _todayKey);
    await _prefs.setInt(_keyLastSpinPrize, prize);
    await addCoins(prize);
  }

  // ─── Daily Quiz ───────────────────────────────────────────────────────────────

  bool get hasCompletedDailyQuiz =>
      _prefs.getString(_keyDailyQuizDate) == _todayKey;

  Future<void> markDailyQuizCompleted() =>
      _prefs.setString(_keyDailyQuizDate, _todayKey);

  /// Deterministic daily seed — same day → same number
  int get dailySeed {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  // ─── Game Stats ───────────────────────────────────────────────────────────────

  int get totalScore => _prefs.getInt(_keyTotalScore) ?? 0;
  int get roomsPlayed => _prefs.getInt(_keyRoomsPlayed) ?? 0;
  int get bestStreak => _prefs.getInt(_keyBestStreak) ?? 0;

  Future<void> addScore(int points) =>
      _prefs.setInt(_keyTotalScore, totalScore + points);

  Future<void> incrementRoomsPlayed() =>
      _prefs.setInt(_keyRoomsPlayed, roomsPlayed + 1);

  Future<void> updateBestStreak(int streak) {
    if (streak > bestStreak) return _prefs.setInt(_keyBestStreak, streak);
    return Future.value();
  }

  /// Add quiz rewards: coins + score
  Future<void> applyQuizResult({
    required int score,
    required int correctCount,
    required int streak,
  }) async {
    final coinReward = (correctCount * 10).clamp(0, 200);
    await addCoins(coinReward);
    await addScore(score);
    await updateBestStreak(streak);
    await incrementRoomsPlayed();
  }
}
