import 'player.dart';

enum RoomStatus { lobby, active, finished }

class GameRoom {
  const GameRoom({
    this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.players,
    required this.status,
    required this.questionCount,
    this.secondsPerQuestion = 15,
  });

  final String? id;
  final String name;
  final String code;
  final String category;
  final List<Player> players;
  final RoomStatus status;
  final int questionCount;
  final int secondsPerQuestion;

  GameRoom copyWith({
    String? id,
    String? name,
    String? code,
    String? category,
    List<Player>? players,
    RoomStatus? status,
    int? questionCount,
    int? secondsPerQuestion,
  }) {
    return GameRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      players: players ?? this.players,
      status: status ?? this.status,
      questionCount: questionCount ?? this.questionCount,
      secondsPerQuestion: secondsPerQuestion ?? this.secondsPerQuestion,
    );
  }
}
