// Çeviri kalıplarının offline banka kapsamını raporlar:
//   dart run tool/check_explanations.dart
// ignore_for_file: avoid_print
import 'package:zankurd_mobile/src/data/offline_question_bank.dart';
import 'package:zankurd_mobile/src/l10n/explanation_ku.dart';

void main() {
  var translated = 0;
  final missed = <String>[];
  for (final q in offlineQuestionBank) {
    final ku = explanationToKu(q.explanation);
    if (ku != q.explanation) {
      translated++;
    } else {
      missed.add(q.explanation);
    }
  }
  print('Toplam: ${offlineQuestionBank.length}');
  print('Çevrilen: $translated');
  print('Çevrilemeyen: ${missed.length}');
  print('--- İlk 15 çevrilemeyen örnek ---');
  for (final e in missed.take(15)) {
    print(e);
  }
}
