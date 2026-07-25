import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/question_language_policy.dart';

/// 2026-07-25 canlı denetimi.
///
/// * Soru akışı (ve dolayısıyla sayaç) ilk sorunun GÖRSELİNİN yüklenmesini
///   bekliyordu. Görsel hata verdiğinde `onReady` hiç tetiklenmediği için
///   kapı hiç açılmıyor, ilk soruda sayaç sonsuza kadar donmuş kalıyordu.
/// * `QuestionLanguagePolicy.detectLanguage` kelime ayırıcısında `ê` yoktu;
///   Kurmancî'nin en sık harflerinden biri kelime sınırı sayılıyordu.
void main() {
  group('görsel hazır sinyali', () {
    late String source;
    setUpAll(() {
      source = File(
        'lib/src/screens/quiz/quiz_widgets.dart',
      ).readAsStringSync();
    });

    test('ağ görseli hata verdiğinde de hazır sinyali gönderilir', () {
      final index = source.indexOf('errorWidget:');
      expect(index, greaterThan(-1));
      final block = source.substring(index, index + 220);
      expect(
        block,
        contains('_notifyReady()'),
        reason: 'errorWidget hazır sinyali göndermiyor',
      );
    });

    test('asset görseli hata verdiğinde de hazır sinyali gönderilir', () {
      final index = source.indexOf('errorBuilder:');
      expect(index, greaterThan(-1));
      final block = source.substring(index, index + 220);
      expect(block, contains('_notifyReady()'));
    });

    test('görsel hiç yanıt vermezse zaman aşımı akışı başlatır', () {
      final quiz = File('lib/src/screens/quiz_screen.dart').readAsStringSync();
      expect(quiz, contains('_visualReadyFallbackTimer'));
      expect(
        quiz,
        contains('_visualReadyFallbackTimer?.cancel()'),
        reason: 'Zaman aşımı sayacı dispose edilmiyor',
      );
    });
  });

  group('QuestionLanguagePolicy.detectLanguage', () {
    test('ê içeren Kurmancî kelimeler parçalanmaz', () {
      // "tê" Kurmancî işaretlerinden biri; eski regex bunu "t" yapıyordu.
      expect(
        QuestionLanguagePolicy.detectLanguage(
          'Di Kurmancî de ev peyv çawa tê gotin?',
        ),
        'ku',
      );
    });

    test('"birêvebirin" Türkçe "bir" olarak parçalanmaz', () {
      // Eski regex bu kelimeyi "bir" + "vebirina" yapıyor ve "bir"
      // Türkçe listesine takılıyordu.
      expect(
        QuestionLanguagePolicy.detectLanguage(
          'Modela birêvebirina civakê ya li derveyî sîstema dewletê ye.',
        ),
        'ku',
      );
    });

    test('Türkçe metin hâlâ doğru tespit edilir', () {
      expect(
        QuestionLanguagePolicy.detectLanguage(
          'Aşağıdakilerden hangisi bu konuyla ilgili değildir?',
        ),
        'tr',
      );
    });
  });
}
