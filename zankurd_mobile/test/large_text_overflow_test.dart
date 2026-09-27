import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/screens/avatar_editor_screen.dart';
import 'package:zankurd_mobile/src/screens/categories_tab.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/learn_home_screen.dart';
import 'package:zankurd_mobile/src/screens/learner_lexicon_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/password_recovery_screen.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/room_result_recovery_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/screens/suggest_question_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
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
      'zankurd.profileName.completed.user': true,
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

  // ── Kapsam boşluğu: kapı ve para ekranları ──────────────────────────
  //
  // Ratchet kurulduğunda "ana akış" ekranları alınmıştı. Dışarıda kalanlar
  // rastgele değil, hepsi aynı türden: kullanıcının uygulamaya GİRDİĞİ
  // (auth, isim kapısı), PARA harcadığı (paywall) ve başka bir insanla
  // BULUŞTUĞU (oda, eşleştirme) ekranlar. Bunlar en az ana ekran kadar
  // kritik ve daha dar: oda kodu, e-posta alanı ve fiyat satırı sabit
  // genişlikte yan yana duran öğeler taşır — %200 yazıda ilk kırılacak
  // yerler tam olarak buralarıdır (2026-08-03 kapsam denetimi).
  testWidgets('oda', (t) async {
    await expectNoOverflow(
      t,
      RoomScreen(repository: repository, initialRoom: repository.createRoom()),
    );
  });

  testWidgets('eşleştirme', (t) async {
    await expectNoOverflow(t, MatchmakingScreen(repository: repository));
  });

  testWidgets('premium', (t) async {
    await expectNoOverflow(t, PaywallScreen(repository: repository));
  });

  testWidgets('giriş', (t) async {
    await expectNoOverflow(t, const SignInScreen());
  });

  testWidgets('kayıt', (t) async {
    await expectNoOverflow(t, const SignUpScreen());
  });

  testWidgets('isim kapısı', (t) async {
    await expectNoOverflow(
      t,
      ProfileNameGateScreen(repository: repository, onCompleted: () {}),
    );
  });

  testWidgets('kategoriler', (t) async {
    await expectNoOverflow(
      t,
      Scaffold(body: CategoriesTab(repository: repository)),
    );
  });

  // JEV 2026-09-23 denetimi: ekran turunda bulunan ancak %200 yazı
  // ratchet'inde hiç açılmayan yüzeyler. Her birini hem büyük yazıda hem
  // de iPhone SE genişliğinde kuruyoruz; iki eksen ayrı tutuluyor ki bir
  // kırılma olduğunda sebebi doğrudan görülsün.
  Map<String, Widget Function()> extendedLargeTextScreens() => {
    'öğren ana sayfası': () => LearnHomeScreen(repository: repository),
    'seviye listesi': () =>
        LevelScreen(repository: repository, category: 'Ziman'),
    'alt kategori': () =>
        SubcategoryScreen(repository: repository, category: 'Ziman'),
    'soru öner': () => SuggestQuestionScreen(repository: repository),
    'parola kurtarma': () => const PasswordRecoveryScreen(),
    'öğrenci sözlüğü': () => const LearnerLexiconScreen(),
    'avatar düzenleyici': () => AvatarEditorScreen(repository: repository),
    'onboarding': () => OnboardingScreen(onComplete: () {}),
    'oda sonuç kurtarma': () {
      final room = repository.createRoom();
      return RoomResultRecoveryScreen(
        repository: repository,
        snapshot: RoomResultSnapshot(
          room: room,
          ownPlayerId: 'user',
          questionIds: const [],
          answers: const [],
          winnerId: null,
          endedReason: 'completed',
          forfeitedBy: null,
          finishedAt: DateTime.utc(2026, 9, 23),
        ),
        // Bu vaka sahiplik uyuşmazlığı hata yüzeyini deterministik açar;
        // ağ/ödül settlement'ı çalıştırmadan recovery ekranının gerçek
        // büyük-yazı düzenini ölçer.
        expectedUserId: 'different-user',
      );
    },
  };

  for (final entry in extendedLargeTextScreens().entries) {
    testWidgets('${entry.key} — %200 yazı', (t) async {
      await expectNoOverflow(t, entry.value());
    });

    testWidgets('dar ekran — ${entry.key}', (t) async {
      await expectNoOverflow(t, entry.value(), size: se, textScale: 1.0);
    });
  }

  testWidgets('dar ekran — oda', (t) async {
    await expectNoOverflow(
      t,
      RoomScreen(repository: repository, initialRoom: repository.createRoom()),
      size: se,
      textScale: 1.0,
    );
  });

  testWidgets('dar ekran — premium', (t) async {
    await expectNoOverflow(
      t,
      PaywallScreen(repository: repository),
      size: se,
      textScale: 1.0,
    );
  });

  testWidgets('dar ekran — giriş', (t) async {
    await expectNoOverflow(t, const SignInScreen(), size: se, textScale: 1.0);
  });

  testWidgets('şık — üç uzun rakip ismi %200 yazıda alt satıra iner', (
    t,
  ) async {
    // 2026-09: rakip rozetleri sabit `Row` idi; 2-3 uzun isim veya %200
    // ölçekte yatay taşma çizgileri çıkıyordu. `Wrap` aynı görünümü tek
    // satırda korur, sığmayınca alt satıra iner. Bu test dar çerçevede
    // (320px) üç uzun isimle taşma olmadığını sabitler.
    await expectNoOverflow(
      t,
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: QuizOptionTile(
              index: 0,
              answer: 'Bersiva rast a pirsê ev e',
              selected: false,
              correct: false,
              disabled: true,
              onTap: () {},
              opponentNamesWhoSelected: const [
                'Dilbixwînê Mezin',
                'Rojda Xanimê Dirêj',
                'Şivanê Çiyayî',
              ],
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('oyun merkezi — sırayla düello (%200 yazı)', (t) async {
    final repo = MockZanKurdRepository();
    await t.runAsync(() async {
      final a = await repo.startAsyncDuel();
      for (var i = 0; i < a.questions.length; i++) {
        await repo.answerAsyncDuel(
          duelId: a.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }
      repo.addPendingAsyncDuelForTesting(
        opponentName: 'Rojda',
        opponentCorrect: 3,
        opponentMs: 60000,
      );
      final b = await repo.startAsyncDuel();
      for (var i = 0; i < b.questions.length; i++) {
        await repo.answerAsyncDuel(
          duelId: b.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 4000,
        );
      }
    });
    await expectNoOverflow(
      t,
      PlayHubScreen(repository: repo, asyncDuelEnabled: true),
    );
  });

  testWidgets('sırayla düello — soru (%200 yazı)', (t) async {
    final repo = MockZanKurdRepository();
    await t.runAsync(() async {
      await repo.startAsyncDuel();
    });
    await expectNoOverflow(t, AsyncDuelPlayScreen(repository: repo));
  });

  testWidgets('sırayla düello — sonuç (%200 yazı)', (t) async {
    final repo = MockZanKurdRepository();
    late AsyncDuelSummary completedSummary;
    await t.runAsync(() async {
      repo.addPendingAsyncDuelForTesting(
        opponentName: 'Rojda',
        opponentCorrect: 0,
        opponentMs: 999999,
      );
      final a = await repo.startAsyncDuel();
      for (var i = 0; i < a.questions.length; i++) {
        await repo.answerAsyncDuel(
          duelId: a.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }
      final summaries = await repo.loadMyAsyncDuels();
      completedSummary = summaries.firstWhere((s) => s.outcome != null);
    });
    await expectNoOverflow(
      t,
      AsyncDuelResultScreen(
        repository: repo,
        view: AsyncDuelResultView.fromSummary(completedSummary),
      ),
    );
  });

  testWidgets('sırayla düello listesi (%200 yazı)', (t) async {
    final repo = MockZanKurdRepository();
    await t.runAsync(() async {
      final a = await repo.startAsyncDuel();
      for (var i = 0; i < a.questions.length; i++) {
        await repo.answerAsyncDuel(
          duelId: a.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }
    });
    await expectNoOverflow(t, AsyncDuelListScreen(repository: repo));
  });
}
