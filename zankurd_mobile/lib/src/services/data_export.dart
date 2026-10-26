import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/lesson_completion_store.dart';
import '../data/progress_sync.dart';
import '../data/word_list_store.dart';

/// "İlerleme verilerimi dışa aktar" (2026-10-27).
///
/// Cihazdaki öğrenme verisinin okunur bir kopyası: ilerleme anlık görüntüsü
/// (XP, seri, rozetler, başarılar, ustalık, yanlışlar, seviye, hikâyeler),
/// kayıtlı kelimeler ve biten dersler. Sunucuya hiçbir şey gönderilmez;
/// dosya yalnız kullanıcının seçtiği yere paylaşılır. Hesap kimliği,
/// e-posta ya da başka oyuncuların verisi bilerek YOKTUR.
class DataExport {
  const DataExport._();

  static const fileName = 'zankurd_verilerim.json';

  static Future<Uint8List> build({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = LocalProgressSnapshot.read(prefs);
    final words = (await WordListStore.load()).words;
    final lessons = (await LessonCompletionStore.loadLocal()).toList()..sort();
    final data = {
      'app': 'ZanKurd',
      'format': 1,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'progress': snapshot.toJson(),
      'savedWords': [for (final word in words) word.toJson()],
      'completedLessons': lessons,
    };
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
  }
}
