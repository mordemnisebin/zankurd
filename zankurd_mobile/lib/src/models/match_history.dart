/// Profildeki "Son maçlar" satırının türü (`list_my_recent_matches.kind`).
///
/// `async`: sırayla düello; `room1v1`: canlı hızlı düello (iki kişilik oda);
/// `room`: kalabalık oda maçı. Tanınmayan tür [room] sayılır: yeni bir sunucu
/// türü satırı düşürmek yerine genel oda ikonuyla görünür.
enum RecentMatchKind { async, room1v1, room }

/// Maçın çağıran açısından sonucu.
enum RecentMatchResult { win, loss, draw }

RecentMatchKind _kindFromJson(Object? value) => switch (value) {
  'async' => RecentMatchKind.async,
  'room_1v1' => RecentMatchKind.room1v1,
  _ => RecentMatchKind.room,
};

RecentMatchResult? _resultFromJson(Object? value) => switch (value) {
  'win' => RecentMatchResult.win,
  'loss' => RecentMatchResult.loss,
  'draw' => RecentMatchResult.draw,
  _ => null,
};

/// `list_my_recent_matches` satırı: bitmiş tek bir maç.
///
/// Skorlar boş olabilir: hükmen kaybeden turunu bitirmediyse kendi skoru ya
/// da rakibinki yoktur; satır o zaman skor göstermez.
class RecentMatch {
  const RecentMatch({
    required this.kind,
    required this.id,
    required this.result,
    required this.playedAt,
    this.opponentId,
    this.opponentName,
    this.forfeit = false,
    this.myScore,
    this.opponentScore,
  });

  final RecentMatchKind kind;
  final String id;
  final RecentMatchResult result;
  final DateTime playedAt;
  final String? opponentId;
  final String? opponentName;

  /// Hükmen sonuç (rakip ya da ben maçı terk ettim / turu bitirmedim).
  final bool forfeit;
  final int? myScore;
  final int? opponentScore;

  /// Bilinmeyen sonuçlu satır `null` döner (listeden düşer): "sonuç yok"
  /// bir kazanç ya da kayıp gibi uydurulmaz.
  static RecentMatch? tryParse(Map<String, dynamic> json) {
    final result = _resultFromJson(json['result']);
    final at = json['at'];
    final id = json['id'];
    if (result == null || at is! String || id is! String) return null;
    final playedAt = DateTime.tryParse(at);
    if (playedAt == null) return null;
    return RecentMatch(
      kind: _kindFromJson(json['kind']),
      id: id,
      result: result,
      playedAt: playedAt,
      opponentId: json['opponent_id'] as String?,
      opponentName: json['opponent_name'] as String?,
      forfeit: json['forfeit'] as bool? ?? false,
      myScore: (json['my_score'] as num?)?.toInt(),
      opponentScore: (json['opponent_score'] as num?)?.toInt(),
    );
  }
}

/// `get_my_records` sunucu sayıları (profildeki "Rekorlarım").
///
/// Düello = sırayla düello + canlı hızlı düello. Rekor yoksa alan null:
/// ekran "—" gösterir, sıfır uydurmaz.
class ServerRecords {
  const ServerRecords({
    this.duelWins = 0,
    this.duelLosses = 0,
    this.duelDraws = 0,
    this.bestQuizStreak,
    this.bestContestCorrect,
  });

  final int duelWins;
  final int duelLosses;
  final int duelDraws;

  /// Canlı odalarda en uzun art arda doğru serisi.
  final int? bestQuizStreak;

  /// Günlük yarışta tek günde en çok doğru sayısı.
  final int? bestContestCorrect;

  int get duelTotal => duelWins + duelLosses + duelDraws;

  /// Kazanma oranı (0–100, yuvarlanmış); hiç düello yoksa null.
  int? get winRatePercent =>
      duelTotal == 0 ? null : (duelWins * 100 / duelTotal).round();

  factory ServerRecords.fromJson(Map<String, dynamic> json) => ServerRecords(
    duelWins: (json['duel_wins'] as num?)?.toInt() ?? 0,
    duelLosses: (json['duel_losses'] as num?)?.toInt() ?? 0,
    duelDraws: (json['duel_draws'] as num?)?.toInt() ?? 0,
    bestQuizStreak: (json['best_quiz_streak'] as num?)?.toInt(),
    bestContestCorrect: (json['best_contest_correct'] as num?)?.toInt(),
  );
}
