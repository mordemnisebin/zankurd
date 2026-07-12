import '../l10n/explanation_ku.dart';
import '../l10n/explanation_overrides.dart';
import 'question_metadata.dart';

enum QuestionType { multipleChoice, trueFalse, visual }

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.category,
    required this.prompt,
    required this.answers,
    required this.correctAnswer,
    required this.explanation,
    this.explanationKu,
    this.explanationTr,
    this.type = QuestionType.multipleChoice,
    this.imageUrl,
    this.difficulty = 2,
    this.metadata,
  });

  final String id;
  final String category;
  final String prompt;
  final List<String> answers;
  final String correctAnswer;
  final String explanation;
  final String? explanationKu;
  final String? explanationTr;
  final QuestionType type;
  final String? imageUrl;
  final int difficulty;

  /// Editör/kalite meta verisi (opsiyonel, geriye uyumlu). Eski verilerde
  /// `null`'dır ve [ContentQualityPolicy] bunu "uygun ama doğrulanmamış"
  /// olarak ele alır.
  final QuestionMetadata? metadata;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  String get promptText => prompt;

  List<String> get displayAnswers {
    if (type == QuestionType.trueFalse || answers.length < 3) {
      return List.unmodifiable(answers);
    }

    final rotated = List<String>.of(answers);
    final offset = _stableAnswerOffset(rotated.length);
    return List.unmodifiable([
      ...rotated.skip(offset),
      ...rotated.take(offset),
    ]);
  }

  String optionKeyForAnswer(String answer) {
    final index = answers.indexOf(answer);
    return switch (index) {
      0 => 'A',
      1 => 'B',
      2 => 'C',
      3 => 'D',
      _ => '',
    };
  }

  int _stableAnswerOffset(int length) {
    final seed = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final offset = seed % length;
    return offset == 0 ? 1 : offset;
  }

  String get levelPrefix {
    return switch (difficulty) {
      1 => 'Easy',
      2 => 'Medium',
      3 => 'Hard',
      _ => 'Medium',
    };
  }

  String get typeLabel {
    return switch (type) {
      QuestionType.multipleChoice => 'Şıklı',
      QuestionType.trueFalse => 'Doğru/Yanlış',
      QuestionType.visual => 'Görselli',
    };
  }

  String typeLabelLocalized(bool isKu) {
    return switch (type) {
      QuestionType.multipleChoice => isKu ? 'Hilbijarin' : 'Şıklı',
      QuestionType.trueFalse => isKu ? 'Rast/Xelet' : 'Doğru/Yanlış',
      QuestionType.visual => isKu ? 'Entık' : 'Görselli',
    };
  }

  String getLocalizedExplanation(bool isKu) {
    // Öncelik: soruya özel açıklama (DB) > elle yazılmış override > şablon.
    if (isKu) {
      if (explanationKu != null && explanationKu!.trim().isNotEmpty) {
        return explanationKu!;
      }
      final override = explanationOverrides[id];
      if (override != null) return override.ku;
      return explanationToKu(explanation);
    } else {
      if (explanationTr != null && explanationTr!.trim().isNotEmpty) {
        return explanationTr!;
      }
      final override = explanationOverrides[id];
      if (override != null) return override.tr;
      return explanation;
    }
  }
}
