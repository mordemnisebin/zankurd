import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Puan yıldızının DOLULUKLA konuştuğunun bekçisi.
///
/// ## Kusur
///
/// Kazanılan ve kazanılmayan yıldız aynı KONTUR glifiyle çiziliyordu:
/// `AppIcons.star` FontAwesome **Regular** ailesinden geliyor ve iki
/// durumu yalnız renk ayırıyordu. Mor kutlama zemininde altın bir kontur
/// "boş yıldız" gibi okunuyor; 5/5 doğru bir tur üç boş yıldızla
/// kutlanıyordu. Turun en güçlü ödül anında ekran "hiçbir şey kazanmadın"
/// diyordu (2026-08-12 simülatör turu, iPhone SE).
///
/// Sessizdi çünkü hesap doğruydu — %80 üstü zaten üç yıldız seçiyordu — ve
/// hiçbir test bir ikonun dolu mu boş mu çizildiğine bakmıyordu. Renk
/// testleri de geçiyordu: altın gerçekten altındı.
///
/// Doluluk aynı zamanda renkten BAĞIMSIZ ikinci bir işarettir; renk körü
/// bir oyuncu için tek ayırt edici odur.
void main() {
  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
      ChangeNotifierProvider<ChildSafetyProvider>(
        create: (_) => ChildSafetyProvider(),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );

  AnswerRecord record({required bool correct, required String id}) =>
      AnswerRecord(
        id: id,
        category: 'Ziman',
        prompt: 'Ev gotin çi wateyê dide?',
        answers: const ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: correct ? 'A' : 'B',
        explanation: 'Rast bersiv A ye.',
      );

  QuizResultScreen screenWith({
    required int correctCount,
    required int totalQuestions,
  }) {
    final repository = MockZanKurdRepository();
    return QuizResultScreen(
      repository: repository,
      room: repository.createRoom(),
      score: 100 * correctCount,
      correctCount: correctCount,
      wrongCount: totalQuestions - correctCount,
      totalQuestions: totalQuestions,
      bestStreak: correctCount,
      coinsAwarded: 0,
      answerRecords: [
        for (var i = 0; i < totalQuestions; i++)
          record(correct: i < correctCount, id: 'q$i'),
      ],
    );
  }

  /// Kahramandaki üç puan yıldızını doluluklarıyla döndürür.
  List<bool> starFills(WidgetTester tester) {
    final icons = tester
        .widgetList<Icon>(find.byType(Icon))
        .where(
          (icon) =>
              icon.icon == AppIcons.star || icon.icon == AppIcons.starSolid,
        )
        .where((icon) => icon.size == 22 || icon.size == 30)
        .toList();
    return icons.map((icon) => icon.icon == AppIcons.starSolid).toList();
  }

  testWidgets('kusursuz tur üç yıldızı da DOLU gösteriyor', (tester) async {
    await tester.pumpWidget(
      wrap(screenWith(correctCount: 10, totalQuestions: 10)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      starFills(tester),
      [true, true, true],
      reason:
          '%100 doğru bir turda üç yıldız da kazanılmıştır; kontur glifi '
          'kazanılmamış demektir.',
    );
  });

  testWidgets('yarısı doğru turda yalnız kazanılanlar dolu', (tester) async {
    await tester.pumpWidget(
      wrap(screenWith(correctCount: 5, totalQuestions: 10)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      starFills(tester),
      [true, true, false],
      reason:
          '%50 doğruluk iki yıldız kazandırır; üçüncüsü kontur kalmalı ki '
          'ilerlemenin sürdüğü görünsün.',
    );
  });

  testWidgets('zayıf turda tek yıldız dolu, ikisi kontur', (tester) async {
    await tester.pumpWidget(
      wrap(screenWith(correctCount: 2, totalQuestions: 10)),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(starFills(tester), [true, false, false]);
  });

  test('dolu ve boş yıldız gerçekten AYRI glifler', () {
    // İkisi aynı kod noktasını paylaşır; ayrımı font AİLESİ yapar. Biri
    // ötekine eşitlenirse ekran yine tek biçime döner ve üstteki üç test
    // de sessizce anlamsızlaşır.
    expect(AppIcons.starSolid.codePoint, AppIcons.star.codePoint);
    expect(
      AppIcons.starSolid.fontFamily,
      isNot(AppIcons.star.fontFamily),
      reason: 'Dolu yıldız Solid, kontur yıldız Regular ailesinden gelmeli.',
    );
  });
}
