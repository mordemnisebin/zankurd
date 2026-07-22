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

  // 2026-07-22 canlı UX denetimi: şablon çeşitlilik koruması
  group('şablon çeşitlilik koruması', () {
    test('no single 4-word prefix accounts for more than 20% of bank', () {
      // Tüm soruların prompt'larından ilk 4 kelimeyi al
      final prefixCounts = <String, int>{};
      for (final q in offlineQuestionBank) {
        final words = q.prompt.split(RegExp(r'\s+'));
        if (words.length < 4) continue;
        final prefix = words.sublist(0, 4).join(' ');
        prefixCounts[prefix] = (prefixCounts[prefix] ?? 0) + 1;
      }

      final totalCount = offlineQuestionBank.length;
      // Eşik: bankanın %20'si — mevcut en yoğun önek ~%17 (400/2347).
      // Bu eşik mevcut bankayla geçer ama gelecekte kalıp soru yığını
      // eklenirse kırılır.
      const maxAllowedShare = 0.20;
      final maxAllowedCount = (totalCount * maxAllowedShare).ceil();

      final sorted = prefixCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;

      expect(
        top.value,
        lessThanOrEqualTo(maxAllowedCount),
        reason:
            'Önek "${top.key}" bankanın %${(top.value / totalCount * 100).toStringAsFixed(1)}\'ini '
            'oluşturuyor ($top.value/$totalCount). İzin verilen: '
            '%${(maxAllowedShare * 100).toStringAsFixed(0)} ($maxAllowedCount). '
            'Şablon çeşitliliğini artırmak için farklı kalıplar kullanın.',
      );
    });
  });
}
