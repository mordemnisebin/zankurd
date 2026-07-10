import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/categories_tab.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
  });

  testWidgets('header brandOrange aksan çizgisi taşır', (tester) async {
    await tester.pumpWidget(
      wrap(CategoriesTab(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final accent = tester.widget<Container>(
      find.byKey(const ValueKey('categories-header-accent')),
    );
    final decoration = accent.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.brandOrange);
    expect(decoration.gradient, isNull);
    expect(find.text('Kategoriler'), findsOneWidget);
  });

  testWidgets('mastery rozeti seed edilen kategoride görünür', (tester) async {
    SharedPreferences.setMockInitialValues({'zankurd.mastery.Ziman': 25});
    MasteryStore.resetInstance();

    await tester.pumpWidget(
      wrap(CategoriesTab(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mastery-badge-Ziman')), findsOneWidget);
  });

  testWidgets('kart dokunuşu SubcategoryScreen açar', (tester) async {
    await tester.pumpWidget(
      wrap(CategoriesTab(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('category-card-Ziman')));
    await tester.pumpAndSettle();

    expect(find.byType(SubcategoryScreen), findsOneWidget);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(CategoriesTab(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
