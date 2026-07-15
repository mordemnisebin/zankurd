import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Günlük oyun serisini (streak) yerelde izler.
///
/// Kurallar: gün yerel saate göre hesaplanır; aynı gün içinde ikinci
/// oyun seriyi artırmaz; bir gün atlanırsa seri 1'den başlar. En iyi
/// seri ayrıca saklanır. SharedPreferences yoksa bellek-içi çalışır.
class StreakStore {
  StreakStore._(this._preferences, this._current, this._best, this._lastDay);

  static const _currentKey = 'zankurd.streak.current';
  static const _bestKey = 'zankurd.streak.best';
  static const _lastDayKey = 'zankurd.streak.lastDay';
  static StreakStore? _instance;

  static Future<StreakStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_store');
      preferences = null;
    }
    return _instance = StreakStore._(
      preferences,
      preferences?.getInt(_currentKey) ?? 0,
      preferences?.getInt(_bestKey) ?? 0,
      preferences?.getString(_lastDayKey),
    );
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() => _instance = null;

  final SharedPreferences? _preferences;
  int _current;
  int _best;
  String? _lastDay;

  int get best => _best;
  String? get lastDay => _lastDay;

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static bool _isYesterday(String lastDay, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return lastDay == _dayKey(yesterday);
  }

  /// Görünen seri: bugün ya da dün oynanmışsa sürer, yoksa 0'dır.
  int effectiveStreak({DateTime? now}) {
    final today = now ?? DateTime.now();
    final lastDay = _lastDay;
    if (lastDay == null) return 0;
    if (lastDay == _dayKey(today) || _isYesterday(lastDay, today)) {
      return _current;
    }
    return 0;
  }

  /// Tamamlanan bir oyunu işler ve güncel seriyi döner.
  Future<int> recordPlay({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayKey = _dayKey(today);
    final lastDay = _lastDay;

    if (lastDay == todayKey) {
      return _current;
    }
    if (lastDay != null && _isYesterday(lastDay, today)) {
      _current += 1;
    } else {
      _current = 1;
    }
    if (_current > _best) _best = _current;
    _lastDay = todayKey;
    await _persist();
    return _current;
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) return;
    await preferences.setInt(_currentKey, _current);
    await preferences.setInt(_bestKey, _best);
    final lastDay = _lastDay;
    if (lastDay != null) {
      await preferences.setString(_lastDayKey, lastDay);
    }
  }
}
