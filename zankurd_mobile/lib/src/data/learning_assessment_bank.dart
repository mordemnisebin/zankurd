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
    int limit = 5,
  }) {
    if (limit <= 0) return const [];
    final source = LearnerLexicon.sources[lessonId];
    final lessonEntries = LearnerLexicon.entriesForSource(lessonId);
    if (source == null || lessonEntries.isEmpty) return const [];

    final generated = <QuizQuestion>[];
    for (final entry in lessonEntries) {
      generated
        ..add(
          _question(
            entry: entry,
            source: source,
            category: category,
            kuToTr: true,
          ),
        )
        ..add(
          _question(
            entry: entry,
            source: source,
            category: category,
            kuToTr: false,
          ),
        );
    }

    // Aynı ders her açıldığında aynı başlangıç kümesi gelsin. _selectFresh
    // katmanı daha sonra görülen soruları döndürerek tekrarları azaltır.
    return generated.take(limit).toList(growable: false);
  }

  static QuizQuestion _question({
    required LearnerLexiconEntry entry,
    required LearnerLexiconSource source,
    required String category,
    required bool kuToTr,
  }) {
    final answer = kuToTr ? entry.meaningTr : entry.termKu;
    final pool = LearnerLexicon.entries
        .where((candidate) => candidate.id != entry.id)
        .map((candidate) => kuToTr ? candidate.meaningTr : candidate.termKu)
        .where(
          (candidate) => candidate.trim().isNotEmpty && candidate != answer,
        )
        .toSet()
        .toList(growable: false);
    final answers = _stableOptions(answer, pool, entry.id, kuToTr);
    final direction = kuToTr ? 'ku-tr' : 'tr-ku';
    // 2026-09-25 düzeltmesi: üç alan da aynı formülü taşıyordu
    // ("sêv = elma."), yani `explanationKu` bir Kürtçe açıklama değildi ve
    // Türkçe okurken de Kürtçe terim görünüyordu. Artık sorunun yönüne
    // göre ayrı cümleler kurulur.
    final explanationKu = kuToTr
        ? '“${entry.termKu}” bi Tirkî “${entry.meaningTr}” ye.'
        : '“${entry.meaningTr}” bi Kurmancî “${entry.termKu}” e.';
    final explanationTr = kuToTr
        ? '“${entry.termKu}” Türkçede “${entry.meaningTr}” demektir.'
        : '“${entry.meaningTr}” Kurmancîde “${entry.termKu}” olarak söylenir.';

    return QuizQuestion(
      id: 'lesson_${source.id}_${entry.id}_$direction',
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

  static List<String> _stableOptions(
    String correct,
    List<String> candidates,
    String seed,
    bool kuToTr,
  ) {
    final values = <String>[correct, ...candidates.take(3)];
    if (values.length <= 1) return values;
    final rotation =
        (seed.codeUnits.fold<int>(kuToTr ? 1 : 2, (sum, unit) => sum + unit)) %
        values.length;
    return <String>[...values.skip(rotation), ...values.take(rotation)];
  }
}
