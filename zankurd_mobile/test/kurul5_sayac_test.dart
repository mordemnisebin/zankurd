// Kurul 5. tur 2026-10-20 (Opus, Grok): soru sayacı küçük ve gri kalıyordu.
// Bekçi: normalde birincil metin rengi ve ≥ 20 px kalın; ≤ 5 sn kehribar;
// ≤ 3 sn kırmızı; duraklatılmışta (hotSeconds -1) gerilim rengi yok.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  Future<TextStyle> style(WidgetTester tester, int s, {int hot = 5}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [SahneTokens.night]),
        home: Scaffold(
          body: SahneStageTimer(
            secondsLeft: s,
            hotSeconds: hot,
            semanticLabel: '$s',
          ),
        ),
      ),
    );
    return tester
        .widget<Text>(find.byKey(const ValueKey('stage-timer-seconds')))
        .style!;
  }

  testWidgets('sayaç rengi: birincil → kehribar → kırmızı', (tester) async {
    const t = SahneTokens.night;
    final calm = await style(tester, 17);
    expect(calm.color, t.tx);
    expect(calm.fontSize, greaterThanOrEqualTo(20));
    expect(calm.fontWeight, FontWeight.w800);
    expect((await style(tester, 5)).color, t.shortfallTx);
    expect((await style(tester, 3)).color, t.errTx);
    expect((await style(tester, 3, hot: -1)).color, t.tx);
  });
}
