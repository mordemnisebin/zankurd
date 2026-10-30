import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/quiz_top_bar.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// 2026-10-29 çevrimiçi (gerçek sunucu, iOS) gezintisinin istemci bulguları
/// X1–X7. Her bekçinin belgesi kusuru, niçin sessiz kalacağını ve kuralı söyler.
///
/// X8 (son şık / alt sönme) `quiz_son_sik_perde_test.dart` içindedir.

class _EmptyBoardRepo extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => const [];

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => null;
}

class _CoinRepo extends MockZanKurdRepository {
  final spends = <int>[];

  @override
  Future<int> loadCoinBalance() async => 500;

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    spends.add(amount);
    return true;
  }
}

class _GuestAuth extends AuthProvider {
  _GuestAuth() : super.test();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  bool get isGuest => true;
}

const _room = GameRoom(
  name: '1vs1',
  code: 'ZK-TEST000000',
  category: 'Ziman',
  questionCount: 1,
  status: RoomStatus.finished,
  players: [],
);

AnswerRecord _record(int i) => AnswerRecord(
  id: 'q$i',
  category: 'Ziman',
  prompt: 'p$i',
  answers: const ['A', 'B'],
  correctAnswer: 'A',
  selectedAnswer: 'A',
  explanation: '',
  responseMs: 4000,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    AchievementStore.resetInstance();
    BadgeService.resetInstance();
    DailyMissionStore.resetInstance();
    MasteryStore.resetInstance();
    MistakeStore.resetInstance();
    StreakStore.resetInstance();
    XPStore.resetInstance();
  });

  // ── X1 ───────────────────────────────────────────────────────────────────
  group('X1 — sıralamanın boş durumu neyi saydığını söyler', () {
    /// ## Kusur
    /// Günün turunu bitiren oyuncu Sıralama > Gün sekmesinde "Henüz puan yok"
    /// görüyordu; lig kartı da "Bu hafta yarış, lige gir" diyordu. Sıralama
    /// yalnız biten ÇEVRİMİÇİ odalardan (canlı düello + oda) beslenir
    /// (`get_leaderboard`: room_players x rooms); Günün turunun kendi sıralaması
    /// var. Metin bunu söylemiyordu.
    ///
    /// ## Niçin sessiz kalırdı
    /// Metin ile veri kaynağı ayrı yerlerde duruyordu; hiçbir test ikisini
    /// birlikte okumuyordu.
    ///
    /// ## Kural
    /// Metin, SQL'in gerçekten saydığı kaynaklarla (düello, oda) örtüşür;
    /// sayılmayanı (turnuva, Günün turu) sayılıyor gibi göstermez ve Günün
    /// turunun sıralamasına bağlantı verir.
    test('metin veri kaynağıyla örtüşür (SQL: yalnız room_players)', () {
      final sql = File(
        'supabase/2026-10-15_sosyal_ve_sertlestirme.sql',
      ).readAsStringSync();
      final start = sql.indexOf(
        'create or replace function public.get_leaderboard(',
      );
      final end = sql.indexOf('create or replace function', start + 10);
      final body = sql.substring(start, end);
      expect(body, contains('from public.room_players'));
      expect(body, contains('join public.rooms'));
      expect(body.toLowerCase(), isNot(contains('tournament')));
      expect(body.toLowerCase(), isNot(contains('async_duel')));
      expect(body.toLowerCase(), isNot(contains('contest')));

      final tr = Tr.forKu(K.startRaceHint, false);
      expect(tr, contains('düello'));
      expect(tr, contains('oda'));
      expect(tr, contains('Günün turu'));
      expect(tr.toLowerCase(), isNot(contains('turnuva')));
      final ku = Tr.forKu(K.startRaceHint, true);
      expect(ku, isNotEmpty);
    });

    testWidgets('boş Gün sekmesi nedenini söyler ve Günün turuna götürür', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: LeaderboardScreen(repository: _EmptyBoardRepo()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Henüz puan yok'), findsOneWidget);
      expect(
        find.text(
          'Canlı düello ve oda puanları burada sayılır. '
          'Günün turu kendi sıralamasında.',
        ),
        findsOneWidget,
      );
      final link = find.byKey(
        const ValueKey('leaderboard-empty-daily-ranking'),
      );
      expect(link, findsOneWidget);
      await tester.tap(link);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ContestScreen), findsOneWidget);
    });

    test('lig açıklaması da yalnız sayılan kaynakları anar', () {
      final tr = Tr.forKu(K.buHaftaYarisLige, false);
      expect(tr, contains('düello'));
      expect(tr, contains('oda'));
    });
  });

  // ── X2 ───────────────────────────────────────────────────────────────────
  test('X2 — turnuva bekleme kuralı sunucu kuralıyla örtüşür', () {
    // Sunucu: `start_due_tournaments` kupa açıldıktan fill_hours (24) sonra,
    // en az min_size (2) oyuncu varsa başlatır; yoksa açık kalır.
    final sql = File(
      'supabase/2026-07-26_real_player_tournament.sql',
    ).readAsStringSync();
    expect(sql, contains('min_size int not null default 2'));
    expect(sql, contains('fill_hours int not null default 24'));
    final tr = Tr.forKu(K.tournamentWaitingBody, false);
    expect(tr, contains('24 saat'));
    expect(tr, contains('en az 2 oyuncu'));
    expect(tr, contains('yoksa oyuncu beklenir'));
    // Ayrılma RPC'si yok: ekran uydurma bir "Ayrıl" eylemi sunmaz.
    final screen = File(
      'lib/src/screens/tournament_screen.dart',
    ).readAsStringSync();
    expect(screen.contains('leave_tournament'), isFalse);
  });

  // ── X3 ───────────────────────────────────────────────────────────────────
  group('X3 — profil rozeti misafire doğruyu söyler', () {
    /// ## Kusur
    /// Misafir (anonim) hesapta profil "İlerlemen kayıtlı" yazıyordu. Hesap
    /// cihazla birlikte kaybolabilir; söz gerçek hesabındır.
    ///
    /// ## Kural
    /// Misafir: "Bu cihazda kayıtlı"; gerçek hesap: "İlerlemen kayıtlı".
    setUp(() async {
      await SyncManager.resetForTesting();
    });

    Future<void> pumpProfile(WidgetTester tester, AuthProvider auth) async {
      await tester.pumpWidget(
        testShell(
          authProvider: auth,
          remoteAvailability: RemoteAvailability(reachable: true),
          child: Scaffold(
            body: ProfileScreen(repository: MockZanKurdRepository()),
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('misafir: "Bu cihazda kayıtlı", "İlerlemen kayıtlı" yok', (
      tester,
    ) async {
      await pumpProfile(tester, _GuestAuth());
      expect(find.text('Bu cihazda kayıtlı'), findsOneWidget);
      expect(find.text('İlerlemen kayıtlı'), findsNothing);
    });

    testWidgets('gerçek hesap: "İlerlemen kayıtlı"', (tester) async {
      await pumpProfile(tester, FakeAuthProvider());
      expect(find.text('İlerlemen kayıtlı'), findsOneWidget);
      expect(find.text('Bu cihazda kayıtlı'), findsNothing);
    });
  });

  // ── X4 ───────────────────────────────────────────────────────────────────
  group('X4 — bot rakip açıkça "Bot" etiketlidir', () {
    /// ## Kusur
    /// Bot yedek düellosunda rakip gerçek bir oyuncu gibi ("Sero") görünüyordu.
    ///
    /// ## Kural
    /// Rakip `Player.isBot` ise düello kartında ve sonuç ekranında adın yanında
    /// "Bot" rozeti çıkar; gerçek rakipte çıkmaz.
    testWidgets('düello kartında bot rozeti', (tester) async {
      final repository = MockZanKurdRepository();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LanguageProvider()..setLang('tr'),
            ),
            ChangeNotifierProvider(create: (_) => AuthProvider.test()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => SoundProvider()),
            ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuizScreen(
                roundId: 'test-round',
                repository: repository,
                room: repository.createRoom(),
                questions: [repository.playableQuestions.first],
                is1v1: true,
                enableTimer: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('duel-bot-chip')), findsOneWidget);
      expect(find.text('Bot'), findsWidgets);
    });

    testWidgets('sonuç ekranında bot rozeti; gerçek rakipte yok', (
      tester,
    ) async {
      Future<void> pump(Player opponent) async {
        await tester.pumpWidget(
          testShell(
            child: QuizResultScreen(
              repository: MockZanKurdRepository(),
              room: _room.copyWith(
                players: const [
                  Player(name: 'Ben', score: 0, state: Player.readyState),
                ],
              ),
              score: 100,
              correctCount: 4,
              wrongCount: 0,
              totalQuestions: 4,
              bestStreak: 1,
              answerRecords: [for (var i = 1; i <= 4; i++) _record(i)],
              coinsAwarded: 0,
              opponents: [opponent],
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(const Player(name: 'Sero', score: 40, state: Player.botState));
      expect(find.byKey(const ValueKey('result-bot-chip')), findsOneWidget);

      await pump(const Player(name: 'Rojda', score: 40, state: 'Hazır'));
      expect(find.byKey(const ValueKey('result-bot-chip')), findsNothing);
    });
  });

  // ── X5 ───────────────────────────────────────────────────────────────────
  group('X5 — "yarış tamamla" görevi ve günlük seri rozeti', () {
    /// ## Kusur
    /// Tek başına çözülen "Pratik" turunun sonunda "Görev tamamlandı! · 1 yarış
    /// tamamla" çıkıyordu; ayrıca "Günlük seri: 1 gün" aynı günün her turunda
    /// "Yeni rozet" altında yeniden listeleniyordu.
    ///
    /// ## Kural
    /// `completeQuiz` ("yarış tamamla") yalnız yarış turlarında (düello, oda,
    /// bot yarışı, Günün turu) ilerler. Seri satırı yalnız seriyi o gün İLK
    /// ilerleten turda görünür.
    test('mağaza: countsAsRace=false yarış görevini ilerletmez', () async {
      final store = await DailyMissionStore.loadForTest([
        DailyMission(type: MissionType.completeQuiz, target: 1, coinReward: 25),
      ]);
      var done = await store.reportQuizCompleted(
        correctAnswers: 3,
        category: 'Ziman',
        streakAlive: true,
        countsAsRace: false,
      );
      expect(done, isEmpty);
      done = await store.reportQuizCompleted(
        correctAnswers: 3,
        category: 'Ziman',
        streakAlive: true,
      );
      expect(done, hasLength(1));
    });

    Future<void> playRound(
      WidgetTester tester, {
      List<Player> opponents = const [],
      bool dailyQuiz = false,
      Key? key,
    }) async {
      // Uzun ekran: ayrıntılar bölümü alt perdenin arkasında kalmasın.
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: QuizResultScreen(
            key: key,
            repository: MockZanKurdRepository(),
            room: _room,
            score: 100,
            correctCount: 4,
            wrongCount: 0,
            totalQuestions: 4,
            bestStreak: 1,
            answerRecords: [for (var i = 1; i <= 4; i++) _record(i)],
            coinsAwarded: 0,
            opponents: opponents,
            dailyQuiz: dailyQuiz,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    DailyMission raceMission() =>
        DailyMission(type: MissionType.completeQuiz, target: 1, coinReward: 25);

    testWidgets('solo "Pratik" turu görevi tamamlamaz', (tester) async {
      final store = await DailyMissionStore.loadForTest([raceMission()]);
      await playRound(tester);
      expect(store.missions.single.completed, isFalse);
      expect(find.textContaining('1 yarış tamamla'), findsNothing);
    });

    testWidgets('bot yarışı görevi tamamlar', (tester) async {
      final store = await DailyMissionStore.loadForTest([raceMission()]);
      await playRound(
        tester,
        opponents: const [
          Player(name: 'Sero', score: 10, state: Player.botState),
        ],
      );
      expect(store.missions.single.completed, isTrue);
    });

    testWidgets('Günün turu görevi tamamlar', (tester) async {
      final store = await DailyMissionStore.loadForTest([raceMission()]);
      await playRound(tester, dailyQuiz: true);
      expect(store.missions.single.completed, isTrue);
    });

    testWidgets('"Günlük seri" aynı günün ikinci turunda tekrar çıkmaz', (
      tester,
    ) async {
      Future<void> openDetails() async {
        final details = find.byKey(
          const ValueKey('result-collapsible-header'),
          skipOffstage: false,
        );
        if (details.evaluate().isEmpty) return;
        await tester.ensureVisible(details);
        await tester.tap(details);
        await tester.pumpAndSettle();
      }

      await playRound(tester, key: const ValueKey('r1'));
      await openDetails();
      expect(find.textContaining('Günlük seri: 1 gün'), findsWidgets);

      StreakStore.resetInstance();
      await playRound(tester, key: const ValueKey('r2'));
      await openDetails();
      expect(find.textContaining('Günlük seri'), findsNothing);
    });
  });

  // ── X6 ───────────────────────────────────────────────────────────────────
  group('X6 — iki şıklı soruda Şık İpucu pasif ve sebebi söylenir', () {
    /// ## Kusur
    /// Doğru/yanlış sorusunda Şık İpucu %50/%50 gösteriyor ve günlük ücretsiz
    /// hakkı boşa harcatıyordu.
    ///
    /// ## Niçin sessiz kalırdı
    /// Eleme jokerleri iki şıkta gizlenmişti ama Şık İpucu "iki şıkta da
    /// dürüst dağılım gösterir" diye serbest bırakılmıştı; dağılımın bilgisiz
    /// olduğunu ve hakkın yandığını hiçbir test düşünmedi.
    ///
    /// ## Kural
    /// En az üç şık yoksa ipucu pasif çizilir; ekran okuyucu sebebi okur,
    /// dokunmak jetonu/hakkı harcamaz ve sebebi söyler.
    const tf = QuizQuestion(
      id: 'tf-1',
      category: 'Ziman',
      prompt: 'Dil, dil demektir.',
      answers: ['Doğru', 'Yanlış'],
      correctAnswer: 'Doğru',
      explanation: '',
      type: QuestionType.trueFalse,
    );
    const four = QuizQuestion(
      id: 'four-1',
      category: 'Ziman',
      prompt: 'Pirtûk çi ye?',
      answers: ['Kitêb', 'Mase', 'Av', 'Mal'],
      correctAnswer: 'Kitêb',
      explanation: '',
    );

    Future<_CoinRepo> pump(WidgetTester tester, QuizQuestion q) async {
      final repository = _CoinRepo();
      freshMockRepository();
      SharedPreferences.setMockInitialValues({
        'zankurd.onboarding.seen': true,
        'zankurd.quiz_tutorial.seen': true,
        'zankurd.wildcard_hint.audience': true,
      });
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            roundId: 'test-round',
            repository: repository,
            room: repository.createRoom(),
            questions: [q, q],
            experience: QuizExperience.competition,
            enableTimer: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      return repository;
    }

    Finder audience() => find.byWidgetPredicate(
      (w) => w is WildcardButton && w.type == WildcardType.audience,
    );

    testWidgets('iki şık: pasif, sebep semantics\'te, dokunmak harcamaz', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repository = await pump(tester, tf);
      final reason = Tr.forKu(K.wildcardUnavailableTwoOptions, false);

      expect(tester.widget<WildcardButton>(audience()).unavailable, isTrue);
      expect(find.bySemanticsLabel(RegExp(reason)), findsOneWidget);

      await tester.ensureVisible(audience());
      await tester.tap(audience());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(repository.spends, isEmpty, reason: 'jeton/hak harcanmamalı');
      expect(find.text(reason), findsWidgets, reason: 'sebep söylenir');
      handle.dispose();
    });

    testWidgets('dört şık: ipucu kullanılabilir', (tester) async {
      await pump(tester, four);
      expect(tester.widget<WildcardButton>(audience()).unavailable, isFalse);
    });
  });

  // ── X7 ───────────────────────────────────────────────────────────────────
  group('X7 — üst çubuk künyesi skor büyüyünce kısalmaz', () {
    setUpAll(loadAppFonts);

    /// ## Kusur
    /// Skor 1.095'e çıkınca sağ grup genişliyor, orta yuvada konu işareti +
    /// "Soru 8/10 · Dil" sığmıyor ve konu adı "…" oluyordu.
    ///
    /// ## Kural
    /// İlk kural "skor 1.000'de konu işareti düşer" idi; tur 3'te (2026-10-30)
    /// işaretin soru ORTASINDA düşmesi orta yuvayı genişletip soruyu kaydırdı.
    /// Artık sağ grubun skor yuvası baştan en geniş hâliyle ayrılır; işaret
    /// skordan bağımsız yerinde kalır ve künye yine kesilmez.
    Future<void> pumpCenter(WidgetTester tester, int score) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: const SahneStageScaffold(
            body: SizedBox.shrink(),
            center: QuizStageCenter(category: 'Ziman', index: 7, total: 10),
            score: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SahneStatChip(
                    leading: SahneGlyph(SahneGlyphKind.star),
                    label: '1.095',
                  ),
                  SizedBox(width: 12),
                  Text('19'),
                  SizedBox(width: 12),
                  SizedBox(width: 48, height: 48),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('skor 1095: işaret yerinde, "Soru 8/10 · Dil" kısalmaz', (
      tester,
    ) async {
      await pumpCenter(tester, 1095);
      expect(
        find.byKey(const ValueKey('quiz-question-icon-badge')),
        findsOneWidget,
      );
      final finder = find.byKey(const ValueKey('quiz-stage-kicker'));
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(paragraph.didExceedMaxLines, isFalse, reason: 'künye kesilmemeli');
      expect(tester.widget<Text>(finder).data, 'Soru 8/10 · Dil');
    });

    testWidgets('skor 100: konu işareti yerinde', (tester) async {
      await pumpCenter(tester, 100);
      expect(
        find.byKey(const ValueKey('quiz-question-icon-badge')),
        findsOneWidget,
      );
    });
  });
}
