import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

// Tur 7 (Opus + Grok): devre dışı birincil düğme yazısı ("Yarışı başlat",
// "Sonraki") silik kalıyordu. `tx3` AA'yı geçtiği için hiçbir test
// yakalamadı; hedef artık ≥ 5.5:1 (iki temada), yine etkin etiketten soluk.
double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('pasif birincil düğme etiketi ≥ 5.5:1, etkin etiketten soluk', () {
    for (final t in [SahneTokens.day, SahneTokens.night]) {
      final r = _ratio(t.disabledFg, t.disabledFill);
      expect(
        r,
        greaterThanOrEqualTo(5.5),
        reason: 'disabledFg ${t.disabledFg}',
      );
      expect(_ratio(t.tx, t.disabledFill), greaterThan(r));
    }
  });
}
