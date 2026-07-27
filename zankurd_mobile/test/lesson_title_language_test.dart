import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';

import 'support/widget_test_helpers.dart';

/// Ders adı arayüz dilini izlemeli.
///
/// 2026-07-27 karanlık tema taraması: Türkçe arayüzde ders listesi
/// "Silavkirin / Nasandin / Pratîkên Rojane" diye görünüyordu. Adın
/// Türkçesi modelde (`Lesson.titleTr`) var ve depo onu dolduruyor; kart
/// her zaman Kurmancî adı yazıyordu.
///
/// Ders **içeriği** Kurmancî'dir ve öyle kalmalı — çevrilen şey yalnız
/// dersin adıdır; kullanıcı listede ne öğreneceğini kendi dilinde okur.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.navTour.seen': true});
  });

  Future<void> pump(WidgetTester tester, {required bool ku}) async {
    await tester.pumpWidget(
      testShell(
        child: LearningScreen(repository: MockZanKurdRepository()),
        languageProvider: ku ? kurmanciLang() : null,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Türkçe arayüzde ders adı Türkçe', (tester) async {
    await pump(tester, ku: false);

    expect(find.text('Selamlaşma'), findsWidgets);
    expect(find.text('Silavkirin'), findsNothing);
  });

  testWidgets('Kurmancî arayüzde ders adı Kurmancî', (tester) async {
    // Karşı taraf: Türkçeye çevirirken Kurmancî adı kaybolmamalı.
    await pump(tester, ku: true);

    expect(find.text('Silavkirin'), findsWidgets);
  });
}
