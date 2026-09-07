import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';

import 'support/widget_test_helpers.dart';

/// Profil analiz panelindeki kategori çubukları 700 ms easeOutCubic
/// dolumla büyüyordu ve "hareketi azalt" tercihini hiç okumuyordu.
///
/// Çubuk boyu süsüdür, veri taşımaz: tercih açıkken çubuklar ilk karede
/// tam boyda durmalı. Aksi hâlde ayar, profilin analiz yüzeyinde yok
/// sayılmış olur.
Finder _categoryBars() {
  return find.byWidgetPredicate(
    (widget) => widget is LinearProgressIndicator && widget.minHeight == 16,
  );
}

Future<void> _openAnalytics(
  WidgetTester tester, {
  required bool reducedMotion,
}) async {
  MasteryStore.resetInstance();
  MistakeStore.resetInstance();
  SharedPreferences.setMockInitialValues({
    'zankurd.mastery.Ziman': 8,
    'zankurd.mastery.Dîrok': 3,
  });
  await MistakeStore.load();
  await MasteryStore.load();

  await tester.pumpWidget(
    testShell(
      reducedMotion: reducedMotion,
      child: Scaffold(body: ProfileScreen(repository: MockZanKurdRepository())),
    ),
  );
  for (
    var i = 0;
    i < 40 && find.text('Detaylı İstatistik').evaluate().isEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 50));
  }

  final detailed = find.text('Detaylı İstatistik');
  await tester.ensureVisible(detailed);
  await tester.pumpAndSettle();
  await tester.tap(detailed);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hareketi azalt açıkken kategori çubukları büyümez', (
    tester,
  ) async {
    await _openAnalytics(tester, reducedMotion: true);

    expect(find.text('Kategorilere göre performans'), findsOneWidget);
    expect(_categoryBars(), findsNWidgets(2));
    expect(
      find.ancestor(
        of: _categoryBars(),
        matching: find.byType(TweenAnimationBuilder<double>),
      ),
      findsNothing,
    );
    final bar = tester.widget<LinearProgressIndicator>(_categoryBars().first);
    expect(bar.value, closeTo(1.0, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tercih kapalıyken kategori çubukları büyür', (tester) async {
    await _openAnalytics(tester, reducedMotion: false);

    expect(find.text('Kategorilere göre performans'), findsOneWidget);
    expect(
      find.ancestor(
        of: _categoryBars(),
        matching: find.byType(TweenAnimationBuilder<double>),
      ),
      findsWidgets,
    );
  });
}
