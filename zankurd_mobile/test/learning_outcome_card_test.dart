// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
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

Widget _wrap(
  Widget child, {
  String language = 'tr',
  bool dark = false,
  double textScale = 1,
}) => ChangeNotifierProvider<LanguageProvider>(
  create: (_) => LanguageProvider()..setLang(language),
  child: MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('tek doğru cevapta özet yanlış cevap varmış gibi yönlendirmez', (
    tester,
  ) async {
    final outcome = LearningOutcome.fromRecords([
      _record('1', 'Ziman', correct: true),
    ]);
    await tester.pumpWidget(
      _wrap(LearningOutcomeCard(outcome: outcome, onReview: null)),
    );
    expect(find.text('1 cevap · 1 doğru · 0 yanlış'), findsOneWidget);
    expect(find.textContaining('Yanlışlarına bakıp'), findsNothing);
    expect(find.byKey(const ValueKey('learning-outcome-review')), findsNothing);
  });

  testWidgets('cevapsız sorular doğru yanlış özetinden ayrı gösterilir', (
    tester,
  ) async {
    final outcome = LearningOutcome.fromRecords([
      _record('1', '', correct: true),
      const AnswerRecord(
        id: '2',
        category: 'Ziman',
        prompt: 'Pirs',
        answers: ['A', 'B'],
        correctAnswer: 'A',
        selectedAnswer: null,
        explanation: 'Şirove',
      ),
    ]);
    await tester.pumpWidget(
      _wrap(LearningOutcomeCard(outcome: outcome, onReview: null)),
    );
    expect(find.text('1 cevap · 1 doğru · 0 yanlış'), findsOneWidget);
    expect(find.text('1 soru cevapsız kaldı.'), findsOneWidget);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final language in ['ku', 'tr']) {
    for (final dark in [false, true]) {
      testWidgets(
        'öğrenme özeti 320px ve büyük yazıda okunur: $language dark=$dark',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 568));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final outcome = LearningOutcome.fromRecords([
            _record('z1', 'Ziman', correct: true),
            _record('z2', 'Ziman', correct: true),
            _record('d1', 'Dîrok', correct: false),
            _record('d2', 'Dîrok', correct: false),
          ]);
          await tester.pumpWidget(
            _wrap(
              SingleChildScrollView(
                child: LearningOutcomeCard(outcome: outcome, onReview: () {}),
              ),
              language: language,
              dark: dark,
              textScale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const ValueKey('learning-outcome-review')),
          );
          expect(
            find.byKey(const ValueKey('learning-outcome-review')).hitTestable(),
            findsOneWidget,
          );
        },
      );
    }
  }

  test('tek doğru soru konu gücü ilan etmez; tek yanlış tekrar konusudur', () {
    // 2026-10-02: eskiden tek yanlış da eşiğe takılıyor, kutu "Nerelerde
    // zorlandın?" derken yalnız güçlü konuyu yazıyordu. Güçlü konu eşiği
    // (2+ cevap) aynı kaldı; zayıf konu artık en az bir yanlışı olan en
    // düşük doğruluklu kategoridir.
    final outcome = LearningOutcome.fromRecords([
      _record('1', 'Ziman', correct: true),
      _record('2', 'Dîrok', correct: false),
    ]);

    expect(outcome.strongestCategory, isNull);
    expect(outcome.reviewCategory, 'Dîrok');
    expect(outcome.reviewRecords.map((record) => record.id), ['2']);
  });

  test('simülatör turu: Siyaset 0/1 zayıf, Coğrafya 3/3 güçlü konudur', () {
    // 2026-10-02 simülatör: Günün dersi 9/10, Siyaset 0/1, Coğrafya 3/3.
    // Kutu zayıf konu yerine en çok sorulan konuyu yazıyordu.
    final outcome = LearningOutcome.fromRecords([
      _record('c1', 'Cografya', correct: true),
      _record('c2', 'Cografya', correct: true),
      _record('c3', 'Cografya', correct: true),
      _record('s1', 'Siyaset', correct: false),
      _record('z1', 'Ziman', correct: true),
      _record('z2', 'Ziman', correct: true),
      _record('m1', 'Muzîk', correct: true),
      _record('d1', 'Dîrok', correct: true),
      _record('d2', 'Dîrok', correct: true),
      _record('k1', 'Çand', correct: true),
    ]);

    expect(outcome.reviewCategory, 'Siyaset');
    expect(outcome.reviewWrong, 1);
    expect(outcome.reviewAnswered, 1);
    expect(outcome.reviewRecords.map((r) => r.id), ['s1']);
    expect(outcome.strongestCategory, 'Cografya');
  });

  test('zayıf konu: en düşük doğruluk, eşitlikte en çok yanlış', () {
    final outcome = LearningOutcome.fromRecords([
      // Ziman 3/4 (1 yanlış, %75), Dîrok 1/3 (2 yanlış, %33),
      // Çand 0/1 (1 yanlış, %0), Muzîk 0/2 (2 yanlış, %0).
      _record('z1', 'Ziman', correct: true),
      _record('z2', 'Ziman', correct: true),
      _record('z3', 'Ziman', correct: true),
      _record('z4', 'Ziman', correct: false),
      _record('d1', 'Dîrok', correct: true),
      _record('d2', 'Dîrok', correct: false),
      _record('d3', 'Dîrok', correct: false),
      _record('c1', 'Çand', correct: false),
      _record('m1', 'Muzîk', correct: false),
      _record('m2', 'Muzîk', correct: false),
    ]);

    expect(outcome.reviewCategory, 'Muzîk');
    expect(outcome.reviewWrong, 2);
  });

  testWidgets('başlık satırın söylediğiyle uyuşur: zayıf konu varken zorlanma '
      'sorulur, tek yanlış satırı gösterilir', (tester) async {
    final outcome = LearningOutcome.fromRecords([
      _record('c1', 'Cografya', correct: true),
      _record('c2', 'Cografya', correct: true),
      _record('c3', 'Cografya', correct: true),
      _record('s1', 'Siyaset', correct: false),
    ]);
    await tester.pumpWidget(
      _wrap(LearningOutcomeCard(outcome: outcome, onReview: () {})),
    );
    expect(find.text('Nerelerde zorlandın?'), findsOneWidget);
    expect(find.textContaining('Siyaset: 1 soruda 1 yanlış'), findsOneWidget);
    expect(find.textContaining('Coğrafya: 3 sorudan 3 doğru'), findsOneWidget);
  });

  testWidgets('yanlışsız turda başlık "zorlandın" demez; güçlü konu kendi '
      'başlığıyla gelir', (tester) async {
    final outcome = LearningOutcome.fromRecords([
      _record('c1', 'Cografya', correct: true),
      _record('c2', 'Cografya', correct: true),
      _record('c3', 'Cografya', correct: true),
      _record('z1', 'Ziman', correct: true),
    ]);
    await tester.pumpWidget(
      _wrap(
        LearningOutcomeCard(
          outcome: outcome,
          onReview: null,
          showCounts: false,
        ),
      ),
    );
    expect(find.text('Nerelerde zorlandın?'), findsNothing);
    expect(find.text('En güçlü olduğun konu:'), findsOneWidget);
    expect(find.textContaining('Coğrafya: 3 sorudan 3 doğru'), findsOneWidget);
    expect(find.byKey(const ValueKey('learning-outcome-review')), findsNothing);
  });

  testWidgets('yorumu olmayan ve sayımı başka yerde gösterilen kart gizlenir', (
    tester,
  ) async {
    final outcome = LearningOutcome.fromRecords([
      _record('1', 'Ziman', correct: true),
      _record('2', 'Dîrok', correct: true),
    ]);
    await tester.pumpWidget(
      _wrap(
        LearningOutcomeCard(
          outcome: outcome,
          onReview: null,
          showCounts: false,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('learning-outcome-card')), findsNothing);
    expect(find.text('Nerelerde zorlandın?'), findsNothing);
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

    expect(find.text('Nerelerde zorlandın?'), findsOneWidget);
    expect(find.textContaining('Dil: 2 sorudan 2 doğru'), findsOneWidget);
    expect(find.textContaining('Tarih: 2 soruda 2 yanlış'), findsOneWidget);
    expect(find.text('Tarih yanlışlarını gözden geçir'), findsOneWidget);
    expect(find.textContaining('ustalaştın'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('learning-outcome-review')));
    expect(tapped, isTrue);
  });

  testWidgets(
    'Kurmancî kart tek yanlışı zayıf konu olarak, iddiasız gösterir',
    (tester) async {
      // 2026-10-02: tek yanlış artık "temkinli genel öneri" değil, sayıyla
      // söylenen zayıf konu satırıdır ("1 pirsê 1 şaş"); iddia değil sayım.
      final outcome = LearningOutcome.fromRecords([
        _record('1', 'Dîrok', correct: false),
      ]);

      await tester.pumpWidget(
        _wrap(
          LearningOutcomeCard(outcome: outcome, onReview: () {}),
          language: 'ku',
        ),
      );

      expect(find.text('Te li ku zehmetî kişand?'), findsOneWidget);
      expect(
        find.textContaining('Dîrok: di 1 pirsan de 1 şaş'),
        findsOneWidget,
      );
      expect(find.text('Li şaşiyên Dîrok binêre'), findsOneWidget);
    },
  );

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
