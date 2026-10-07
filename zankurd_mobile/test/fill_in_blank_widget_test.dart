import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/fill_in_blank_widget.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// 2026-08-10 denetim bulgusu: `fillInBlank` modelde ve rozetlerde vardı
/// ama quiz alanı onu normal şıklara düşürüyordu; yazılabilir bir alan hiç
/// yoktu. Bu bekçi, türün gerçekten serbest metin etkileşimi sunduğunu ve
/// boş/yalnız boşluk yanıtı göndermediğini sabitler.
const _question = QuizQuestion(
  id: 'fill-widget-1',
  category: 'Ziman',
  prompt: 'Ez ___ dixwînim.',
  answers: ['pirtûk'],
  correctAnswer: 'pirtûk',
  acceptedAnswers: ['pirtuk'],
  explanation: '',
  type: QuestionType.fillInBlank,
);

const _nextQuestion = QuizQuestion(
  id: 'fill-widget-2',
  category: 'Ziman',
  prompt: 'Îro hewa ___ e.',
  answers: ['germ'],
  correctAnswer: 'germ',
  explanation: '',
  type: QuestionType.fillInBlank,
);

Widget _host({
  required ValueChanged<String> onSubmit,
  QuizQuestion question = _question,
  bool disabled = false,
  bool showResult = false,
  String? selectedAnswer,
}) {
  return ChangeNotifierProvider(
    create: (_) => LanguageProvider(initialLang: 'tr'),
    child: MaterialApp(
      home: Scaffold(
        body: FillInBlankWidget(
          question: question,
          disabled: disabled,
          showResult: showResult,
          selectedAnswer: selectedAnswer,
          onAnswerSubmitted: onSubmit,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('gönderme denetimi erişilebilir düğme rolü taşır', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(onSubmit: (_) {}));
    await tester.enterText(
      find.byKey(const ValueKey('fill-in-blank-input')),
      'pirtûk',
    );
    await tester.pump();

    final data = tester
        .getSemantics(find.byKey(const ValueKey('fill-in-blank-submit')))
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('yazılan yanıt kenar boşlukları temizlenerek gönderilir', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(_host(onSubmit: (value) => submitted = value));

    final submit = find.byKey(const ValueKey('fill-in-blank-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('fill-in-blank-input')),
      '  PIRTUK  ',
    );
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();

    expect(submitted, 'PIRTUK');
  });

  testWidgets('soru değişince önceki sorunun yazısı alanda kalmaz', (
    tester,
  ) async {
    await tester.pumpWidget(_host(onSubmit: (_) {}));
    final input = find.byKey(const ValueKey('fill-in-blank-input'));
    await tester.enterText(input, 'pirtûk');

    await tester.pumpWidget(_host(question: _nextQuestion, onSubmit: (_) {}));
    await tester.pump();

    expect(tester.widget<SahneField>(input).controller!.text, isEmpty);
  });

  testWidgets('yanlış yazılı yanıttan sonra kanonik doğru cevap gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        disabled: true,
        showResult: true,
        selectedAnswer: 'nivîs',
        onSubmit: (_) {},
      ),
    );

    expect(find.text('Doğru cevap: pirtûk'), findsOneWidget);
    expect(find.byKey(const ValueKey('fill-in-blank-submit')), findsNothing);
    final liveRegion = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(liveRegion.excludeSemantics, isTrue);
  });

  testWidgets('kabul edilen alternatiften sonra kanonik yazım öğretilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        disabled: true,
        showResult: true,
        selectedAnswer: 'PIRTUK',
        onSubmit: (_) {},
      ),
    );

    expect(find.text('Doğru: pirtûk'), findsOneWidget);
  });

  /// ## Kusur
  ///
  /// Harf sırası yalnız `î ê û` taşıyordu; `ç` ve `ş` "Türkçe klavyede zaten
  /// var" diye bilerek dışarıda bırakılmıştı. 2026-10-07 simülatör QA'sında
  /// klavye Türkçe olmayınca `çiya`, `şev` gibi cevaplar yazılamadı.
  ///
  /// Sessizdi çünkü hiçbir test sırayı bütün olarak sabitlemiyordu;
  /// geometri bekçisi yalnız üç harfin ekrana sığdığına bakıyordu.
  testWidgets('özel harf sırası ç ş ê î û düğmelerini verir ve ekler', (
    tester,
  ) async {
    await tester.pumpWidget(_host(onSubmit: (_) {}));
    for (final letter in ['ç', 'ş', 'ê', 'î', 'û']) {
      final chip = find.byKey(ValueKey('fill-in-blank-diacritic-$letter'));
      expect(chip, findsOneWidget, reason: '$letter düğmesi yok');
      await tester.tap(chip);
      await tester.pump();
    }
    final input = tester.widget<SahneField>(
      find.byKey(const ValueKey('fill-in-blank-input')),
    );
    expect(input.controller!.text, 'çşêîû');
  });
}
