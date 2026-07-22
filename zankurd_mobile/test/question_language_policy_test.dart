import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/offline_question_bank.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_language_policy.dart';

/// 2026-07-22 canlı UX denetimi (P0-2): oynanan quizde soru gövdesi
/// Kurmancî, şıkların tamamı Türkçe olan sorulara rastlandı. Arayüz dili
/// hangisi olursa olsun oyuncu sorunun yarısını anlamıyor.
///
/// 348 mevcut ihlal tek seferde düzeltilemez (editöryel çeviri işi), ama
/// sayının **artmaması** koda bağlanabilir. Bu testler cırcır (ratchet)
/// görevi görür: yeni ihlal eklenirse kırılır, düzeltme yapılırsa taban
/// düşürülmelidir.
void main() {
  const policy = QuestionLanguagePolicy();

  group('dil tutarlılığı sezgisi', () {
    test('Kurmancî gövde + Türkçe tanım şıkları ihlal sayılır', () {
      const question = QuizQuestion(
        id: 'offline_10878',
        category: 'Muzîk',
        prompt: 'Di çarçoveya Muzîkê de \'Komele\' navê çi ye?',
        answers: [
          'kış gecesi sohbetlerinde icra edilen sözlü müzik',
          'tek bir sanatçının şarkı söylemesi veya çalması',
          'Şırnak ve Cizre yöresinin ritmik ve makamsal müziği',
          'Kürt müziğini çok kültürlü ortamda icra eden grup',
        ],
        correctAnswer: 'Kürt müziğini çok kültürlü ortamda icra eden grup',
        explanation: 'Ravekirin',
      );

      expect(
        policy.validate(question),
        contains(QuestionLanguagePolicy.mixedLanguageIssue),
      );
      expect(policy.isConsistent(question), isFalse);
    });

    test('çeviri alıştırmasında dil farkı meşrudur', () {
      const question = QuizQuestion(
        id: 'translation',
        category: 'Ziman',
        prompt: 'Peyva Kurmancî "biçûk" bi Tirkî çi tê gotin?',
        answers: ['küçük', 'büyük', 'uzun', 'kısa'],
        correctAnswer: 'küçük',
        explanation: 'Ravekirin',
      );

      expect(policy.validate(question), isEmpty);
    });

    test('gövde ve şıklar aynı dildeyse ihlal yok', () {
      const question = QuizQuestion(
        id: 'consistent',
        category: 'Dîrok',
        prompt: 'Kovara "Hawar" ji aliyê kê ve hat derxistin?',
        answers: [
          'Celadet Alî Bedirxan',
          'Ehmedê Xanî',
          'Melayê Cizîrî',
          'Feqiyê Teyran',
        ],
        correctAnswer: 'Celadet Alî Bedirxan',
        explanation: 'Ravekirin',
      );

      expect(policy.validate(question), isEmpty);
    });
  });

  group('offline banka tabanı', () {
    /// 2026-07-22 ölçümü: 2347 sorunun 320'si (%13.6). Bu sayı yalnızca
    /// AZALMALIDIR; editöryel düzeltme yapıldıkça taban da düşürülmelidir.
    /// Güncel dökümü almak için: tools/audit_question_language_mix.py
    const knownViolationBaseline = 320;

    test('dil karışıklığı sayısı tabanı aşmıyor', () {
      final violations = offlineQuestionBank
          .where((q) => !policy.isConsistent(q))
          .toList();

      expect(
        violations.length,
        lessThanOrEqualTo(knownViolationBaseline),
        reason:
            'Yeni dil karışıklığı eklendi. Sorunlu id\'ler: '
            '${violations.take(10).map((q) => q.id).join(", ")}',
      );
    });

    test('Ziman kategorisi tabanın dışında tutuluyor', () {
      final zimanViolations = offlineQuestionBank
          .where((q) => q.category == 'Ziman')
          .where((q) => !policy.isConsistent(q));

      expect(zimanViolations, isEmpty);
    });
  });
}
