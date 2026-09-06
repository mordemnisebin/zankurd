import 'package:shared_preferences/shared_preferences.dart';

import '../models/mastery_level.dart';
import '../utils/error_reporter.dart';

class MasteryStore {
  MasteryStore._(this._preferences);

  static const _keyPrefix = 'zankurd.mastery.';
  static const _answeredKeyPrefix = 'zankurd.masteryAnswered.';
  static const _evidenceCorrectKeyPrefix = 'zankurd.masteryEvidenceCorrect.';
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

  Future<void> clear() async {
    final prefs = _preferences;
    if (prefs == null) return;
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_keyPrefix) ||
          key.startsWith(_answeredKeyPrefix) ||
          key.startsWith(_evidenceCorrectKeyPrefix)) {
        await prefs.remove(key);
      }
    }
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
