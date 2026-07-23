import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Günlük oyun serisini (streak) yerelde izler.
///
/// Kurallar: gün yerel saate göre hesaplanır; aynı gün içinde ikinci
/// oyun seriyi artırmaz; bir gün atlanırsa seri 1'den başlar. En iyi
/// seri ayrıca saklanır. SharedPreferences yoksa bellek-içi çalışır.
class StreakStore {
  StreakStore._(
    this._preferences,
    this._current,
    this._best,
    this._lastDay,
    this._freeze,
  );

  static const _currentKey = 'zankurd.streak.current';
  static const _bestKey = 'zankurd.streak.best';
  static const _lastDayKey = 'zankurd.streak.lastDay';
  static const _freezeKey = 'zankurd.streak.freeze';

  /// Aynı anda tutulabilecek en fazla dondurma jetonu.
  static const maxFreeze = 2;
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
      preferences?.getInt(_freezeKey) ?? 0,
    );
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() => _instance = null;

  final SharedPreferences? _preferences;
  int _current;
  int _best;
  String? _lastDay;
  int _freeze;

  int get best => _best;
  String? get lastDay => _lastDay;

  /// Elde tutulan dondurma jetonu sayısı (0..[maxFreeze]).
  int get freezeCount => _freeze;

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

  /// Şu an oynanırsa mevcut bir serinin (>0) kırılıp kırılmayacağını söyler.
  /// Yani seri sürüyordu ama bir (veya daha fazla) gün atlandı.
  bool willBreakOnPlay({DateTime? now}) {
    final today = now ?? DateTime.now();
    final lastDay = _lastDay;
    if (lastDay == null || _current <= 0) return false;
    return lastDay != _dayKey(today) && !_isYesterday(lastDay, today);
  }

  /// Kırılacak seri elde jeton varken dondurulabilir mi?
  bool canFreeze({DateTime? now}) =>
      _freeze > 0 && willBreakOnPlay(now: now);

  /// Bir dondurma jetonu ekler (mağaza alımı). Üst sınır [maxFreeze].
  Future<int> addFreeze() async {
    if (_freeze >= maxFreeze) return _freeze;
    _freeze += 1;
    await _persist();
    return _freeze;
  }

  /// Bir jeton harcayarak seriyi korur ve bugünkü oyunu işler.
  /// Atlanan gün(ler) köprülenir; seri +1 devam eder. Jeton yoksa ya da
  /// seri zaten kırılmayacaksa normal [recordPlay] davranışına düşer.
  Future<int> freezeAndRecordPlay({DateTime? now}) async {
    final today = now ?? DateTime.now();
    if (!canFreeze(now: today)) {
      return recordPlay(now: today);
    }
    _freeze -= 1;
    _current += 1;
    if (_current > _best) _best = _current;
    _lastDay = _dayKey(today);
    await _persist();
    return _current;
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
    await preferences.setInt(_freezeKey, _freeze);
    final lastDay = _lastDay;
    if (lastDay != null) {
      await preferences.setString(_lastDayKey, lastDay);
    }
  }

  Future<void> clear() async {
    _current = 0;
    _best = 0;
    _lastDay = null;
    _freeze = 0;
    final preferences = _preferences;
    if (preferences == null) return;
    await preferences.remove(_currentKey);
    await preferences.remove(_bestKey);
    await preferences.remove(_lastDayKey);
    await preferences.remove(_freezeKey);
  }
}
