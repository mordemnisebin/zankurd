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
  testWidgets('S12: aynı soruda benzersiz cevap sayısı gerilemez', (
    tester,
  ) async {
    freshMockRepository();
    final repo = _ProgressRepo();
    addTearDown(repo.disposeVisual);
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repo,
          room: t8GameRoom(crowd: true),
          questions: const [t8GameQuestion, t8GameQuestion],
          enableTimer: false,
        ),
      ),
    );
    for (var count = 0; count <= 4; count++) {
      repo.count = count;
      await tester.pump(const Duration(milliseconds: 6500));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('$count/4 cevapladı'), findsOneWidget);
    }
    repo.count = 0;
    await tester.pump(const Duration(milliseconds: 6500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('4/4 cevapladı'), findsOneWidget);
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
      final before = tester.getTopLeft(find.byType(QuizQuestionPrompt)).dy;
      if (fails) {
        bundle.image.completeError(StateError('fixture image unavailable'));
      } else {
        await tester.runAsync(() async {
          bundle.image.complete(await rootBundle.load('assets/zankurd.webp'));
        });
      }
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (fails) {
        expect(
          find.byKey(const ValueKey('quiz-image-load-failed')),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.byType(QuizQuestionPrompt)).dy,
          lessThan(before),
        );
      } else {
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
      expect(find.text('Senin cevabın'), findsOneWidget);
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
      if (choice == 'TIMEOUT')
        expect(
          find.textContaining('Cevap vermedin · Süre doldu'),
          findsOneWidget,
        );
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
        await capture(tester, boundary, 'S10_once_${ku ? 'KU' : 'TR'}');
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
            ku ? 'Li benda bersiva hevrikê ye' : 'Rakibin cevabı bekleniyor',
          ),
          findsOneWidget,
        );
        expect(find.text(ku ? 'Bersiva te' : 'Senin cevabın'), findsOneWidget);
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
  @override
  Future<RoomAnswerProgress?> loadRoomAnswerProgress(GameRoom room) async =>
      RoomAnswerProgress(questionIndex: 0, answered: count, active: 4);
}

class _DelayedImageBundle extends CachingAssetBundle {
  final image = Completer<ByteData>();
  @override
  Future<ByteData> load(String key) =>
      key == 'assets/zankurd.webp' ? image.future : rootBundle.load(key);
}

class _RevealRepo extends T8GameVisualRepository {
  _RevealRepo(this.snapshot);
  final RoomResumeSnapshot snapshot;
  @override
  bool get usesServerHiddenAnswers => true;
  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) async =>
      snapshot;
  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async => snapshot;
}
