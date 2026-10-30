import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

const _q = QuizQuestion(
  id: 'screen-order',
  category: 'Ziman',
  prompt: 'Test',
  answers: ['alpha', 'beta', 'gamma', 'delta'],
  correctAnswer: 'alpha',
  answersTr: ['bir', 'iki', 'üç', 'dört'],
  correctAnswerTr: 'bir',
  promptTr: 'Test TR',
  explanation: '',
);

class _Repository extends MockZanKurdRepository {
  _Repository(this.matchId);
  final String matchId;
  final choices = <String>[];
  AsyncDuelStart get start => AsyncDuelStart(
    duelId: matchId,
    role: AsyncDuelRole.creator,
    expiresAt: DateTime(2099),
    questions: [_q, _q],
  );
  @override
  Future<AsyncDuelStart> startAsyncDuel({String? category}) async => start;
  @override
  Future<AsyncDuelStart> resumeAsyncDuel(String duelId) async => start;
  @override
  Future<AsyncDuelStart> startTournamentMatch(String matchId) async => start;
  @override
  Future<TournamentPresent> presentTournamentQuestion(
    String matchId,
    int questionIndex,
  ) async => const TournamentPresent(elapsedMs: 0, question: _q);
  @override
  Future<AsyncDuelAnswer> answerAsyncDuel({
    required String duelId,
    required int questionIndex,
    required String choice,
    required int responseMs,
  }) async {
    choices.add(choice);
    throw StateError('Test: yanıt bekletiliyor');
  }

  @override
  Future<AsyncDuelAnswer> answerTournamentQuestion({
    required String matchId,
    required int questionIndex,
    required String choice,
  }) async {
    choices.add(choice);
    throw StateError('Test: yanıt bekletiliyor');
  }
}

class _JokerRepository extends MockZanKurdRepository {
  final replacement = QuizQuestion.fromJson({
    ..._q.toJson(),
    'id': 'replacement',
  });
  @override
  List<QuizQuestion> get playableQuestions => [_q, replacement];
  @override
  Future<int> loadCoinBalance() async => 500;
  @override
  Future<bool> spendCoins(int amount, String reason) async => true;
}

List<String> _shown(WidgetTester tester) => tester
    .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
    .map((tile) => tile.answer)
    .toList();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
  });

  testWidgets(
    'üretilen solo tohumu resume da yenileniyordu; yalnız sabit kimlik sınanıyordu',
    (tester) async {
      final orders = <String>{};
      for (var i = 0; i < 8; i++) {
        final repo = freshMockRepository();
        SharedPreferences.setMockInitialValues({
          'zankurd.quiz_tutorial.seen': true,
        });
        await tester.pumpWidget(
          testShell(
            child: QuizScreen(
              repository: repo,
              room: repo.createRoom(),
              questions: const [_q, _q],
              enableTimer: false,
            ),
          ),
        );
        final first = _shown(tester);
        expect(first.length, 4);
        orders.add(first.join('|'));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(_shown(tester), first);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(orders.length, greaterThan(1));
    },
  );

  testWidgets(
    'joker yanlış konumu etkiliyordu; karıştırılmış şık ve yeni soru sınanmıyordu',
    (tester) async {
      freshMockRepository();
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
        'zankurd.wildcard_hint.fiftyFifty': true,
        'zankurd.wildcard_hint.audience': true,
        'zankurd.wildcard_hint.changeQuestion': true,
      });
      final repo = _JokerRepository();
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repo,
            room: repo.createRoom(),
            questions: const [_q, _q],
            roundId: 'joker-round',
            enableTimer: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final before = _shown(tester);
      Future<void> use(WildcardType type) async {
        final finder = find.byWidgetPredicate(
          (w) => w is WildcardButton && w.type == type,
        );
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
      }

      await use(WildcardType.fiftyFifty);
      expect(_shown(tester), before);
      final tiles = tester.widgetList<QuizOptionTile>(
        find.byType(QuizOptionTile),
      );
      expect(tiles.where((t) => t.disabled).length, 2);
      expect(tiles.singleWhere((t) => t.answer == 'bir').disabled, isFalse);
      await use(WildcardType.audience);
      expect(_shown(tester), before);
      final voted = tester.widgetList<QuizOptionTile>(
        find.byType(QuizOptionTile),
      );
      expect(
        voted.singleWhere((t) => t.answer == 'bir').audiencePercent,
        greaterThanOrEqualTo(.5),
      );
      for (final tile in voted.where((t) => t.disabled)) {
        expect(tile.audiencePercent, isNull);
      }
      await use(WildcardType.changeQuestion);
      expect(
        _shown(tester),
        repo.replacement
            .forRound('joker-round')
            .localized(isKu: false)
            .displayAnswers,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final mode in ['solo', 'duel', 'room', 'local-tournament']) {
    testWidgets(
      '$mode ilk kare/resume sırası sapıyordu; model testi ekranı kapsamıyordu',
      (tester) async {
        final repo = freshMockRepository();
        final online = mode == 'duel' || mode == 'room';
        final room = repo.createRoom().copyWith(
          id: online ? 'shared-room' : null,
          status: RoomStatus.active,
          maxPlayers: mode == 'room' ? 4 : 2,
          isCustom: mode == 'room',
        );
        final seed = online ? 'shared-room' : 'solo-or-match';
        List<String>? first;
        for (final ku in [true, false]) {
          await tester.pumpWidget(const SizedBox.shrink());
          final lang = LanguageProvider(initialLang: ku ? 'ku' : 'tr');
          await tester.pumpWidget(
            testShell(
              languageProvider: lang,
              child: QuizScreen(
                repository: repo,
                room: room,
                questions: const [_q, _q],
                roundId: 'solo-or-match',
                enableTimer: false,
                is1v1: mode == 'duel',
                versusBannerText: mode == 'local-tournament' ? 'test' : null,
              ),
            ),
          );
          // Henüz pumpAndSettle yok: ilk çizilen şıklar zaten doğru sırada.
          // T15: çevrimiçi içerik sunucunun KU/orijinal diliyle kalır;
          // iki arayüz dilinde de kanonik seçenek anahtarları aynı olmalı.
          final expected = _q.forRound(seed).localized(isKu: online || ku);
          expect(_shown(tester), expected.displayAnswers);
          final keys = _shown(tester).map(expected.optionKeyForAnswer).toList();
          first ??= keys;
          expect(
            keys,
            first,
            reason: 'İki istemci / farklı dil / yeniden açma',
          );
          await tester.pump(const Duration(milliseconds: 100));
          lang.setLanguage(ku ? AppLanguage.tr : AppLanguage.ku);
          await tester.pump();
          expect(_shown(tester), expected.displayAnswers);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();
          expect(_shown(tester), expected.displayAnswers);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final tournament in [false, true]) {
    testWidgets(
      '${tournament ? 'turnuva' : 'sırayla düello'} maç/anahtar sapması sessizdi; sunum ve resume sınanmıyordu',
      (tester) async {
        final repo = _Repository('server-match');
        for (final resume in [false, true]) {
          await tester.pumpWidget(
            testShell(
              child: AsyncDuelPlayScreen(
                repository: repo,
                entry: tournament
                    ? const AsyncDuelEntry.tournament('server-match')
                    : resume
                    ? const AsyncDuelEntry.resume('server-match')
                    : null,
              ),
            ),
          );
          // RPC tamamlanınca ilk görünen karede sıra hazırdır.
          await tester.pump();
          await tester.pump();
          final expected = _q.forRound('server-match');
          expect(_shown(tester), expected.displayAnswers);
          await tester.pump(const Duration(milliseconds: 100));
          expect(_shown(tester), expected.displayAnswers);
          final first = tester.widget<QuizOptionTile>(
            find.byType(QuizOptionTile).first,
          );
          first.onTap!();
          await tester.pump();
          expect(repo.choices.last, expected.optionKeyForAnswer(first.answer));
          expect(_shown(tester), expected.displayAnswers);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  }
}
