import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_question_bank.dart';
import '../utils/error_reporter.dart';

/// Yanlış cevaplanan soruların kimliklerini ve tekrar zamanlarını yerelde tutar.
///
/// SuperMemo SM-2 Aralıklı Tekrar (Spaced Repetition) algoritması ile çalışır.
/// Her soru için repetitions (tekrar sayısı), intervalDays (gün cinsinden aralık)
/// ve easeFactor (kolaylık derecesi) parametreleri tutulur.
/// Yanlış cevaplandığında aralık 1 güne sıfırlanır, easeFactor azaltılır.
/// Doğru cevaplandığında kullanıcının zorluk derecelendirmesine (Zor, Orta, Kolay)
/// göre aralık ve easeFactor formülle güncellenir.
/// SharedPreferences yoksa bellek-içi çalışır.
class MistakeStore {
  MistakeStore._(this._preferences, this._ids, this._metadata, this._history);

  static const _storageKey = 'zankurd.mistakeQuestionIds';
  static const _metadataKey = 'zankurd.mistakeMetadata';
  static const _historyKey = 'zankurd.dailyPerformance';
  static MistakeStore? _instance;

  static Future<MistakeStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'mistake_store_preferences');
      preferences = null;
    }

    final ids = preferences?.getStringList(_storageKey)?.toSet() ?? <String>{};

    final metadataString = preferences?.getString(_metadataKey);
    final Map<String, Map<String, dynamic>> metadata = {};
    if (metadataString != null) {
      try {
        final decoded = jsonDecode(metadataString) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          if (val is Map<String, dynamic>) {
            metadata[key] = Map<String, dynamic>.from(val);
          }
        });
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'mistake_store_metadata');
      }
    }

    final historyString = preferences?.getString(_historyKey);
    final Map<String, Map<String, int>> history = {};
    if (historyString != null) {
      try {
        final decoded = jsonDecode(historyString) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          if (val is Map<String, dynamic>) {
            history[key] = {
              'correct': (val['correct'] as num?)?.toInt() ?? 0,
              'wrong': (val['wrong'] as num?)?.toInt() ?? 0,
            };
          }
        });
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'mistake_store_history');
      }
    }

    return _instance = MistakeStore._(preferences, ids, metadata, history);
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() => _instance = null;

  final SharedPreferences? _preferences;
  final Set<String> _ids;
  final Map<String, Map<String, dynamic>> _metadata;
  final Map<String, Map<String, int>> _history;

  Set<String> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;
  bool contains(String id) => _ids.contains(id);

  bool isReadyForReview(String id) {
    if (!_ids.contains(id)) return false;
    final meta = _metadata[id];
    if (meta == null) return true; // Legacy, review immediately
    final nextReview = meta['nextReview'] as int?;
    if (nextReview == null) return true;
    return DateTime.now().millisecondsSinceEpoch >= nextReview;
  }

  int get readyCount => _ids.where((id) => isReadyForReview(id)).length;
  Set<String> get readyIds => _ids.where((id) => isReadyForReview(id)).toSet();

  Future<void> markMistake(String id, {String? category}) async {
    await _recordAnswer(false);
    _ids.add(id);

    // Get existing easeFactor if present to keep continuity, or start fresh at 2.5
    final double currentEF =
        (_metadata[id]?['easeFactor'] as num?)?.toDouble() ?? 2.5;

    // Incorrect answer: reset repetitions to 0, interval to 1 day, reduce easeFactor
    _metadata[id] = {
      'nextReview': DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch,
      'intervalDays': 1,
      'repetitions': 0,
      'easeFactor': math.max(1.3, currentEF - 0.2),
      // ignore: use_null_aware_elements
      if (category != null) 'category': category,
    };
    await _persist();
  }

  /// Normal quizler veya varsayılan çözümler için (Orta zorluk - q = 4).
  Future<void> markResolved(String id) async {
    await markResolvedSM2(id, 4);
  }

  /// SM-2 formülüne göre dereceli çözüm.
  /// score (q) parametresi:
  /// 3 = Zor (Kürtçe: Zor, Türkçe: Zor)
  /// 4 = Orta (Kürtçe: Navîn, Türkçe: Orta)
  /// 5 = Kolay (Kürtçe: Hêsan, Türkçe: Kolay)
  Future<void> markResolvedSM2(String id, int score) async {
    await _recordAnswer(true);
    if (!_ids.contains(id)) return;

    final meta = _metadata[id];

    // Extract current parameters
    double easeFactor = 2.5;
    int repetitions = 0;
    int intervalDays = 1;

    if (meta != null) {
      easeFactor = (meta['easeFactor'] as num?)?.toDouble() ?? 2.5;
      repetitions = (meta['repetitions'] as num?)?.toInt() ?? 0;
      // Handle legacy intervalHours if present
      if (meta.containsKey('intervalHours') &&
          !meta.containsKey('intervalDays')) {
        final hours = (meta['intervalHours'] as num?)?.toInt() ?? 24;
        intervalDays = (hours / 24).round();
      } else {
        intervalDays = (meta['intervalDays'] as num?)?.toInt() ?? 1;
      }
    }

    if (score < 3) {
      // Treat as incorrect response: reset progress
      repetitions = 0;
      intervalDays = 1;
      easeFactor = math.max(1.3, easeFactor - 0.2);
    } else {
      // Calculate new ease factor based on SM-2 formula
      easeFactor =
          easeFactor + (0.1 - (5 - score) * (0.08 + (5 - score) * 0.02));
      easeFactor = easeFactor.clamp(1.3, 3.0);

      // Calculate new interval
      if (repetitions == 0) {
        intervalDays = 1;
      } else if (repetitions == 1) {
        intervalDays = 6;
      } else {
        intervalDays = (intervalDays * easeFactor).round();
      }
      repetitions += 1;
    }

    // If card is mastered (repetitions >= 5 or interval >= 30 days), remove it
    if (repetitions >= 5 || intervalDays >= 30) {
      _ids.remove(id);
      _metadata.remove(id);
    } else {
      _metadata[id] = {
        'nextReview': DateTime.now()
            .add(Duration(days: intervalDays))
            .millisecondsSinceEpoch,
        'intervalDays': intervalDays,
        'repetitions': repetitions,
        'easeFactor': easeFactor,
        // ignore: use_null_aware_elements
        if (meta != null && meta.containsKey('category'))
          'category': meta['category'],
      };
    }
    await _persist();
  }

  Map<String, int> getMistakesCountByCategory() {
    final Map<String, int> counts = {};
    for (final id in _ids) {
      final meta = _metadata[id];
      String? category = meta?['category'] as String?;
      if (category == null) {
        // Fallback to offlineQuestionBank search
        final match = offlineQuestionBank.where((q) => q.id == id).firstOrNull;
        if (match != null) {
          category = match.category;
        }
      }
      if (category != null) {
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> clear() async {
    _ids.clear();
    _metadata.clear();
    _history.clear();
    await _persist();
  }

  Future<void> _recordAnswer(bool correct) async {
    final todayKey = _dayKey(DateTime.now());
    final dayData = _history.putIfAbsent(
      todayKey,
      () => {'correct': 0, 'wrong': 0},
    );
    if (correct) {
      dayData['correct'] = (dayData['correct'] ?? 0) + 1;
    } else {
      dayData['wrong'] = (dayData['wrong'] ?? 0) + 1;
    }

    // Keep history clean: remove older than 7 days
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    _history.removeWhere((key, _) {
      try {
        final parsed = DateTime.parse(key);
        return parsed.isBefore(cutoff);
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'mistake_store_date_parse');
        return true;
      }
    });
  }

  Map<String, Map<String, int>> getLast7DaysHistory() {
    final Map<String, Map<String, int>> result = {};
    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key = _dayKey(day);
      result[key] = _history[key] ?? {'correct': 0, 'wrong': 0};
    }
    return result;
  }

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  Future<void> _persist() async {
    final prefs = _preferences;
    if (prefs == null) return;
    await prefs.setStringList(_storageKey, _ids.toList());
    await prefs.setString(_metadataKey, jsonEncode(_metadata));
    await prefs.setString(_historyKey, jsonEncode(_history));
  }
}
