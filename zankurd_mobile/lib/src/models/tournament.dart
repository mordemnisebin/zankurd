import 'package:flutter/foundation.dart';

@immutable
class TournamentMatch {
  final String id;
  final String playerOneId;
  final String playerOneName;
  final String playerTwoId;
  final String playerTwoName;
  final int playerOneScore;
  final int playerTwoScore;
  final String status; // 'pending', 'active', 'completed'
  final String winnerId;
  final String questionCategory;
  final int questionsAnswered;

  const TournamentMatch({
    required this.id,
    required this.playerOneId,
    required this.playerOneName,
    required this.playerTwoId,
    required this.playerTwoName,
    required this.playerOneScore,
    required this.playerTwoScore,
    required this.status,
    required this.winnerId,
    this.questionCategory = '',
    this.questionsAnswered = 0,
  });

  TournamentMatch copyWith({
    String? id,
    String? playerOneId,
    String? playerOneName,
    String? playerTwoId,
    String? playerTwoName,
    int? playerOneScore,
    int? playerTwoScore,
    String? status,
    String? winnerId,
    String? questionCategory,
    int? questionsAnswered,
  }) => TournamentMatch(
    id: id ?? this.id,
    playerOneId: playerOneId ?? this.playerOneId,
    playerOneName: playerOneName ?? this.playerOneName,
    playerTwoId: playerTwoId ?? this.playerTwoId,
    playerTwoName: playerTwoName ?? this.playerTwoName,
    playerOneScore: playerOneScore ?? this.playerOneScore,
    playerTwoScore: playerTwoScore ?? this.playerTwoScore,
    status: status ?? this.status,
    winnerId: winnerId ?? this.winnerId,
    questionCategory: questionCategory ?? this.questionCategory,
    questionsAnswered: questionsAnswered ?? this.questionsAnswered,
  );

  factory TournamentMatch.fromJson(Map<String, dynamic> json) =>
      TournamentMatch(
        id: json['id'] as String? ?? '',
        playerOneId: json['playerOneId'] as String? ?? '',
        playerOneName: json['playerOneName'] as String? ?? 'TBD',
        playerTwoId: json['playerTwoId'] as String? ?? '',
        playerTwoName: json['playerTwoName'] as String? ?? 'TBD',
        playerOneScore: json['playerOneScore'] as int? ?? 0,
        playerTwoScore: json['playerTwoScore'] as int? ?? 0,
        status: json['status'] as String? ?? 'pending',
        winnerId: json['winnerId'] as String? ?? '',
        questionCategory: json['questionCategory'] as String? ?? '',
        questionsAnswered: json['questionsAnswered'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'playerOneId': playerOneId,
    'playerOneName': playerOneName,
    'playerTwoId': playerTwoId,
    'playerTwoName': playerTwoName,
    'playerOneScore': playerOneScore,
    'playerTwoScore': playerTwoScore,
    'status': status,
    'winnerId': winnerId,
    'questionCategory': questionCategory,
    'questionsAnswered': questionsAnswered,
  };
}

@immutable
class TournamentRound {
  final int roundNumber;
  final List<TournamentMatch> matches;
  final String status; // 'pending', 'active', 'completed'

  const TournamentRound({
    required this.roundNumber,
    required this.matches,
    this.status = 'pending',
  });

  TournamentRound copyWith({
    int? roundNumber,
    List<TournamentMatch>? matches,
    String? status,
  }) => TournamentRound(
    roundNumber: roundNumber ?? this.roundNumber,
    matches: matches ?? this.matches,
    status: status ?? this.status,
  );

  factory TournamentRound.fromJson(Map<String, dynamic> json) =>
      TournamentRound(
        roundNumber: json['roundNumber'] as int? ?? 0,
        matches:
            (json['matches'] as List?)
                ?.map(
                  (m) => TournamentMatch.fromJson(m as Map<String, dynamic>),
                )
                .toList() ??
            [],
        status: json['status'] as String? ?? 'pending',
      );

  Map<String, dynamic> toJson() => {
    'roundNumber': roundNumber,
    'matches': matches.map((m) => m.toJson()).toList(),
    'status': status,
  };
}

@immutable
class TournamentBracket {
  final String tournamentId;
  final String userId;
  final List<TournamentRound> rounds;
  final int currentRound;
  final String status; // 'active', 'won', 'eliminated'
  final int totalScore;
  final List<String> botWinners;
  final DateTime createdAt;
  final DateTime? completedAt;

  const TournamentBracket({
    required this.tournamentId,
    required this.userId,
    required this.rounds,
    this.currentRound = 0,
    this.status = 'active',
    this.totalScore = 0,
    this.botWinners = const [],
    required this.createdAt,
    this.completedAt,
  });

  TournamentBracket copyWith({
    String? tournamentId,
    String? userId,
    List<TournamentRound>? rounds,
    int? currentRound,
    String? status,
    int? totalScore,
    List<String>? botWinners,
    DateTime? createdAt,
    DateTime? completedAt,
  }) => TournamentBracket(
    tournamentId: tournamentId ?? this.tournamentId,
    userId: userId ?? this.userId,
    rounds: rounds ?? this.rounds,
    currentRound: currentRound ?? this.currentRound,
    status: status ?? this.status,
    totalScore: totalScore ?? this.totalScore,
    botWinners: botWinners ?? this.botWinners,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt ?? this.completedAt,
  );

  factory TournamentBracket.fromJson(Map<String, dynamic> json) =>
      TournamentBracket(
        tournamentId: json['tournamentId'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        rounds:
            (json['rounds'] as List?)
                ?.map(
                  (r) => TournamentRound.fromJson(r as Map<String, dynamic>),
                )
                .toList() ??
            [],
        currentRound: json['currentRound'] as int? ?? 0,
        status: json['status'] as String? ?? 'active',
        totalScore: json['totalScore'] as int? ?? 0,
        botWinners: (json['botWinners'] as List?)?.cast<String>() ?? [],
        createdAt: json['createdAt'] is String
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        completedAt: json['completedAt'] is String
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
    'tournamentId': tournamentId,
    'userId': userId,
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'currentRound': currentRound,
    'status': status,
    'totalScore': totalScore,
    'botWinners': botWinners,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };
}

@immutable
class TournamentStandings {
  final int rank;
  final String playerId;
  final String playerName;
  final int totalScore;
  final String status; // 'champion', 'finalist', 'eliminated'

  const TournamentStandings({
    required this.rank,
    required this.playerId,
    required this.playerName,
    this.totalScore = 0,
    required this.status,
  });

  TournamentStandings copyWith({
    int? rank,
    String? playerId,
    String? playerName,
    int? totalScore,
    String? status,
  }) => TournamentStandings(
    rank: rank ?? this.rank,
    playerId: playerId ?? this.playerId,
    playerName: playerName ?? this.playerName,
    totalScore: totalScore ?? this.totalScore,
    status: status ?? this.status,
  );

  factory TournamentStandings.fromJson(Map<String, dynamic> json) =>
      TournamentStandings(
        rank: json['rank'] as int? ?? 0,
        playerId: json['playerId'] as String? ?? '',
        playerName: json['playerName'] as String? ?? '',
        totalScore: json['totalScore'] as int? ?? 0,
        status: json['status'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'playerId': playerId,
    'playerName': playerName,
    'totalScore': totalScore,
    'status': status,
  };
}

/// Daily tournament setup (16 players, 4 rounds, 4 questions per match)
class TournamentConfig {
  static const int totalPlayers = 16;
  static const int roundCount = 4;
  static const int questionsPerMatch = 4;
  static const int coinRewardPerMatch = 50;
  static const int coinBonusChampion = 500;
  static const String tournamentCategory = 'Ziman';

  /// Generate bracket structure: 16→8→4→2→1 (4 rounds)
  static List<TournamentRound> generateBracket() {
    final rounds = <TournamentRound>[];
    int matchesInRound = totalPlayers ~/ 2;

    for (int i = 1; i <= roundCount; i++) {
      final matches = List<TournamentMatch>.generate(
        matchesInRound,
        (index) => TournamentMatch(
          id: 'r${i}_m${index + 1}',
          playerOneId: '',
          playerOneName: 'TBD',
          playerTwoId: '',
          playerTwoName: 'TBD',
          playerOneScore: 0,
          playerTwoScore: 0,
          status: 'pending',
          winnerId: '',
        ),
      );
      rounds.add(
        TournamentRound(
          roundNumber: i,
          matches: matches,
          status: i == 1 ? 'pending' : 'pending',
        ),
      );
      matchesInRound = matchesInRound ~/ 2;
    }
    return rounds;
  }
}
