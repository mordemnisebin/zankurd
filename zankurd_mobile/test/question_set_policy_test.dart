import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_set_policy.dart';

QuizQuestion _q({
  required String id,
  required String prompt,
  required List<String> answers,
  required String correct,
  String explanation = '',
}) {
  return QuizQuestion(
    id: id,
    category: 'Ziman',
    prompt: prompt,
    answers: answers,
    correctAnswer: correct,
    explanation: explanation,
  );
}

void main() {
  group('cevap sızıntısı', () {
    // 2026-07-25 canlı denetiminde görülen gerçek çift: 1. soru terimi
    // tanımlatıyor, 2. soru aynı terimi şık olarak sunuyordu.
    final tanimSorusu = _q(
      id: 'a',
      prompt:
          "Di gotûbêja dersê de, di qada ziman de têgeha 'rênivîsa Hawarê' "
          'bi kîjan ravekirinê çêtir tê fêmkirin?',
      answers: const [
        'peyvên wekî di... de',
        'guhertina paşgira navdêr',
        'pergala alfabeya kurdî ya bi tîpên latînî',
      ],
      correct: 'pergala alfabeya kurdî ya bi tîpên latînî',
    );

    final tersSoru = _q(
      id: 'b',
      prompt: 'Kîjan têgeh li qada ziman bi vê ravekirinê tê nasîn?',
      answers: const [
        'ergatîf',
        'rênivîsa Hawarê',
        'tewandin',
        'lêkera gerguhêz',
      ],
      correct: 'rênivîsa Hawarê',
    );

    test('bir sorunun cevabı diğerinin metninde geçiyorsa sızıntı sayılır', () {
      expect(QuestionSetPolicy.leaksBetween(tanimSorusu, tersSoru), isTrue);
      // İlişki simetriktir; sıra önemsiz.
      expect(QuestionSetPolicy.leaksBetween(tersSoru, tanimSorusu), isTrue);
    });

    test('bir sorunun cevabı diğerinin şıkkıysa sızıntı sayılır', () {
      final ilk = _q(
        id: 'c',
        prompt: 'Kurmancî alfabe kaç harften oluşur?',
        answers: const ['31', '29', 'tewandin'],
        correct: 'tewandin',
      );
      expect(QuestionSetPolicy.leaksBetween(ilk, tersSoru), isTrue);
    });

    test('ilgisiz sorular sızıntı sayılmaz', () {
      final baska = _q(
        id: 'd',
        prompt: 'Diyarbekir hangi bölgededir?',
        answers: const ['Bakur', 'Başûr', 'Rojhilat'],
        correct: 'Bakur',
      );
      expect(QuestionSetPolicy.leaksBetween(tanimSorusu, baska), isFalse);
    });

    test('çok kısa cevaplar tesadüfi eşleşmeyle elenmez', () {
      // "31" gibi kısa bir cevap başka bir metinde geçse bile sızıntı
      // sayılmamalı; aksi halde geçerli sorular kaybolurdu.
      final kisa = _q(
        id: 'e',
        prompt: 'Alfabede kaç harf var?',
        answers: const ['31', '29'],
        correct: '31',
      );
      final digeri = _q(
        id: 'f',
        prompt: '31 Mart olayları hangi yıldadır?',
        answers: const ['1909', '1920'],
        correct: '1909',
      );
      expect(QuestionSetPolicy.leaksBetween(kisa, digeri), isFalse);
    });

    test('withoutLeaks sırayı korur ve çakışanı atar', () {
      final temiz = _q(
        id: 'g',
        prompt: 'Hewler hangi ülkededir?',
        answers: const ['Iraq', 'Iran'],
        correct: 'Iraq',
      );
      final sonuc = QuestionSetPolicy.withoutLeaks([
        tanimSorusu,
        tersSoru,
        temiz,
      ]);
      expect(sonuc.map((q) => q.id), ['a', 'g']);
    });

    test('limit dolunca durur', () {
      final sonuc = QuestionSetPolicy.withoutLeaks([
        tanimSorusu,
        _q(
          id: 'x',
          prompt: 'Soru bir',
          answers: const ['aaaa', 'bbbb'],
          correct: 'aaaa',
        ),
        _q(
          id: 'y',
          prompt: 'Soru iki',
          answers: const ['cccc', 'dddd'],
          correct: 'cccc',
        ),
      ], limit: 2);
      expect(sonuc, hasLength(2));
    });
  });

  group('okuma yükü', () {
    // Bankadaki `difficulty` konu zorluğunu anlatır, okuma yükünü değil:
    // ölçümde zorluk 1'in şık uzunluğu medyanı tüm seviyelerin en
    // yüksekti; tanım biçimli ağır sorular başlangıç basamağına düşüyordu
    // (2026-07-25 canlı denetimi).
    final kisa = _q(
      id: 'k',
      prompt: 'Hewler li ku ye?',
      answers: const ['Iraq', 'Iran'],
      correct: 'Iraq',
    );
    final uzun = _q(
      id: 'u',
      prompt:
          'Di nirxandina xwendekaran de, kîjan têgeh li qada paradigma bi '
          "vê ravekirinê tê nasîn: 'modela aboriyê ya ku li ser bingeha "
          "parvekirinê ye'?",
      answers: const [
        'modela aboriyê ya ku li ser bingeha parvekirin û hevkariyê ava dibe',
        'sîstema bazara azad a bê sînor',
      ],
      correct:
          'modela aboriyê ya ku li ser bingeha parvekirin û hevkariyê ava dibe',
    );

    test('uzun şıklı soru daha yüksek yük alır', () {
      expect(
        QuestionSetPolicy.readingLoad(uzun),
        greaterThan(QuestionSetPolicy.readingLoad(kisa)),
      );
    });

    test('sıralama hafiften ağıra, eşitlikte özgün sıra korunur', () {
      final sirali = QuestionSetPolicy.byReadingLoad([uzun, kisa]);
      expect(sirali.map((q) => q.id), ['k', 'u']);

      // Kararlılık: aynı girdi her zaman aynı çıktıyı verir.
      expect(
        QuestionSetPolicy.byReadingLoad([uzun, kisa]).map((q) => q.id),
        QuestionSetPolicy.byReadingLoad([uzun, kisa]).map((q) => q.id),
      );
    });
  });

  group('totolojik açıklama', () {
    test('açıklama sorunun tanımını tekrar ediyorsa yakalanır', () {
      final soru = _q(
        id: 'h',
        prompt:
            "Kîjan têgeh bi vê ravekirinê tê nasîn: 'lêkerên ku hewcedariya "
            "wan bi artêla tewandî heye bo temamkirina wateyê'?",
        answers: const ['ergatîf', 'lêkera gerguhêz'],
        correct: 'lêkera gerguhêz',
        explanation:
            '«lêkera gerguhêz» şu anlama gelir: lêkerên ku hewcedariya wan '
            'bi artêla tewandî heye bo temamkirina wateyê.',
      );
      expect(QuestionSetPolicy.explanationIsTautological(soru), isTrue);
    });

    test('gerçek bilgi ekleyen açıklama geçer', () {
      final soru = _q(
        id: 'i',
        prompt:
            "Kîjan têgeh bi vê ravekirinê tê nasîn: 'lêkerên ku "
            "hewcedariya wan bi artêla tewandî heye'?",
        answers: const ['ergatîf', 'lêkera gerguhêz'],
        correct: 'lêkera gerguhêz',
        explanation:
            'Kurmancîde geçişli fiiller geçmiş zamanda ergatif yapı kurar; '
            'özne bükümlenir, nesne yalın kalır. Bu, Hint-Avrupa dilleri '
            'içinde ender görülen bir özelliktir.',
      );
      expect(QuestionSetPolicy.explanationIsTautological(soru), isFalse);
    });

    test('boş açıklama totolojik sayılmaz', () {
      final soru = _q(
        id: 'j',
        prompt: 'Bir soru metni burada duruyor ve yeterince uzundur',
        answers: const ['aaaa', 'bbbb'],
        correct: 'aaaa',
      );
      expect(QuestionSetPolicy.explanationIsTautological(soru), isFalse);
    });
  });
}
