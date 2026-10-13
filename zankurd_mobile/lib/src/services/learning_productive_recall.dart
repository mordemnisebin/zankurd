import '../models/question_metadata.dart';
import '../models/quiz_question.dart';

/// Öğrenme modunda editör tarafından açıkça uygun görülen çoktan seçmeli
/// soruları yazmalı hatırlamaya çevirir.
///
/// Dönüşüm fail-closed çalışır: yalnız `approved` ve
/// `productiveRecallEligible` işaretli, cevabı gizli olmayan MC sorularına
/// uygulanır. Böylece seçeneklere bağımlı promptlar otomatik dönüştürülmez.
abstract final class LearningProductiveRecall {
  static List<QuizQuestion> orderForLearning(List<QuizQuestion> questions) {
    if (questions.length < 2) {
      return List<QuizQuestion>.of(questions);
    }

    final eligibleIndexes = <int>[
      for (var index = 0; index < questions.length; index++)
        if (_isEligible(questions[index])) index,
    ];
    if (eligibleIndexes.isEmpty || questions.every(_isEligible)) {
      return List<QuizQuestion>.of(questions);
    }

    final targetPositions = questions.length <= 5
        ? const <int>[1]
        : const <int>[1, 4];
    final promotedIndexes = eligibleIndexes
        .take(targetPositions.length)
        .toSet();
    final promoted = <QuizQuestion>[
      for (final index in eligibleIndexes.take(targetPositions.length))
        questions[index],
    ];
    final ordered = <QuizQuestion>[
      for (var index = 0; index < questions.length; index++)
        if (!promotedIndexes.contains(index)) questions[index],
    ];

    final warmupIndex = ordered.indexWhere(
      (question) => !_isEligible(question),
    );
    if (warmupIndex > 0) {
      final warmup = ordered.removeAt(warmupIndex);
      ordered.insert(0, warmup);
    }

    for (var index = 0; index < promoted.length; index++) {
      final target = targetPositions[index].clamp(0, ordered.length);
      ordered.insert(target, promoted[index]);
    }
    return ordered;
  }

  static QuizQuestion transform(QuizQuestion question) {
    if (!_isEligible(question)) {
      return question;
    }

    final metadata = question.metadata;
    final translatedCorrect = question.correctAnswerTr?.trim();
    return QuizQuestion(
      id: question.id,
      category: question.category,
      prompt: question.prompt,
      answers: [question.correctAnswer],
      correctAnswer: question.correctAnswer,
      acceptedAnswers: question.acceptedAnswers,
      acceptedAnswersTr: question.acceptedAnswersTr,
      answerLanguage: question.answerLanguage,
      explanation: question.explanation,
      explanationKu: question.explanationKu,
      explanationTr: question.explanationTr,
      promptTr: question.promptTr,
      answersTr: translatedCorrect == null || translatedCorrect.isEmpty
          ? null
          : [translatedCorrect],
      correctAnswerTr: question.correctAnswerTr,
      hintKu: question.hintKu,
      hintTr: question.hintTr,
      audioUrl: question.audioUrl,
      type: QuestionType.fillInBlank,
      imageUrl: question.imageUrl,
      imageAltKu: question.imageAltKu,
      imageAltTr: question.imageAltTr,
      difficulty: question.difficulty,
      metadata: metadata,
    );
  }

  static bool isEligible(QuizQuestion question) => _isEligible(question);

  static bool _isEligible(QuizQuestion question) {
    final metadata = question.metadata;
    return question.type == QuestionType.multipleChoice &&
        !question.hasHiddenAnswer &&
        metadata?.reviewStatus == ReviewStatus.approved &&
        metadata?.productiveRecallEligible == true;
  }
}
