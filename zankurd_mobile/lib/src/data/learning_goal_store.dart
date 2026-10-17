import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';

import '../models/learning_goal.dart';
import '../utils/error_reporter.dart';

class LearningGoalStore {
  LearningGoalStore._(this._preferences, this._goal);

  static String get _key =>
      LocalProgressScope.physical('zankurd.learning_goal.v1');
  static LearningGoalStore? _instance;
  static Future<LearningGoalStore>? _loading;
  static int _loadGeneration = 0;

  final SharedPreferences? _preferences;
  LearningGoal? _goal;

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
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_goal_store');
    }
    return LearningGoalStore._(
      preferences,
      LearningGoal.fromStorageKey(preferences?.getString(_key)),
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
    await removePersistedPreferenceKeys(_preferences, [_key]);
    _goal = null;
  }

  Future<bool> save(LearningGoal goal) async {
    final preferences = _preferences;
    if (preferences == null) return false;
    try {
      final saved = await preferences.setString(_key, goal.storageKey);
      if (!saved) {
        await preferences.reload();
        return false;
      }
      _goal = goal;
      return true;
    } catch (error, stack) {
      try {
        await preferences.reload();
      } catch (_) {}
      ErrorReporter.record(error, stack, reason: 'learning_goal_save');
      return false;
    }
  }
}
