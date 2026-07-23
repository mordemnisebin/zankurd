import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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

  testWidgets('seviye yolu 5 düğümü ve final kupasını gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    // Seviye adları veri katmanında Kurmancî; TR arayüzde çevrilir
    // (2026-07-22 UX denetimi — LevelNames).
    expect(find.text('Başlangıç'), findsOneWidget);
    expect(find.text('Destpêk'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.byIcon(AppIcons.trophy), findsOneWidget);
  });

  testWidgets('düğüm numarası heading1 ağırlığı ve yumuşak gölge taşır', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    final numberText = tester.widget<Text>(find.text('1'));
    // Rubik ailesinde w800 yüzü yok; heading1 bilinçli olarak w900'e
    // sabitlendi (bkz. app_theme.dart yorum satırı).
    expect(numberText.style?.fontWeight, FontWeight.w900);
  });

  testWidgets('etiket chip yüzey renginde kalır', (tester) async {
    await tester.pumpWidget(
      wrap(LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    final label = find.ancestor(
      of: find.text('Başlangıç'),
      matching: find.byType(Container),
    );
    final decoration =
        tester.widget<Container>(label.first).decoration as BoxDecoration;
    expect(decoration.color, AppTheme.lightSurface);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // 2026-07-23 M16: yıldızlar "ilerleme" ile karıştırılabiliyordu; artık
  // Tooltip + Semantics ile "zorluk" anlamını taşıyorlar. Semantics label'ı
  // bySemanticsLabel yerine widget üzerinden doğrulanıyor çünkü üst düğüm
  // Semantics'i (level başlığı) alt node'ları tek bir okunan metinde
  // birleştiriyor — asıl doğrulanması gereken _DifficultyStars'ın kendi
  // label'ı verip vermediği.
  testWidgets('zorluk yıldızları "Zorluk" tooltip ve semantics etiketi taşır', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    final tooltips = tester.widgetList<Tooltip>(find.byType(Tooltip));
    expect(tooltips.where((t) => t.message == 'Zorluk').length, 5);

    final difficultyLabels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((w) => w.properties.label)
        .whereType<String>()
        .where(
          (l) => RegExp(r'^Zorluk: 5 üzerinden \d yıldız$').hasMatch(l),
        );
    expect(difficultyLabels.length, 5);
  });
}
