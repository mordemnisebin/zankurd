import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// Boşluk doldurma yanıtlarının klavye toleransı sözleşmesi.
///
/// Kusur: Ham metin eşitliği kenar boşluğu, harf büyüklüğü ve Unicode'un
/// eşdeğer yazımlarını yanlış sayıyordu. Buna karşılık bütün Kurmancî
/// harflerini ASCII'ye katlamak da `şêr` ile `ser` gibi farklı sözcükleri
/// birleştirir. Genel eşleştirme bu yüzden yazımı korur; klavye kolaylıkları
/// yalnız editörün [QuizQuestion.acceptedAnswers] alanında açıkça onayladığı
/// alternatiflerle sağlanır.
void main() {
  QuizQuestion question(String correctAnswer) => QuizQuestion(
    id: 'fill-$correctAnswer',
    category: 'Ziman',
    prompt: 'Valahiyê tijî bike.',
    answers: [correctAnswer],
    correctAnswer: correctAnswer,
    explanation: '',
    type: QuestionType.fillInBlank,
  );

  test('harf büyüklüğü ve kenar boşlukları kabul edilir', () {
    const pairs = {
      'pirtûk': '  PIRTÛK ',
      'şev': 'ŞEV',
      'çem': 'ÇEM',
      'rê': 'RÊ',
      'îro': 'ÎRO',
    };

    for (final entry in pairs.entries) {
      expect(
        question(entry.key).acceptsAnswer(entry.value),
        isTrue,
        reason: '${entry.value} → ${entry.key}',
      );
    }
    expect(question('pirtûk').acceptsAnswer('pirtuk'), isFalse);
    expect(question('pirtûk').acceptsAnswer('pirtik'), isFalse);
  });

  test('Türkçe hedef cevapta noktalı ve noktasız I doğru eşlenir', () {
    QuizQuestion translatedQuestion(String turkishAnswer) => QuizQuestion(
      id: 'fill-tr-$turkishAnswer',
      category: 'Ziman',
      prompt: 'Peyva Kurmancî binivîse.',
      promptTr: 'Türkçe kelimeyi yaz.',
      answers: ['dil'],
      answersTr: [turkishAnswer],
      correctAnswer: 'dil',
      correctAnswerTr: turkishAnswer,
      explanation: '',
      type: QuestionType.fillInBlank,
    ).localized(isKu: false);

    final light = translatedQuestion('ışık');
    expect(light.answerLanguage, AnswerLanguage.turkish);
    expect(light.acceptsAnswer('IŞIK'), isTrue);
    expect(translatedQuestion('istanbul').acceptsAnswer('İSTANBUL'), isTrue);
    expect(translatedQuestion('sık').acceptsAnswer('sik'), isFalse);
  });

  test('Türkçe eşleme Kurmancî I/i davranışına taşınmaz', () {
    final kurmanji = question('dil');
    expect(kurmanji.answerLanguage, AnswerLanguage.kurmanji);
    expect(kurmanji.acceptsAnswer('DIL'), isTrue);
  });

  test('Türkçe arayüzde aynı kalan Kurmancî cevap dili korunur', () {
    const source = QuizQuestion(
      id: 'fill-ku-answer-in-tr-ui',
      category: 'Ziman',
      prompt: 'Valahiyê tijî bike.',
      promptTr: 'Boşluğu doldur.',
      answers: ['mirovekî'],
      answersTr: ['mirovekî'],
      correctAnswer: 'mirovekî',
      correctAnswerTr: 'mirovekî',
      explanation: '',
      type: QuestionType.fillInBlank,
    );

    final localized = source.localized(isKu: false);
    expect(localized.answerLanguage, AnswerLanguage.kurmanji);
    expect(localized.acceptsAnswer('MIROVEKÎ'), isTrue);
  });

  test('farklı Kurmancî sözcükler ASCII katlamasıyla birleşmez', () {
    expect(question('şêr').acceptsAnswer('ser'), isFalse);
    expect(question('şev').acceptsAnswer('sev'), isFalse);
  });

  test('editörün açıkça verdiği alternatif yanıt da kabul edilir', () {
    const q = QuizQuestion(
      id: 'fill-alias',
      category: 'Ziman',
      prompt: 'Silavê binivîse.',
      answers: ['rojbaş'],
      correctAnswer: 'rojbaş',
      acceptedAnswers: ['roj bas'],
      explanation: '',
      type: QuestionType.fillInBlank,
    );

    expect(q.acceptsAnswer('  ROJ BAS  '), isTrue);
    expect(q.acceptsAnswer('şevbaş'), isFalse);
  });

  test('birleşik olmayan Unicode Kurmancî harfleri de aynı yazım sayılır', () {
    expect(question('pirtûk').acceptsAnswer('pirtu\u0302k'), isTrue);
    expect(question('şev').acceptsAnswer('s\u0327ev'), isTrue);
    expect(question('çem').acceptsAnswer('c\u0327em'), isTrue);
  });

  test('alternatif yanıt JSON ve dil yansıtmasında kaybolmaz', () {
    const q = QuizQuestion(
      id: 'fill-round-trip',
      category: 'Ziman',
      prompt: 'Ev ___ e.',
      promptTr: 'Bu bir ___.',
      answers: ['dibistan'],
      answersTr: ['okul'],
      correctAnswer: 'dibistan',
      correctAnswerTr: 'okul',
      acceptedAnswers: ['mekteb'],
      acceptedAnswersTr: ['mektep'],
      explanation: '',
      type: QuestionType.fillInBlank,
    );

    final restored = QuizQuestion.fromJson(q.toJson());
    expect(restored.acceptedAnswers, ['mekteb']);
    expect(restored.acceptedAnswersTr, ['mektep']);

    final localized = restored.localized(isKu: false);
    expect(localized.acceptedAnswers, ['mektep']);
    expect(localized.acceptsAnswer('MEKTEP'), isTrue);
    expect(localized.acceptsAnswer('mekteb'), isFalse);
  });

  test('JSON ayrıştırma camelCase ve snake_case tür adlarını kabul eder', () {
    final json = question('pirtûk').toJson()..['type'] = 'fill_in_blank';

    expect(QuizQuestion.fromJson(json).type, QuestionType.fillInBlank);
  });

  test(
    'kabul edilen yazılı yanıt çevrimdışı puanlamada kanonik şık anahtarına gider',
    () {
      const q = QuizQuestion(
        id: 'fill-keyboard-alias',
        category: 'Ziman',
        prompt: 'Valahiyê tijî bike.',
        answers: ['pirtûk'],
        correctAnswer: 'pirtûk',
        acceptedAnswers: ['pirtuk'],
        explanation: '',
        type: QuestionType.fillInBlank,
      );

      expect(q.optionKeyForAnswer(' PIRTUK '), 'A');
      expect(q.optionKeyForAnswer('nivîs'), isEmpty);
    },
  );

  test('tek kanonik cevaplı boşluk doldurma sorusu oynanabilir', () {
    const policy = QuestionContentPolicy();

    expect(policy.validate(question('pirtûk')), isEmpty);
  });

  test('boşluk doldurma tam bir kanonik cevap ister', () {
    const policy = QuestionContentPolicy();
    const noAnswer = QuizQuestion(
      id: 'fill-none',
      category: 'Ziman',
      prompt: 'Valahiyê tijî bike.',
      answers: [],
      correctAnswer: '',
      explanation: '',
      type: QuestionType.fillInBlank,
    );
    const twoAnswers = QuizQuestion(
      id: 'fill-many',
      category: 'Ziman',
      prompt: 'Valahiyê tijî bike.',
      answers: ['pirtûk', 'pênûs'],
      correctAnswer: 'pirtûk',
      explanation: '',
      type: QuestionType.fillInBlank,
    );

    expect(
      policy.validate(noAnswer),
      contains('fill_in_blank_requires_one_canonical_answer'),
    );
    expect(
      policy.validate(twoAnswers),
      contains('fill_in_blank_requires_one_canonical_answer'),
    );
  });

  test('A–D protokollü çevrimiçi gizli-cevap akışı yazılı türü reddeder', () {
    const policy = QuestionContentPolicy();
    const hidden = QuizQuestion(
      id: 'fill-hidden',
      category: 'Ziman',
      prompt: 'Valahiyê tijî bike.',
      answers: [''],
      correctAnswer: '',
      explanation: '',
      type: QuestionType.fillInBlank,
    );

    expect(
      policy.validate(hidden, allowHiddenAnswer: true),
      contains('hidden_answer_unsupported'),
    );
    expect(
      policy.validate(question('pirtûk'), allowHiddenAnswer: true),
      contains('hidden_answer_unsupported'),
    );
  });
}
