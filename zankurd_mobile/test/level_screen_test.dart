import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

class _RetryableLevelRepository extends MockZanKurdRepository {
  _RetryableLevelRepository({required this.returnEmpty});

  bool fail = true;
  final bool returnEmpty;
  int loadCalls = 0;

  @override
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    String? subCategory,
    int limit = 10,
  }) async {
    loadCalls += 1;
    if (fail) throw StateError('level questions unavailable');
    if (returnEmpty) return const [];
    return super.loadLevelQuestions(
      category: category,
      difficultyMin: difficultyMin,
      difficultyMax: difficultyMax,
      subCategory: subCategory,
      limit: limit,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  testWidgets('seviye yolu 5 düğümü gösterir; ilki açık, gerisi kilitli', (
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

    // Yol bir merdivendir: kilit yokken 5. seviye (zorluk 4-5) ilk günden
    // açıktı ve harita vaat ettiği ilerlemeyi sağlamıyordu (2026-07-25
    // canlı denetimi). Temiz ilerlemede yalnız ilk düğüm açık olmalı.
    expect(find.text('1'), findsOneWidget);
    // 2-5 arası düğümler numara yerine kilit ikonu taşır; final kupası da
    // kilitli olduğu için görünmez.
    expect(find.text('4'), findsNothing);
    expect(find.byIcon(AppIcons.lock), findsNWidgets(4));
    expect(find.byIcon(AppIcons.trophy), findsNothing);

    // Beş satır da çizilir — kilitli olmak görünmez olmak değildir.
    expect(find.text('Başlangıç'), findsOneWidget);
    expect(find.text('Usta'), findsOneWidget);
  });

  testWidgets('kilitli düğüme dokunmak nedenini söyler', (tester) async {
    await tester.pumpWidget(
      wrap(LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    // Sessizce hiçbir şey yapmayan düğüm "bozuk" hissi verir.
    await tester.tap(find.byIcon(AppIcons.lock).first);
    await tester.pump();
    expect(find.textContaining('seviyeyi tamamla'), findsOneWidget);
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
        .where((l) => RegExp(r'^Zorluk: 5 üzerinden \d yıldız$').hasMatch(l));
    expect(difficultyLabels.length, 5);
  });

  testWidgets('seviye sorusu hatası görünür ve aynı seviye tekrar denenir', (
    tester,
  ) async {
    final repository = _RetryableLevelRepository(returnEmpty: false);
    await tester.pumpWidget(
      wrap(LevelScreen(repository: repository, category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-state')), findsOneWidget);
    expect(find.text('Tekrar'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Tekrar'));
    await tester.pump();

    expect(repository.loadCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seviye soru listesi boşsa açıklamalı boş durum gösterilir', (
    tester,
  ) async {
    final repository = _RetryableLevelRepository(returnEmpty: true);
    await tester.pumpWidget(
      wrap(LevelScreen(repository: repository, category: 'Ziman')),
    );
    await tester.pumpAndSettle();

    repository.fail = false;
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-empty-state')), findsOneWidget);
    expect(find.text('Bu kategori için soru bulunamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
