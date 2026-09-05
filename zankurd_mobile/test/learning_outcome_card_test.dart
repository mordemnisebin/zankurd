import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/learning_outcome_card.dart';

import 'support/widget_test_helpers.dart';

AnswerRecord _record(String id, String category, {required bool correct}) =>
    AnswerRecord(
      id: id,
      category: category,
      prompt: 'Pirs $id',
      answers: const ['A', 'B'],
      correctAnswer: 'A',
      selectedAnswer: correct ? 'A' : 'B',
      explanation: 'Şirove',
    );

Widget _wrap(Widget child, {String language = 'tr'}) =>
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang(language),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('tek sorudan konu gücü ya da konu eksiği çıkarmaz', () {
    final outcome = LearningOutcome.fromRecords([
      _record('1', 'Ziman', correct: true),
      _record('2', 'Dîrok', correct: false),
    ]);

    expect(outcome.strongestCategory, isNull);
    expect(outcome.reviewCategory, isNull);
    expect(outcome.reviewRecords.map((record) => record.id), ['2']);
  });

  test('yeterli kayıtta en güçlü ve tekrar konusunu cevaplardan türetir', () {
    final outcome = LearningOutcome.fromRecords([
      _record('z1', 'Ziman', correct: true),
      _record('z2', 'Ziman', correct: true),
      _record('z3', 'Ziman', correct: true),
      _record('d1', 'Dîrok', correct: false),
      _record('d2', 'Dîrok', correct: true),
      _record('d3', 'Dîrok', correct: false),
    ]);

    expect(outcome.strongestCategory, 'Ziman');
    expect(outcome.strongestCorrect, 3);
    expect(outcome.strongestAnswered, 3);
    expect(outcome.reviewCategory, 'Dîrok');
    expect(outcome.reviewWrong, 2);
    expect(outcome.reviewRecords.map((record) => record.id), ['d1', 'd3']);
  });

  testWidgets('kart ölçülü kanıt dili ve somut tekrar eylemi gösterir', (
    tester,
  ) async {
    var tapped = false;
    final outcome = LearningOutcome.fromRecords([
      _record('z1', 'Ziman', correct: true),
      _record('z2', 'Ziman', correct: true),
      _record('d1', 'Dîrok', correct: false),
      _record('d2', 'Dîrok', correct: false),
    ]);

    await tester.pumpWidget(
      _wrap(
        LearningOutcomeCard(outcome: outcome, onReview: () => tapped = true),
      ),
    );

    expect(find.text('Bu turdan öğrenme özeti'), findsOneWidget);
    expect(find.textContaining('Dil: 2 sorunun 2\'si doğru'), findsOneWidget);
    expect(find.textContaining('Tarih: 2 soruda 2 yanlış'), findsOneWidget);
    expect(find.text('Tarih yanlışlarını gözden geçir'), findsOneWidget);
    expect(find.textContaining('ustalaştın'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('learning-outcome-review')));
    expect(tapped, isTrue);
  });

  testWidgets('Kurmancî kart tek kayıt için temkinli genel öneri gösterir', (
    tester,
  ) async {
    final outcome = LearningOutcome.fromRecords([
      _record('1', 'Dîrok', correct: false),
    ]);

    await tester.pumpWidget(
      _wrap(
        LearningOutcomeCard(outcome: outcome, onReview: () {}),
        language: 'ku',
      ),
    );

    expect(find.text('Kurteya fêrbûna vê dorê'), findsOneWidget);
    expect(find.textContaining('Ji bo mijarekê'), findsOneWidget);
    expect(find.text('Bersiva şaş binêre'), findsOneWidget);
  });

  testWidgets('sonuç kartı seçilen konunun yanlışlarını yerel tekrara açar', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();
    final records = [
      _record('z1', 'Ziman', correct: true),
      _record('z2', 'Ziman', correct: true),
      _record('d1', 'Dîrok', correct: false),
      _record('d2', 'Dîrok', correct: false),
      _record('c1', 'Çand', correct: false),
    ];
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 200,
          correctCount: 2,
          wrongCount: 3,
          totalQuestions: 5,
          bestStreak: 2,
          answerRecords: records,
          coinsAwarded: 0,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('learning-outcome-review')),
      250,
    );
    await tester.tap(find.byKey(const ValueKey('learning-outcome-review')));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewScreen), findsOneWidget);
    final review = tester.widget<ReviewScreen>(find.byType(ReviewScreen));
    expect(review.records.map((record) => record.id), ['d1', 'd2']);
  });
}
