import 'dart:convert';
import 'dart:io';

import 'package:zankurd_mobile/src/data/offline_question_bank.dart';

/// offlineQuestionBank'i (derlenmiş Dart listesi, kaynak metin değil) JSON'a
/// döker. Regex ile kaynak dosyayı ayrıştırmak yerine Dart'ın kendi obje
/// modelini kullanır — böylece format/kaçış hatası riski sıfırdır.
void main() {
  final list = offlineQuestionBank.map((q) => q.toJson()).toList();
  File(
    'assets/data/offline_questions.json',
  ).writeAsStringSync(jsonEncode(list));
  stdout.writeln(
    'Wrote ${list.length} questions to assets/data/offline_questions.json',
  );
}
