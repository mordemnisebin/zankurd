import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// Tur başlığı, turun gerçekten ne olduğunu söylemeli.
///
/// 2026-07-27 canlı gezinti: "Günün dersi" karışık kategorili bir turdur
/// ama odası varsayılan `Ziman` ile kurulur. Ekranın tepesinde "Ziman"
/// yazarken ilk soru "Çand" etiketiyle geliyordu — başlık, içeriği
/// yalanlıyordu.
void main() {
  late MockZanKurdRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
    repository = MockZanKurdRepository();
  });

  Future<void> pump(WidgetTester tester, {required String roomName}) async {
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom().copyWith(
            name: roomName,
            questionCount: 2,
          ),
          questions: repository.questions.take(2).toList(),
          experience: QuizExperience.learning,
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('adı olan tur başlıkta kendi adını gösterir', (tester) async {
    await pump(tester, roomName: 'Günün dersi');

    expect(find.text('Günün dersi'), findsOneWidget);
    expect(find.text('Dil'), findsNothing);
  });

  testWidgets('adsız turda kategoriye düşülür', (tester) async {
    // Karşı taraf: kategori başlığı tümüyle kaldırılmamalı. Adsız turda
    // başlık bir kategoriyi söylemeye devam eder.
    //
    // 2026-09-29 doğallık (K2): o kategori ODANIN değil ŞU ANKİ SORUNUN
    // kategorisidir. Oda "Ziman" (Dil) iken ilk soru Siyaset olunca başlık
    // "Dil", gövde künyesi "Siyaset · Soru 1/2" diyordu; bu bekçi eskiden
    // "Dil"i, yani tam o çelişkiyi sabitliyordu. Başlık ile künye artık
    // aynı adı taşır.
    await pump(tester, roomName: 'Hevalên Zanînê');

    final first = repository.questions.first;
    final name = CategoryNames.localized(first.category, false);
    expect(find.text(name), findsOneWidget);
    // Gövde künyesi aynı adı cümle düzeniyle taşır ("Siyaset · Soru 1/2").
    expect(find.textContaining('$name · Soru 1/'), findsOneWidget);
  });
}
