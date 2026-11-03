import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/widgets/daily_event_board.dart';

import 'support/widget_test_helpers.dart';

/// Sonuç ekranında sıralama satırları geç gelince sayfa sıçramasın.
///
/// 2026-11-03 simülatör turu: "Bugünün sıralaması" yüklenirken yer tutucu
/// tek 120 pt'lik çubuktu; gerçek pano (üç sıra satırı + dünün birincisi)
/// bunun neredeyse iki katıydı. Satırlar gelince altındaki geri sayım ve
/// eylemler aşağı kayıyordu. Sessizdi: pano doğru çiziliyordu, yalnız
/// ARA durum yanlış boydaydı. Bekçi, yüklenmeden önce ve sonra geri sayımın
/// aynı yerde durduğunu ölçer.
class _SlowRepo extends MockZanKurdRepository {
  final completer = Completer<DailyEventBoard?>();

  @override
  Future<DailyEventBoard?> loadDailyEventBoard() => completer.future;
}

void main() {
  testWidgets('pano yüklenince geri sayım yerinden oynamaz', (tester) async {
    final repo = _SlowRepo();
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DailyEventBoardCard(
              repository: repo,
              clock: () => DateTime.utc(2026, 10, 24, 18, 30),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('daily-event-board-loading')),
      findsOneWidget,
    );
    final countdown = find.byKey(const ValueKey('daily-event-countdown'));
    final before = tester.getTopLeft(countdown).dy;

    repo.completer.complete(
      const DailyEventBoard(
        top: [
          DailyEventEntry(
            rank: 1,
            name: 'Rojda',
            correct: 10,
            total: 10,
            seconds: 62,
          ),
          DailyEventEntry(
            rank: 2,
            name: 'Baran',
            correct: 9,
            total: 10,
            seconds: 70,
          ),
          DailyEventEntry(
            rank: 3,
            name: 'Dilan',
            correct: 9,
            total: 10,
            seconds: 80,
          ),
        ],
        yesterdayWinner: DailyEventEntry(
          rank: 1,
          name: 'Hevi',
          correct: 10,
          total: 10,
          seconds: 55,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rojda'), findsOneWidget);
    expect(
      tester.getTopLeft(countdown).dy,
      closeTo(before, 0.5),
      reason: 'sıralama gelince sayfa kaydı',
    );
  });
}
