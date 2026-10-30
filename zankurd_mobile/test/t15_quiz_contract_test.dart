import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/game/server_clock.dart';
import 'package:zankurd_mobile/src/game/reveal_timing.dart';
import 'package:zankurd_mobile/src/widgets/quiz_top_bar.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_timer_widget.dart';
import 'package:zankurd_mobile/src/widgets/quiz_stage_kit.dart';
import 'support/realistic_device.dart';
import 'support/t8_game_fixtures.dart';
import 'support/widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader('Lucide')..addFont(
          File(
            'assets/fonts/Lucide.ttf',
          ).readAsBytes().then((b) => ByteData.view(b.buffer)),
        ))
        .load();
  });
  testWidgets('S7: isteğe bağlı bozuk görsel en çok iki metin satırıdır', (
    tester,
  ) async {
    freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: const Center(
          child: QuizQuestionImage(url: 'asset://assets/missing-t15-image.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(QuizQuestionImage)).height,
      lessThanOrEqualTo(44),
    );
    expect(
      find.byKey(const ValueKey('quiz-question-image-zoom')),
      findsNothing,
    );
  });
  testWidgets('S9: cevapsız resume ilk karede eski tam süreyi göstermez', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: const Center(
          child: QuizTimerWidget(
            animation: AlwaysStoppedAnimation(1),
            maxSeconds: 30,
            isPaused: true,
            stopped: true,
            expired: true,
          ),
        ),
      ),
    );
    expect(find.text('0'), findsOneWidget);
    expect(find.text('30'), findsNothing);
  });
  testWidgets(
    'S10: bir ve iki satırlık başlıkta üst çubuk sabit, yazı en az 14',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> show(String title) => tester.pumpWidget(
        testShell(
          child: SahneStageScaffold(
            center: QuizStageCenter(
              category: 'Ziman',
              title: title,
              index: 0,
              total: 10,
            ),
            body: const SizedBox(key: ValueKey('body-anchor')),
          ),
        ),
      );
      await show('Dil');
      final before = tester.getRect(find.byKey(const ValueKey('body-anchor')));
      await show('Kürt edebiyatı ve sanat tarihi boyunca');
      expect(tester.getRect(find.byKey(const ValueKey('body-anchor'))), before);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('quiz-stage-kicker')))
            .style!
            .fontSize,
        greaterThanOrEqualTo(14),
      );
    },
  );
  testWidgets('S10: dar başlık bilgisi 14 punto altına düşmez', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: const Center(
          child: SizedBox(
            width: 130,
            child: QuizStageCenter(
              category: 'Cografya',
              title: 'Kürt edebiyatı ve tarihi',
              index: 9,
              total: 10,
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('quiz-stage-kicker')))
          .style!
          .fontSize,
      greaterThanOrEqualTo(14),
    );
  });
  testWidgets('S10 S13: TR/KU 1/10 ve 10/10 kontrol geometrisi sabit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    final lang = turkishLang();
    for (final ku in [false, true]) {
      lang.setLang(ku ? 'ku' : 'tr');
      Rect? firstBody;
      Rect? firstTimer;
      for (final index in [0, 9]) {
        await tester.pumpWidget(
          testShell(
            languageProvider: lang,
            child: RepaintBoundary(
              key: boundary,
              child: SahneStageScaffold(
                onClose: () {},
                center: QuizStageCenter(
                  category: 'Cografya',
                  index: index,
                  total: 10,
                ),
                score: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 48, height: 48),
                    SahneStageTimer(secondsLeft: 30, semanticLabel: '30'),
                    SizedBox(width: 48, height: 48),
                  ],
                ),
                body: const SizedBox(key: ValueKey('t15-body-anchor')),
              ),
            ),
          ),
        );
        await tester.pump();
        final kicker = find.byKey(const ValueKey('quiz-stage-kicker'));
        final paragraph = tester.renderObject<RenderParagraph>(kicker);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(tester.widget<Text>(kicker).data, contains('${index + 1}/10'));
        final body = tester.getRect(
          find.byKey(const ValueKey('t15-body-anchor')),
        );
        final timer = tester.getRect(find.byType(SahneStageTimer));
        firstBody ??= body;
        firstTimer ??= timer;
        expect(body, firstBody);
        expect(timer, firstTimer);
        expect(tester.getRect(kicker).right, lessThanOrEqualTo(timer.left));
        await capture(
          tester,
          boundary,
          'S10_sonra_${ku ? 'KU' : 'TR'}_${index + 1}_10',
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
  testWidgets('S12: aynı soruda benzersiz cevap sayısı gerilemez', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    freshMockRepository();
    final repo = _ProgressRepo();
    final boundary = GlobalKey();
    addTearDown(repo.disposeVisual);
    await tester.pumpWidget(
      testShell(
        child: RepaintBoundary(
          key: boundary,
          child: QuizScreen(
            repository: repo,
            room: t8GameRoom(crowd: true),
            questions: const [t8GameQuestion, t8GameQuestion],
            enableTimer: false,
          ),
        ),
      ),
    );
    for (var count = 0; count <= 4; count++) {
      repo.count = count;
      await tester.pump(const Duration(milliseconds: 6500));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('$count/4 cevapladı'), findsOneWidget);
      await capture(tester, boundary, 'S12_sonra_${count}_4');
    }
    repo.count = 0;
    await tester.pump(const Duration(milliseconds: 6500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('4/4 cevapladı'), findsOneWidget);
    repo.questionIndex = 1;
    await tester.pump(const Duration(milliseconds: 6500));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('0/4 cevapladı'), findsOneWidget);
    expect(find.textContaining('Soru 2/2'), findsOneWidget);
    await capture(tester, boundary, 'S12_sonra_yeni_soru_0_4');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final fails in [false, true]) {
    testWidgets('S7: yavaş görsel ardından ${fails ? 'hata' : 'başarı'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = freshMockRepository();
      final bundle = _DelayedImageBundle();
      final boundary = GlobalKey();
      const q = QuizQuestion(
        id: 't15-image',
        category: 'Ziman',
        prompt: 'Yek + yek?',
        answers: ['2', '3', '4', '5'],
        correctAnswer: '2',
        explanation: '',
        imageUrl: 'asset://assets/zankurd.webp',
      );
      await tester.pumpWidget(
        testShell(
          child: DefaultAssetBundle(
            bundle: bundle,
            child: RepaintBoundary(
              key: boundary,
              child: QuizScreen(
                repository: repo,
                room: repo.createRoom(),
                questions: const [q],
                enableTimer: false,
                experience: QuizExperience.learning,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await capture(
        tester,
        boundary,
        'S7_sonra_yavas_${fails ? 'hata' : 'basari'}',
      );
      final before = tester.getTopLeft(find.text('Yek + yek?')).dy;
      if (fails) {
        bundle.image.completeError(StateError('fixture image unavailable'));
      } else {
        await tester.runAsync(() async {
          bundle.image.complete(await rootBundle.load('assets/zankurd.webp'));
        });
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((image) => image.image != null)) {
            break;
          }
        }
      }
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (fails) {
        expect(
          find.byKey(const ValueKey('quiz-image-load-failed')),
          findsOneWidget,
        );
        expect(tester.getTopLeft(find.text('Yek + yek?')).dy, lessThan(before));
      } else {
        expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((image) => image.image != null),
          isTrue,
          reason: 'Başarı karesi yalnız gerçek görsel çözüldükten sonra alınır',
        );
        expect(
          find.byKey(const ValueKey('quiz-question-image-zoom')),
          findsOneWidget,
        );
      }
      await capture(
        tester,
        boundary,
        'S7_sonra_${fails ? 'hata' : 'basarili'}',
      );
      await tester.tap(find.text('2').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
            .singleWhere((tile) => tile.answer == '2')
            .selected,
        isTrue,
        reason: 'Görsel hatasından sonra öğrenme cevabı seçilebilir kalır',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final choice in ['A', 'B', 'TIMEOUT']) {
    testWidgets('S8 S9: sunucu açılışında kişisel $choice ayrımı', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      freshMockRepository();
      final now = DateTime.utc(2026, 10, 30);
      final snapshot = RoomResumeSnapshot(
        room: t8GameRoom(),
        currentQuestionIndex: 0,
        ownScore: choice == 'A' ? 100 : 0,
        streak: 0,
        bestStreak: 0,
        correctCount: choice == 'A' ? 1 : 0,
        wrongCount: choice == 'A' ? 0 : 1,
        answers: [
          ResumedAnswer(
            questionId: 't8-game',
            questionIndex: 0,
            selectedOptionKey: choice,
            correctOptionKey: 'A',
            isCorrect: choice == 'A',
            pointsAwarded: choice == 'A' ? 100 : 0,
            responseMs: 30000,
          ),
        ],
        serverNow: now,
        questionStartedAt: now.subtract(const Duration(seconds: 30)),
        deadline: now,
        remainingMs: 0,
        serverClock: ServerClock(serverNow: now, elapsed: () => Duration.zero),
        revealClock: ServerRevealClock(
          serverNow: now,
          endsAt: now.add(const Duration(seconds: 60)),
          elapsed: () => Duration.zero,
        ),
      );
      final repo = _RevealRepo(snapshot);
      addTearDown(repo.disposeVisual);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        testShell(
          child: RepaintBoundary(
            key: boundary,
            child: QuizScreen(
              repository: repo,
              room: snapshot.room,
              questions: [
                t8GameQuestion.copyWith(correctAnswer: ''),
                t8GameQuestion,
              ],
              is1v1: true,
              resumeSnapshot: snapshot,
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Doğru cevap'), findsOneWidget);
      expect(
        find.text('Senin cevabın'),
        choice == 'TIMEOUT' ? findsNothing : findsOneWidget,
      );
      if (choice == 'TIMEOUT') {
        expect(
          tester.widget<QuizTimerWidget>(find.byType(QuizTimerWidget)).expired,
          isTrue,
        );
        expect(
          find.textContaining('Cevap vermedin · Süre doldu'),
          findsOneWidget,
        );
      }
      expect(find.textContaining('Sonraki soru:'), findsOneWidget);
      expect(find.byKey(const ValueKey('stage-timer-revealed')), findsNothing);
      expect(find.text('0'), findsWidgets);
      await capture(tester, boundary, 'S8_S9_sonra_$choice');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final ku in [false, true]) {
    testWidgets(
      'S8 S10 S11 S13: düello kayıt, kişisel cevap ve tek sayaç ku=$ku',
      (tester) async {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        freshMockRepository();
        final repo = T8GameVisualRepository();
        addTearDown(repo.disposeVisual);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          testShell(
            languageProvider: ku ? kurmanciLang() : turkishLang(),
            child: RepaintBoundary(
              key: boundary,
              child: QuizScreen(
                repository: repo,
                room: t8GameRoom(),
                questions: const [t8GameQuestion, t8GameQuestion],
                is1v1: true,
                enableTimer: false,
              ),
            ),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await capture(tester, boundary, 'S10_sonra_${ku ? 'KU' : 'TR'}');
        expect(
          find.text('1/2'),
          findsNothing,
          reason: 'Soru sayacı skor kartında tekrarlanmaz',
        );
        expect(
          find.text('Yek + yek?'),
          findsOneWidget,
          reason: 'Çevrimiçi KU soru arayüz dilinden bağımsızdır',
        );
        final dock = tester.getRect(find.byType(QuizStableDockHeight));
        await tester.tap(find.text('2').first);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          find.textContaining(
            ku ? 'Bersiva te hat tomarkirin:' : 'Cevabın kaydedildi:',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            ku
                ? 'Em li benda bersiva hevrikê te ne'
                : 'Rakibin cevabı bekleniyor',
          ),
          findsOneWidget,
        );
        expect(find.text(ku ? 'Bersiva te' : 'Senin cevabın'), findsOneWidget);
        await tester.tap(find.text('3').first);
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.textContaining(
            ku
                ? 'Bersiva te hat tomarkirin: A · 2'
                : 'Cevabın kaydedildi: A · 2',
          ),
          findsOneWidget,
          reason: 'Kayıttan sonra farklı şık dokunuşu seçimi değiştirmez',
        );
        expect(
          tester.getRect(find.byType(QuizStableDockHeight)).height,
          closeTo(dock.height, .5),
        );
        await capture(tester, boundary, 'S11_sonra_${ku ? 'KU' : 'TR'}_kayit');
        repo.revealOpponentAnswer();
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text(ku ? 'Bersiva rast' : 'Doğru cevap'), findsOneWidget);
        expect(
          find.textContaining(ku ? 'Pirsa din' : 'Sonraki soru'),
          findsOneWidget,
        );
        await capture(tester, boundary, 'S8_sonra_${ku ? 'KU' : 'TR'}_dogru');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('S8 S9 S12 S13: oda dil değişimi ve cevapsız 2/4 açılışı', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    freshMockRepository();
    final lang = turkishLang();
    final boundary = GlobalKey();
    final room = t8GameRoom(crowd: true);
    final now = DateTime.utc(2026, 10, 30);
    RoomResumeSnapshot snapshot({required bool reveal}) => RoomResumeSnapshot(
      room: room,
      currentQuestionIndex: 0,
      ownScore: 0,
      streak: 0,
      bestStreak: 0,
      correctCount: 0,
      wrongCount: 0,
      answers: reveal
          ? const [
              ResumedAnswer(
                questionId: 't15-crowd-language',
                questionIndex: 0,
                selectedOptionKey: 'TIMEOUT',
                correctOptionKey: 'A',
                isCorrect: false,
                pointsAwarded: 0,
                responseMs: 30000,
              ),
            ]
          : const [],
      serverNow: now,
      questionStartedAt: now.subtract(const Duration(seconds: 30)),
      deadline: reveal ? now : now.add(const Duration(seconds: 30)),
      remainingMs: reveal ? 0 : 30000,
      serverClock: ServerClock(serverNow: now, elapsed: () => Duration.zero),
      revealClock: reveal
          ? ServerRevealClock(
              serverNow: now,
              endsAt: now.add(const Duration(seconds: 60)),
              elapsed: () => Duration.zero,
            )
          : null,
    );
    final repo = _RevealRepo(snapshot(reveal: false))..answeredCount = 2;
    addTearDown(repo.disposeVisual);
    const q = QuizQuestion(
      id: 't15-crowd-language',
      category: 'Cografya',
      prompt: 'Yek + yek?',
      answers: ['2', '3', '4', '5'],
      correctAnswer: '',
      explanation: '',
    );
    await tester.pumpWidget(
      testShell(
        languageProvider: lang,
        child: RepaintBoundary(
          key: boundary,
          child: QuizScreen(
            repository: repo,
            room: room,
            questions: const [q, q],
            resumeSnapshot: repo.snapshot,
          ),
        ),
      ),
    );
    for (final reveal in [false, true]) {
      if (reveal) {
        repo.snapshot = snapshot(reveal: true);
        await tester.pump(const Duration(milliseconds: 6500));
      }
      for (final ku in [false, true]) {
        lang.setLang(ku ? 'ku' : 'tr');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(ku ? 'Ode' : 'Oda'), findsOneWidget);
        expect(
          find.textContaining(
            ku ? 'Pirs 1/2 · Erdnîgarî' : 'Soru 1/2 · Coğrafya',
          ),
          findsOneWidget,
        );
        expect(find.text(ku ? 'Rêza te' : 'Sıralaman'), findsOneWidget);
        expect(find.text(ku ? '(Tu)' : '(Sen)'), findsOneWidget);
        expect(
          find.text(ku ? '2/4 bersiv da' : '2/4 cevapladı'),
          findsOneWidget,
        );
        expect(find.text('Yek + yek?'), findsOneWidget);
        if (reveal) {
          expect(
            find.textContaining(
              ku
                  ? 'Te bersiv neda · Dem qediya'
                  : 'Cevap vermedin · Süre doldu',
            ),
            findsOneWidget,
          );
          expect(
            find.text(ku ? 'Bersiva rast' : 'Doğru cevap'),
            findsOneWidget,
          );
          expect(find.text(ku ? 'Bersiva te' : 'Senin cevabın'), findsNothing);
          expect(find.text('0'), findsWidgets);
        } else {
          expect(
            find.text(ku ? 'Bersivekê hilbijêre' : 'Bir cevap seç'),
            findsOneWidget,
          );
          expect(find.text('30'), findsOneWidget);
        }
        await capture(
          tester,
          boundary,
          'S12_S13_sonra_${ku ? 'KU' : 'TR'}_${reveal ? 'cevapsiz' : 'acik'}',
        );
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['T15_CAPTURE'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/Users/kocer/Projects/zankurd_kapisma/t15/kanit/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

class _ProgressRepo extends T8GameVisualRepository {
  int count = 0;
  int questionIndex = 0;
  @override
  Future<RoomAnswerProgress?> loadRoomAnswerProgress(GameRoom room) async =>
      RoomAnswerProgress(
        questionIndex: questionIndex,
        answered: count,
        active: 4,
      );

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async => questionIndex == 0
      ? null
      : RoomResumeSnapshot(
          room: t8GameRoom(crowd: true),
          currentQuestionIndex: questionIndex,
          ownScore: 0,
          streak: 0,
          bestStreak: 0,
          correctCount: 0,
          wrongCount: 0,
          answers: const [],
          serverNow: DateTime.utc(2026, 10, 30),
          questionStartedAt: null,
          deadline: null,
          remainingMs: 30000,
        );
}

class _DelayedImageBundle extends CachingAssetBundle {
  final image = Completer<ByteData>();
  @override
  Future<ByteData> load(String key) =>
      key == 'assets/zankurd.webp' ? image.future : rootBundle.load(key);
}

class _RevealRepo extends T8GameVisualRepository {
  _RevealRepo(this.snapshot);
  RoomResumeSnapshot snapshot;
  int? answeredCount;
  @override
  bool get usesServerHiddenAnswers => true;
  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) async =>
      snapshot;
  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async => snapshot;
  @override
  Future<RoomAnswerProgress?> loadRoomAnswerProgress(GameRoom room) async =>
      answeredCount == null
      ? null
      : RoomAnswerProgress(
          questionIndex: 0,
          answered: answeredCount!,
          active: 4,
          revealed: snapshot.revealClock != null,
        );
}
