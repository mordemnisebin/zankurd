import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  testWidgets('kartlar açık yüzeyde tint border ile listelenir', (
    tester,
  ) async {
    final first = SubcategoryConfig.subcategories['Ziman']!.first;

    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardKey = ValueKey('subcategory-card-${first.id}');
    expect(find.byKey(cardKey), findsOneWidget);
    expect(find.text(first.nameTr), findsOneWidget);

    final card = tester.widget<Container>(
      find
          .descendant(of: find.byKey(cardKey), matching: find.byType(Container))
          .first,
    );
    final decoration = card.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.lightSurface);
    expect(decoration.gradient, isNull);
  });

  testWidgets('kart dokunuşu LevelScreen açar', (tester) async {
    final first = SubcategoryConfig.subcategories['Ziman']!.first;

    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('subcategory-card-${first.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(LevelScreen), findsOneWidget);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // 2026-07-23: M15 devamı — sinor_duma/amur/tevger/jineoloji artık
  // "Yazım & Sanat" grubunun pen ikonunu miras almıyor, kendi anlamına
  // uygun ikon alıyor. Bu test regresyonu (pen'e geri dönüşü) yakalar.
  Future<void> expectCardIcon(
    WidgetTester tester, {
    required String category,
    required String id,
    required IconData expectedIcon,
  }) async {
    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: category,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardKey = ValueKey('subcategory-card-$id');
    expect(find.byKey(cardKey), findsOneWidget);

    final icons = tester
        .widgetList<Icon>(
          find.descendant(of: find.byKey(cardKey), matching: find.byType(Icon)),
        )
        .map((w) => w.icon)
        .toSet();
    expect(icons, contains(expectedIcon));
    expect(icons, isNot(contains(AppIcons.pen)));
  }

  testWidgets('sinor_duma anlamına uygun konum ikonu alır', (tester) async {
    await expectCardIcon(
      tester,
      category: 'Cografya',
      id: 'sinor_duma',
      expectedIcon: AppIcons.locationDot,
    );
  });

  testWidgets('amur anlamına uygun müzik ikonu alır', (tester) async {
    await expectCardIcon(
      tester,
      category: 'Muzîk',
      id: 'amur',
      expectedIcon: AppIcons.music,
    );
  });

  testWidgets('tevger anlamına uygun bayrak ikonu alır', (tester) async {
    await expectCardIcon(
      tester,
      category: 'Siyaset',
      id: 'tevger',
      expectedIcon: AppIcons.flag,
    );
  });

  testWidgets('jineoloji anlamına uygun venus ikonu alır', (tester) async {
    await expectCardIcon(
      tester,
      category: 'Paradigma',
      id: 'jineoloji',
      expectedIcon: AppIcons.venus,
    );
  });
}
