// Yarış sekmesi üç seçime inince (canlı düello, sırayla düello, oda) oda
// eylemleri ve rakip seçimi birer alt sayfaya taşındı (2026-10-24). Bu
// yardımcılar testlerin o ekstra dokunuşu tek yerden yapmasını sağlar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _tapTile(WidgetTester tester, Finder tile) async {
  if (tile.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

/// "Oda" kartına dokunur; "Oda kur" / "Kodla katıl" satırları açılır.
Future<void> openRoomSheet(WidgetTester tester) =>
    _tapTile(tester, find.byKey(const ValueKey('play-hub-room')));

/// "Sırayla düello" kartına dokunur; rakip seçimi sayfası açılır.
Future<void> openAsyncOpponentSheet(WidgetTester tester) =>
    _tapTile(tester, find.byKey(const ValueKey('play-hub-async-duel')));

/// Canlı düello kahramanının düğmesine dokunur; rakip seçimi açılır.
Future<void> openLiveOpponentSheet(WidgetTester tester) =>
    _tapTile(tester, find.byKey(const ValueKey('play-hub-quick-duel-cta')));
