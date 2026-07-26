import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/favorite_questions_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import 'support/widget_test_helpers.dart';

/// Ekranların veri dolu olmayan hâlleri: boş ve hatalı.
///
/// 2026-07-26: arkadaşlar ekranı, arkadaş listesi boş olduğunda düzen
/// hatasıyla çöküyordu — yani kusur yalnız **yeni kullanıcıda** vardı ve
/// tam da ilk kullanımda çıkıyordu. Nedeni basitti: sahte depo her yerde
/// dolu veri döndürüyor, dolayısıyla ne testler ne ekran turu boş listeyi
/// hiç denemiş.
///
/// Bu koşum o boşluğu kapatır: her ana ekran önce her listesi boş, sonra
/// her listesi hata veren bir depoyla açılır ve hiçbirinde istisna
/// atmamalıdır. İkisi ayrı yollardır — biri `AppEmptyState`e, diğeri
/// `AppErrorState`e gider — ve ikisi de sıradan durumlardır: yeni
/// kullanıcı ile uçak modu.
///
/// Ekranlar tek tek açılır: `takeException` yalnız ilk hatayı verir,
/// hepsini tek testte toplamak ikincisini gizlerdi.
class _EmptyRepository extends MockZanKurdRepository {
  @override
  Future<List<Friend>> loadFriends() async => const [];

  @override
  Future<List<Friend>> loadFriendsLeaderboard() async => const [];

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => const [];

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
    int limit = 20,
  }) async => const [];

  @override
  Future<List<ContestLeaderboardRow>> getContestLeaderboard({
    required String contestId,
    int limit = 10,
  }) async => const [];

  @override
  Future<List<UserContestBadge>> loadUserContestBadges() async => const [];

  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async => const [];

  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async => const [];

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => const [];
}

/// Her listesi hata veren depo.
///
/// Boş liste ile başarısız istek ayrı yollardır: biri `AppEmptyState`e,
/// diğeri `AppErrorState`e gider. Sunucusu olan bir üründe ikincisi de
/// sıradan bir durumdur — uçak modu, kapalı sunucu, süresi dolmuş oturum.
/// Ekranların o yolda da açılması gerekir.
class _FailingRepository extends MockZanKurdRepository {
  Never _fail() => throw StateError('injected: depo erişilemez');

  @override
  Future<List<Friend>> loadFriends() async => _fail();

  @override
  Future<List<Friend>> loadFriendsLeaderboard() async => _fail();

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => _fail();

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
    int limit = 20,
  }) async => _fail();

  @override
  Future<List<ContestLeaderboardRow>> getContestLeaderboard({
    required String contestId,
    int limit = 10,
  }) async => _fail();

  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async => _fail();

  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async => _fail();

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => _fail();
}

void main() {
  late _EmptyRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed': true,
      'zankurd.navTour.seen': true,
      'zankurd.quiz_tutorial.seen': true,
    });
    repository = _EmptyRepository();
  });

  Future<void> expectOpensCleanly(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testShell(child: screen));
    // `pumpAndSettle` kullanılmaz: yükleme göstergeleri sonsuz animasyondur.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(tester.takeException(), isNull);
  }

  testWidgets('ana ekran', (t) async {
    await expectOpensCleanly(
      t,
      Scaffold(body: HomeScreen(repository: repository)),
    );
  });

  testWidgets('oyun merkezi', (t) async {
    await expectOpensCleanly(t, PlayHubScreen(repository: repository));
  });

  testWidgets('profil', (t) async {
    await expectOpensCleanly(
      t,
      Scaffold(body: ProfileScreen(repository: repository)),
    );
  });

  testWidgets('sıralama', (t) async {
    await expectOpensCleanly(t, LeaderboardScreen(repository: repository));
  });

  testWidgets('arkadaşlar', (t) async {
    await expectOpensCleanly(t, FriendsScreen(repository: repository));
  });

  testWidgets('yarışma', (t) async {
    await expectOpensCleanly(t, ContestScreen(repository: repository));
  });

  testWidgets('turnuva', (t) async {
    await expectOpensCleanly(t, TournamentScreen(repository: repository));
  });

  testWidgets('öğrenme', (t) async {
    await expectOpensCleanly(t, LearningScreen(repository: repository));
  });

  testWidgets('favori sorular', (t) async {
    await expectOpensCleanly(t, FavoriteQuestionsScreen(repository: repository));
  });

  testWidgets('tekrar — kayıt yokken', (t) async {
    // Tur boş kayıtla açıldığında da çizilmeli: oyuncu hiç soru
    // cevaplamadan bu ekrana ulaşabilir.
    await expectOpensCleanly(
      t,
      ReviewScreen(records: const [], room: repository.createRoom()),
    );
  });

  // ── Depo hata verdiğinde ──

  Future<void> expectFailsGracefully(
    WidgetTester tester,
    Widget screen,
  ) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testShell(child: screen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    // Ekranın kendisi ayakta kalmalı: hata, kullanıcıya panel olarak
    // gösterilir; çerçeveye kadar sızarsa ekran kırmızı görünür.
    expect(tester.takeException(), isNull);
  }

  testWidgets('hata — sıralama', (t) async {
    await expectFailsGracefully(
      t,
      LeaderboardScreen(repository: _FailingRepository()),
    );
  });

  testWidgets('hata — arkadaşlar', (t) async {
    await expectFailsGracefully(
      t,
      FriendsScreen(repository: _FailingRepository()),
    );
  });

  testWidgets('hata — yarışma', (t) async {
    await expectFailsGracefully(
      t,
      ContestScreen(repository: _FailingRepository()),
    );
  });

  testWidgets('hata — turnuva', (t) async {
    await expectFailsGracefully(
      t,
      TournamentScreen(repository: _FailingRepository()),
    );
  });

  testWidgets('hata — öğrenme', (t) async {
    await expectFailsGracefully(
      t,
      LearningScreen(repository: _FailingRepository()),
    );
  });

  testWidgets('hata — favori sorular', (t) async {
    await expectFailsGracefully(
      t,
      FavoriteQuestionsScreen(repository: _FailingRepository()),
    );
  });
}
