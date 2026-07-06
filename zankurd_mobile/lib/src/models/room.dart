import 'dart:math';

import 'player.dart';

enum RoomStatus { lobby, active, finished }

/// Karışması zor karakterlerden (I/O/0/1 yok) 4 haneli oda kodu üretir.
/// 32^4 ≈ 1M kombinasyon; saat milisaniyesine dayalı eski üretim yalnızca
/// 1000 farklı kod verdiğinden çakışma kaçınılmazdı.
String generateRoomCode([Random? random]) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = random ?? Random();
  final suffix = List.generate(
    4,
    (_) => alphabet[rng.nextInt(alphabet.length)],
  ).join();
  return 'ZK-$suffix';
}

class GameRoom {
  const GameRoom({
    this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.players,
    required this.status,
    required this.questionCount,
    this.hostId,
  });

  final String? id;
  final String name;
  final String code;
  final String category;
  final List<Player> players;
  final RoomStatus status;
  final int questionCount;
  final String? hostId;

  GameRoom copyWith({
    String? id,
    String? name,
    String? code,
    String? category,
    List<Player>? players,
    RoomStatus? status,
    int? questionCount,
    String? hostId,
  }) {
    return GameRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      players: players ?? this.players,
      status: status ?? this.status,
      questionCount: questionCount ?? this.questionCount,
      hostId: hostId ?? this.hostId,
    );
  }
}
