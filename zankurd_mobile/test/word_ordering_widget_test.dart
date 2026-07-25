import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/word_ordering_widget.dart';

/// 2026-07-25 denetim bulgusu: WordOrderingWidget hiç test edilmemişti ve
/// hiçbir veri kaynağı `QuestionType.wordOrdering` üretmediği için canlıda
/// erişilemiyordu. Bu testler widget'ın davranış sözleşmesini sabitler.

const _q1 = QuizQuestion(
  id: 'wo-1',
  category: 'Ziman',
  prompt: 'Hevokê rêz bike',
  answers: ['Ez', 'diçim', 'malê'],
  correctAnswer: 'Ez diçim malê',
  explanation: '',
  type: QuestionType.wordOrdering,
);

const _q2 = QuizQuestion(
  id: 'wo-2',
  category: 'Ziman',
  prompt: 'Hevokê rêz bike',
  answers: ['Ew', 'nan', 'dixwe'],
  correctAnswer: 'Ew nan dixwe',
  explanation: '',
  type: QuestionType.wordOrdering,
);

Widget _host({
  required QuizQuestion question,
  required ValueChanged<String> onSubmit,
  bool disabled = false,
  String? selectedAnswer,
}) {
  return ChangeNotifierProvider(
    create: (_) => LanguageProvider(initialLang: 'tr'),
    child: MaterialApp(
      home: Scaffold(
        body: WordOrderingWidget(
          key: ValueKey('word-ordering-${question.id}'),
          question: question,
          disabled: disabled,
          selectedAnswer: selectedAnswer,
          onAnswerSubmitted: onSubmit,
        ),
      ),
    ),
  );
}

Future<void> _tapWord(WidgetTester tester, String word) async {
  await tester.tap(find.text(word).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('seçilen kelimeler sırayla cümleye dönüşür', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      _host(question: _q1, onSubmit: (value) => submitted = value),
    );

    await _tapWord(tester, 'Ez');
    await _tapWord(tester, 'diçim');
    await _tapWord(tester, 'malê');
    await tester.tap(find.text('Kontrol et'));
    await tester.pumpAndSettle();

    expect(submitted, 'Ez diçim malê');
  });

  testWidgets('geri alınan kelime havuza döner', (tester) async {
    await tester.pumpWidget(_host(question: _q1, onSubmit: (_) {}));

    // Havuzda her kelimeden bir tane var.
    expect(find.text('Ez'), findsOneWidget);
    await _tapWord(tester, 'Ez');
    // Cümlede bir tane, havuzda yok.
    expect(find.text('Ez'), findsOneWidget);

    // Cümledeki chip'e dokununca havuza geri döner ve tekrar seçilebilir.
    await _tapWord(tester, 'Ez');
    await _tapWord(tester, 'Ez');
    await tester.tap(find.text('Kontrol et'));
    await tester.pumpAndSettle();
  });

  testWidgets('soru değişince önceki sorunun kelimeleri kalmaz', (
    tester,
  ) async {
    await tester.pumpWidget(_host(question: _q1, onSubmit: (_) {}));
    await _tapWord(tester, 'Ez');
    expect(find.text('diçim'), findsOneWidget);

    // Aynı ağaç konumunda ikinci soruya geçilir.
    await tester.pumpWidget(_host(question: _q2, onSubmit: (_) {}));
    await tester.pumpAndSettle();

    for (final word in _q1.answers) {
      expect(find.text(word), findsNothing, reason: 'eski kelime: $word');
    }
    for (final word in _q2.answers) {
      expect(find.text(word), findsOneWidget, reason: 'yeni kelime: $word');
    }
  });

  testWidgets('cevap verildikten sonra havuz ve buton gizlenir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        question: _q1,
        onSubmit: (_) {},
        disabled: true,
        selectedAnswer: 'Ez diçim malê',
      ),
    );

    expect(find.text('Kontrol et'), findsNothing);
    expect(find.text('Ez diçim malê'), findsOneWidget);
  });

  testWidgets('karıştırma cevabı olduğu gibi ekrana vermez', (tester) async {
    // Kelimelerin havuzdaki sırası doğru cümleyle birebir aynı olmamalı;
    // aksi halde kullanıcı soldan sağa tıklayarak soruyu düşünmeden çözer.
    const long = QuizQuestion(
      id: 'wo-3',
      category: 'Ziman',
      prompt: 'Hevokê rêz bike',
      answers: ['Ez', 'ji', 'te', 'hez', 'dikim'],
      correctAnswer: 'Ez ji te hez dikim',
      explanation: '',
      type: QuestionType.wordOrdering,
    );

    for (var attempt = 0; attempt < 8; attempt++) {
      await tester.pumpWidget(_host(question: long, onSubmit: (_) {}));
      await tester.pumpAndSettle();

      final chips = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((t) => long.answers.contains(t))
          .toList();
      expect(chips.join(' '), isNot(long.correctAnswer));
    }
  });
}
