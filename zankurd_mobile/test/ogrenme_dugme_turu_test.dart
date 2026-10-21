import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/learner_lexicon_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/fill_in_blank_widget.dart';
import 'package:zankurd_mobile/src/screens/quiz/word_ordering_widget.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/utils/result_sharer.dart';

import 'support/widget_test_helpers.dart';

/// 2026-10-21 gerçek simülatör düğme turunun öğrenme bulguları. Her biri
/// sessiz kaldı çünkü ekran testleri yalnız "açılıyor mu"ya bakıyordu:
/// Devam'ın NEREYE döndüğüne, iptal edilen paylaşımın ödül verip
/// vermediğine, yanlış alanın kenar rengine, geri alınan kelimenin yerine
/// bakan yoktu.
Widget _host(Widget child) => ChangeNotifierProvider<LanguageProvider>(
  create: (_) => LanguageProvider(initialLang: 'tr'),
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('öğrenme sonucu Devam ana sayfaya değil önceki ekrana döner', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(child: const Scaffold(body: Text('ROOT_HOME'))),
    );
    await tester.pumpAndSettle();
    final navigator = Navigator.of(tester.element(find.text('ROOT_HOME')));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('LEARNING_SCREEN')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 100,
          correctCount: 5,
          wrongCount: 0,
          totalQuestions: 5,
          bestStreak: 5,
          answerRecords: const [],
          coinsAwarded: 0,
          isLearningExperience: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final action = find.byKey(
      const ValueKey('result-primary-learning-continue'),
    );
    await tester.scrollUntilVisible(
      action,
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('LEARNING_SCREEN'), findsOneWidget);
    expect(find.byType(QuizResultScreen), findsNothing);
  });

  test('paylaşım iptal edilirse ödül sayılmaz, tamamlanırsa sayılır', () {
    expect(ResultSharer.statusCounts(ShareResultStatus.dismissed), isFalse);
    expect(ResultSharer.statusCounts(ShareResultStatus.success), isTrue);
    // Sonucu bildirmeyen platform: ödül kesilmez (bkz. share() yorumu).
    expect(ResultSharer.statusCounts(ShareResultStatus.unavailable), isTrue);
  });

  testWidgets('sözlük sonuç kartına dokununca madde balonu açılır', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(initialLang: 'tr'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const LearnerLexiconScreen(initialQuery: 'Rojbaş'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = LearnerLexicon.search('Rojbaş').first;
    await tester.tap(find.byKey(ValueKey('lexicon-entry-${entry.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lexicon-entry-sheet')), findsOneWidget);
    // Ekranın içinden açılan balon "Sözlükte aç" ile kendini yinelemez.
    expect(find.byKey(const ValueKey('lexicon-sheet-open')), findsNothing);
  });

  group('boşluk doldurma hükmü', () {
    const q = QuizQuestion(
      id: 'fib-verdict',
      category: 'Ziman',
      prompt: 'Ez ___ dixwînim.',
      answers: ['pirtûk'],
      correctAnswer: 'pirtûk',
      explanation: '',
      type: QuestionType.fillInBlank,
    );

    Widget fib(String answer) => _host(
      FillInBlankWidget(
        question: q,
        disabled: true,
        showResult: true,
        selectedAnswer: answer,
        onAnswerSubmitted: (_) {},
      ),
    );

    testWidgets('yanlışta alan Hata kenarı + ✕ taşır', (tester) async {
      await tester.pumpWidget(fib('nan'));
      expect(
        find.byKey(const ValueKey('fill-in-blank-verdict-wrong')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('fill-in-blank-verdict-correct')),
        findsNothing,
      );
    });

    testWidgets('doğruda alan Rast kenarı + ✓ taşır', (tester) async {
      await tester.pumpWidget(fib('pirtûk'));
      expect(
        find.byKey(const ValueKey('fill-in-blank-verdict-correct')),
        findsOneWidget,
      );
    });

    testWidgets('süre dolunca alan nötr kalır', (tester) async {
      await tester.pumpWidget(fib('TIMEOUT'));
      expect(
        find.byKey(const ValueKey('fill-in-blank-verdict-wrong')),
        findsNothing,
      );
    });
  });

  testWidgets('kelime sıralamada geri alınan kelime özgün yerine döner', (
    tester,
  ) async {
    const q = QuizQuestion(
      id: 'wo-undo',
      category: 'Ziman',
      prompt: 'Hevokê rêz bike',
      answers: ['Ez', 'diçim', 'malê', 'îro'],
      correctAnswer: 'Ez diçim malê îro',
      explanation: '',
      type: QuestionType.wordOrdering,
    );
    await tester.pumpWidget(
      _host(
        WordOrderingWidget(
          question: q,
          disabled: false,
          onAnswerSubmitted: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Havuzun görsel sırası: yalnız havuz kelimeleri bulunur (cümle alanı
    // boşken kelimeler tek yerde durur).
    List<String> pool() {
      final found = <(String, Offset)>[
        for (final w in ['Ez', 'diçim', 'malê', 'îro'])
          if (find.text(w).evaluate().isNotEmpty)
            (w, tester.getTopLeft(find.text(w).first)),
      ];
      found.sort((a, b) {
        final dy = a.$2.dy.compareTo(b.$2.dy);
        return dy != 0 ? dy : a.$2.dx.compareTo(b.$2.dx);
      });
      return [for (final f in found) f.$1];
    }

    final before = pool();
    expect(before, hasLength(4));
    final middle = before[1];
    await tester.tap(find.text(middle).first);
    await tester.pumpAndSettle();
    // Seçilen kelime cümle alanına geçti (yukarıda, havuzdan önce); dokununca
    // geri alınır ve havuzdaki ÖZGÜN yerine döner (eskiden sona düşerdi).
    await tester.tap(find.text(middle).first);
    await tester.pumpAndSettle();
    expect(pool(), before);
  });
}
