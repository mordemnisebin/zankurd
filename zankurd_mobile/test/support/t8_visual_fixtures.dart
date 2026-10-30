// Bellek içi T8 örnekleri: ağ, oturum ya da canlı veri bağlantısı yok.
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/services/presence_controller.dart';

TournamentMatch t8TournamentMatch({
  bool completed = true,
  bool submitted = true,
}) => TournamentMatch(
  id: 'final',
  playerOneId: 'user',
  playerOneName: 'Rojhat',
  playerTwoId: 'rival',
  playerTwoName: 'QaAlı',
  playerOneScore: submitted ? 245 : 0,
  playerTwoScore: 510,
  playerOneSubmitted: submitted,
  playerTwoSubmitted: true,
  status: completed ? 'completed' : 'active',
  winnerId: completed ? 'rival' : '',
);

TournamentBracket t8TournamentBracket(
  TournamentMatch match, {
  bool finished = true,
}) => TournamentBracket(
  tournamentId: 'cup',
  userId: 'user',
  currentRound: 0,
  status: finished ? 'eliminated' : 'active',
  totalScore: match.playerOneScore,
  createdAt: DateTime.utc(2026, 10, 30),
  completedAt: finished ? DateTime.utc(2026, 10, 30, 12) : null,
  rounds: [
    TournamentRound(roundNumber: 1, matches: [match]),
  ],
);

class T8CupRepo extends MockZanKurdRepository {
  T8CupRepo(this.bracket);
  final TournamentBracket bracket;
  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => null;
  @override
  Future<TournamentBracket?> loadTournamentBracket() async => bracket;
  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => [];
}

class T8DuelRepo extends MockZanKurdRepository {
  T8DuelRepo(this.link);
  final bool link;
  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() async => [
    AsyncDuelSummary(
      duelId: 'open',
      status: AsyncDuelStatus.open,
      role: AsyncDuelRole.creator,
      myCorrect: 1,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 13)),
      seen: true,
      challengeCode: link ? 'ABC123' : null,
    ),
  ];
}

/// Gerçek ekranların yerel, bellek içi önizleme deposu.
class T8VisualRepo extends MockZanKurdRepository {
  static const topics = [
    'Ziman',
    'Teknolojî',
    'Siyaset',
    'Sînema',
    'Paradigma',
    'Muzîk',
    'Edebiyat',
    'Dîrok',
    'Çand',
    'Cografya',
  ];
  @override
  Future<List<String>> loadMatchmakingCategories() async => topics;
  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async => [
    for (var i = 0; i < 5; i++)
      Lesson(
        id: 'lesson-$i',
        slug: 'lesson-$i',
        titleTr: 'Ders ${i + 1}',
        titleKu: 'Ders ${i + 1}',
        category: category,
        order: i,
      ),
  ];
  @override
  Future<Set<String>> loadCompletedLessonIds() async => {
    'lesson-0',
    'lesson-1',
    'lesson-2',
  };
}

/// Önizlemede hesap düğmeleri hiçbir kimlik servisine bağlanmaz.
class T8VisualAuthProvider extends AuthProvider {
  T8VisualAuthProvider() : super.test(authenticated: true);

  @override
  bool get isGuest => true;

  @override
  Future<bool> linkGoogleAccount() async => false;

  @override
  Future<bool> linkAppleAccount() async => false;

  @override
  Future<bool> upgradeGuestAccount({
    required String email,
    required String password,
  }) async => false;
}

class T8PresenceGateway implements PresenceGateway {
  bool visible = false;

  @override
  Future<bool> loadVisibility() async => visible;

  @override
  Future<void> setVisibility(bool value) async {
    visible = value;
  }

  @override
  Future<void> touch() async {}
}
