import 'package:shared_preferences/shared_preferences.dart';

import '../models/learning_goal.dart';
import '../utils/error_reporter.dart';

class LearningGoalStore {
  LearningGoalStore._(this._preferences, this._goal);

  static const _key = 'zankurd.learning_goal.v1';
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
    await _preferences?.remove(_key);
    _goal = null;
  }

  Future<void> save(LearningGoal goal) async {
    _goal = goal;
    await _preferences?.setString(_key, goal.storageKey);
  }
}
