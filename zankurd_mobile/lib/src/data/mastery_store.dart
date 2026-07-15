import 'package:shared_preferences/shared_preferences.dart';

import '../models/mastery_level.dart';
import '../utils/error_reporter.dart';

class MasteryStore {
  MasteryStore._(this._preferences);

  static const _keyPrefix = 'zankurd.mastery.';
  static MasteryStore? _instance;

  final SharedPreferences? _preferences;

  static Future<MasteryStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'mastery_store');
      preferences = null;
    }
    return _instance = MasteryStore._(preferences);
  }

  static void resetInstance() => _instance = null;

  int correctCount(String category) =>
      _preferences?.getInt('$_keyPrefix$category') ?? 0;

  MasteryLevel levelFor(String category) =>
      MasteryLevelDetails.fromCorrectCount(correctCount(category));

  int nextThreshold(String category) {
    final count = correctCount(category);
    if (count < 20) return 20;
    if (count < 100) return 100;
    return 400;
  }

  Future<MasteryLevel?> addCorrect(String category, int count) async {
    if (count <= 0) return null;
    final before = levelFor(category);
    final newCount = correctCount(category) + count;
    await _preferences?.setInt('$_keyPrefix$category', newCount);
    final after = MasteryLevelDetails.fromCorrectCount(newCount);
    return after != before && after != MasteryLevel.none ? after : null;
  }
}
