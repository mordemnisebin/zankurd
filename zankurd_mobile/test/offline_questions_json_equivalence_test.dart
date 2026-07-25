import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// offline_questions.json ve editorial_questions.json dosyalarının
/// QuizQuestion.fromJson ile eksiksiz parse edildiğini doğrular.
///
/// Eski offline_question_bank.dart Dart const dosyasıyla karşılaştırma testi
/// kaldırıldı: kaynak artık JSON assetlerin kendisidir.
void main() {
  test(
    'offline_questions.json eksiksiz parse edilir ve kimlikler benzersiz',
    () async {
      final raw = await File(
        'assets/data/offline_questions.json',
      ).readAsString();
      final decoded = jsonDecode(raw) as List;
      final fromJson = decoded
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(fromJson.length, greaterThan(1000));
      final ids = fromJson.map((q) => q.id).toSet();
      expect(ids.length, fromJson.length, reason: 'Duplicate IDs in JSON');
      for (final q in fromJson) {
        expect(q.answers, contains(q.correctAnswer), reason: q.id);
      }
    },
  );

  test(
    'editorial_questions.json eksiksiz parse edilir ve kimlikler benzersiz',
    () async {
      final raw = await File(
        'assets/data/editorial_questions.json',
      ).readAsString();
      final decoded = jsonDecode(raw) as List;
      final fromJson = decoded
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(fromJson.length, greaterThanOrEqualTo(150));
      final ids = fromJson.map((q) => q.id).toSet();
      expect(ids.length, fromJson.length, reason: 'Duplicate IDs in JSON');
      for (final q in fromJson) {
        expect(q.answers, contains(q.correctAnswer), reason: q.id);
      }
    },
  );

  test('offline ve editorial JSON kimlik alanları çakışmıyor', () async {
    final offlineRaw = await File(
      'assets/data/offline_questions.json',
    ).readAsString();
    final editorialRaw = await File(
      'assets/data/editorial_questions.json',
    ).readAsString();

    final offlineIds = (jsonDecode(offlineRaw) as List)
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toSet();
    final editorialIds = (jsonDecode(editorialRaw) as List)
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toSet();

    final overlap = offlineIds.intersection(editorialIds);
    expect(overlap, isEmpty, reason: 'Çakışan ID\'ler: $overlap');
  });
}
