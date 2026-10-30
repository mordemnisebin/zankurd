// T10 görsel örneği: yalnız bellek, ağ/kimlik servisi yok.
import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/game/server_clock.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

const _question = QuizQuestion(
  id: 't10-preview-question',
  category: 'Ziman',
  prompt: 'Yek + yek?',
  promptTr: 'Bir + bir?',
  answers: ['2', '3', '4', '5'],
  correctAnswer: '',
  explanation: '',
);

const _room = GameRoom(
  id: 't10-preview-room',
  name: 'T10',
  code: 'T10',
  category: 'Ziman',
  isCustom: true,
  maxPlayers: 4,
  hostId: 'A',
  status: RoomStatus.active,
  questionCount: 1,
  secondsPerQuestion: 20,
  players: [
    Player(id: 'A', name: 'QaAzad', score: 0, state: Player.readyState),
    Player(id: 'B', name: 'QaBero', score: 0, state: Player.readyState),
    Player(id: 'C', name: 'QaCano', score: 0, state: Player.readyState),
    Player(id: 'D', name: 'QaDlan', score: 0, state: Player.readyState),
  ],
);

class _RoomRepo extends MockZanKurdRepository {
  final _startedAt = DateTime.now();
  String? _choice;

  @override
  String get currentUserId => 'B';
  @override
  bool get usesServerHiddenAnswers => true;
  @override
  Future<String> getProfileName() async => 'QaBero';
  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      const Stream.empty();
  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) =>
      const Stream.empty();
  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {}
  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => _room.players;
  @override
  Future<RoomEndState> loadRoomEndState(GameRoom room) async =>
      const RoomEndState(
        status: RoomStatus.active,
        endedReason: null,
        forfeitedBy: null,
      );
  @override
  Future<RoomAnswerProgress?> loadRoomAnswerProgress(GameRoom room) async =>
      RoomAnswerProgress(
        questionIndex: 0,
        answered: _choice == null || _choice == 'TIMEOUT' ? 1 : 2,
        active: 4,
      );
  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    _choice = selectedOptionOptionKey;
    return {'accepted': true, 'pending': true};
  }

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async {
    final now = DateTime.now();
    final deadline = _startedAt.add(const Duration(seconds: 20));
    return RoomResumeSnapshot(
      room: _room,
      currentQuestionIndex: 0,
      ownScore: 0,
      streak: 0,
      bestStreak: 0,
      correctCount: 0,
      wrongCount: 0,
      answers: const [],
      pendingAnswer: _choice == null
          ? null
          : ResumedPendingAnswer(
              questionId: _question.id,
              questionIndex: 0,
              selectedOptionKey: _choice!,
              responseMs: 2000,
            ),
      serverNow: now,
      serverClock: ServerClock(serverNow: now),
      questionStartedAt: _startedAt,
      deadline: deadline,
      remainingMs: deadline.difference(now).inMilliseconds.clamp(0, 20000),
    );
  }

  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) =>
      loadMyResumableRoom();
  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) => loadMyResumableRoom();
}

/// Her açılışta yeni 20 saniye; seçimden sonra sayaç akar ve sayı 2/4 olur.
class T10RoomVisualFixture extends StatefulWidget {
  const T10RoomVisualFixture({super.key});
  @override
  State<T10RoomVisualFixture> createState() => _T10RoomVisualFixtureState();
}

class _T10RoomVisualFixtureState extends State<T10RoomVisualFixture> {
  final _repo = _RoomRepo();
  @override
  Widget build(BuildContext context) =>
      QuizScreen(repository: _repo, room: _room, questions: const [_question]);
}
