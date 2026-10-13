// 2026-10-02 uçtan uca QA: "Oda kur" sayfası kapatılamıyordu.
//
// ## Kusur
//
// Sayfanın içeriği (kategori, soru sayısı, süre, giriş ücreti) ekrandan
// uzun; kaydırma alanı sayfanın tüm yüksekliğini dolduruyordu. Sonuç: perde
// (barrier) açıkta kalmıyor, aşağı çekme kaydırma alanına gidiyor, tutamaç ya
// da kapat düğmesi yok. Aynı ekrandaki "Odaya katıl" sayfası kısa olduğu için
// perdeye dokunuşla kapanıyordu.
//
// ## Niçin sessiz kalıyordu
//
// Testler sayfayı hep SEÇİM yapıp "Odayı aç" diyerek kapatıyordu; kapatmadan
// çıkışı (perde, çekme, düğme) kimse denemiyordu. Test yüzeyi 800x600 iken
// de sayfa zaten ekranı doldurduğundan kusur testte "normal" görünürdü.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

import 'support/widget_test_helpers.dart';

Future<void> _openSheet(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(child: PlayHubScreen(repository: MockZanKurdRepository())),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('play-hub-create-room')),
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('custom-room-open')), findsOneWidget);
}

void main() {
  testWidgets('oda kur sayfası kapat düğmesiyle kapanır', (tester) async {
    await _openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('custom-room-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-room-open')), findsNothing);
  });

  testWidgets(
    'oda kur sayfasında üstte perde açıkta kalır ve dokunuşla kapanır',
    (tester) async {
      await _openSheet(tester);
      final handleTop = tester
          .getTopLeft(find.byKey(const ValueKey('custom-room-handle')))
          .dy;
      expect(
        handleTop,
        greaterThan(40),
        reason: 'sayfa ekranı doldurmamalı; üstte perde açıkta olmalı',
      );
      await tester.tapAt(const Offset(195, 12));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('custom-room-open')), findsNothing);
    },
  );

  testWidgets('oda kur sayfası tutamaçtan aşağı çekilince kapanır', (
    tester,
  ) async {
    await _openSheet(tester);
    await tester.fling(
      find.byKey(const ValueKey('custom-room-handle')),
      const Offset(0, 500),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-room-open')), findsNothing);
  });
}
