import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/screens/community_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('Civak lig kategorileri ve arkadaş görevini birleştirir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LanguageProvider()..setLang('tr'),
          ),
          ChangeNotifierProvider(create: (_) => ChildSafetyProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: CommunityScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ligler'), findsOneWidget);
    expect(find.byKey(const ValueKey('league-category-Ziman')), findsOneWidget);

    await tester.tap(find.text('Arkadaşlar').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('friend-quest-card')), findsOneWidget);
    expect(find.text('Birlikte 10 doğru cevap'), findsOneWidget);
  });
}
