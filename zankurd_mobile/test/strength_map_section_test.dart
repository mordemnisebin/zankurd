import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/strength_map_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MistakeStore.resetInstance();
    MasteryStore.resetInstance();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.dark()
            : AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: StrengthMapSection(isKu: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('az veride kesin yargı üretmez, nazik mesaj gösterir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester);
    expect(find.byKey(const ValueKey('strength-map-section')), findsOneWidget);
    expect(find.textContaining('az veri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yüksek mastery güçlü, yoğun hata geliştirilecek olarak çıkar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.mastery.Ziman': 120,
      'zankurd.mistakeQuestionIds': ['m1', 'm2', 'm3', 'm4'],
      'zankurd.mistakeMetadata':
          '{"m1":{"category":"Dîrok"},"m2":{"category":"Dîrok"},'
          '"m3":{"category":"Dîrok"},"m4":{"category":"Dîrok"}}',
    });
    await pump(tester);
    expect(find.text('Güçlü'), findsOneWidget);
    expect(find.text('Geliştirilecek'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget); // Ziman güçlü
    expect(find.text('Tarih'), findsOneWidget); // Dîrok geliştirilecek
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet ve açık temada overflow oluşmaz', (tester) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.mastery.Ziman': 40,
      'zankurd.mistakeQuestionIds': ['m1', 'm2', 'm3'],
      'zankurd.mistakeMetadata':
          '{"m1":{"category":"Muzîk"},"m2":{"category":"Muzîk"},'
          '"m3":{"category":"Çand"}}',
    });
    await pump(
      tester,
      size: const Size(800, 1200),
      brightness: Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });
}
