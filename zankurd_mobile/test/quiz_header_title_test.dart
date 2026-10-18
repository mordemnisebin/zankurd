import 'package:flutter/material.dart';
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
///
/// 2026-10-19 SADELEŞME (bu dosya güncellendi): soru ekranının üst satırı
/// tek künyedir: "Kategori · Soru n/N". Tur adı ("Günün dersi", oda kodu) üst
/// satırdan kalktı; çünkü künye zaten SORUNUN kendi kategorisini söyler ve
/// satırda iki başlığa yer yok (kalabalık, gözü yoruyor). Korunan kural
/// aynı: başlık içeriği yalanlamaz — odanın varsayılan kategorisi ("Dil")
/// değil sorunun kategorisi yazılır. Eski "adı olan tur adını gösterir"
/// testi tam tersini bekliyordu: ad GÖSTERİLMEZ, künye gösterilir.
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

  testWidgets('adı olan turda üst satır turun adını değil sorunun künyesini '
      'gösterir', (tester) async {
    await pump(tester, roomName: 'Günün dersi');

    final first = repository.questions.first;
    final name = CategoryNames.localized(first.category, false);
    expect(find.text('Günün dersi'), findsNothing);
    expect(find.byKey(const ValueKey('quiz-stage-kicker')), findsOneWidget);
    expect(find.text('$name · Soru 1/2'), findsOneWidget);
    // Odanın varsayılan kategorisi künyeyi yalanlamaz.
    expect(find.text('Dil'), name == 'Dil' ? findsWidgets : findsNothing);
  });

  testWidgets('adsız turda da künye sorunun kategorisini söyler', (
    tester,
  ) async {
    // Karşı taraf: kategori başlığı tümüyle kaldırılmamalı.
    //
    // 2026-09-29 doğallık (K2): o kategori ODANIN değil ŞU ANKİ SORUNUN
    // kategorisidir. Oda "Ziman" (Dil) iken ilk soru Siyaset olunca başlık
    // "Dil", künye "Siyaset · Soru 1/2" diyordu; artık tek künye var.
    await pump(tester, roomName: 'Hevalên Zanînê');

    final first = repository.questions.first;
    final name = CategoryNames.localized(first.category, false);
    expect(find.textContaining('$name · Soru 1/'), findsOneWidget);
    expect(find.text(name), findsNothing, reason: 'künye tek parça metin');
  });
}
