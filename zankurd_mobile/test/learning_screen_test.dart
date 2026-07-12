import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/screen_identity_header.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  testWidgets('kimlik bandı playGreen ScreenIdentityHeader olur', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<ScreenIdentityHeader>(
      find.byType(ScreenIdentityHeader),
    );
    expect(header.accent, AppTheme.playGreen);
    expect(find.text('Öğren'), findsOneWidget);
  });

  testWidgets('seçili sekme düz playGreen dolgu taşır', (tester) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final tab = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('learning-tab-everyday')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = tab.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.playGreen);
    expect(decoration.gradient, isNull);
  });

  testWidgets('dersler mock repodan listelenir', (tester) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alfabê'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('learning-path-node-lesson_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('learning-path-node-lesson_2')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('learning-mastery-goal')), findsOneWidget);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('seviye kaydı varsa önerilen başlangıç rozeti gösterilir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.placement.v1.level': 'pesketi',
    });
    PlacementStore.resetInstance();
    addTearDown(PlacementStore.resetInstance);

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    // Önerilen düğüm işaretlenir (kilit/tamamlanma değişmeden).
    expect(
      find.byKey(const ValueKey('lesson-recommended-badge')),
      findsOneWidget,
    );
  });

  testWidgets('seviye kaydı yoksa önerilen rozet ilk düğümde olur', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
    addTearDown(PlacementStore.resetInstance);

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();
    // Destpêk/kayıt yok → ilk düğüm önerilir; rozet yine tek olur.
    expect(
      find.byKey(const ValueKey('lesson-recommended-badge')),
      findsOneWidget,
    );
  });
}
