import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';

import 'support/widget_test_helpers.dart';

/// Eleme jokerlerinin iki şıklı soruda GÖSTERİLMEDİĞİNİN bekçisi.
///
/// ## Kusur
///
/// 50/50 iki yanlış şıkkı gizler:
/// `answers.where((a) => a != correctAnswer).shuffle().take(2)`.
///
/// Doğru/yanlış sorusunda iki şık vardır, yani tek bir yanlış. `take(2)` onu
/// gizler ve geriye YALNIZ doğru cevap kalır: oyuncu 20 jeton ödeyip cevabın
/// kendisini satın alıyordu.
///
/// Çift cevap aynı sorunun daha ağır hâliydi. İki şıklı bir soruda "iki kez
/// cevapla" hakkı kazanmayı GARANTİ eder — 50 jetona kesin puan.
///
/// Banka doğru/yanlış sorularıyla dolu; ikisi de kuramsal değildi.
///
/// Sessizdi çünkü kapı soru TÜRÜNE bakıyordu — `fillInBlank` ve
/// `wordOrdering` dışarıdaydı, doğru/yanlış ise şıklı bir tür olduğu için
/// içerideydi. Oysa eleme jokerlerini anlamlı kılan tür değil, ŞIK SAYISI.
///
/// Seyirci jokeri kasıtlı olarak kapının dışında: iki şıkta da dürüst bir
/// dağılım gösterir ve cevabı ele vermez.
void main() {
  const trueFalse = QuizQuestion(
    id: 'wildcard_tf_probe',
    category: 'Ziman',
    prompt: 'Doğru mu yanlış mı: «av» su demektir.',
    answers: ['Rast', 'Şaş'],
    correctAnswer: 'Rast',
    explanation: 'Av su demektir.',
    type: QuestionType.trueFalse,
  );

  const multipleChoice = QuizQuestion(
    id: 'wildcard_mc_probe',
    category: 'Ziman',
    prompt: '«av» ne demektir?',
    answers: ['su', 'taş', 'ağaç', 'renk'],
    correctAnswer: 'su',
    explanation: 'Av su demektir.',
  );

  Future<Set<WildcardType>> shownWildcards(
    WidgetTester tester,
    QuizQuestion question,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester
        .widgetList<WildcardButton>(find.byType(WildcardButton))
        .map((button) => button.type)
        .toSet();
  }

  testWidgets('iki şıklı soruda eleme jokerleri hiç görünmüyor', (
    tester,
  ) async {
    final shown = await shownWildcards(tester, trueFalse);

    expect(
      shown,
      isNot(contains(WildcardType.fiftyFifty)),
      reason:
          '50/50 iki şıkta tek yanlışı gizler ve geriye yalnız doğru cevap '
          'kalır; oyuncu 20 jetona cevabı satın alır.',
    );
    expect(
      shown,
      isNot(contains(WildcardType.doubleAnswer)),
      reason:
          'İki şıkta iki cevap hakkı kazanmayı garanti eder; 50 jetona kesin '
          'puan satılır.',
    );
    expect(
      shown,
      contains(WildcardType.audience),
      reason:
          'Seyirci jokeri iki şıkta da dürüsttür ve kapatılmamalı — bu bekçi '
          'yalnız eleyen jokerleri kısıtlar.',
    );
  });

  testWidgets('dört şıklı soruda bütün jokerler duruyor', (tester) async {
    // Korumanın öteki yarısı: kısıt, meşru kullanımı kırmamalı.
    final shown = await shownWildcards(tester, multipleChoice);

    expect(shown, contains(WildcardType.fiftyFifty));
    expect(shown, contains(WildcardType.audience));
    expect(shown, contains(WildcardType.doubleAnswer));
  });
}
