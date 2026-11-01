/// G10/G11 bekçileri. Kusur: sıra kuralı ve önceki oturum doğruları
/// kayboluyordu. Sessizdi: sahte depolar sırasız cevabı kabul ediyor,
/// testler yalnız yeni açılan oyunun UI dizisine bakıyordu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';

import 'support/widget_test_helpers.dart';

class _FinalRepository extends MockZanKurdRepository {
  _FinalRepository({
    this.loseFinal = false,
    this.hideFirstRecovery = false,
    this.failBeforeFinal = false,
  });
  final bool loseFinal;
  final bool failBeforeFinal;
  final bool hideFirstRecovery;
  bool finalStored = false;
  int reads = 0;
  int finalCalls = 0;

  @override
  Future<AsyncDuelAnswer> answerAsyncDuel({
    required String duelId,
    required int questionIndex,
    required String choice,
    required int responseMs,
  }) async {
    if (questionIndex == 6) {
      finalCalls++;
      if (failBeforeFinal) throw StateError('Request never reached server');
      if (finalStored) throw StateError('Already answered');
    }
    final answer = await super.answerAsyncDuel(
      duelId: duelId,
      questionIndex: questionIndex,
      choice: choice,
      responseMs: responseMs,
    );
    if (answer.finished) {
      finalStored = true;
      if (loseFinal) throw StateError('Response lost');
    }
    return AsyncDuelAnswer(
      correct: true,
      correctOption: choice,
      answered: answer.answered,
      total: answer.total,
      finished: answer.finished,
      result: answer.finished
          ? const AsyncDuelResult(waiting: true, myCorrect: 5, myMs: 1000)
          : null,
    );
  }

  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() async {
    if (finalStored && hideFirstRecovery && reads++ == 0) {
      throw StateError('Read offline');
    }
    final rows = await super.loadMyAsyncDuels();
    return [
      for (final row in rows)
        AsyncDuelSummary(
          duelId: row.duelId,
          status: row.status,
          role: row.role,
          createdAt: row.createdAt,
          seen: row.seen,
          myCorrect: finalStored ? 5 : null,
        ),
    ];
  }
}

class _OrderedRepository extends MockZanKurdRepository {
  _OrderedRepository({this.alwaysFail = false});
  final bool alwaysFail;
  final List<int> calls = [];
  int accepted = 0;

  @override
  Future<AsyncDuelAnswer> answerAsyncDuel({
    required String duelId,
    required int questionIndex,
    required String choice,
    required int responseMs,
  }) async {
    calls.add(questionIndex);
    if (questionIndex != accepted) throw StateError('Invalid index');
    if (alwaysFail || calls.length == 1) throw StateError('Network');
    // RPC işlem sırası HTTP başlatma sırasıyla aynı olmak zorunda değil.
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final response = await super.answerAsyncDuel(
      duelId: duelId,
      questionIndex: questionIndex,
      choice: choice,
      responseMs: responseMs,
    );
    accepted++;
    return response;
  }
}

Future<void> _show(
  WidgetTester tester,
  MockZanKurdRepository repo, {
  AsyncDuelEntry? entry,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(
      child: AsyncDuelPlayScreen(repository: repo, entry: entry),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _quit(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('async-duel-quit')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Çık'));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyMissionStore.resetInstance();
  });

  for (final lost in [false, true]) {
    testWidgets('G11 kusur: devamdaki 3 doğru eksikti; sessizdi çünkü '
        'yalnız taze oturum sınanıyordu (yanıt kaybı: $lost)', (tester) async {
      final repo = _FinalRepository(loseFinal: lost);
      final start = await repo.startAsyncDuel();
      for (var i = 0; i < 3; i++) {
        await repo.answerAsyncDuel(
          duelId: start.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }
      await _show(tester, repo, entry: AsyncDuelEntry.resume(start.duelId));
      for (var i = 3; i < 7; i++) {
        await tester.tap(find.byKey(const ValueKey('async-duel-option-0')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect((await DailyMissionStore.load()).correctAnswersToday, 5);
      expect(find.byKey(const ValueKey('async-duel-result')), findsOneWidget);
      // Tamamlanmış aynı turu yeniden yüklemek yeni görev kazanımı değildir.
      DailyMissionStore.resetInstance();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelPlayScreen(
            repository: repo,
            entry: AsyncDuelEntry.resume(start.duelId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect((await DailyMissionStore.load()).correctAnswersToday, 5);
    });
  }

  testWidgets('G11 kusur: Already answered finali kaybolurdu; sessizdi çünkü '
      'kayıp cevap ve sonuç okuma hatası birlikte sınanmıyordu', (
    tester,
  ) async {
    final repo = _FinalRepository(loseFinal: true, hideFirstRecovery: true);
    final start = await repo.startAsyncDuel();
    for (var i = 0; i < 6; i++) {
      await repo.answerAsyncDuel(
        duelId: start.duelId,
        questionIndex: i,
        choice: 'A',
        responseMs: 1000,
      );
    }
    await _show(tester, repo, entry: AsyncDuelEntry.resume(start.duelId));
    await tester.tap(find.byKey(const ValueKey('async-duel-option-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect((await DailyMissionStore.load()).correctAnswersToday, 0);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(repo.finalCalls, 2);
    expect((await DailyMissionStore.load()).correctAnswersToday, 5);
  });

  testWidgets(
    'G11 kusur: yazılmamış final tamamlanmış sayılabilirdi; sessizdi çünkü '
    'yanıt kaybı ile isteğin hiç ulaşmaması ayrılmıyordu',
    (tester) async {
      final repo = _FinalRepository(failBeforeFinal: true);
      final start = await repo.startAsyncDuel();
      for (var i = 0; i < 6; i++) {
        await repo.answerAsyncDuel(
          duelId: start.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }
      await _show(tester, repo, entry: AsyncDuelEntry.resume(start.duelId));
      await tester.tap(find.byKey(const ValueKey('async-duel-option-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.finalStored, isFalse);
      expect((await repo.loadMyAsyncDuels()).single.myCorrect, isNull);
      expect((await DailyMissionStore.load()).correctAnswersToday, 0);
      expect(find.byKey(const ValueKey('async-duel-result')), findsNothing);
      expect(find.text('Tekrar dene'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('G10 kusur: terk paralel gönderiliyordu; sessizdi çünkü '
      'sahte sunucu indeks doğrulamıyordu', (tester) async {
    final repo = _OrderedRepository();
    await _show(tester, repo);
    await _quit(tester);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(repo.calls, [0, 0, 1, 2, 3, 4, 5, 6]);
    expect(repo.accepted, 7);
  });

  testWidgets('G10 kusur: başarısız indeks atlanıyordu; sessizdi çünkü '
      'kısmi terk sonucu gözlenmiyordu', (tester) async {
    final repo = _OrderedRepository(alwaysFail: true);
    await _show(tester, repo);
    await _quit(tester);
    await tester.pumpAndSettle();
    expect(repo.calls, [0, 0]);
    expect(find.text('Yarım kaldı'), findsOneWidget);
  });

  test('G11 kusur: tur yeniden açılınca çift sayılırdı; sessizdi çünkü '
      'gün değişimi ve eşzamanlı tamamlamalar sınanmıyordu', () async {
    final today = DateTime.now();
    final store = await DailyMissionStore.load(now: today);
    await Future.wait([
      for (var i = 0; i < 2; i++)
        store.reportQuizCompleted(
          completionId: 'async-duel:once',
          correctAnswers: 5,
          category: 'Ziman',
          streakAlive: true,
        ),
    ]);
    expect(store.correctAnswersToday, 5);
    DailyMissionStore.resetInstance();
    final tomorrow = await DailyMissionStore.load(
      now: today.add(const Duration(days: 1)),
    );
    await tomorrow.reportQuizCompleted(
      completionId: 'async-duel:once',
      correctAnswers: 5,
      category: 'Ziman',
      streakAlive: true,
    );
    expect(tomorrow.correctAnswersToday, 0);
  });
}
