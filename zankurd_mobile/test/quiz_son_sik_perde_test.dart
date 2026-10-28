import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// Uzun soruda SON şık alt perdenin (joker satırı) arkasında kalmaz.
///
/// ## Kusur (2026-10-29 çevrimiçi gezinti, ekran 20 ve 54)
///
/// Uzun sorularda D şıkkı ilk bakışta alt perdenin altında yarım kalıyordu.
/// Soru gövdesinin kayan alanı ekranın dibine kadar uzanır (perde gövdeyi
/// örter, `extendBody`), ama kaydırma alanının alt boşluğu yalnız 24 px idi:
/// en sona kaydırınca bile son şık perdenin altında kalıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Testler kısa sorularla koşuyordu; kısa soru ekrana sığar, kaydırma
/// hiç gerekmez. Yalnız uzun soru + dolu joker perdesi bir araya gelince
/// görünür.
///
/// ## Kural
///
/// Kayan alan alt perdenin ÜSTÜNDE biter (alt boşluk perdeyi sayar): en sona
/// kaydırılan içeriğin son şıkkı perdenin üst kenarını aşmaz. İçerik taşıyorsa
/// ilk bakışta alt kenar söner ([sahneStageBottomFadeKey]): yarım kalan şık
/// "aşağıda devamı var" der; en sonda sönme kalkar.
///
/// NOT: kusurun ilk varsayımı ("kayan alan perdenin arkasına uzanıyor") test
/// ile çürütüldü; kayan alan perdenin üstünde bitiyordu. Asıl eksik, yarım
/// kalan şıkkın kaydırılabildiğini söyleyen hiçbir ipucunun olmamasıydı.
const _long = QuizQuestion(
  id: 'son-sik-1',
  category: 'Ziman',
  prompt:
      'Di rêzimana Kurmancî de peyva «navdêr» ji bo çi tê bikaranîn û di '
      'hevokê de çi erkî dike? Ev pirs bi qasî têra xwe dirêj e ku li ser '
      'ekranên biçûk bi tevahî nêzîkî perdeya jêrîn bibe û şikê dawîn veşêre.',
  answers: [
    'Ji bo navê kes, tişt an cihan tê bikaranîn',
    'Ji bo kirina karekî tê bikaranîn',
    'Ji bo diyarkirina rengê tiştan tê bikaranîn',
    'Ji bo girêdana du hevokan tê bikaranîn',
  ],
  correctAnswer: 'Ji bo navê kes, tişt an cihan tê bikaranîn',
  explanation: 'Navdêr navê kes, tişt an cihan e.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final size in const [Size(375, 667), Size(390, 844)]) {
    testWidgets(
      '2026-10-29 X8: ${size.width.toInt()}x${size.height.toInt()} en sona '
      'kaydırılınca son şık alt perdenin üstünde kalır',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({
          'zankurd.quiz_tutorial.seen': true,
          'zankurd.navTour.seen': true,
        });
        final repository = freshMockRepository();
        SharedPreferences.setMockInitialValues({
          'zankurd.quiz_tutorial.seen': true,
          'zankurd.navTour.seen': true,
        });
        await tester.pumpWidget(
          testShell(
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.8)),
                child: QuizScreen(
                  repository: repository,
                  room: repository.createRoom(),
                  questions: const [_long, _long],
                  experience: QuizExperience.competition,
                  enableTimer: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(const ValueKey('quiz-portrait-scroll')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(
          scrollable.position.maxScrollExtent,
          greaterThan(0),
          reason: 'kurulum: soru kaydırma gerektirmeli',
        );
        // İlk bakış: altta devam eden içerik var, alt kenar söner.
        expect(
          find.byKey(sahneStageBottomFadeKey),
          findsOneWidget,
          reason: 'taşan gövdenin alt kenarı sönmeli ("aşağıda devamı var")',
        );
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();
        expect(
          find.byKey(sahneStageBottomFadeKey),
          findsNothing,
          reason: 'en sonda sönme kalkar',
        );

        final last = find.text(_long.answers.last);
        final dock = find.byKey(const ValueKey('quiz-wildcard-row'));
        expect(last, findsOneWidget);
        expect(dock, findsOneWidget);
        expect(
          tester.getRect(last).bottom,
          lessThanOrEqualTo(tester.getRect(dock).top),
          reason: 'son şık alt perdenin arkasında kalmamalı',
        );
      },
    );
  }
}
