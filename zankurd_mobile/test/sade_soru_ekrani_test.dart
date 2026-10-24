// 2026-10-19 SADELEŞME: soru ekranının yeni üst satırı ve joker dizisi.
//
// ## Kusur
//
// Test edenler uygulamanın genel tasarımını "çok kalabalık, gözü yoruyor,
// hoş değil" buldu (iki bağımsız dış inceleme de aynısını söyledi). Soru
// ekranında kalabalığın kaynağı: arkada parlayan ışık huzmesi, 60 px'lik
// elmas sayaç, 5'li elmas dizisi, gövdede ayrı künye + kaydet/bildir satırı
// ve jokerlerin üstündeki iki satırlık açıklama cümlesiydi.
//
// ## Niçin sessiz kalırdı
//
// Eksik ya da geri gelen bir öğe derleme hatası vermez; yalnız ekran yine
// kalabalık olur. Bu dosya yeni sözleşmeyi sabitler: TEK üst satır (kapat |
// "Kategori · n/N" | saniye + ⋯), 4 px ilerleme çubuğu, huzme ve elmas yok,
// Kaydet ve Bildir ⋯ menüsünde, joker dizisinde açıklama cümlesi yok ve
// jetonu yetmeyen joker soluk (kilit simgesiz) ama dokunulabilir (dokununca nedenini
// söyler). 320 px ve 2.0 yazı ölçeğinde taşma yok.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/free_wildcard_store.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1.0,
    bool timer = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: testShell(
          child: QuizScreen(
            repository: repo,
            room: repo.createRoom(),
            questions: repo.questions.take(2).toList(),
            enableTimer: timer,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('tek üst satır: kapat, künye, saniye, ⋯; huzme ve elmas yok', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byKey(const ValueKey('quiz-close')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-stage-kicker')), findsOneWidget);
    expect(find.textContaining('Soru 1/2 · '), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-circular-timer')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-timer-seconds')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-more-menu')), findsOneWidget);

    // Kalkanlar: huzme, elmas sayaç, elmas dizisi.
    expect(find.byKey(const ValueKey('sahne-stage-beam')), findsNothing);
    expect(find.byType(SahneTimerDiamond), findsNothing);
    expect(find.byType(SahneDiamondRow), findsNothing);

    // Eski gövde araç satırı yok: kaydet/bildir yalnız menüde.
    expect(find.byTooltip('Bildir'), findsNothing);
    expect(find.byTooltip('Kaydet'), findsNothing);

    final bar = tester.widget<SahneProgressBar>(
      find.byKey(const ValueKey('quiz-progress-bar')),
    );
    expect(bar.height, 4);
  });

  testWidgets('⋯ menüsü Kaydet ve Bildir satırlarını taşır', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('quiz-more-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quiz-menu-favorite')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-menu-report')), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget);
    expect(find.text('Bildir'), findsOneWidget);
  });

  testWidgets('soru metni 26/32 ve şıklar 12 yarıçaplı', (tester) async {
    await pump(tester);
    final question = tester.widget<Text>(
      find
          .descendant(
            of: find.byKey(const ValueKey('quiz-answer-content')),
            matching: find.byType(Text),
          )
          .first,
    );
    // Test yazı tipinde (kare harfler) uzun soru satır bütçesini aşıp Manşet
    // 22'ye inebilir; gerçek yazıda 26 (bkz. `QuizQuestionPrompt.styleFor`).
    expect(
      question.style?.fontSize,
      anyOf(SahneType.question.fontSize, SahneType.headline.fontSize),
    );
    expect(SahneType.question.fontSize, 26);
    expect(SahneType.question.height, 32 / 26);
    expect(SahneShape.m.borderRadius, BorderRadius.circular(12));
    expect(SahneShape.l.borderRadius, BorderRadius.circular(16));
  });

  testWidgets(
    'joker dizisinde açıklama cümlesi yok; kilitli joker dokunulabilir '
    've nedenini söyler',
    (tester) async {
      final semantics = tester.ensureSemantics();
      // Bugünkü bedava joker hakkı harcanmış: kilitli durumu bu koşulda
      // sınanır (hak varken satır açıktır, bkz. `free_wildcard_quiz_test`).
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
        'zankurd.navTour.seen': true,
        'zankurd.missions.freeWildcardDay': FreeWildcardStore.dayKey(
          DateTime.now(),
        ),
      });
      await pump(tester, timer: false);

      // Açıklama cümlesi ekranda yazılmaz (ekran okuyucuda durur).
      expect(
        find.text('Yarışı bitir, jeton kazan, jokerleri aç'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('quiz-wildcard-row')), findsOneWidget);

      // Başlangıç bakiyesi 0: hiçbir jokere yetmez; kurul 4. tur 2026-10-20:
      // dört ölü kilitli çip yerine TEK sönük satır (kilit + bakiye).
      expect(find.byType(SahneJokerButton), findsNothing);
      expect(find.byIcon(AppIcons.lock), findsWidgets);

      // Satıra dokununca neden söylenir (ölü düğme yok).
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('quiz-wildcard-row')),
          matching: find.byIcon(AppIcons.lock),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('quiz-wildcard-locked-note')),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

  for (final size in [const Size(320, 640), const Size(390, 844)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('üst satır ve joker dizisi taşmaz '
          '(${size.width.toInt()} px, x$scale)', (tester) async {
        await pump(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        // Kapat ve ⋯ en az 48.
        for (final key in ['quiz-close', 'quiz-more-menu']) {
          final box = tester.getSize(find.byKey(ValueKey(key)));
          expect(box.width, greaterThanOrEqualTo(48), reason: key);
          expect(box.height, greaterThanOrEqualTo(48), reason: key);
        }
      });
    }
  }
}
