import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home/quick_play_grid.dart';
import 'package:zankurd_mobile/src/widgets/colorful_action_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  QuickPlayGrid buildGrid({bool dailyQuizLoading = false}) => QuickPlayGrid(
    isKu: false,
    dailyQuizLoading: dailyQuizLoading,
    onDuel: () {},
    onDailyQuiz: () {},
    onSpinWheel: () {},
    onTournament: () {},
  );

  testWidgets('uses four keyed colorful action cards', (tester) async {
    await tester.pumpWidget(wrap(buildGrid()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quick-play-duel')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-play-daily')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-play-wheel')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-play-tournament')), findsOneWidget);
    expect(find.byType(ColorfulActionCard), findsNWidgets(4));
  });

  testWidgets(
    'Pirs-tarzı tam-genişlik tek-sütun kart listesi (küçük grid değil)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(buildGrid()));
      await tester.pumpAndSettle();

      // Küçük 2 sütunlu grid artık yok; dikey tek-sütun liste kullanılır.
      expect(find.byType(GridView), findsNothing);

      final firstCardWidth = tester
          .getSize(find.byKey(const ValueKey('quick-play-duel')))
          .width;
      final secondCardTop = tester
          .getTopLeft(find.byKey(const ValueKey('quick-play-daily')))
          .dy;
      final firstCardBottom = tester
          .getBottomLeft(find.byKey(const ValueKey('quick-play-duel')))
          .dy;

      // Her kart neredeyse tam genişlik kaplar (dar 2-sütun değil).
      expect(firstCardWidth, greaterThan(300));
      // İkinci kart, ilkinin altında (yan yana değil, alt alta).
      expect(secondCardTop, greaterThanOrEqualTo(firstCardBottom));
    },
  );

  testWidgets('fits a narrow 360px viewport without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(buildGrid()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

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

    expect(find.text('1vs1 Düello'), findsOneWidget);
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

    expect(find.text('Şerê 1vs1'), findsOneWidget);
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

  testWidgets(
    'daily quiz tile shows a spinner and ignores taps while loading',
    (tester) async {
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
    },
  );
}
