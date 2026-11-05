import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';
import 'progress_sync.dart';

import '../models/learning_goal.dart';
import '../utils/error_reporter.dart';

class LearningGoalStore {
  LearningGoalStore._(
    this._preferences,
    this._goal,
    this._goalKey,
    this._stampKey,
  );

  static String get _key =>
      LocalProgressScope.physical('zankurd.learning_goal.v1');

  /// Hedefin son seçilme anı (ms). Bulut birleşiminde "hangi cihazın seçimi
  /// yeni" sorusunun ölçüsü (bkz. `ProgressSnapshot.merge`, öğrenme hedefi).
  static String get _atKey =>
      LocalProgressScope.physical(LocalProgressSnapshot.goalAtLogicalKey);
  static LearningGoalStore? _instance;
  static Future<LearningGoalStore>? _loading;
  static int _loadGeneration = 0;

  final SharedPreferences? _preferences;
  LearningGoal? _goal;

  /// Örneğin KENDİ anahtarları, yüklendiği anda sabitlenir. `_key`/`_atKey`
  /// her çağrıda etkin hesaptan türetildiği için iki `await` arasında hesap
  /// değişirse hedef B'nin alanına yazılabiliyordu (alan 3 #5).
  final String _goalKey;
  final String _stampKey;

  static Future<LearningGoalStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    final inFlight = _loading;
    if (inFlight != null) return inFlight;

    final generation = _loadGeneration;
    final loading = _loadFresh().then((store) {
      if (_loadGeneration == generation) {
        return _instance ??= store;
      }
      return store;
    });
    _loading = loading;
    try {
      return await loading;
    } finally {
      if (identical(_loading, loading)) _loading = null;
    }
  }

  static Future<LearningGoalStore> _loadFresh() async {
    final goalKey = _key;
    final stampKey = _atKey;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_goal_store');
    }
    return LearningGoalStore._(
      preferences,
      LearningGoal.fromStorageKey(preferences?.getString(goalKey)),
      goalKey,
      stampKey,
    );
  }

  static void resetInstance() {
    _loadGeneration++;
    _instance = null;
    _loading = null;
  }

  LearningGoal? get goal => _goal;

  /// Kayıtlı hedefi siler; hesap değişiminde yabancının hedefi devralınmaz.
  Future<void> clear() async {
    await removePersistedPreferenceKeys(_preferences, [_goalKey, _stampKey]);
    _goal = null;
  }

  Future<bool> save(LearningGoal goal) async {
    final preferences = _preferences;
    if (preferences == null) return false;
    final goalKey = _goalKey;
    final stampKey = _stampKey;
    // Önceki damga: hedef yazılamazsa geri konur. Eskiden damga yeni, hedef
    // eski kalıyor ve bulut birleşimi eski hedefi "yeni seçim" diye öbür
    // cihaza yayıyordu (alan 3 #18).
    final previousStamp = preferences.getInt(stampKey);
    Future<void> restoreStamp() async {
      try {
        if (previousStamp == null) {
          await preferences.remove(stampKey);
        } else {
          await preferences.setInt(stampKey, previousStamp);
        }
      } catch (_) {}
    }

    try {
      // Zaman damgası hedeften ÖNCE yazılır: damga yazılamazsa eski damga
      // yeni seçimi "eski" gösterip öbür cihazın hedefine yenik düşürürdü;
      // bu durumda damga kaldırılır (damgasız = eski veri kuralı).
      final stamped = await preferences.setInt(
        stampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      if (!stamped) await preferences.remove(stampKey);
      final saved = await preferences.setString(goalKey, goal.storageKey);
      if (!saved) {
        await restoreStamp();
        await preferences.reload();
        return false;
      }
      _goal = goal;
      ProgressSyncService.markDirty();
      return true;
    } catch (error, stack) {
      await restoreStamp();
      try {
        await preferences.reload();
      } catch (_) {}
      ErrorReporter.record(error, stack, reason: 'learning_goal_save');
      return false;
    }
  }
}
