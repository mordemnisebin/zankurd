import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider(create: (_) => ChildSafetyProvider()),
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
    score: 1000,
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
    ],
  );
}

String _dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

void main() {
  setUp(() => StreakStore.resetInstance());

  testWidgets('kırılacak seride dondurma teklifi görünür ve seriyi korur', (
    tester,
  ) async {
    // Eski bir gün: bugün oynanınca seri kırılacak (current > 0).
    SharedPreferences.setMockInitialValues({
      'zankurd.streak.current': 3,
      'zankurd.streak.best': 3,
      'zankurd.streak.lastDay': '2020-01-01',
    });
    StreakStore.resetInstance();

    final repo1 = MockZanKurdRepository();
    await repo1.awardQuizCoins(score: 1000, correctCount: 10, totalQuestions: 10, bestStreak: 5);
    await tester.pumpWidget(wrap(buildScreen(repo1)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Serin kırılıyor!'), findsOneWidget);

    await tester.tap(find.text('Koru (50)'));
    await tester.pumpAndSettle();

    // Seri sıfırlanmadı, +1 devam etti (3 -> 4) ve kalıcı yazıldı.
    StreakStore.resetInstance();
    final store = await StreakStore.load();
    expect(store.effectiveStreak(), greaterThanOrEqualTo(4));
  });

  testWidgets('teklif reddedilince seri normal şekilde sıfırlanır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.streak.current': 3,
      'zankurd.streak.best': 3,
      'zankurd.streak.lastDay': '2020-01-01',
    });
    StreakStore.resetInstance();

    final repo2 = MockZanKurdRepository();
    await repo2.awardQuizCoins(score: 1000, correctCount: 10, totalQuestions: 10, bestStreak: 5);
    await tester.pumpWidget(wrap(buildScreen(repo2)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hayır, sıfırlansın'));
    await tester.pumpAndSettle();

    StreakStore.resetInstance();
    final store = await StreakStore.load();
    // Normal recordPlay: seri 1'e düştü.
    expect(store.effectiveStreak(), 1);
  });

  testWidgets('seri sağlamsa dondurma teklifi gösterilmez', (tester) async {
    // lastDay bugün: seri kırılmaz, teklif çıkmaz.
    SharedPreferences.setMockInitialValues({
      'zankurd.streak.current': 2,
      'zankurd.streak.best': 2,
      'zankurd.streak.lastDay': _dayKey(DateTime.now()),
    });
    StreakStore.resetInstance();

    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Serin kırılıyor!'), findsNothing);
  });
}
