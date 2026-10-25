import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/profile/profile_week_strip.dart';

import 'support/widget_test_helpers.dart';

/// Profilin haftalık etkinlik şeridi (2026-10-25).
///
/// Kusur: yeni oyuncunun profili yalnız boş durumlardı; alışkanlık hiçbir
/// yerde görünmüyordu. Kural: son yedi gün, bugün en sağda; oynanan gün
/// sayılır, dondurulan gün oynanmış sayılmaz.
void main() {
  testWidgets('son yedi gün, oynanan günler sayılır', (tester) async {
    await tester.pumpWidget(
      testShell(
        languageProvider: turkishLang(),
        child: Scaffold(
          body: ProfileWeekStrip(
            clock: () => DateTime(2026, 10, 25, 9),
            loader: () async =>
                ({'2026-10-25', '2026-10-23', '2026-10-18'}, {'2026-10-24'}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Son 7 gün'), findsOneWidget);
    // 18 Ekim yedi günün dışında (19–25).
    expect(find.text('2/7'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('18'), findsNothing);
  });

  testWidgets('ay sınırında takvim günleri doğru', (tester) async {
    await tester.pumpWidget(
      testShell(
        languageProvider: turkishLang(),
        child: Scaffold(
          body: ProfileWeekStrip(
            clock: () => DateTime(2026, 11, 2),
            loader: () async => ({'2026-10-31'}, <String>{}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('27'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1/7'), findsOneWidget);
  });
}
