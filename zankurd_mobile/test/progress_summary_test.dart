import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/progress_summary.dart';

/// İlerleme özetinin kullanıcıya verdiği sözleşmeler.
///
/// Özet, yanlış kesinlik vermemekle yükümlüdür: model bir sonraki eşiği
/// bilmiyorsa yüzde uydurmaz, ve aynı bilgiyi ekranda iki kez göstermez.
Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('XP oranı sayıyla da yazılır', (tester) async {
    // Renkli çubuk tek başına ölçü vermez.
    await tester.pumpWidget(
      _wrap(
        const ProgressSummary(
          level: 4,
          xpInLevel: 120,
          xpNeeded: 400,
          levelLabel: 'Seviye',
        ),
      ),
    );
    expect(find.text('120/400'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('hedef bilinmiyorsa oran uydurulmaz', (tester) async {
    // `xpNeeded == 0` bölme hatası ya da "12/0" gibi anlamsız bir oran
    // üretmemeli; yalnız kazanılan XP yazılır.
    await tester.pumpWidget(
      _wrap(
        const ProgressSummary(
          level: 1,
          xpInLevel: 12,
          xpNeeded: 0,
          levelLabel: 'Seviye',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('12/0'), findsNothing);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.0);
  });

  testWidgets('XP hedefi aşsa bile oran 1.0 ile sınırlanır', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ProgressSummary(
          level: 9,
          xpInLevel: 900,
          xpNeeded: 400,
          levelLabel: 'Seviye',
        ),
      ),
    );
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 1.0);
  });

  testWidgets('büyük sayılar ve 200% yazı taşmaz', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(320, 568) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProgressSummary(
                level: 128,
                xpInLevel: 987654,
                xpNeeded: 1000000,
                levelLabel: 'Asta te ya niha',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  // ── Gerçek ürüne bağlılık ────────────────────────────────────────────
  test('ana sayfa özeti gerçek XPStore verisinden besler', () {
    final home = File('lib/src/screens/home_screen.dart').readAsStringSync();
    expect(home, contains('ProgressSummary('));
    expect(home, contains('XPStore.load()'));
    expect(home, contains('store.currentLevel'));
    expect(home, contains('store.xpNeededForNextLevel'));
  });

  test('coin ana sayfada iki kez gösterilmez', () {
    // Başlıkta kalıcı bir coin rozeti var; özet coin çizmemeli.
    final summary = File(
      'lib/src/widgets/progress_summary.dart',
    ).readAsStringSync();
    expect(
      summary,
      isNot(contains('RewardKind.coin')),
      reason: 'coin başlıkta duruyor; özette tekrar edilmemeli',
    );
  });

  test('ilerleme özeti ana eylemin ALTINDA durur', () {
    // Turuncu "Başla" ekranın ilk ve en güçlü eylemi kalmalı.
    final home = File('lib/src/screens/home_screen.dart').readAsStringSync();
    expect(
      home.indexOf('TodayTaskCard('),
      lessThan(home.indexOf('ProgressSummary(')),
      reason: 'özet CTA’nın üstüne çıkarsa ana eylem aşağı itilir',
    );
  });
}
