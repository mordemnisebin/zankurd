import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider<PremiumService>(
      create: (_) => PremiumService.fallback(),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

QuizResultScreen buildScreen(MockZanKurdRepository repository) {
  return QuizResultScreen(
    repository: repository,
    room: repository.createRoom(),
    score: 1840,
    correctCount: 8,
    wrongCount: 2,
    totalQuestions: 10,
    bestStreak: 5,
    coinsAwarded: 120,
    answerRecords: const [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Ev gotin çi wateyê dide?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: 'A',
        explanation: 'Rast bersiv A ye.',
      ),
      AnswerRecord(
        id: 'q2',
        category: 'Ziman',
        prompt: 'Kîjan bersiv rast e?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: 'B',
        explanation: 'Rast bersiv A ye.',
      ),
    ],
  );
}

void main() {
  testWidgets('light solo vitrin kimlik yeşili gradyan taşır', (tester) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('result-score-header')),
    );
    final decoration = header.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    // 2026-07-24: solo vitrin kimlik anıdır — turuncu yalnız eylem
    // butonunda kalır, beyaz metin perdesiz AA geçmeli.
    //
    // 2026-08-03: iki güvence de aynen duruyor; sabitlenen ŞEY değişti.
    // Test `culturalBrandBg`i tek tek eşitliyordu, yani kimliğin hangi
    // renk olduğunu dondurmuştu. Oysa korunması gereken kural "yeşil
    // olsun" değil, "eylem rengi OLMASIN ve beyazı perdesiz okutsun".
    // Marka yeşilinden koyu turuncuya inen eski gradyan gerçek cihazda
    // kutlama değil çamur veriyordu; Rengîn kutlama yüzeyi derin
    // mürekkepten ametiste geçer. Kural test edilir, sabit edilmez.
    expect(gradient.colors, hasLength(2));
    for (final color in gradient.colors) {
      final luminance = color.computeLuminance();
      expect(
        1.05 / (luminance + 0.05),
        greaterThanOrEqualTo(4.5),
        reason: 'beyaz metin perdesiz okunmalı: $color',
      );
      // Kimlik yüzeyi eylem rengini kullanamaz.
      expect(
        color,
        isNot(AppTheme.brand),
        reason: 'vitrin eylem turuncusunu kullanmamalı',
      );
      expect(color, isNot(AppTheme.brandDeep));
      expect(color, isNot(AppTheme.brandLite));
    }
  });

  testWidgets(
    'yanlış varsa inceleme ana eylem, diğer yollar kapalı gruptadır',
    (tester) async {
      await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('result-primary-review-mistakes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('result-play-again-button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('result-more-options')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-home-button')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('result-more-options')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('result-home-button')), findsOneWidget);
    },
  );

  // 2026-07-23 M33: Roj maskotu sonuç ekranında görünsün ve yüksek
  // doğrulukta (8/10 = %80) kutlama modunda olsun.
  testWidgets('skor başlığında Roj maskotu kutlama modunda görünür', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('result-score-header')),
      findsOneWidget,
      reason: 'M33 eklerken mevcut skor başlığı bozulmamalı',
    );
    final mascot = tester.widget<RojMascot>(find.byType(RojMascot));
    expect(mascot.mood, RojMood.celebrate);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('sonuç ${size.width.toInt()}x${size.height.toInt()} taşmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
