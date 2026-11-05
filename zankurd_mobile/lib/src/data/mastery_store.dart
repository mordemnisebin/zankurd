import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';
import 'result_progress_journal.dart';
import 'local_progress_write_lock.dart';

import '../models/mastery_level.dart';
import '../utils/error_reporter.dart';

class MasteryStore {
  MasteryStore._(this._preferences, this._owner);

  static String get _keyPrefix =>
      LocalProgressWriteLock.physical('zankurd.mastery.');
  static String get _answeredKeyPrefix =>
      LocalProgressWriteLock.physical('zankurd.masteryAnswered.');
  static String get _evidenceCorrectKeyPrefix =>
      LocalProgressWriteLock.physical('zankurd.masteryEvidenceCorrect.');
  static MasteryStore? _instance;
  static Future<MasteryStore>? _loading;
  static int _loadGeneration = 0;

  final SharedPreferences? _preferences;
  final String? _owner;

  static Future<MasteryStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    final inFlight = _loading;
    if (inFlight != null) return inFlight;

    final generation = _loadGeneration;
    final loading = _loadFresh(LocalProgressScope.activeUserId).then((store) {
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

  static Future<MasteryStore> _loadFresh(String? owner) =>
      LocalProgressWriteLock.run(owner, () async {
        SharedPreferences? preferences;
        try {
          preferences = await SharedPreferences.getInstance();
        } catch (error, stack) {
          ErrorReporter.record(error, stack, reason: 'mastery_store');
          preferences = null;
        }
        if (preferences != null) {
          await ResultProgressJournal.recover(
            preferences: preferences,
            namespace: LocalProgressWriteLock.physical(
              'zankurd.achievements.masteryResultJournal',
            ),
          );
        }
        return MasteryStore._(preferences, owner);
      });

  static void resetInstance() {
    _loadGeneration++;
    _instance = null;
    _loading = null;
  }

  Future<void> clear() => LocalProgressWriteLock.run(_owner, () async {
    final prefs = _preferences;
    if (prefs == null) return;
    final keys = prefs.getKeys();
    await removePersistedPreferenceKeys(
      prefs,
      keys.where(
        (key) =>
            key.startsWith(_keyPrefix) ||
            key.startsWith(_answeredKeyPrefix) ||
            key.startsWith(_evidenceCorrectKeyPrefix) ||
            key.startsWith(
              LocalProgressWriteLock.physical(
                'zankurd.achievements.masteryResultJournal.',
              ),
            ),
      ),
    );
  });

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

  Future<MasteryLevel?> addCorrect(
    String category,
    int count, {
    String? operationId,
  }) => LocalProgressWriteLock.run(_owner, () async {
    if (count <= 0) return null;
    final prefs = _preferences;
    if (operationId != null) {
      if (prefs == null) throw StateError('Mastery storage unavailable');
      final key = '$_keyPrefix$category';
      final result = await ResultProgressJournal.run(
        preferences: prefs,
        namespace: LocalProgressWriteLock.physical(
          'zankurd.achievements.masteryResultJournal',
        ),
        operationId: '$operationId:correct:$category',
        prepare: () {
          final oldCount = prefs.getInt(key) ?? 0;
          final before = MasteryLevelDetails.fromCorrectCount(oldCount);
          final after = MasteryLevelDetails.fromCorrectCount(oldCount + count);
          return ResultProgressMutation(
            values: {key: oldCount + count},
            result: {
              'promotion': after != before && after != MasteryLevel.none
                  ? after.name
                  : null,
            },
          );
        },
      );
      return MasteryLevel.values
          .where((level) => level.name == result['promotion'])
          .firstOrNull;
    }
    if (prefs != null) {
      await ResultProgressJournal.recover(
        preferences: prefs,
        namespace: LocalProgressWriteLock.physical(
          'zankurd.achievements.masteryResultJournal',
        ),
      );
    }
    final before = levelFor(category);
    final newCount = correctCount(category) + count;
    // Kimliksiz yolda da yazım sonucu denetlenir (alan 3 #22).
    if (await _preferences?.setInt('$_keyPrefix$category', newCount) == false) {
      await _preferences?.reload();
      throw StateError('Mastery correct count was not persisted.');
    }
    final after = MasteryLevelDetails.fromCorrectCount(newCount);
    return after != before && after != MasteryLevel.none ? after : null;
  });

  /// Cevaplanan soruları öğrenme kanıtı olarak kaydeder.
  ///
  /// Doğru sayısı [addCorrect] ile ayrı güncellenir; burada cevap sayısı ve
  /// bu turun kanıtındaki doğru sayısı ayrı tutulur. Negatif ve boş kayıtlar
  /// sessizce yok sayılır.
  Future<void> recordAnswered(
    String category,
    int count, {
    int correct = 0,
    String? operationId,
  }) => LocalProgressWriteLock.run(_owner, () async {
    if (count <= 0) return;
    final prefs = _preferences;
    if (prefs == null) {
      if (operationId != null) throw StateError('Mastery storage unavailable');
      return;
    }
    if (operationId != null) {
      final answeredKey = '$_answeredKeyPrefix$category';
      final correctKey = '$_evidenceCorrectKeyPrefix$category';
      await ResultProgressJournal.run(
        preferences: prefs,
        namespace: LocalProgressWriteLock.physical(
          'zankurd.achievements.masteryResultJournal',
        ),
        operationId: '$operationId:answered:$category',
        prepare: () => ResultProgressMutation(
          values: {
            answeredKey: (prefs.getInt(answeredKey) ?? 0) + count,
            correctKey:
                (prefs.getInt(correctKey) ?? 0) + correct.clamp(0, count),
          },
        ),
      );
      return;
    }
    await ResultProgressJournal.recover(
      preferences: prefs,
      namespace: LocalProgressWriteLock.physical(
        'zankurd.achievements.masteryResultJournal',
      ),
    );
    final nextAnswered = answeredCount(category) + count;
    final nextCorrect =
        (prefs.getInt('$_evidenceCorrectKeyPrefix$category') ?? 0) +
        correct.clamp(0, count);
    final answeredSaved = await prefs.setInt(
      '$_answeredKeyPrefix$category',
      nextAnswered,
    );
    final correctSaved = await prefs.setInt(
      '$_evidenceCorrectKeyPrefix$category',
      nextCorrect,
    );
    if (!answeredSaved || !correctSaved) {
      await prefs.reload();
      throw StateError('Mastery answer evidence was not persisted.');
    }
  });
}
