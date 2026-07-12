import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home/daily_theme_card.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('günlük tema kartı dar genişlikte taşmadan çizilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: DailyThemeCard(isKu: true, dayOverride: DateTime.monday),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('günlük tema kartı bugünün kategorisini gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: DailyThemeCard(isKu: true, dayOverride: DateTime.wednesday),
        ),
      ),
    );

    expect(find.text('Dîrok'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
