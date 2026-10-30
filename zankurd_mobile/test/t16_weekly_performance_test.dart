import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/widgets/weekly_performance_chart.dart';

import 'support/widget_test_helpers.dart';

class _HistoryRepository extends MockZanKurdRepository {
  bool failHistory = false;
  int correct = 8;
  List<DateTime>? boundaries;

  @override
  Future<({int correct, int wrong})?> loadOnlineAnswerStats() async =>
      (correct: correct, wrong: 3);

  @override
  Future<List<({int correct, int wrong})>?> loadOnlineAnswerHistory({
    required List<DateTime> dayBoundaries,
  }) async {
    boundaries = dayBoundaries;
    if (failHistory) throw StateError('history unavailable');
    return [
      for (var i = 0; i < 7; i++)
        (correct: i == 6 ? correct : 0, wrong: i == 6 ? 3 : 0),
    ];
  }
}

void main() {
  setUp(() {
    freshMockRepository();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> open(
    WidgetTester tester,
    _HistoryRepository repository, {
    Listenable? refreshSignal,
  }) async {
    final local = await MistakeStore.load();
    await local.markResolved('local-correct');
    // A server answer updates SRS, but must not become a second local answer.
    await local.markResolved('online-correct', countAnswer: false);
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(
            repository: repository,
            refreshSignal: refreshSignal,
          ),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final detailed = find.text('Ayrıntılı istatistik');
    await tester.ensureVisible(detailed);
    await tester.pumpAndSettle();
    await tester.tap(detailed);
    await tester.pumpAndSettle();
  }

  testWidgets('T16 weekly chart combines local and online answers once', (
    tester,
  ) async {
    final repository = _HistoryRepository();
    await open(tester, repository);
    final chart = tester.widget<WeeklyPerformanceChart>(
      find.byType(WeeklyPerformanceChart),
    );
    expect(chart.history, hasLength(7));
    expect(chart.history.values.last, {'correct': 9, 'wrong': 3});
    expect(repository.boundaries, hasLength(8));
    expect(repository.boundaries!.first.hour, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T16 unavailable online history never shows partial bars', (
    tester,
  ) async {
    await open(tester, _HistoryRepository()..failHistory = true);
    expect(find.byType(WeeklyPerformanceChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T16 profile refresh reloads weekly local and online data', (
    tester,
  ) async {
    final repository = _HistoryRepository();
    final refresh = ChangeNotifier();
    addTearDown(refresh.dispose);
    await open(tester, repository, refreshSignal: refresh);
    final local = await MistakeStore.load();
    await local.markResolved('later-local');
    repository.correct = 10;
    refresh.notifyListeners();
    await tester.pumpAndSettle();
    final chart = tester.widget<WeeklyPerformanceChart>(
      find.byType(WeeklyPerformanceChart),
    );
    expect(chart.history.values.last, {'correct': 12, 'wrong': 3});
  });
}
