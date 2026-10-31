import 'progress_snapshot.dart';

/// Ödeme öncesinde saklanan değişmez, tarihli kullanıcı kararı.
class PaidFreezeIntent {
  const PaidFreezeIntent({
    required this.ownerId,
    required this.roundId,
    required this.idempotencyKey,
    required this.playedDay,
    required this.previousLastDay,
    required this.targetCurrent,
    required this.targetBest,
    required this.playedDays,
    required this.frozenDays,
  });

  final String ownerId;
  final String roundId;
  final String idempotencyKey;
  final String playedDay;
  final String previousLastDay;
  final int targetCurrent;
  final int targetBest;
  final List<String> playedDays;
  final List<String> frozenDays;

  Map<String, Object> toJson() => {
    'ownerId': ownerId,
    'roundId': roundId,
    'idempotencyKey': idempotencyKey,
    'playedDay': playedDay,
    'previousLastDay': previousLastDay,
    'targetCurrent': targetCurrent,
    'targetBest': targetBest,
    'playedDays': playedDays,
    'frozenDays': frozenDays,
  };

  static PaidFreezeIntent decode(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid freeze intent.');
    }
    final owner = value['ownerId'];
    final round = value['roundId'];
    final key = value['idempotencyKey'];
    final day = value['playedDay'];
    final previous = value['previousLastDay'];
    final current = value['targetCurrent'];
    final best = value['targetBest'];
    final played = value['playedDays'];
    final frozen = value['frozenDays'];
    bool days(Object? values) =>
        values is List &&
        values.length <= 400 &&
        values.every(
          (v) =>
              v is String &&
              SnapshotStreak.isValidDayKey(v) &&
              day is String &&
              v.compareTo(day) <= 0,
        );
    if (owner is! String ||
        owner.trim().isEmpty ||
        owner != owner.trim() ||
        round is! String ||
        round.trim().isEmpty ||
        round != round.trim() ||
        key != 'zankurd.quiz_result_progress_receipt.$owner:$round' ||
        day is! String ||
        !SnapshotStreak.isValidDayKey(day) ||
        previous is! String ||
        !SnapshotStreak.isValidDayKey(previous) ||
        previous.compareTo(day) >= 0 ||
        current is! int ||
        current < 2 ||
        best is! int ||
        best < current ||
        !days(played) ||
        !days(frozen) ||
        !(played as List).contains(day)) {
      throw const FormatException('Invalid dated freeze intent.');
    }
    return PaidFreezeIntent(
      ownerId: owner,
      roundId: round,
      idempotencyKey: key as String,
      playedDay: day,
      previousLastDay: previous,
      targetCurrent: current,
      targetBest: best,
      playedDays: List<String>.from(played),
      frozenDays: List<String>.from(frozen as List),
    );
  }
}
