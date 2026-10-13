import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';

import 'support/widget_test_helpers.dart';

/// 2026-09-03 simülatör: quiz/ayarlar geri tuşu VoiceOver'da «Back»
/// diyordu. Etiket dile bağlı olmalı.
void main() {
  testWidgets('ayarlar geri tuşu Türkçede Geri der', (tester) async {
    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final back = find.byTooltip('Geri');
    expect(back, findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('ayarlar geri tuşu Kurmancîde Vegere der', (tester) async {
    await tester.pumpWidget(
      testShell(
        languageProvider: kurmanciLang(),
        child: SettingsScreen(repository: MockZanKurdRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Vegere'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });
}
