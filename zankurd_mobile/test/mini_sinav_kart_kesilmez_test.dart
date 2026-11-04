/// Ders mini sınavında cevaptan sonra soru kartı üst çubuğun altında
/// yarım kalmamalı.
///
/// ## Kusur
///
/// Simülatör turu 5 (2026-11-04, 390x844): Elîfbê mini sınavında ilk soru
/// cevaplanınca kayan gövde, doğru şıkkı/açıklamayı görünür alana alırken soru
/// kartını yukarı itti; kartın ilk satırı başlığın altında kesik kaldı.
///
/// ## Niçin sessiz kaldı
///
/// Cevap sonrası kaydırma test koşucusunda kapalıdır; açan testler yalnız
/// fotoğrafın payını ölçüyordu, düz metinli sorunun kartının görünürlüğünü
/// değil.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

const _soru = QuizQuestion(
  id: 'mini-sinav-kart',
  category: 'Ziman',
  prompt:
      'Kîjan tîp di alfabeya Kurmancî ya Hawarê de tune ye û ji bo çi nayê bikaranîn?',
  answers: ['ş', 'q', 'ğ', 'x'],
  correctAnswer: 'ğ',
  explanation:
      'Alfabeya Hawarê 31 tîp e û «ğ» tê de tune ye; ew di alfabeyên din de '
      'tê bikaranîn. Ji bo bîranînê: Kurmancî ji «ğ» ne, ji «q» û «x» e.',
);

void main() {
  setUpAll(loadAppFonts);

  for (final (ad, boyut) in [
    ('375x667', const Size(375, 667)),
    ('390x844', const Size(390, 844)),
  ]) {
    testWidgets('$ad: cevaptan sonra soru kartının üstü görünür', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(boyut);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      revealCorrectAnswerInTests = true;
      addTearDown(() => revealCorrectAnswerInTests = false);

      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: MediaQuery(
            data: MediaQueryData(
              size: boyut,
              padding: kPhoneInsets,
              viewPadding: kPhoneInsets,
            ),
            child: QuizScreen(
              repository: repository,
              room: repository.createRoom(),
              questions: const [_soru],
              enableTimer: false,
              practice: true,
              experience: QuizExperience.learning,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(QuizOptionTile, 'ğ'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      final kaydirma = tester.getRect(
        find.byKey(const ValueKey('quiz-portrait-scroll')),
      );
      final metin = tester.getRect(find.textContaining('Kîjan tîp'));
      expect(
        metin.top,
        greaterThanOrEqualTo(kaydirma.top),
        reason: 'Soru metninin ilk satırı kayan alanın üstünde kesik kaldı.',
      );
    });
  }
}
