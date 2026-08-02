import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/services/room_result_presentation.dart';

void main() {
  test('terminal snapshot seçili dile ve yetkili istatistiklere çevrilir', () {
    final questions = [
      _question('q1', imageUrl: 'https://example.com/q1.webp'),
      _question('q2'),
      _question('q3'),
      _question('q4'),
    ];
    final snapshot = _snapshot(
      questionIds: const ['q1', 'q2', 'q3', 'q4'],
      answers: [
        _answer('q1', 0, selected: 'A', correct: 'A', points: 10),
        _answer('q2', 1, selected: 'B', correct: 'B', points: 20),
        _answer('q3', 2, selected: 'A', correct: 'C', points: 0),
        _answer('q4', 3, selected: 'D', correct: 'D', points: 30),
      ],
      ownScore: 60,
    );

    final result = buildRoomResultPresentation(
      snapshot,
      questions,
      isKu: false,
    );

    expect(result.score, 60);
    expect(result.correctCount, 3);
    expect(result.wrongCount, 1);
    expect(result.totalQuestions, 4);
    expect(result.bestStreak, 2);
    expect(result.opponents.map((player) => player.id), ['opponent']);
    expect(result.answerRecords, hasLength(4));
    expect(result.answerRecords.first.prompt, 'Türkçe q1');
    expect(result.answerRecords.first.answers, const [
      'bir',
      'iki',
      'üç',
      'dört',
    ]);
    expect(result.answerRecords.first.selectedAnswer, 'bir');
    expect(result.answerRecords.first.correctAnswer, 'bir');
    expect(result.answerRecords.first.explanation, 'Yetkili açıklama q1');
    expect(result.answerRecords.first.explanationKu, 'Ravekirina q1');
    expect(result.answerRecords.first.explanationTr, 'Açıklama q1');
    expect(result.answerRecords.first.responseMs, 900);
    expect(result.answerRecords.first.pointsEarned, 10);
    expect(result.answerRecords.first.imageUrl, 'https://example.com/q1.webp');
  });

  test('TIMEOUT cevabı sonuçta unanswered olarak kalır', () {
    final result = buildRoomResultPresentation(
      _snapshot(
        questionIds: const ['q1'],
        answers: [_answer('q1', 0, selected: 'TIMEOUT', correct: 'A')],
        ownScore: 0,
      ),
      [_question('q1')],
      isKu: true,
    );

    expect(result.correctCount, 0);
    expect(result.wrongCount, 0);
    expect(result.answerRecords.single.selectedAnswer, isNull);
    expect(result.answerRecords.single.isUnanswered, isTrue);
  });

  test('soru listesi snapshot sırasıyla birebir eşleşmelidir', () {
    final snapshot = _snapshot(
      questionIds: const ['q1', 'q2'],
      answers: [
        _answer('q1', 0, selected: 'A', correct: 'A'),
        _answer('q2', 1, selected: 'A', correct: 'A'),
      ],
      ownScore: 0,
    );

    expect(
      () => buildRoomResultPresentation(snapshot, [
        _question('q2'),
        _question('q1'),
      ], isKu: true),
      throwsFormatException,
    );
  });

  test('eksik soru listesi reddedilir', () {
    final snapshot = _snapshot(
      questionIds: const ['q1', 'q1'],
      answers: [
        _answer('q1', 0, selected: 'A', correct: 'A'),
        _answer('q1', 1, selected: 'A', correct: 'A'),
      ],
      ownScore: 0,
    );

    expect(
      () =>
          buildRoomResultPresentation(snapshot, [_question('q1')], isKu: true),
      throwsFormatException,
    );
  });

  test('tekrarlı soru kimliği tam uzunlukta olsa da reddedilir', () {
    final snapshot = _snapshot(
      questionIds: const ['q1', 'q1'],
      answers: [
        _answer('q1', 0, selected: 'A', correct: 'A'),
        _answer('q1', 1, selected: 'A', correct: 'A'),
      ],
      ownScore: 0,
    );

    expect(
      () => buildRoomResultPresentation(snapshot, [
        _question('q1'),
        _question('q1'),
      ], isKu: true),
      throwsFormatException,
    );
  });

  test('görünür şıklarda bulunmayan option key reddedilir', () {
    final snapshot = _snapshot(
      questionIds: const ['q1'],
      answers: [_answer('q1', 0, selected: 'D', correct: 'A')],
      ownScore: 0,
    );
    const twoOptionQuestion = QuizQuestion(
      id: 'q1',
      category: 'Ziman',
      prompt: 'Pirs',
      answers: ['Erê', 'Na'],
      correctAnswer: 'Erê',
      explanation: 'Ravekirin',
      type: QuestionType.trueFalse,
    );

    expect(
      () => buildRoomResultPresentation(snapshot, [
        twoOptionQuestion,
      ], isKu: true),
      throwsFormatException,
    );
  });

  test('aynı görünen iki canonical şık sessizce doğru sayılmaz', () {
    const duplicateOptions = QuizQuestion(
      id: 'q1',
      category: 'Ziman',
      prompt: 'Pirs',
      answers: ['heman', 'heman', 'sê', 'çar'],
      correctAnswer: 'heman',
      explanation: 'Ravekirin',
    );

    expect(
      () => buildRoomResultPresentation(
        _snapshot(
          questionIds: const ['q1'],
          answers: [_answer('q1', 0, selected: 'A', correct: 'A')],
          ownScore: 0,
        ),
        [duplicateOptions],
        isKu: true,
      ),
      throwsFormatException,
    );
  });
}

QuizQuestion _question(String id, {String? imageUrl}) => QuizQuestion(
  id: id,
  category: 'Ziman',
  prompt: 'Kurmancî $id',
  promptTr: 'Türkçe $id',
  answers: const ['yek', 'du', 'sê', 'çar'],
  answersTr: const ['bir', 'iki', 'üç', 'dört'],
  correctAnswer: 'yek',
  correctAnswerTr: 'bir',
  explanation: 'Temel açıklama',
  imageUrl: imageUrl,
);

ResumedAnswer _answer(
  String questionId,
  int questionIndex, {
  required String selected,
  required String correct,
  int points = 0,
}) => ResumedAnswer(
  questionId: questionId,
  questionIndex: questionIndex,
  selectedOptionKey: selected,
  correctOptionKey: correct,
  isCorrect: selected == correct,
  pointsAwarded: points,
  responseMs: 900,
  explanation: 'Yetkili açıklama $questionId',
  explanationKu: 'Ravekirina $questionId',
  explanationTr: 'Açıklama $questionId',
);

RoomResultSnapshot _snapshot({
  required List<String> questionIds,
  required List<ResumedAnswer> answers,
  required int ownScore,
}) {
  final players = [
    Player(id: 'me', name: 'Ez', score: ownScore, state: Player.readyState),
    const Player(
      id: 'opponent',
      name: 'Hevrik',
      score: 40,
      state: Player.readyState,
    ),
  ];
  return RoomResultSnapshot(
    room: GameRoom(
      id: 'room-1',
      name: '1vs1',
      code: 'ZK-TEST',
      category: 'Ziman',
      players: players,
      status: RoomStatus.finished,
      questionCount: questionIds.length,
    ),
    ownPlayerId: 'me',
    questionIds: questionIds,
    answers: answers,
    winnerId: ownScore > 40 ? 'me' : null,
    endedReason: 'completed',
    forfeitedBy: null,
    finishedAt: DateTime.utc(2026, 8, 2),
  );
}
