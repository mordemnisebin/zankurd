import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';

import '../models/mastery_level.dart';
import '../utils/error_reporter.dart';

class MasteryStore {
  MasteryStore._(this._preferences);

  static String get _keyPrefix =>
      LocalProgressScope.physical('zankurd.mastery.');
  static String get _answeredKeyPrefix =>
      LocalProgressScope.physical('zankurd.masteryAnswered.');
  static String get _evidenceCorrectKeyPrefix =>
      LocalProgressScope.physical('zankurd.masteryEvidenceCorrect.');
  static MasteryStore? _instance;
  static Future<MasteryStore>? _loading;
  static int _loadGeneration = 0;

  final SharedPreferences? _preferences;

  static Future<MasteryStore> load() async {
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

  static Future<MasteryStore> _loadFresh() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'mastery_store');
      preferences = null;
    }
    return MasteryStore._(preferences);
  }

  static void resetInstance() {
    _loadGeneration++;
    _instance = null;
    _loading = null;
  }

  Future<void> clear() async {
    final prefs = _preferences;
    if (prefs == null) return;
    final keys = prefs.getKeys();
    await removePersistedPreferenceKeys(
      prefs,
      keys.where(
        (key) =>
            key.startsWith(_keyPrefix) ||
            key.startsWith(_answeredKeyPrefix) ||
            key.startsWith(_evidenceCorrectKeyPrefix),
      ),
    );
  }

  int correctCount(String category) =>
      _preferences?.getInt('$_keyPrefix$category') ?? 0;

  /// Bu kategoride cevaplanmış soru sayısı.
  ///
  /// Doğru sayısından özellikle ayrı tutulur: doğru cevaplar ilerleme
  /// puanını, bu sayaç ise öğrenme sinyalinin ne kadar gözlemlendiğini
  /// anlatır. Eski kurulumlarda kayıt yoksa sıfır döner; böylece geçmiş
  /// etkinlik yanlışlıkla doğruluk kanıtı gibi sunulmaz.
  int answeredCount(String category) =>
      _preferences?.getInt('$_answeredKeyPrefix$category') ?? 0;

  int? accuracyPercent(String category) {
    final answered = answeredCount(category);
    if (answered <= 0) return null;
    final correct =
        _preferences?.getInt('$_evidenceCorrectKeyPrefix$category') ?? 0;
    return ((correct / answered) * 100).round().clamp(0, 100);
  }

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

  /// Cevaplanan soruları öğrenme kanıtı olarak kaydeder.
  ///
  /// Doğru sayısı [addCorrect] ile ayrı güncellenir; burada cevap sayısı ve
  /// bu turun kanıtındaki doğru sayısı ayrı tutulur. Negatif ve boş kayıtlar
  /// sessizce yok sayılır.
  Future<void> recordAnswered(
    String category,
    int count, {
    int correct = 0,
  }) async {
    if (count <= 0) return;
    final prefs = _preferences;
    if (prefs == null) return;
    final nextAnswered = answeredCount(category) + count;
    final nextCorrect =
        (prefs.getInt('$_evidenceCorrectKeyPrefix$category') ?? 0) +
        correct.clamp(0, count);
    await prefs.setInt('$_answeredKeyPrefix$category', nextAnswered);
    await prefs.setInt('$_evidenceCorrectKeyPrefix$category', nextCorrect);
  }
}
