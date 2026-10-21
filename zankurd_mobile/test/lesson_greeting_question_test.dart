import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sabah selamında genel selam ikinci bir doğru seçenek değildir', () {
    final bank =
        jsonDecode(
              File(
                'assets/data/ders_2026_10_01_questions.json',
              ).readAsStringSync(),
            )
            as List<dynamic>;
    final question = bank.cast<Map<String, dynamic>>().singleWhere(
      (q) => q['id'] == 'ders_2026_10_01_0003',
    );
    expect(question['correctAnswer'], 'Rojbaş');
    expect(question['answers'], isNot(contains('Silav')));
    expect(question['answersTr'], isNot(contains('Merhaba')));
    expect(question['answers'], hasLength(4));
    expect(question['answersTr'], hasLength(4));
  });
}
