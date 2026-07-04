import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home/quick_play_grid.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders all four quick-play tiles with Turkish labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        QuickPlayGrid(
          isKu: false,
          dailyQuizLoading: false,
          onDuel: () {},
          onDailyQuiz: () {},
          onSpinWheel: () {},
          onTournament: () {},
        ),
      ),
    );

    expect(find.text('1V1 Düello'), findsOneWidget);
    expect(find.text('Günün Yarışması'), findsOneWidget);
    expect(find.text('Günün Çarkı'), findsOneWidget);
    expect(find.text('Turnuva Modu'), findsOneWidget);
  });

  testWidgets('renders all four quick-play tiles with Kurdish labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        QuickPlayGrid(
          isKu: true,
          dailyQuizLoading: false,
          onDuel: () {},
          onDailyQuiz: () {},
          onSpinWheel: () {},
          onTournament: () {},
        ),
      ),
    );

    expect(find.text('Şerê 1V1'), findsOneWidget);
    expect(find.text('Pêşbirka Rojê'), findsOneWidget);
    expect(find.text('Çerxa Rojê'), findsOneWidget);
    expect(find.text('Turnuva'), findsOneWidget);
  });

  testWidgets('tapping a tile invokes its own callback only', (tester) async {
    var duelTapped = false;
    var dailyQuizTapped = false;
    var spinWheelTapped = false;
    var tournamentTapped = false;

    await tester.pumpWidget(
      wrap(
        QuickPlayGrid(
          isKu: false,
          dailyQuizLoading: false,
          onDuel: () => duelTapped = true,
          onDailyQuiz: () => dailyQuizTapped = true,
          onSpinWheel: () => spinWheelTapped = true,
          onTournament: () => tournamentTapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Turnuva Modu'));
    await tester.pump();

    expect(tournamentTapped, isTrue);
    expect(duelTapped, isFalse);
    expect(dailyQuizTapped, isFalse);
    expect(spinWheelTapped, isFalse);
  });

  testWidgets('daily quiz tile shows a spinner and ignores taps while loading', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      wrap(
        QuickPlayGrid(
          isKu: false,
          dailyQuizLoading: true,
          onDuel: () {},
          onDailyQuiz: () => tapped = true,
          onSpinWheel: () {},
          onTournament: () {},
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Günün Yarışması'));
    await tester.pump();

    expect(tapped, isFalse);
  });
}
