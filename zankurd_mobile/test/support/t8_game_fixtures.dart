import 'dart:async';

import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';

/// Canlı bağlantı kurmadan üretim oyun ekranını sürer.
class T8GameVisualRepository extends MockZanKurdRepository {
  final _broadcast = StreamController<Map<String, dynamic>>.broadcast();

  @override
  String? get currentUserId => 'user';

  @override
  Future<String> getProfileName() async => 'Ali';

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) async* {
    yield {'sender': 'Bero', 'sender_id': 'other', 'ready': true};
    yield* _broadcast.stream;
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => room.players;

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value(room.players);

  void revealOpponentAnswer() => _broadcast.add({
    'sender': 'Bero',
    'sender_id': 'other',
    'answered': true,
    'score': 284,
    'question_index': 0,
    'selected_answer': '2',
  });

  Future<void> disposeVisual() => _broadcast.close();
}

const t8GameQuestion = QuizQuestion(
  id: 't8-game',
  category: 'Ziman',
  prompt: 'Yek + yek?',
  promptTr: 'Bir + bir?',
  answers: ['2', '3', '4', '5'],
  correctAnswer: '2',
  explanation: '',
);

GameRoom t8GameRoom({bool crowd = false}) => GameRoom(
  id: crowd ? 't8-crowd' : 't8-duel',
  name: 'T8',
  code: 'T8',
  category: 'Ziman',
  status: RoomStatus.active,
  questionCount: 2,
  secondsPerQuestion: 30,
  maxPlayers: crowd ? 4 : 2,
  isCustom: crowd,
  players: [
    const Player(id: 'user', name: 'Ali', score: 0, state: ''),
    const Player(id: 'other', name: 'Bero', score: 284, state: ''),
    if (crowd) ...const [
      Player(id: 'third', name: 'Cano', score: 100, state: ''),
      Player(id: 'fourth', name: 'Dilan', score: 150, state: ''),
    ],
  ],
);
