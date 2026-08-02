import '../models/answer_record.dart';
import '../models/player.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';

/// Tamamlanmış çevrimiçi oda sonucunun UI'dan bağımsız sunum verisi.
class RoomResultPresentation {
  RoomResultPresentation({
    required this.room,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.totalQuestions,
    required this.bestStreak,
    required List<AnswerRecord> answerRecords,
    required List<Player> opponents,
  }) : answerRecords = List.unmodifiable(answerRecords),
       opponents = List.unmodifiable(opponents);

  final GameRoom room;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int totalQuestions;
  final int bestStreak;
  final List<AnswerRecord> answerRecords;
  final List<Player> opponents;
}

/// Yetkili terminal snapshot'ı, aktif bir QuizScreen'e ihtiyaç duymadan
/// sonuç ekranının kullandığı verilere dönüştürür.
RoomResultPresentation buildRoomResultPresentation(
  RoomResultSnapshot snapshot,
  List<QuizQuestion> questions, {
  required bool isKu,
}) {
  final questionIds = snapshot.questionIds;
  if (questionIds.length != snapshot.room.questionCount ||
      questions.length != questionIds.length ||
      snapshot.answers.length != questionIds.length ||
      questionIds.any((id) => id.trim().isEmpty) ||
      questionIds.toSet().length != questionIds.length ||
      questions.map((question) => question.id).toSet().length !=
          questions.length) {
    throw const FormatException('Room result questions are incomplete.');
  }

  final ownPlayers = snapshot.room.players
      .where((player) => player.id == snapshot.ownPlayerId)
      .toList(growable: false);
  if (ownPlayers.length != 1) {
    throw const FormatException('Room result owner is not a room player.');
  }

  final localizedQuestions = <QuizQuestion>[];
  for (var index = 0; index < questions.length; index++) {
    final question = questions[index];
    if (question.id != questionIds[index]) {
      throw const FormatException(
        'Room result questions are not in canonical order.',
      );
    }
    final localized = question.localized(isKu: isKu);
    final visibleOptions = localized.answers
        .map((option) => option.trim())
        .toList(growable: false);
    if (visibleOptions.any((option) => option.isEmpty) ||
        visibleOptions.toSet().length != visibleOptions.length) {
      throw const FormatException(
        'Room result options are empty or ambiguous.',
      );
    }
    localizedQuestions.add(localized);
  }

  final records = <AnswerRecord>[];
  var correctCount = 0;
  var wrongCount = 0;
  var currentStreak = 0;
  var bestStreak = 0;

  for (var index = 0; index < snapshot.answers.length; index++) {
    final answer = snapshot.answers[index];
    if (answer.questionIndex != index ||
        answer.questionId != questionIds[index]) {
      throw const FormatException(
        'Room result answers are not in canonical order.',
      );
    }

    final question = localizedQuestions[index];
    final correctAnswer = question.answerForOptionKey(answer.correctOptionKey);
    if (correctAnswer == null) {
      throw const FormatException('Room result correct option is unavailable.');
    }

    final String? selectedAnswer;
    if (answer.selectedOptionKey == 'TIMEOUT') {
      selectedAnswer = null;
    } else {
      selectedAnswer = question.answerForOptionKey(answer.selectedOptionKey);
      if (selectedAnswer == null) {
        throw const FormatException(
          'Room result selected option is unavailable.',
        );
      }
    }
    final canonicalIsCorrect =
        answer.selectedOptionKey != 'TIMEOUT' &&
        answer.selectedOptionKey == answer.correctOptionKey;
    if (answer.isCorrect != canonicalIsCorrect) {
      throw const FormatException('Room result answer is inconsistent.');
    }

    if (answer.isCorrect) {
      correctCount++;
      currentStreak++;
      if (currentStreak > bestStreak) bestStreak = currentStreak;
    } else {
      currentStreak = 0;
      if (selectedAnswer != null) wrongCount++;
    }

    final revealedQuestion = question.withRevealedAnswer(
      correctAnswer: correctAnswer,
      explanation: answer.explanation,
      explanationKu: answer.explanationKu,
      explanationTr: answer.explanationTr,
    );
    records.add(
      AnswerRecord(
        id: revealedQuestion.id,
        category: revealedQuestion.category,
        prompt: revealedQuestion.promptText,
        answers: List.unmodifiable(revealedQuestion.answers),
        correctAnswer: correctAnswer,
        selectedAnswer: selectedAnswer,
        explanation: revealedQuestion.explanation,
        explanationKu: revealedQuestion.explanationKu,
        explanationTr: revealedQuestion.explanationTr,
        responseMs: answer.responseMs,
        pointsEarned: answer.pointsAwarded,
        imageUrl: revealedQuestion.imageUrl,
      ),
    );
  }

  final players = List<Player>.unmodifiable(snapshot.room.players);
  return RoomResultPresentation(
    room: snapshot.room.copyWith(players: players),
    score: ownPlayers.single.score,
    correctCount: correctCount,
    wrongCount: wrongCount,
    totalQuestions: questionIds.length,
    bestStreak: bestStreak,
    answerRecords: records,
    opponents: players
        .where((player) => player.id != snapshot.ownPlayerId)
        .toList(growable: false),
  );
}
