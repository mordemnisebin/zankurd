import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// Serbest metinli soru tiplerinin (boşluk doldurma, kelime sıralama) GERÇEK
/// telefon geometrisinde quiz ekranına sığdığının bekçisi.
///
/// ## Niçin var
///
/// Ölçümlü soru düzeni (`quiz_screen_ui.dart` `availableHeight` yolu) dört
/// şıklı kartlara göre ayarlandı ve `quiz_screen_responsive_layout_test` de
/// şıklı sorularla koşar. Oysa bu iki tip ekrana çok farklı bir paket
/// koyar: metin girişi + üçlü diyakritik satırı + tam genişlikte gönder
/// düğmesi; ya da sarılan kelime çipleri. Bunların dikey bütçesi şık
/// kutularınınkiyle aynı değil.
///
/// ## Niçin sessiz kalırdı
///
/// Varsayılan test koşucusu 800×600, güvenli alanı SIFIR ve her harfi kare
/// olan ölçü fontudur (bkz. `realistic_device.dart` başlığı). Sıfır dolguyla
/// çentik örtüşmesi, ölçü fontuyla taşma/kırpma görünmez. Bu tiplerin kendi
/// widget testleri de yalnız widget'ı tek başına, sahte ortamda pompalar.
///
/// Bu bekçi üç şeyi bir araya getirir: `kPhoneSize` yüzeyi (402×874),
/// iPhone sınıfı dolgular (üst 59 / alt 34), gerçek Rubik fontu ve
/// bankaların **günümüzdeki en uzun** Kurmancî içerikleri — içerik uzadıkça
/// ölçü otomatik da sertleşer.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// En uzun Kurmancî istemli boşluk doldurma sorusu.
  QuizQuestion longestFillPrompt() {
    final rows =
        (jsonDecode(
                  File(
                    'assets/data/fill_in_blank_2026_08_questions.json',
                  ).readAsStringSync(),
                )
                as List)
            .cast<Map<String, dynamic>>();
    final questions = rows.map(QuizQuestion.fromJson).toList();
    questions.sort((a, b) => b.prompt.length.compareTo(a.prompt.length));
    return questions.first;
  }

  /// En çok kelimeli cümle kurma sorusu.
  QuizQuestion wordiestSentence() {
    final rows =
        (jsonDecode(
                  File(
                    'assets/data/sentence_building_questions.json',
                  ).readAsStringSync(),
                )
                as List)
            .cast<Map<String, dynamic>>();
    final questions = rows.map(QuizQuestion.fromJson).toList();
    int words(QuizQuestion q) =>
        q.correctAnswer.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    questions.sort((a, b) => words(b).compareTo(words(a)));
    return questions.first;
  }

  Future<void> pumpQuiz(
    WidgetTester tester,
    List<QuizQuestion> questions,
  ) async {
    await tester.binding.setSurfaceSize(kPhoneSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        languageProvider: kurmanciLang(),
        child: withDeviceInsets(
          QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: questions,
            enableTimer: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Denetim yüzeyin içinde ve dolgulara girmeden görünür olmalı.
  void expectOnScreen(WidgetTester tester, Finder finder, String what) {
    final rect = tester.getRect(finder);
    expect(
      rect.top,
      greaterThanOrEqualTo(kPhoneInsets.top),
      reason: '$what üst güvenli alana ($rect) giriyor.',
    );
    expect(
      rect.bottom,
      lessThanOrEqualTo(kPhoneSize.height - kPhoneInsets.bottom),
      reason: '$what alt güvenli alana ($rect) giriyor.',
    );
    expect(
      rect.left,
      greaterThanOrEqualTo(0),
      reason: '$what soldan taşıyor ($rect).',
    );
    expect(
      rect.right,
      lessThanOrEqualTo(kPhoneSize.width),
      reason: '$what sağdan taşıyor ($rect).',
    );
  }

  testWidgets(
    'en uzun boşluk doldurma sorusu gerçek telefona sığar ve çözülebilir',
    (tester) async {
      final fill = longestFillPrompt();
      await pumpQuiz(tester, [fill, fill]);

      final input = find.byKey(const ValueKey('fill-in-blank-input'));
      await tester.ensureVisible(input);
      await tester.pumpAndSettle();
      expectOnScreen(tester, input, 'Cevap girişi');

      // Türkçe klavyede bulunmayan üç sesliyi ekleyen satır görünürde ve
      // erişilebilirde olmalı: gizli kaldıysa doğru cevap yazılamaz.
      for (final letter in ['î', 'ê', 'û']) {
        final chip = find.byKey(ValueKey('fill-in-blank-diacritic-$letter'));
        await tester.ensureVisible(chip);
        expectOnScreen(tester, chip, 'Diyakritik düğmesi $letter');
      }

      final submit = find.byKey(const ValueKey('fill-in-blank-submit'));
      await tester.ensureVisible(submit);
      expectOnScreen(tester, submit, 'Kontrol bike düğmesi');

      // Doğru cevabı klavyeden yaz ve gönder.
      await tester.enterText(input, fill.correctAnswer);
      await tester.pump();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('fill-in-blank-result')),
        findsOneWidget,
        reason: 'Cevap gönderildi ama sonuç satırı çıkmadı.',
      );

      final next = find.byKey(const ValueKey('quiz-next-button'));
      await tester.ensureVisible(next);
      expectOnScreen(tester, next, 'Piştre düğmesi');
      await tester.tap(next);
      await tester.pumpAndSettle();

      // İkinci soruda yanlış cevap: sonuç satırı doğru cevabı göstermeli.
      final input2 = find.byKey(const ValueKey('fill-in-blank-input'));
      await tester.ensureVisible(input2);
      await tester.enterText(input2, ' bi yanş e ');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('fill-in-blank-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining(fill.correctAnswer), findsWidgets);

      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.byType(QuizResultScreen), findsOneWidget);
    },
  );

  testWidgets(
    'en çok kelimeli cümle kurma sorusu gerçek telefona sığar ve çözülebilir',
    (tester) async {
      final sentence = wordiestSentence();
      await pumpQuiz(tester, [sentence]);

      // Kelimeler doğru cümle sırasıyla seçilir; her çip ekranda görünür
      // ve dokunulabilir olmalı (taşan/hit-test edilemeyen çip = çözümsüz).
      for (final word in sentence.correctAnswer.split(RegExp(r'\s+'))) {
        final chip = find.text(word).first;
        await tester.ensureVisible(chip);
        expectOnScreen(tester, chip, 'Kelime çipi «$word»');
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }

      final submit = find.text('Kontrol bike');
      await tester.ensureVisible(submit);
      expectOnScreen(tester, submit, 'Kontrol bike düğmesi');
      await tester.tap(submit);
      await tester.pumpAndSettle();

      // Cevap birebir doğru cümle: yerel puanlama doğru saymalı.
      expect(find.textContaining(sentence.correctAnswer), findsWidgets);

      final next = find.byKey(const ValueKey('quiz-next-button'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.byType(QuizResultScreen), findsOneWidget);
    },
  );
}
