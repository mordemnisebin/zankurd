import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';

import 'support/widget_test_helpers.dart';

/// Turun bütün açıklamaları sonuç ekranında, hepsi bir arada.
///
/// Ürün kuralı: tur **içinde** yalnız doğru cevap gösterilir, açıklamalar
/// turun sonunda toplu hâlde verilir. Böylece geri sayım işlerken oyuncu
/// metin okumak zorunda kalmaz ama öğrenme de kaybolmaz.
///
/// Kuralın hiçbir bekçisi yoktu (2026-07-27). Sonuç ekranı bugün doğru
/// çalışıyor; kural sözlü kaldığı sürece yarın sessizce kaybolabilirdi —
/// bölüm katlanabilir yapılır, listelenen kayıt sayısı sınırlanır ya da
/// yalnız yanlışlar gösterilir ve kimse fark etmez.
///
/// Test dili de ölçer: Kurmancî arayüzde Kurmancî açıklama görünmeli.
/// Bankada Kurmancî açıklaması Türkçenin kopyası olan sorular çıkmıştı,
/// yani bu iki şey birbirinden bağımsız değil.
void main() {
  const records = [
    AnswerRecord(
      id: 'r1',
      category: 'Ziman',
      prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
      answers: ['su', 'ekmek', 'yol', 'dağ'],
      correctAnswer: 'su',
      selectedAnswer: 'su',
      explanation: '«av» Türkçede «su» demektir.',
      explanationKu: '«av» bi Tirkî dibe «su».',
      explanationTr: '«av» Türkçede «su» demektir.',
    ),
    AnswerRecord(
      id: 'r2',
      category: 'Dîrok',
      prompt: 'Şerefname kê nivîsandiye?',
      answers: ['Şerefxan', 'Ehmedê Xanî', 'Melayê Cizîrî', 'Feqiyê Teyran'],
      correctAnswer: 'Şerefxan',
      selectedAnswer: 'Ehmedê Xanî',
      explanation: 'Şerefname, Şerefxanê Bidlîsî tarafından yazıldı.',
      explanationKu: 'Şerefname ji aliyê Şerefxanê Bidlîsî ve hatiye '
          'nivîsandin.',
      explanationTr: 'Şerefname, Şerefxanê Bidlîsî tarafından yazıldı.',
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpResult(WidgetTester tester, {required bool ku}) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        languageProvider: ku ? kurmanciLang() : turkishLang(),
        child: Scaffold(
          body: QuizResultScreen(
            repository: repository,
            room: repository.createRoom(),
            score: 200,
            correctCount: 1,
            wrongCount: 1,
            totalQuestions: 2,
            bestStreak: 1,
            coinsAwarded: 20,
            answerRecords: records,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('doğru ve yanlış, her sorunun açıklaması sonuçta var', (
    tester,
  ) async {
    await pumpResult(tester, ku: false);

    for (final record in records) {
      // `ensureVisible` yerine kaydırma: bölüm listenin altında.
      final finder = find.textContaining(
        record.explanationTr!.substring(0, 20),
        skipOffstage: false,
      );
      expect(
        finder,
        findsOneWidget,
        reason: '${record.id} açıklaması sonuç ekranında yok',
      );
    }
  });

  testWidgets('Kurmancî arayüzde açıklamalar Kurmancî', (tester) async {
    await pumpResult(tester, ku: true);

    expect(
      find.textContaining('bi Tirkî dibe', skipOffstage: false),
      findsOneWidget,
      reason: 'Kurmancî açıklama görünmüyor',
    );
    expect(
      find.textContaining('tarafından yazıldı', skipOffstage: false),
      findsNothing,
      reason: 'Kurmancî arayüzde Türkçe açıklama gösterildi',
    );
  });
}
