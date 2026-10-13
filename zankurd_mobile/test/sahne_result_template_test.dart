import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Tek sonuç şablonu (`SahneResultScaffold`): kahraman → sayımlar → ödül →
/// bölümler → alt perde; anlamsız sıfır gösterilmez.
///
/// ## Kusur (2026-10-01, tasarım denetimi A6)
///
/// Bitiş ekranları — tur sonucu, sırayla düello, seviye belirleme, tur özeti
/// — puanı, sayımları, ödülü ve sonraki eylemi her biri kendi sırasıyla ve
/// kendi aralıklarıyla diziyordu: tur sonucunda ödül sayımların ÜSTÜNDEYDI,
/// düelloda sayım yoktu, her birinin alt perdesi ayrı yazılmıştı (iki farklı
/// "Kapat/Yeni düello" ve "Paylaş/Tekrar oyna" düzeni). Sıfır ödüllü ya da
/// sıfır doğrulu düello "+0 XP" çipi basıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Her ekranın kendi testi kendi düzenini sabitliyordu; "bütün bitiş
/// ekranları aynı şablonda mı" sorusunu hiçbir test sormuyordu — yeni bir
/// sonuç ekranı kendi iskeletini yazsa hepsi yeşil kalırdı. Bu dosya
/// şablonun kurallarını (sıra, sıfır gizleme, gece renkleri) ve hangi
/// dosyaların şablonu kullandığını ölçer.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpTemplate(
    WidgetTester tester, {
    List<SahneResultStat> stats = const [],
    int coins = 0,
    int xp = 0,
    ThemeMode mode = ThemeMode.dark,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        themeProvider: ThemeProvider(initialMode: mode),
        child: SahneResultScaffold(
          hero: const SahneResultHero(
            emblem: SizedBox(height: 44),
            title: 'Bitti',
            value: 7,
          ),
          stats: SahneResultStats.hasVisible(stats)
              ? SahneResultStats(stats: stats)
              : null,
          rewards: SahneResultRewards.hasAny(coins: coins, xp: xp)
              ? SahneResultRewards(coins: coins, xp: xp)
              : null,
          sections: const [Text('bölüm')],
          primary: SahneResultAction(label: 'Tamam', onPressed: () {}),
          secondary: SahneResultAction(label: 'Kapat', onPressed: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
  }

  SahneResultStat stat(String label, int value, {bool showZero = false}) =>
      SahneResultStat(
        leading: const SizedBox(),
        value: value,
        label: label,
        showWhenZero: showZero,
      );

  testWidgets('sıra: kahraman, sayımlar, ödül, bölüm', (tester) async {
    await pumpTemplate(
      tester,
      stats: [stat('Doğru', 2, showZero: true)],
      coins: 30,
    );
    final hero = tester.getTopLeft(find.text('Bitti')).dy;
    final stats = tester.getTopLeft(find.text('Doğru')).dy;
    final reward = tester.getTopLeft(find.text('+30')).dy;
    final section = tester.getTopLeft(find.text('bölüm')).dy;
    expect(hero, lessThan(stats));
    expect(stats, lessThan(reward), reason: 'ödül sayımların ALTINDA');
    expect(reward, lessThan(section));
  });

  testWidgets('sıfır karo ve sıfır ödül çizilmez', (tester) async {
    await pumpTemplate(
      tester,
      stats: [
        stat('Doğru', 3, showZero: true),
        stat('Yanlış', 0, showZero: true),
        stat('Boş', 0),
        stat('Seri', 0),
      ],
    );
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Yanlış'), findsOneWidget, reason: 'omurga çifti kalır');
    expect(find.text('Boş'), findsNothing);
    expect(find.text('Seri'), findsNothing);
    expect(find.byType(SahneResultRewards), findsNothing);
    expect(find.textContaining('+0'), findsNothing);
  });

  testWidgets('hiç görünür karo yoksa sayım şeridi için yer ayrılmaz', (
    tester,
  ) async {
    await pumpTemplate(tester, stats: [stat('Boş', 0), stat('Seri', 0)]);
    expect(SahneResultStats.hasVisible([stat('Boş', 0)]), isFalse);
    expect(find.byType(SahneResultStats), findsNothing);
  });

  testWidgets('alt perde: solda ikincil, sağda tek birincil', (tester) async {
    await pumpTemplate(tester);
    final secondary = tester.getCenter(find.text('Kapat')).dx;
    final primary = tester.getCenter(find.text('Tamam')).dx;
    expect(secondary, lessThan(primary));
  });

  group('sırayla düello sonucu', () {
    AsyncDuelSummary summary({
      required int mine,
      required int theirs,
      required AsyncDuelOutcome outcome,
    }) => AsyncDuelSummary(
      duelId: 'd1',
      status: AsyncDuelStatus.completed,
      role: AsyncDuelRole.creator,
      opponentName: 'Rojda',
      myCorrect: mine,
      opponentCorrect: theirs,
      outcome: outcome,
      createdAt: DateTime.utc(2026, 9, 28),
      seen: true,
    );

    Future<void> pumpDuel(
      WidgetTester tester,
      AsyncDuelSummary s, {
      ThemeMode mode = ThemeMode.light,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          themeProvider: ThemeProvider(initialMode: mode),
          child: AsyncDuelResultScreen(
            repository: MockZanKurdRepository(),
            view: AsyncDuelResultView.fromSummary(s),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('sıfır doğrulu kayıp düello "+0 XP" basmaz', (tester) async {
      await pumpDuel(
        tester,
        summary(mine: 0, theirs: 5, outcome: AsyncDuelOutcome.loss),
      );
      expect(find.textContaining('XP'), findsNothing);
      expect(find.byType(SahneResultRewards), findsNothing);
    });

    testWidgets('kazanç XP çipi gösterir', (tester) async {
      await pumpDuel(
        tester,
        summary(mine: 5, theirs: 3, outcome: AsyncDuelOutcome.win),
      );
      expect(find.text('+130 XP'), findsOneWidget);
    });

    // Kahraman gece sahnesinin içindedir; başlık rengi çağıranın (gündüz
    // olabilen) bağlamından değil sahnenin belirteçlerinden çözülür.
    // Eskiden zafer başlığı gündüz temasında koyu altın (`goldTx` gündüz)
    // çizilip ışınların üstünde okunmuyordu.
    testWidgets('zafer başlığı gündüz temasında da gece altınıdır', (
      tester,
    ) async {
      await pumpDuel(
        tester,
        summary(mine: 5, theirs: 3, outcome: AsyncDuelOutcome.win),
        mode: ThemeMode.light,
      );
      final title = tester.widget<Text>(find.text('Kazandın!'));
      expect(title.style?.color, SahneTokens.night.goldTx);
    });
  });

  test('bütün bitiş ekranları ortak şablonu kullanır', () {
    for (final path in [
      'lib/src/screens/quiz_result_screen.dart',
      'lib/src/screens/async_duel/async_duel_result_screen.dart',
      'lib/src/screens/level_placement_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('SahneResultScaffold('),
        reason: '$path kendi sonuç iskeletini yazmamalı',
      );
      expect(
        source,
        isNot(contains('class _ResultDock')),
        reason: '$path kendi alt perdesini yazmamalı',
      );
    }
    final review = File(
      'lib/src/screens/review_screen.dart',
    ).readAsStringSync();
    expect(review, contains('SahneResultStats('));
    expect(review, isNot(contains('class _SummaryTile')));
  });
}
