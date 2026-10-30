import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import '../test/support/t8_game_fixtures.dart';
import '../test/support/t8_visual_fixtures.dart';
import '../tool/t8_web_preview.dart' show t8PreviewScreen;
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import '../test/support/widget_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('T8 çevrimdışı native görsel kanıt', (tester) async {
    freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
    Future<void> show(
      Widget child, {
      bool ku = false,
      double scale = 1,
      AuthProvider? auth,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        testShell(
          reducedMotion: true,
          authProvider: auth,
          languageProvider: ku ? kurmanciLang() : turkishLang(),
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      // ignore: avoid_print
      print('CAPTURE_SCREENSHOT: $name');
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    for (final ku in [false, true]) {
      final language = ku ? 'ku' : 'tr';
      final repository = T8GameVisualRepository();
      addTearDown(repository.disposeVisual);
      await show(
        QuizScreen(
          repository: repository,
          room: t8GameRoom(),
          questions: const [t8GameQuestion, t8GameQuestion],
          is1v1: true,
          enableTimer: true,
          suspenseHold: Duration.zero,
        ),
        ku: ku,
      );
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('duel-tug-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('duel-tug-left')), findsNothing);
      expect(find.byKey(const ValueKey('duel-tug-right')), findsOneWidget);
      await capture('t8_e4_zero_score_$language');

      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 400));
      final waiting = tester.widget<SahneStageTimer>(
        find.byType(SahneStageTimer),
      );
      expect(waiting.secondary, isTrue);
      expect(waiting.semanticLabel, contains(ku ? 'hevrik' : 'Rakibin süresi'));
      expect(waiting.pending, isFalse);
      await capture('t8_e10_opponent_timer_$language');

      repository.revealOpponentAnswer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<SahneStageTimer>(find.byType(SahneStageTimer)).pending,
        isTrue,
      );
      expect(find.byKey(const ValueKey('stage-timer-paused')), findsOneWidget);
      await capture('t8_e11_reveal_pause_$language');

      await show(
        QuizScreen(
          repository: repository,
          room: t8GameRoom(crowd: true),
          questions: const [t8GameQuestion, t8GameQuestion],
          enableTimer: true,
          suspenseHold: Duration.zero,
        ),
        ku: ku,
        scale: 1.3,
      );
      expect(find.byType(QuizScreen), findsOneWidget);
      final selfMark = find.byKey(const ValueKey('quiz-crowd-self-mark'));
      expect(selfMark, findsOneWidget);
      expect(tester.widget<Text>(selfMark).data, ku ? '(Tu)' : '(Sen)');
      await capture('t8_e14_crowd_self_$language');

      for (final win in [false, true]) {
        await show(
          QuizResultScreen(
            repository: repository,
            room: t8GameRoom(),
            score: win ? 500 : 200,
            correctCount: 4,
            wrongCount: 1,
            totalQuestions: 5,
            bestStreak: 4,
            coinsAwarded: 0,
            answerRecords: const [],
            opponents: [
              Player(
                id: 'other',
                name: 'Bero',
                score: win ? 200 : 500,
                state: 'Bot',
              ),
            ],
          ),
          ku: ku,
        );
        expect(find.byType(QuizResultScreen), findsOneWidget);
        final hero = tester.widget<SahneResultHero>(
          find.byKey(const ValueKey('result-score-header')),
        );
        expect(hero.celebrate, win);
        expect(hero.lightGlow, win);
        expect(hero.calm, !win);
        await capture('t8_e6_${win ? 'win' : 'loss'}_$language');
      }
    }
    for (final ku in [false, true]) {
      final language = ku ? 'ku' : 'tr';
      for (final screen in [
        'auth',
        'settings',
        'learning',
        'matchmaking',
        'inbox',
        'final',
        'forfeit',
      ]) {
        freshMockRepository();
        final repo = T8VisualRepo();
        final auth = T8VisualAuthProvider();
        auth.presence.bind(T8PresenceGateway(), userId: 't8-guest');
        auth.presence.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await show(
          t8PreviewScreen({'screen': screen}, repo),
          ku: ku,
          auth: auth,
        );
        await tester.pump(const Duration(milliseconds: 500));
        switch (screen) {
          case 'auth':
            final save = find.text(Tr.forKu(K.saveAccount, ku));
            await tester.scrollUntilVisible(
              save,
              250,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(save);
            await tester.pumpAndSettle();
            expect(save.hitTestable(), findsOneWidget);
            await tester.tap(save);
            await tester.pump(const Duration(milliseconds: 500));
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(
              find.byKey(const ValueKey('guest-upgrade-apple')),
              findsOneWidget,
            );
            expect(find.byKey(const ValueKey('auth-google')), findsOneWidget);
            expect(
              tester
                  .widget<FilledButton>(
                    find.byKey(const ValueKey('guest-upgrade-save')),
                  )
                  .onPressed,
              isNull,
            );
          case 'settings':
            final label = find.text(Tr.forKu(K.presenceVisibilitySub, ku));
            await tester.ensureVisible(label);
            await tester.pump(const Duration(milliseconds: 300));
            expect(label.hitTestable(), findsOneWidget);
          case 'learning':
            final card = tester.getRect(
              find.byKey(const ValueKey('learning-active-frame')),
            );
            final viewport = tester.getRect(
              find.byType(SingleChildScrollView).first,
            );
            expect(card.top, greaterThanOrEqualTo(viewport.top));
            expect(card.bottom, lessThanOrEqualTo(viewport.bottom + 0.5));
          case 'matchmaking':
            expect(
              find.byKey(const ValueKey('matchmaking-whole-rows')),
              findsOneWidget,
            );
          case 'inbox':
            expect(
              find.text(Tr.forKu(K.asyncDuelOpenInvite, ku)),
              findsOneWidget,
            );
            expect(
              find.text(
                Tr.forKu(K.asyncDuelCorrectCaption, ku, {
                  'total': '7',
                  'correct': '1',
                }),
              ),
              findsOneWidget,
            );
          case 'final':
            expect(
              find.text(Tr.forKu(K.tournamentRunnerUp, ku)),
              findsOneWidget,
            );
            expect(
              find.text(Tr.forKu(K.joinNewTournament, ku)),
              findsOneWidget,
            );
          case 'forfeit':
            final label = find.text(
              Tr.forKu(K.cupSubmissionForfeitNotPlayed, ku),
            );
            await tester.ensureVisible(label.first);
            await tester.pump(const Duration(milliseconds: 300));
            expect(label, findsWidgets);
        }
        await capture('t8_${screen}_$language');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
