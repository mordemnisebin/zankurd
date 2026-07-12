import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/services/placement_scoring.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child, {Size size = const Size(390, 844)}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
  });

  testWidgets('sınav soru göstergesi ve şıklarla açılır (baskısız)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LevelPlacementScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Soru 1/'), findsOneWidget);
    expect(find.text('Şimdilik geç'), findsOneWidget);
    // Baskı öğeleri yok: sayaç/skor/coin metni beklenmiyor.
    expect(find.textContaining('Coin'), findsNothing);
  });

  testWidgets('"Şimdilik geç" onFinished(null) ile geçer ve işaretler', (
    tester,
  ) async {
    PlacementLevel? finished;
    var called = false;
    await tester.pumpWidget(
      wrap(
        LevelPlacementScreen(
          repository: MockZanKurdRepository(),
          onFinished: (level) {
            called = true;
            finished = level;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('placement-skip')));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(finished, isNull);
    final store = await PlacementStore.load();
    expect(store.skipped, isTrue);
  });

  testWidgets('tüm sorular doğru cevaplanınca İleri sonucu ve kayıt', (
    tester,
  ) async {
    PlacementLevel? finished;
    await tester.pumpWidget(
      wrap(
        LevelPlacementScreen(
          repository: MockZanKurdRepository(),
          questionCount: 6,
          onFinished: (level) => finished = level,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Her soruda doğru cevap butonuna dokun.
    for (var i = 0; i < 6; i++) {
      final state = tester.state(find.byType(LevelPlacementScreen));
      // Doğru cevabı bul: mevcut sorunun correctAnswer'ına eşit metin.
      final questions = (state as dynamic);
      // ignore: avoid_dynamic_calls
      final QuizQuestion current = questions.currentQuestionForTest;
      await tester.tap(find.text(current.correctAnswer).last);
      await tester.pumpAndSettle();
    }

    expect(
      find.byKey(const ValueKey('placement-result-level')),
      findsOneWidget,
    );
    expect(finished, isNull); // henüz "Başla"ya basılmadı
    final store = await PlacementStore.load();
    expect(store.completed, isTrue);
    expect(store.level, PlacementLevel.pesketi);
  });

  testWidgets('360px dar ekranda overflow oluşmaz', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      wrap(LevelPlacementScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
