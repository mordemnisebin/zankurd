import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sonuç ekranının katlanan "Ayrıntılar" bölümünü açar (2026-10-28 tur 3,
/// T14: "Nerelerde zorlandın?", "Konulara göre" ve yeni rozetler tek katlı
/// bölümde; U5 tur 4: cevap açıklamaları da burada). Bölüm yoksa ya da açıksa bir şey yapmaz.
Future<void> openResultDetails(WidgetTester tester) async {
  final header = find.descendant(
    of: find.byKey(const ValueKey('result-details-section')),
    matching: find.byKey(const ValueKey('result-collapsible-header')),
  );
  if (header.evaluate().isEmpty) {
    // Sonuç listesi tembeldir: bölüm henüz kurulmadıysa oraya kaydır.
    final section = find.byKey(const ValueKey('result-details-section'));
    if (find.byType(Scrollable).evaluate().isEmpty) return;
    try {
      await tester.scrollUntilVisible(
        section,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    } catch (_) {
      return;
    }
    if (header.evaluate().isEmpty) return;
  }
  if (find
      .byKey(const ValueKey('learning-outcome-card'))
      .evaluate()
      .isNotEmpty) {
    return;
  }
  await tester.ensureVisible(header);
  await tester.pump();
  await tester.tap(header, warnIfMissed: false);
  await tester.pumpAndSettle();
}
