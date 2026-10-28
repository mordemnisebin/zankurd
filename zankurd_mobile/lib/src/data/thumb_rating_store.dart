import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';
import 'local_progress_scope.dart';

/// Kullanıcının sorulara verdiği puanın (+1 / -1) yerel hafızası
/// (2026-10-28, soru puanlama).
///
/// Sunucu tek gerçek kaynaktır (`rate_question`); burada yalnız "bu soruya
/// ne dedim" tutulur ki cevap incelemesi yeniden açılınca seçili başparmak
/// görünsün. Anahtar `zankurd.missions.` önekinde: `LocalProgressScope`
/// kullanıcıya bağlar, çıkış/hesap silmede temizler (bkz. [JokerStockStore]).
class QuestionRatingStore {
  const QuestionRatingStore._();

  static String get _key =>
      LocalProgressScope.physical('zankurd.missions.questionRatings');

  static Future<Map<String, int>> _readAll() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) return <String, int>{};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, int>{};
    return {
      for (final entry in decoded.entries)
        if (entry.value == 1 || entry.value == -1)
          entry.key.toString(): entry.value as int,
    };
  }

  /// [questionId] için kayıtlı puan; yoksa `null`.
  static Future<int?> read(String questionId) async {
    try {
      return (await _readAll())[questionId];
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'question_rating_read');
      return null;
    }
  }

  /// Birden çok soru için kayıtlı puanlar (yalnız puanlananlar).
  static Future<Map<String, int>> readAll() async {
    try {
      return await _readAll();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'question_rating_read_all');
      return <String, int>{};
    }
  }

  /// [rating] (+1/-1) kaydeder; `null` kaydı siler (başarısız oyu geri alma).
  static Future<void> write(String questionId, int? rating) async {
    try {
      final all = await _readAll();
      if (rating == null) {
        all.remove(questionId);
      } else {
        all[questionId] = rating;
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key, jsonEncode(all));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'question_rating_write');
    }
  }
}
