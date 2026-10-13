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

  final SharedPreferences? _preferences;
  LearningGoal? _goal;

  static Future<LearningGoalStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'learning_goal_store');
    }
    return _instance = LearningGoalStore._(
      preferences,
      LearningGoal.fromStorageKey(preferences?.getString(_key)),
    );
  }

  static void resetInstance() => _instance = null;

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
