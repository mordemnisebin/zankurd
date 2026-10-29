/// 2026-10-29 son kurul — son tasarım jürisinin (GPT-6 Astra, GPT-6.1 Sol,
/// GPT-6.1 Terra) en az iki modelin uyuştuğu bulguları.
///
/// ## Kusurlar ve niçin sessiz kalırlardı
///
/// 1. **Sonuç "Üst üste" > "Doğru":** ekran turu fikstürü `bestStreak`i sabit
///    2 veriyordu; 1 doğrulu turda "1 Doğru · 2 Üst üste" basıldı. Oyunun
///    kendisi zinciri doğru sayar (`quiz_screen`: doğruda +1, yanlışta 0),
///    ama sonuç ekranı gelen değere körü körüne güveniyordu. Artık ekran
///    zinciri doğru sayısıyla sınırlar; fikstür zinciri kayıtlardan hesaplar.
///    Hiçbir test iki sayının TUTARLILIĞINA bakmıyordu.
/// 2. **İki inceleme eylemi:** alt perdede "Cevapları gör (n)", gövdede
///    "Yanlışları incele" aynı işi sunuyordu; rozetteki "2" neyin sayısı
///    olduğunu söylemiyordu. Testler her düğmenin VARLIĞINI ölçüyordu.
/// 3. **Turnuva "Dolunca":** neyin dolacağı (4 oyuncu) yazmıyordu; bekleme
///    ekranında 24 saatin bittiği an yoktu. Lobide sunucu doluluk vermez
///    (`get_tournament_bracket` yalnız kayıtlı oyuncuya döner) — uydurulmaz.
/// 4. **Oda "3+ kişi":** oda 2 kişiyle başlar (`canStart`, `start_room_game`),
///    kapasite 2–50. Metin bir eski kararın kalıntısıydı.
/// 5. **Bot açıklaması:** bot olasılığı yalnız arama BAŞLAYINCA küçük notta
///    söyleniyordu; VS sahnesinde bot rakip insan gibi görünüyordu.
/// 6. **Kelimelerim sayıları:** "Tekrar · bugün 5", "3 kelime · 2 soru" ve
///    "4 kelime" kapsamı söylemiyordu.
/// 7. **Mağaza:** Joker paketi ve Ekstra çevirmenin işlev satırı yoktu.
/// 8. **Çark:** dinlenirken işaretçi iki dilimin SINIRINI gösteriyordu
///    (dönme açısı 0; −90° bir dilim sınırı). Ödül eşlemesi bir yardımcıya
///    çıkarıldı ve burada her dilim için sınanır.
///
/// ## Tur 2 (2026-10-29 son kurul tur 2: Astra, 6.1 Sol, 6.1 Terra)
///
/// A. **Bot sözü çelişkisi:** seçim ekranı "botla oynamayı seçebilirsin",
///    arama notu "botla eşleşirsin" diyordu. Gerçek akış: ~20 sn sonra diyalog,
///    bot yalnız seçilirse. Not artık seçim ekranıyla aynı sözü söyler ve
///    başlıktaki "Rakip aranıyor"u tekrarlamaz. Sessizdi: iki metnin ayrı
///    varlık testi vardı, birbirini yalanlayıp yalanlamadığına bakan yoktu.
/// B. **Cevapta sıçrayan soru:** dengeli yerleşim (`sahneQuestionBalance`, artık `quizQuestionBalance`)
///    cevaptan sonra yeniden hesaplanıyordu; alt perde geri bildirim şeridine
///    dönüp uzayınca ve açıklama eklenince soru kartı ve şıklar yukarı
///    kayıyordu. Testler yalnız cevap ÖNCESİ ya da SONRASI konumu ölçüyordu,
///    ikisinin farkını ölçen yoktu.
/// C. **Sönük şık yazısı:** seçilmeyen şıklar üçüncül griydi; ölçü 4,5'i
///    geçse de koyu sahnede sönük okunuyordu. Yazı ikincil mürekkebe çıktı,
///    sönüklüğü yüzey taşır; iki temada ≥ 4,5:1 ölçülür.
/// D. **Puan dökümü:** fikstür %67 ve %33'te aynı 240'ı basıyordu (1 doğru en
///    çok 200/250 eder); 1v1 fikstüründe 4 doğruya 320 (en az 400) vardı.
///    Sonuç ekranı puanın nasıl oluştuğunu söylemiyordu; döküm yalnız sayılar
///    gerçek formüle uyuyorsa yazılır.
/// E. **Ders yolu:** kilitli dersler nasıl açılacağını söylemiyordu; güncel
///    ders "Sıradaki ders" + "1. ders" rozetleri, düğüm ve kartla dört kez
///    söyleniyordu.
/// F. **Karşılama boşluğu:** grup tam ortada, ilerleme çubuğunun altında
///    büyük boşluk dil seçimini aşağı itiyordu.
/// G. **Koyu temada küçük etiketler:** ölçüldü (İlerlemen kayıtlı 8,1:1, ünite
///    etiketi 8,2:1); hiçbiri 4,5'in altında değil, çiftler burada sabitlenir.
///    Ölçerken gerçek bir kusur çıktı: GÜNDÜZ temasında sonuç "Ayrıntılar"ındaki
///    "Konulara göre" başlığı ekranın bağlamından gündüz mürekkebini alıyor,
///    gece sahnesinde 1,04:1 kalıyordu. Sessizdi: testlerin varsayılan teması
///    sahneyle aynı belirteçleri verdiği için renk hep doğru görünüyordu.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

class _NoOpponentRepository extends MockZanKurdRepository {
  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async =>
      const {'status': 'waiting'};

  @override
  Stream<Map<String, dynamic>?> subscribeMatchmakingQueue() =>
      const Stream.empty();

  @override
  Future<Map<String, dynamic>> cancelMatchmaking() async => const {
    'status': 'cancelled',
  };
}

class _WaitingCupRepository extends MockZanKurdRepository {
  _WaitingCupRepository(this.bracket);
  final TournamentBracket bracket;

  @override
  String? get currentUserId => 'me';

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => bracket;
}

class _ShopRepo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 300;
}

Widget _matchShell(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang('tr'),
    ),
    ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

List<AnswerRecord> _records({required int wrong, int total = 3}) => [
  for (var i = 0; i < total; i++)
    AnswerRecord(
      id: 'r$i',
      category: 'Ziman',
      prompt: 'Pirs $i',
      answers: const ['A', 'B'],
      correctAnswer: 'A',
      selectedAnswer: i >= total - wrong ? 'B' : 'A',
      explanation: 'Şirove',
      explanationTr: 'Açıklama $i',
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  Future<void> pumpResult(
    WidgetTester tester, {
    required int wrong,
    required int bestStreak,
    ThemeMode? themeMode,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final repository = freshMockRepository();
    final records = _records(wrong: wrong);
    await tester.pumpWidget(
      testShell(
        themeProvider: themeMode == null
            ? null
            : ThemeProvider(initialMode: themeMode),
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 240,
          correctCount: records.length - wrong,
          wrongCount: wrong,
          totalQuestions: records.length,
          bestStreak: bestStreak,
          coinsAwarded: 0,
          answerRecords: records,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  group('1–2 sonuç ekranı', () {
    testWidgets('"Üst üste" doğru sayısını aşamaz', (tester) async {
      await pumpResult(tester, wrong: 2, bestStreak: 2);
      final tiles = tester.widget<ResultStatTiles>(
        find.byType(ResultStatTiles),
      );
      expect(tiles.correct, 1);
      expect(tiles.streak, lessThanOrEqualTo(tiles.correct));
    });

    testWidgets('tek inceleme eylemi; rozet birimli; liste alt perdenin '
        'üstünde biter', (tester) async {
      await pumpResult(tester, wrong: 2, bestStreak: 1);
      expect(
        find.byKey(
          const ValueKey('result-review-mistakes-button'),
          skipOffstage: false,
        ),
        findsNothing,
        reason: 'alt perdedeki "Cevapları gör" varken ikinci inceleme yolu',
      );
      final see = find.byKey(const ValueKey('result-see-answers-button'));
      expect(see, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('result-see-answers-badge')),
          matching: find.text('2 yanlış'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Cevapları gör (2 yanlış)'), findsOneWidget);

      // Kaydırılan gövde sabit alt perdenin ÜSTÜNDE biter: son bölüm
      // perdenin altında kalamaz.
      final list = find.byType(ListView).first;
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(list).bottom,
        lessThanOrEqualTo(tester.getRect(see).top + 0.5),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('3 turnuva', () {
    testWidgets('lobide kapasite görünür', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(child: TournamentScreen(repository: freshMockRepository())),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('tournament-capacity')),
          matching: find.text('${TournamentConfig.totalPlayers} oyuncu'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('beklerken doluluk ve 24 saatin sonu yazılır', (tester) async {
      SharedPreferences.setMockInitialValues({'zankurd.navTour.seen': true});
      final openedAt = DateTime(2026, 10, 29, 9, 5);
      final repository = _WaitingCupRepository(
        TournamentBracket(
          tournamentId: 't1',
          userId: 'me',
          currentRound: 0,
          status: 'active',
          rounds: const [TournamentRound(roundNumber: 1, matches: [])],
          createdAt: openedAt,
          entryCount: 2,
          size: 4,
        ),
      );
      await tester.pumpWidget(
        testShell(child: TournamentScreen(repository: repository)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('2/4 oyuncu katıldı'), findsOneWidget);
      final due = formatMatchDeadline(
        openedAt.add(const Duration(hours: cupFillHours)),
      );
      expect(find.textContaining('24 saatin sonu: $due'), findsOneWidget);
    });
  });

  test('4 oda alt satırı gerçek en az/en çok oyuncu sayısını söyler', () {
    final tr = Tr.of(K.roomTileSub, AppLanguage.tr);
    final ku = Tr.of(K.roomTileSub, AppLanguage.ku);
    for (final s in [tr, ku]) {
      expect(s, isNot(contains('3+')));
      expect(s, contains('{min}'));
      expect(s, contains('{max}'));
    }
    expect(GameRoom.allowedMaxPlayers.first, 2);
  });

  group('5 eşleşme', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      XPStore.resetInstance();
    });

    testWidgets('bot olasılığı aramadan önce, düğmenin üstünde', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _matchShell(MatchmakingScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();
      final note = find.byKey(const ValueKey('matchmaking-bot-disclosure'));
      expect(note, findsOneWidget);
      expect(
        tester.getRect(note).bottom,
        lessThanOrEqualTo(
          tester
              .getRect(find.byKey(const ValueKey('matchmaking-random-cta')))
              .top,
        ),
      );
    });

    testWidgets('bot rakip VS sahnesinde "Bot" diye yazılır', (tester) async {
      tester.view.physicalSize = const Size(480, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _matchShell(
          MatchmakingScreen(
            repository: _NoOpponentRepository(),
            asyncDuelEnabled: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('matchmaking-random-cta')));
      await tester.pump(const Duration(seconds: 20));
      await tester.tap(find.byKey(const ValueKey('mm-offer-bot')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.textContaining(RegExp(r'^Bot · Seviye \d+$')),
        findsOneWidget,
      );
      // Yönlendirme zamanlayıcısı bitsin.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('7 mağaza: güçlendiricilerin işlev satırı var', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(child: ShopScreen(repository: _ShopRepo())),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('shop-stock-note-joker_pack_3')),
      findsOneWidget,
    );
    expect(find.text('Günün çarkında bir tur daha'), findsOneWidget);
  });

  group('8 çark', () {
    final n = SpinWheelScreen.rewards.length;
    final segment = 2 * math.pi / n;

    test('dinlenirken işaretçi bir dilimin ortasını gösterir', () {
      final local =
          (SpinWheelScreen.pointerAngle - SpinWheelScreen.restAngle) %
          (2 * math.pi);
      final offsetInSegment = local % segment;
      expect((offsetInSegment - segment / 2).abs(), lessThan(1e-9));
    });

    test('her kazanan dilim işaretçinin altında ve ortasında durur; ek '
        'çevirme son yerinden en az beş tur döner', () {
      for (var i = 0; i < n; i++) {
        for (final from in [
          0.0,
          SpinWheelScreen.restAngle % (2 * math.pi),
          4.2,
        ]) {
          final target = SpinWheelScreen.spinTarget(i, from: from);
          expect(SpinWheelScreen.segmentUnderPointer(target), i);
          expect(target - from, greaterThanOrEqualTo(5 * 2 * math.pi - 1e-9));
          final local = (SpinWheelScreen.pointerAngle - target) % (2 * math.pi);
          expect(((local % segment) - segment / 2).abs(), lessThan(1e-6));
        }
      }
    });
  });

  group('2026-10-29 son kurul tur 2', () {
    double contrast(Color a, Color b) {
      final l1 = a.computeLuminance();
      final l2 = b.computeLuminance();
      return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
        'zankurd.navTour.seen': true,
      });
      XPStore.resetInstance();
    });

    testWidgets('A: arama notu bot SEÇİMİNİ söyler, başlığı tekrarlamaz', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _matchShell(MatchmakingScreen(repository: _NoOpponentRepository())),
      );
      await tester.pumpAndSettle();
      final disclosure = Tr.of(K.botDisclosure, AppLanguage.tr);
      await tester.tap(find.byKey(const ValueKey('matchmaking-random-cta')));
      await tester.pump(const Duration(seconds: 2));
      final note = Tr.of(K.searchingNote, AppLanguage.tr);
      expect(find.text(note), findsOneWidget);
      expect(note, startsWith(disclosure), reason: 'iki ekran aynı söz');
      expect(note, isNot(contains('eşleşirsin')));
      expect(
        find.textContaining('Rakip aranıyor'),
        findsOneWidget,
        reason: 'durum başlıkta bir kez',
      );
      for (final lang in AppLanguage.values) {
        expect(
          Tr.of(K.searchingNote, lang),
          startsWith(Tr.of(K.botDisclosure, lang)),
          reason: lang.name,
        );
      }
      // Gerçek akış: süre dolunca bot bir SEÇENEK olarak sunulur.
      await tester.pump(const Duration(seconds: 20));
      expect(find.text(Tr.of(K.searchTimedOut, AppLanguage.tr)), findsOne);
      final cancel = find.byKey(const ValueKey('mm-offer-cancel'));
      await tester.tap(
        cancel.evaluate().isNotEmpty
            ? cancel
            : find.text(Tr.of(K.no, AppLanguage.tr)),
      );
      await tester.pumpAndSettle();
    });

    Future<List<String>> pumpLesson(
      WidgetTester tester, {
      QuizExperience experience = QuizExperience.learning,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final repository = MockZanKurdRepository();
      final questions = repository.questions.take(5).toList();
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: questions,
            experience: experience,
            enableTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final q = questions.first;
      return [
        q.correctAnswer,
        q.answers.firstWhere((a) => a != q.correctAnswer),
      ];
    }

    Future<void> settleAnswer(WidgetTester tester) async {
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pumpAndSettle();
    }

    for (final (name, experience, pickWrong) in [
      ('ders · doğru', QuizExperience.learning, false),
      ('ders · yanlış (açıklama kartı)', QuizExperience.learning, true),
      ('yarış · doğru', QuizExperience.competition, false),
    ]) {
      testWidgets('B: soru kartı ve şıklar cevaptan sonra yerinde ($name)', (
        tester,
      ) async {
        final picks = await pumpLesson(tester, experience: experience);
        final scroll = find.byKey(const ValueKey('quiz-portrait-scroll'));
        final content = find.byKey(const ValueKey('quiz-answer-content'));
        final optionA = find.text(picks.last).first;
        final contentTop = tester.getTopLeft(content).dy;
        final optionTop = tester.getTopLeft(optionA).dy;
        final firstOption = find.text(picks.first).first;
        final firstTop = tester.getTopLeft(firstOption).dy;

        await tester.tap(find.text(pickWrong ? picks.last : picks.first));
        await settleAnswer(tester);

        expect(scroll, findsOneWidget);
        expect(tester.getTopLeft(content).dy, closeTo(contentTop, 0.5));
        expect(tester.getTopLeft(optionA).dy, closeTo(optionTop, 0.5));
        expect(tester.getTopLeft(firstOption).dy, closeTo(firstTop, 0.5));
        if (pickWrong) {
          // Açıklama okunur kalır: şıkların ALTINDA, kayan alanda.
          final card = find.byKey(const ValueKey('quiz-wrong-answer-insight'));
          expect(card, findsOneWidget);
          expect(
            tester.getTopLeft(card).dy,
            greaterThan(tester.getBottomLeft(firstOption).dy),
          );
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('C: cevaptan sonra seçilmeyen şıkların yazısı ≥ 4,5:1, '
        'sönüklük yüzeyde', (tester) async {
      final picks = await pumpLesson(tester);
      final repository = MockZanKurdRepository();
      final q = repository.questions.first;
      await tester.tap(find.text(picks.first));
      await settleAnswer(tester);
      final others = q.answers
          .where((a) => a != q.correctAnswer)
          .toList(growable: false);
      expect(others, isNotEmpty);
      for (final other in others) {
        final text = tester.widget<Text>(find.text(other).first);
        final t = SahneTokens.of(tester.element(find.text(other).first));
        final color = text.style!.color!;
        expect(color, isNot(t.tx3), reason: 'üçüncül gri sönük okunuyordu');
        expect(
          contrast(color, t.optionDimFill),
          greaterThanOrEqualTo(4.5),
          reason: other,
        );
      }
      // Token düzeyinde iki tema.
      for (final t in const [SahneTokens.night, SahneTokens.day]) {
        expect(contrast(t.tx2, t.optionDimFill), greaterThanOrEqualTo(4.5));
        expect(contrast(t.tx2, t.optionLetterFill), greaterThanOrEqualTo(4.5));
      }
    });

    test(
      'D: puan dökümü gerçek formüle uyuyorsa yazılır, uymuyorsa uydurulmaz',
      () {
        expect(resultScoreBreakdown(score: 240, correctCount: 2), (
          base: 200,
          bonus: 40,
        ));
        expect(resultScoreBreakdown(score: 560, correctCount: 4), (
          base: 400,
          bonus: 160,
        ));
        // Yerelde 1 doğru en çok 200 eder (100 + 100 hız); çevrimiçi odada
        // sunucu seri bonusu da ekler (en çok 250).
        expect(resultScoreBreakdown(score: 240, correctCount: 1), isNull);
        expect(
          resultScoreBreakdown(score: 240, correctCount: 1, online: true),
          (base: 100, bonus: 140),
        );
        expect(
          resultScoreBreakdown(score: 251, correctCount: 1, online: true),
          isNull,
        );
        // 4 doğru en az 400 eder (eski 1v1 fikstürü: 320).
        expect(resultScoreBreakdown(score: 320, correctCount: 4), isNull);
        expect(resultScoreBreakdown(score: 0, correctCount: 0), isNull);
      },
    );

    testWidgets('D: "Ayrıntılar" puanın kaynağını tek satırda söyler', (
      tester,
    ) async {
      // Gündüz teması: sonuç sahnesi her temada gecedir (bkz. G).
      await pumpResult(
        tester,
        wrong: 1,
        bestStreak: 2,
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.byKey(const ValueKey('result-see-answers-button')));
      await tester.pumpAndSettle();
      final line = find.byKey(const ValueKey('result-score-breakdown'));
      expect(line, findsOneWidget);
      expect(
        tester.widget<Text>(line).data,
        '2 doğru × 100 + 40 hız ve seri bonusu = 240 puan',
      );
      // G (aynı bölüm): gündüz temasında bölümdeki düz yazılar ekranın
      // bağlamından GÜNDÜZ mürekkebini alıyordu ("Konulara göre" #0E1433
      // gece sahnesinde). Renk sahnenin kendi belirteçleriyle ≥ 4,5:1.
      for (final key in const [
        'result-score-breakdown',
        'result-learned-title',
      ]) {
        final finder = find.byKey(ValueKey(key));
        expect(finder, findsOneWidget, reason: key);
        final t = SahneTokens.of(tester.element(finder));
        final color = tester.widget<Text>(finder).style!.color!;
        expect(contrast(color, t.bg), greaterThanOrEqualTo(4.5), reason: key);
        expect(contrast(color, t.s1), greaterThanOrEqualTo(4.5), reason: key);
      }
    });

    testWidgets('D: sayılar formüle uymazsa döküm yok', (tester) async {
      // pumpResult puanı 240 verir; 1 doğruyla bu imkânsız.
      await pumpResult(tester, wrong: 2, bestStreak: 1);
      await tester.tap(find.byKey(const ValueKey('result-see-answers-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('result-score-breakdown'),
          skipOffstage: false,
        ),
        findsNothing,
      );
    });

    testWidgets('E: güncel ders bir kez söylenir; ilk kilitli ders açılma '
        'koşulunu yazar', (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(child: LearningScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('lesson-recommended-badge')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('learning-progress-capsule')),
        findsNothing,
      );
      expect(find.text('Sıradaki ders'), findsNothing);
      final hint = find.byKey(const ValueKey('learning-unlock-hint'));
      expect(hint, findsOneWidget, reason: 'yalnız ilk kilitli düğümde');
      expect(
        tester.widget<Text>(hint).data,
        Tr.of(K.lessonUnlockHint, AppLanguage.tr),
      );
      expect(
        tester.getTopLeft(hint).dy,
        greaterThan(
          tester
              .getBottomLeft(find.byKey(const ValueKey('learning-next-step')))
              .dy,
        ),
      );
      final t = SahneTokens.of(tester.element(hint));
      expect(
        contrast(tester.widget<Text>(hint).style!.color!, t.bg),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'F: karşılamada grup üst-orta durur (üst boşluk < alt boşluk)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => LanguageProvider()..setLang('tr'),
            child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
          ),
        );
        await tester.pumpAndSettle();
        final area = tester.getRect(
          find.byKey(const ValueKey('onboarding-text-scrollbar')),
        );
        final scene = tester.getRect(
          find.byKey(const ValueKey('onboarding-scene')),
        );
        final tr = tester.getRect(
          find.byKey(const ValueKey('onboarding-language-tr')),
        );
        final above = scene.top - area.top;
        final below = area.bottom - tr.bottom;
        expect(above, lessThan(below), reason: 'üstte büyük boşluk yok');
        expect(above, lessThanOrEqualTo(100));
      },
    );

    test('G: koyu temada küçük etiket çiftleri ≥ 4,5:1', () {
      const t = SahneTokens.night;
      for (final (name, fg, bg) in [
        ('İlerlemen kayıtlı (okTx/okTint)', t.okTx, t.okTint),
        ('ünite etiketi (learnTx/learnTint)', t.learnTx, t.learnTint),
        ('ikincil yazı (tx2/bg)', t.tx2, t.bg),
        ('üçüncül yazı (tx3/bg)', t.tx3, t.bg),
        ('üçüncül yazı (tx3/s1)', t.tx3, t.s1),
        ('altın etiket (goldTx/goldTint)', t.goldTx, t.goldTint),
      ]) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
      }
    });
  });
}
