import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import 'support/widget_test_helpers.dart';

/// Sistem yazısı büyütüldüğünde ekranlar taşmamalı.
///
/// iOS ve Android'de kullanıcı yazı boyutunu iki katına kadar çıkarabilir;
/// erişilebilirlik ayarlarında bu sıra dışı değil, yaygın. Düzen varsayılan
/// ölçeğe göre kurulduğunda fazlalık sessizce kırpılır ya da satır taşar —
/// yayında hata görünmez, yalnız yarım kalmış bir arayüz kalır.
///
/// Test her ekranı %200 ölçekte açar ve `takeException` ile taşma olup
/// olmadığına bakar; Flutter taşmayı hata olarak bildirir. Ekranlar tek tek
/// açılır, çünkü `takeException` yalnız ilk hatayı verir — hepsini tek
/// testte toplamak ikinci taşmayı gizlerdi.
void main() {
  late MockZanKurdRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed': true,
      'zankurd.navTour.seen': true,
      'zankurd.quiz_tutorial.seen': true,
    });
    repository = freshMockRepository();
  });

  /// [screen]'i verilen ölçekte ve boyutta açıp taşma arar.
  ///
  /// Varsayılan 390x844 (iPhone 14) ve %200 yazı. Dar ekran geçişi aynı
  /// koşumu 320x568 ile (iPhone SE, hâlâ desteklenen en dar cihaz) ve
  /// normal yazıyla tekrarlar: iki kusur türü ayrı ayrı yakalanmalı,
  /// birleştirmek hangisinin taşırdığını belirsiz bırakır.
  Future<void> expectNoOverflow(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double textScale = 2.0,
  }) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = size * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testShell(
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: screen,
        ),
      ),
    );
    // `pumpAndSettle` kullanılmaz: yükleme göstergeleri sonsuz animasyondur.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(tester.takeException(), isNull);
  }

  testWidgets('ana ekran', (t) async {
    await expectNoOverflow(
      t,
      Scaffold(body: HomeScreen(repository: repository)),
    );
  });

  testWidgets('oyun merkezi', (t) async {
    await expectNoOverflow(t, PlayHubScreen(repository: repository));
  });

  testWidgets('profil', (t) async {
    await expectNoOverflow(
      t,
      Scaffold(body: ProfileScreen(repository: repository)),
    );
  });

  testWidgets('ayarlar', (t) async {
    await expectNoOverflow(t, SettingsScreen(repository: repository));
  });

  testWidgets('mağaza', (t) async {
    await expectNoOverflow(t, ShopScreen(repository: repository));
  });

  testWidgets('sıralama', (t) async {
    await expectNoOverflow(t, LeaderboardScreen(repository: repository));
  });

  testWidgets('arkadaşlar', (t) async {
    await expectNoOverflow(t, FriendsScreen(repository: repository));
  });

  testWidgets('yarışma', (t) async {
    await expectNoOverflow(t, ContestScreen(repository: repository));
  });

  testWidgets('turnuva', (t) async {
    await expectNoOverflow(t, TournamentScreen(repository: repository));
  });

  testWidgets('çark', (t) async {
    await expectNoOverflow(t, SpinWheelScreen(repository: repository));
  });

  testWidgets('soru ekranı', (t) async {
    await expectNoOverflow(
      t,
      QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: repository.questions.take(5).toList(),
        enableTimer: false,
      ),
    );
  });

  testWidgets('sonuç ekranı', (t) async {
    await expectNoOverflow(
      t,
      QuizResultScreen(
        repository: repository,
        room: repository.createRoom(),
        score: 720,
        correctCount: 8,
        wrongCount: 2,
        totalQuestions: 10,
        bestStreak: 5,
        coinsAwarded: 40,
        answerRecords: const [
          AnswerRecord(
            id: 'r1',
            category: 'Ziman',
            prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
            answers: ['su', 'ekmek'],
            correctAnswer: 'su',
            selectedAnswer: 'su',
            explanation: '«av» Türkçede «su» demektir.',
          ),
        ],
      ),
    );
  });

  // ── Dar ekran (iPhone SE, 320x568) ──
  //
  // Ölçek normal; ölçülen şey yazı boyutu değil, genişlik. Uygulama en dar
  // desteklenen cihazda da taşmamalı.
  const se = Size(320, 568);

  testWidgets('dar ekran — ana ekran', (t) async {
    await expectNoOverflow(
      t,
      Scaffold(body: HomeScreen(repository: repository)),
      size: se,
      textScale: 1.0,
    );
  });

  testWidgets('dar ekran — oyun merkezi', (t) async {
    await expectNoOverflow(
      t,
      PlayHubScreen(repository: repository),
      size: se,
      textScale: 1.0,
    );
  });

  testWidgets('dar ekran — profil', (t) async {
    await expectNoOverflow(
      t,
      Scaffold(body: ProfileScreen(repository: repository)),
      size: se,
      textScale: 1.0,
    );
  });

  testWidgets('dar ekran — mağaza', (t) async {
    await expectNoOverflow(
      t,
      ShopScreen(repository: repository),
      size: se,
      textScale: 1.0,
    );
  });

  testWidgets('dar ekran — sıralama', (t) async {
    await expectNoOverflow(
      t,
      LeaderboardScreen(repository: repository),
      size: se,
      textScale: 1.0,
    );
  });

  testWidgets('dar ekran — yarışma', (t) async {
    await expectNoOverflow(
      t,
      ContestScreen(repository: repository),
      size: se,
      textScale: 1.0,
    );
  });

  testWidgets('dar ekran — turnuva', (t) async {
    await expectNoOverflow(
      t,
      TournamentScreen(repository: repository),
      size: se,
      textScale: 1.0,
    );
  });

  testWidgets('dar ekran — soru ekranı', (t) async {
    await expectNoOverflow(
      t,
      QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: repository.questions.take(5).toList(),
        enableTimer: false,
      ),
      size: se,
      textScale: 1.0,
    );
  });
}
