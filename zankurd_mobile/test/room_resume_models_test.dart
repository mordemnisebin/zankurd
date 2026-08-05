import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';

void main() {
  test('resume snapshot cevap geçmişini dışarıdan değiştirilemez tutar', () {
    final sourceAnswers = <ResumedAnswer>[
      const ResumedAnswer(
        questionId: 'question-1',
        questionIndex: 0,
        selectedOptionKey: 'A',
        correctOptionKey: 'B',
        isCorrect: false,
        pointsAwarded: 0,
        responseMs: 4200,
        explanation: 'Açıklama',
        explanationKu: 'Ravekirin',
        explanationTr: 'Açıklama',
      ),
    ];
    final snapshot = RoomResumeSnapshot(
      room: const GameRoom(
        id: 'room-1',
        name: '1vs1',
        code: 'ZK-TEST',
        category: 'Ziman',
        players: [
          Player(id: 'me', name: 'Ez', score: 0, state: Player.readyState),
        ],
        status: RoomStatus.active,
        questionCount: 10,
      ),
      currentQuestionIndex: 1,
      ownScore: 0,
      streak: 0,
      bestStreak: 0,
      correctCount: 0,
      wrongCount: 1,
      answers: sourceAnswers,
      serverNow: DateTime.utc(2026, 8, 2, 12),
      questionStartedAt: DateTime.utc(2026, 8, 2, 11, 59, 55),
      deadline: DateTime.utc(2026, 8, 2, 12, 0, 15),
      remainingMs: 15000,
    );

    sourceAnswers.clear();

    expect(snapshot.answers, hasLength(1));
    expect(snapshot.answers.single.correctOptionKey, 'B');
    expect(
      () => snapshot.answers.add(snapshot.answers.single),
      throwsUnsupportedError,
    );
  });

  test('room end state forfeit bilgisini taşır', () {
    const state = RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'forfeit',
      forfeitedBy: 'player-2',
    );

    expect(state.status, RoomStatus.finished);
    expect(state.endedReason, 'forfeit');
    expect(state.forfeitedBy, 'player-2');
  });
}
