/// AX5 bekçisi: en büyük iOS yazı boyutunda tek kişilik soru oynanabilir kalır.
///
/// ## Kusur
///
/// iOS "Erişilebilirlik Ekstra Ekstra Ekstra Büyük" (≈ 3,1-3,3x) boyutunda
/// soru ekranı (2026-11-01 simülatör kanıtı, `02a_AX5_soru_cevap_yok.png`)
/// kullanılamazdı: sabit üst çubuk (künye dört satıra sarıyordu) ve sabit alt
/// perde (joker dizisi) 375x667 ekranın ~%80'ini yiyor, kaydırılan gövdeye
/// ~115 pt kalıyordu. Soru kartı tek başına bu pencereyi dolduruyor, şıklar
/// ve jokerler ya hiç görünmüyor ya da kaydırılsa bile aynı daracık pencerede
/// bir şık parçası görünüyordu.
///
/// ## Niçin sessiz kaldı
///
/// Yazı ölçeği testleri 1,0-2,0 arası ölçeklerde koşuyordu; 2x'te gövde 275 pt
/// kalıp yeterliydi. `QuizFit.choose` ise 1,35x üstünde kademeyi hiç
/// uygulamaz (nominal döner), yani AX5 için hiçbir önlem ve hiçbir bekçi yoktu.
/// Test ayrıca soruyu KISA yazıyordu; kusur ancak uzun bir Kurmancî soru +
/// sayaç + joker dizisiyle görünür.
///
/// ## Düzeltme
///
/// Sahne yazı ölçeğini `QuizFit.maxStageTextScale` (2,0) ile sınırlar. Normal
/// ölçekte hiçbir şey değişmez (kaydırmasız sığma bekçileri aynen geçerli).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

class _Rich extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 500;
}

const _q = QuizQuestion(
  id: 'ax5-q',
  category: 'Çand',
  prompt:
      'Di çanda Elewiyên herêma Dêrsimê de têgeha "Ziyaretgeh" behsa kîjan '
      'mekanên pîroz dike?',
  answers: ['Cihên pîroz', 'Çem', 'Kevir', 'Daristan'],
  correctAnswer: 'Cihên pîroz',
  explanation: 'x',
);

void main() {
  setUpAll(loadAppFonts);

  for (final scale in [2.0, 3.2]) {
    testWidgets('375x667 @$scale: dört şık ve joker dizisi kaydırarak '
        'ulaşılır, sayaç akar, kaydırma işareti görünür', (tester) async {
      const size = Size(375, 667);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      final repo = _Rich();
      await tester.pumpWidget(
        testShell(
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: kPhoneInsets,
              viewPadding: kPhoneInsets,
              textScaler: TextScaler.linear(scale),
            ),
            child: QuizScreen(
              repository: repo,
              room: repo.createRoom(),
              questions: const [_q],
              enableTimer: true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.byKey(const ValueKey('sahne-stage-scroll-hint')),
        findsOneWidget,
        reason: 'gövde kayıyorsa kaydırma işareti görünmeli',
      );
      final wildcard = find.byKey(const ValueKey('quiz-wildcard-row'));
      expect(wildcard, findsOneWidget);
      final screen = Offset.zero & size;
      expect(
        screen.contains(tester.getRect(wildcard).center),
        isTrue,
        reason: 'joker dizisi (sabit alt perde) ekranda',
      );

      final scroll = find.byKey(const ValueKey('quiz-portrait-scroll'));
      final viewport = tester.getRect(scroll);
      expect(viewport.height, greaterThan(200), reason: 'gövde penceresi dar');
      for (var i = 0; i < 4; i++) {
        final tile = find.byType(QuizOptionTile).at(i);
        await tester.ensureVisible(tile);
        await tester.pump(const Duration(milliseconds: 300));
        final r = tester.getRect(tile);
        expect(
          viewport.contains(r.center),
          isTrue,
          reason: 'şık $i kaydırınca gövde penceresinde ($r / $viewport)',
        );
        expect(
          tile.hitTestable(),
          findsOneWidget,
          reason: 'şık $i dokunulabilir',
        );
      }
      // Sayaç akıyor: saniye metni değişir.
      final timer = find.byKey(const ValueKey('quiz-circular-timer'));
      String texts() => find
          .descendant(of: timer, matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .join('|');
      final t0 = texts();
      await tester.pump(const Duration(seconds: 3));
      expect(texts(), isNot(t0), reason: 'sayaç ilerlemeli');
    });
  }
}
