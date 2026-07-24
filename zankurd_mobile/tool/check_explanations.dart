// Çeviri kalıplarının offline banka kapsamını raporlar:
//   dart run tool/check_explanations.dart
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/l10n/explanation_ku.dart';

void main() {
  // JSON asset dosyasından yükle (offline_question_bank.dart kaldırıldı)
  final raw = File('assets/data/offline_questions.json').readAsStringSync();
  final list = json.decode(raw) as List<dynamic>;
  final bank = list
      .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
      .toList();

  var translated = 0;
  final missed = <String>[];
  for (final q in bank) {
    final ku = explanationToKu(q.explanation);
    if (ku != q.explanation) {
      translated++;
    } else {
      missed.add(q.explanation);
    }
  }
  print('Toplam: ${bank.length}');
  print('Çevrilen: $translated');
  print('Çevrilemeyen: ${missed.length}');
  print('--- İlk 15 çevrilemeyen örnek ---');
  for (final e in missed.take(15)) {
    print(e);
  }
}
