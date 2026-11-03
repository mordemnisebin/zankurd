/// Joker satırı alt güvenli alanı (ana ekran çubuğu) aşmaz.
///
/// ## Kusur (ikinci tur kurulu 2026-11-04, "jokerler alt kenara çok yakın")
///
/// Kurul, tek elle kullanımda joker düğmelerinin gezinme çubuğuyla
/// çakışacağından endişelendi. Kod incelemesi iddiayı çürüttü: alt perde
/// (`SahneBottomDock`) `SafeArea` içindedir ve üstüne ayrıca 12 pt boşluk
/// koyar. Bu dosya o durumu kilitler; perde ileride `SafeArea`sız bir
/// yuvaya taşınırsa ya da iç boşluk kalkarsa düşer.
///
/// ## Niçin sessiz kalırdı
///
/// Testler alt dolgusuz (`padding.bottom = 0`) ekranda koşar; çentikli
/// telefondaki 34 pt'lik ana ekran çubuğu hiçbir yerde ölçülmezdi.
///
/// ## Kural
///
/// 390x844 ve 34 pt alt dolguda joker satırının alt kenarı, ekranın alt
/// kenarından en az 34 + 8 pt yukarıdadır; 375x667'de (dolgusuz) en az
/// 8 pt. Ekran kaydırmasız kalır (bkz. `quiz_son_sik_perde_test`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final (size, bottom) in const [
    (Size(390, 844), 34.0),
    (Size(375, 667), 0.0),
  ]) {
    testWidgets(
      '${size.width.toInt()}x${size.height.toInt()} alt dolgu $bottom: '
      'joker satırı güvenli alanın üstünde',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(top: 47, bottom: bottom);
        tester.view.viewPadding = FakeViewPadding(top: 47, bottom: bottom);
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
            child: QuizScreen(
              repository: repository,
              room: repository.createRoom(),
              questions: [repository.questions.first],
              experience: QuizExperience.competition,
              enableTimer: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(const ValueKey('quiz-wildcard-row'));
        expect(row, findsOneWidget);
        final gap = size.height - tester.getRect(row).bottom;
        expect(
          gap,
          greaterThanOrEqualTo(bottom + 8),
          reason: 'joker satırı ana ekran çubuğuna ($bottom pt) girmemeli',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
