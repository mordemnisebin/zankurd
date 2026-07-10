import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/zana_daily_card.dart';

void main() {
  testWidgets('günün sözü kartı maskot ve iki dilli metinle çizilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Center(child: ZanaDailyCard(isKu: false, dayOverride: 0)),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('zana-daily-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('roj-mascot')), findsOneWidget);
    expect(find.text('Günün Sözü'), findsOneWidget);
    expect(find.text('Zanîn ronahî ye.'), findsOneWidget);
    expect(find.text('Bilgi ışıktır.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gün indeksi sözü deterministik döndürür', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: ZanaDailyCard(isKu: true, dayOverride: 11)),
      ),
    );
    // 11 % 10 = 1 → ikinci söz.
    expect(find.text('Dilop bi dilop gol çêdibe.'), findsOneWidget);
    expect(find.text('Gotina Rojê'), findsOneWidget);
  });
}
