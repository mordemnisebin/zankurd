import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/editorial_question_bank.dart';
import 'package:zankurd_mobile/src/data/offline_question_bank.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';
import 'package:zankurd_mobile/src/services/question_language_policy.dart';

/// 2026-07-24 editoryal denetim. İkinci dalga bankasının sözleşmesi:
/// her soru kaynaklı, iki dilde açıklamalı, dil olarak tutarlı ve
/// oynanabilir olmalı.
String _norm(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('editoryal banka sözleşmesi', () {
    test('banka anlamlı büyüklükte ve kimlikler benzersiz', () {
      expect(editorialQuestionBank.length, greaterThanOrEqualTo(150));
      final ids = editorialQuestionBank.map((q) => q.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('her soru onaylı, Kurmancî ve kaynaklı', () {
      for (final q in editorialQuestionBank) {
        expect(
          q.metadata?.reviewStatus,
          ReviewStatus.approved,
          reason: q.id,
        );
        expect(q.metadata?.dialect, 'Kurmancî', reason: q.id);
        expect(q.metadata?.sourceTitle, isNotEmpty, reason: q.id);
        expect(q.metadata?.sourceReference, isNotEmpty, reason: q.id);
      }
    });

    test('her sorunun iki dilde açıklaması var', () {
      for (final q in editorialQuestionBank) {
        expect(q.explanationKu, isNotNull, reason: q.id);
        expect(q.explanationTr, isNotNull, reason: q.id);
        expect(q.explanationKu!.length, greaterThan(20), reason: q.id);
        expect(q.explanationTr!.length, greaterThan(20), reason: q.id);
      }
    });

    test('şıklar benzersiz ve doğru cevap şıklar arasında', () {
      for (final q in editorialQuestionBank) {
        expect(q.answers, contains(q.correctAnswer), reason: q.id);
        expect(q.answers.toSet(), hasLength(q.answers.length), reason: q.id);
        expect(q.answers.length, greaterThanOrEqualTo(2), reason: q.id);
      }
    });

    test('soru gövdesi doğru cevabı sızdırmaz', () {
      for (final q in editorialQuestionBank) {
        final correct = _norm(q.correctAnswer);
        if (correct.length < 6) continue;
        expect(_norm(q.prompt), isNot(contains(correct)), reason: q.id);
      }
    });

    test('dil tutarlıdır — gövde Kurmancî, şıklar Türkçe değil', () {
      const policy = QuestionLanguagePolicy();
      final violations = editorialQuestionBank
          .where((q) => !policy.isConsistent(q))
          .map((q) => q.id)
          .toList();
      expect(violations, isEmpty, reason: violations.join(', '));
    });

    test('her soru yapısal olarak oynanabilir', () {
      const policy = QuestionContentPolicy();
      for (final q in editorialQuestionBank) {
        expect(policy.validate(q), isEmpty, reason: q.id);
      }
    });

    test('zorluk ve kategori dağılımı dengeli', () {
      final byCategory = <String, int>{};
      final byDifficulty = <int, int>{};
      for (final q in editorialQuestionBank) {
        byCategory[q.category] = (byCategory[q.category] ?? 0) + 1;
        byDifficulty[q.difficulty] = (byDifficulty[q.difficulty] ?? 0) + 1;
      }
      // Sekiz ana kategorinin hepsi temsil edilmeli.
      expect(byCategory.keys.toSet(), hasLength(greaterThanOrEqualTo(8)));
      for (final entry in byCategory.entries) {
        expect(entry.value, greaterThanOrEqualTo(10), reason: entry.key);
      }
      // Beş zorluk kademesinin hepsinde soru olmalı.
      for (var d = 1; d <= 5; d++) {
        expect(byDifficulty[d] ?? 0, greaterThan(0), reason: 'zorluk $d');
      }
    });

    test('prompt metinleri offline banka ile çakışmaz', () {
      final offline = offlineQuestionBank
          .map((q) => '${q.category}|${_norm(q.prompt)}')
          .toSet();
      for (final q in editorialQuestionBank) {
        expect(
          offline.contains('${q.category}|${_norm(q.prompt)}'),
          isFalse,
          reason: q.id,
        );
      }
    });
  });

  group('alt kategori eşlemesi konuya göre yapılır', () {
    // 2026-07-24: eşleme `id.hashCode % n` idi; "Dilbilgisi" filtresi
    // rastgele sorular getiriyordu.
    test('rêziman sorusu rêziman alt kategorisine düşer', () {
      const q = QuizQuestion(
        id: 'test_reziman',
        category: 'Ziman',
        prompt: 'Di Kurmancî de veqetandek çi karê dike?',
        answers: ['Navdêr û rengdêrê girê dide', 'B', 'C', 'D'],
        correctAnswer: 'Navdêr û rengdêrê girê dide',
        explanation: 'Ravekirin bi têra xwe dirêj e ji bo testê.',
      );
      expect(SubcategoryConfig.getSubcategoryId(q), 'reziman');
    });

    test('dengbêj sorusu dengbêjî alt kategorisine düşer', () {
      const q = QuizQuestion(
        id: 'test_dengbej',
        category: 'Muzîk',
        prompt: 'Dengbêj kî ye û kilam çawa tê gotin?',
        answers: ['Stranbêjê devkî', 'B', 'C', 'D'],
        correctAnswer: 'Stranbêjê devkî',
        explanation: 'Ravekirin bi têra xwe dirêj e ji bo testê.',
      );
      expect(SubcategoryConfig.getSubcategoryId(q), 'dengbeji');
    });

    test('konusu belirsiz soru yine de bir alt kategoriye düşer', () {
      const q = QuizQuestion(
        id: 'test_fallback',
        category: 'Çand',
        prompt: 'Ev pirs bê mijar e.',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'Ravekirin bi têra xwe dirêj e ji bo testê.',
      );
      expect(SubcategoryConfig.getSubcategoryId(q), isNotEmpty);
    });
  });
}
