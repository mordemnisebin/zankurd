import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final ku in [false, true]) {
    testWidgets(
      'T14 puan birimi sayıya bağlı, özetten ayrı ${ku ? 'KU' : 'TR'}',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repository = MockZanKurdRepository();
        await tester.pumpWidget(
          testShell(
            reducedMotion: true,
            languageProvider: ku ? kurmanciLang() : turkishLang(),
            child: QuizResultScreen(
              repository: repository,
              room: repository.createRoom(),
              score: 151,
              correctCount: 1,
              wrongCount: 0,
              totalQuestions: 10,
              bestStreak: 1,
              answerRecords: const [],
              coinsAwarded: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final unit = find.byKey(const ValueKey('result-score-unit'));
        final count = find.byKey(const ValueKey('result-score-count'));
        expect(tester.widget<Text>(unit).data, ku ? 'pûan' : 'puan');
        expect(
          tester.widget<Text>(unit).style!.fontSize,
          greaterThanOrEqualTo(14),
        );
        expect(
          tester.getRect(unit).left - tester.getRect(count).right,
          closeTo(8, 0.01),
        );
        expect(tester.getRect(unit).overlaps(tester.getRect(count)), isFalse);
        final hero = tester.widget<SahneResultHero>(
          find.byType(SahneResultHero),
        );
        expect(hero.caption, isNot(contains(ku ? 'pûan' : 'puan')));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  Future<void> pumpScene(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        reducedMotion: true,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: SahneResultScaffold(
              neutral: true,
              hero: const SahneResultHero(
                compactSpacing: true,
                emblem: SahneResultEmblem.win(),
                title: 'Kazandın!',
                value: 151,
                valueSize: 48,
                valueLabel: 'puan',
                caption: 'Sıralaman #1/4 • %10 doğruluk',
                celebrate: true,
              ),
              stats: const SizedBox(key: ValueKey('t14-stats'), height: 80),
              rewards: const SahneResultRewards(
                coins: 27,
                xp: 151,
                label: 'Kazanıldı',
                progress: SahneResultLevelProgress(
                  levelLabel: 'Seviye 1',
                  xpInLevel: 573,
                  xpNeeded: 1000,
                  progress: .573,
                ),
              ),
              sections: [
                const Text('Yarış sıralaması'),
                for (var i = 0; i < 8; i++)
                  SizedBox(height: 70, child: Text('Oyuncu $i')),
              ],
              primary: SahneResultAction(
                label: 'Tekrar oyna',
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('T14 kutlama boyaması sayım alanına taşamaz', (tester) async {
    await pumpScene(tester);
    final clip = find.byKey(const ValueKey('result-celebration-clip'));
    expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.hardEdge);
    expect(
      find.descendant(
        of: clip,
        matching: find.byKey(const ValueKey('result-score-celebration')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getRect(clip).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const ValueKey('t14-stats'))).top,
      ),
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('T14 tüm sıralama satırlarına solmadan erişilir $scale', (
      tester,
    ) async {
      await pumpScene(tester, scale: scale);
      expect(
        find.byKey(const ValueKey('sahne-result-bottom-fade')),
        findsNothing,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      final last = tester.getRect(find.text('Oyuncu 7'));
      final dock = tester.getRect(find.byType(SahneResultDock));
      expect(last.top, greaterThanOrEqualTo(0));
      expect(last.bottom, lessThan(dock.top));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('T14 ödül XP zemini opak ve normal metin kontrastı yeterli', (
    tester,
  ) async {
    await pumpScene(tester);
    final card = tester.widget<SahneSurfaceCard>(
      find.descendant(
        of: find.byType(SahneResultRewards),
        matching: find.byType(SahneSurfaceCard),
      ),
    );
    expect(
      card.color!.a,
      1,
      reason: 'Dekor XP zemininin arkasından görünmemeli.',
    );
    final xp = tester.widget<Text>(find.text('573 / 1.000 XP'));
    final textLuminance = xp.style!.color!.computeLuminance();
    final backgroundLuminance = card.color!.computeLuminance();
    expect(
      (textLuminance + .05) / (backgroundLuminance + .05),
      greaterThanOrEqualTo(4.5),
    );
    expect(xp.style!.fontSize, greaterThanOrEqualTo(14));
  });
}
