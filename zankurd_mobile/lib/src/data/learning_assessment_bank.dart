import 'package:flutter/foundation.dart' show visibleForTesting;
import '../models/question_metadata.dart';
import '../models/quiz_question.dart';
import 'learner_lexicon.dart';

/// Ders slaytlarından editoryal olarak çıkarılmış sözlük çiftlerini mini-quiz
/// sorularına dönüştürür.
///
/// Bu banka yeni bir çeviri üretmez. [LearnerLexicon] içindeki her çift zaten
/// ilgili ZanKurd dersinde açıkça bulunur; burada yalnız ölçme biçimine
/// dönüştürülür ve ders kimliği/provenance bilgisi korunur.
class LearningAssessmentBank {
  const LearningAssessmentBank._();

  static List<QuizQuestion> questionsFor({
    required String lessonId,
    required String category,
    int? limit = 5,
  }) {
    if (limit != null && limit <= 0) return const [];
    final source = LearnerLexicon.sources[lessonId];
    final lessonEntries = LearnerLexicon.entriesForSource(lessonId);
    if (source == null || lessonEntries.isEmpty) return const [];

    // Önce her terimden bir soru: yakın iki sorunun birbirinin çevirisini
    // vermemesi için ters yönler ikinci geçişte gelir.
    final generated = <QuizQuestion>[
      for (final reverse in [false, true])
        for (final (index, entry) in lessonEntries.indexed)
          ?_question(
            entry: entry,
            source: source,
            category: category,
            kuToTr: index.isEven != reverse,
          ),
    ];
    return limit == null ? generated : generated.take(limit).toList();
  }

  /// Sunucu dersinin slaytında geçen hedefler. Bir dersin ölçme etiketi daha
  /// geniş bir yerel konuyu kapsayabildiğinden bunlar slug ile seçilir.
  static const _writingEntries = <String, List<String>>{
    'hejmar': ['yek', 'du', 'penc', 'heft', 'neh', 'deh', 'bist', 'sed'],
    'demsal': ['bihar', 'havin', 'payiz', 'zivistan'],
    'cih-u-war': ['q-gund', 'q-gol', 'q-daristan', 'q-zozan'],
  };

  // Yeni çeviri üretmeden slayttaki cümleyi kurdur. Olmak fiilinde
  // ders_2026_10_02_0016, duygularda wo-ku-007 iki dili birlikte verir.
  // Diğer çiftler 2026-07-06_lesson_seed.sql içinde yan yana yazılıdır.
  static const _sentences = <String, (String, String)>{
    'lekera-bun': ('Tu xwendekar î', 'Sen öğrencisin'),
    'hesten-bingehin': ('ez ji te hez dikim', 'Seni seviyorum.'),
    'newroz': ('Agir sembola Newrozê ye', "Ateş Newroz'un sembolüdür."),
    'dengbeji': (
      'Evdalê Zeynikê dengbêjekî navdar e',
      'Evdalê Zeynikê ünlü bir dengbejdir.',
    ),
    'ciya-u-cem': (
      'Ferat û Dîcle du çemên mezin in',
      'Fırat ve Dicle iki büyük nehirdir.',
    ),
  };

  static List<QuizQuestion> practiceFor({
    required String slug,
    required String bankId,
    required String category,
  }) {
    final source = LearnerLexicon.sources[bankId];
    if (source == null) return const [];
    if (_sentences[slug] case final sentence?) {
      final (ku, tr) = sentence;
      final words = ku.split(' ');
      return [
        QuizQuestion(
          id: 'practice_${slug}_sentence',
          category: category,
          prompt: 'Hevokê rêz bike: "$tr"',
          promptTr: 'Cümleyi sırala: "$tr"',
          type: QuestionType.wordOrdering,
          answers: words,
          // İki nehrin yeri değişse de aynı olgu anlatılır. Diğer taşların
          // sırası yine denetlenir.
          acceptedAnswers: [
            if (slug == 'ciya-u-cem')
              [words[2], words[1], words[0], ...words.skip(3)].join(' '),
          ],
          correctAnswer: ku,
          explanation: '$ku.',
          explanationKu: '$ku.',
          explanationTr: '$ku. ($tr)',
          difficulty: 1,
          metadata: QuestionMetadata(
            learningLessonId: bankId,
            sourceReference: 'lesson:$slug',
          ),
        ),
      ];
    }

    final weekdays = bankId == 'time_weekdays';
    final entries = weekdays
        ? LearnerLexicon.entriesForSource(bankId)
        : [
            for (final id in _writingEntries[slug] ?? const <String>[])
              ?LearnerLexicon.byId(id),
          ];
    return [
      for (final entry in entries) ...[
        if (weekdays)
          ?_question(
            entry: entry,
            source: source,
            category: category,
            kuToTr: true,
          ),
        ?_question(
          entry: entry,
          source: source,
          category: category,
          kuToTr: false,
          write: true,
        ),
      ],
    ];
  }

  /// Kurmancî "e" kopulası: ünlüyle biten sözcükten sonra `ye`, ünsüzle
  /// bitenden sonra `e` (ör. "Bira ye", "Dest e"). Eskiden yön başına
  /// sabitti (KU→TR hep `ye`, TR→KU hep `e`) ve "Erkek kardeş ye" gibi
  /// bozuk cümle üretiyordu. Seçim, sözcüğün son HARFİNE göre yapılır.
  @visibleForTesting
  static String copulaFor(String word) {
    final letters = word.trim().replaceAll(
      RegExp(r'[^A-Za-zÇĞİÖŞÜÂÊÎÛçğıöşüâêîû]+$'),
      '',
    );
    if (letters.isEmpty) return 'e';
    return 'aeêiîouûöüıâAEÊIİÎOUÛÖÜÂ'.contains(letters[letters.length - 1])
        ? 'ye'
        : 'e';
  }

  static QuizQuestion? _question({
    required LearnerLexiconEntry entry,
    required LearnerLexiconSource source,
    required String category,
    required bool kuToTr,
    bool write = false,
  }) {
    final answer = kuToTr ? entry.meaningTr : entry.termKu;
    final direction = kuToTr ? 'ku-tr' : 'tr-ku';
    final answers = write ? [answer] : _options(entry, source.id, kuToTr);
    if (!write && answers.length < 4) return null;
    // 2026-09-25 düzeltmesi: üç alan da aynı formülü taşıyordu
    // ("sêv = elma."), yani `explanationKu` bir Kürtçe açıklama değildi ve
    // Türkçe okurken de Kürtçe terim görünüyordu. Artık sorunun yönüne
    // göre ayrı cümleler kurulur.
    final explanationKu = kuToTr
        ? '“${entry.termKu}” bi Tirkî “${entry.meaningTr}” ${copulaFor(entry.meaningTr)}.'
        : '“${entry.meaningTr}” bi Kurmancî “${entry.termKu}” ${copulaFor(entry.termKu)}.';
    final explanationTr = kuToTr
        ? '“${entry.termKu}” Türkçede “${entry.meaningTr}” demektir.'
        : '“${entry.meaningTr}” Kurmancîde “${entry.termKu}” olarak söylenir.';

    return QuizQuestion(
      id: 'lesson_${source.id}_${entry.id}_${write ? 'write' : direction}',
      type: write ? QuestionType.fillInBlank : QuestionType.multipleChoice,
      category: category,
      prompt: kuToTr
          ? '“${entry.termKu}” bi Tirkî çi wateyê dide?'
          : '“${entry.meaningTr}” bi Kurmancî çawa tê gotin?',
      promptTr: kuToTr
          ? '“${entry.termKu}” Türkçede ne anlama gelir?'
          : '“${entry.meaningTr}” Kurmancî’de nasıl söylenir?',
      answers: answers,
      correctAnswer: answer,
      answerLanguage: kuToTr ? AnswerLanguage.turkish : AnswerLanguage.kurmanji,
      explanation: explanationKu,
      explanationKu: explanationKu,
      explanationTr: explanationTr,
      difficulty: 1,
      metadata: QuestionMetadata(
        sourceTitle: 'ZanKurd ders içeriği: ${source.titleKu}',
        sourceReference: 'lesson:${source.id}:lexicon:${entry.id}',
        learningLessonId: source.id,
      ),
    );
  }

  static final _separator = RegExp(r'\s*[/,;]\s*');

  // Eşanlam ya da alternatif yazım yanlış şık olamaz. Örneğin bir ayın
  // aynı Türkçe karşılığı olan iki Kurmancî adı sözlükte ayrı kayıtlıdır.
  static Set<String> _forms(String text) =>
      text.split(_separator).map(LearnerLexicon.foldForSearch).toSet();

  static List<String> _options(
    LearnerLexiconEntry entry,
    String lessonId,
    bool kuToTr,
  ) {
    final terms = _forms(entry.termKu);
    final meanings = _forms(entry.meaningTr);
    final values = [kuToTr ? entry.meaningTr : entry.termKu];
    final seed = entry.id.codeUnits.fold(kuToTr ? 1 : 2, (a, b) => a + b);
    // Önce aynı dersten. Küçük derslerde kalan yeri sözlükten tamamla.
    for (final pool in [
      LearnerLexicon.entriesForSource(lessonId),
      LearnerLexicon.entries,
    ]) {
      for (var n = 0; n < pool.length && values.length < 4; n++) {
        final candidate = pool[(seed + n) % pool.length];
        final candidateTerms = _forms(candidate.termKu);
        final candidateMeanings = _forms(candidate.meaningTr);
        if (candidateTerms.any(terms.contains) ||
            candidateMeanings.any(meanings.contains)) {
          continue;
        }
        terms.addAll(candidateTerms);
        meanings.addAll(candidateMeanings);
        values.add(kuToTr ? candidate.meaningTr : candidate.termKu);
      }
      if (values.length == 4) break;
    }
    final rotation = seed % values.length;
    return [...values.skip(rotation), ...values.take(rotation)];
  }
}
