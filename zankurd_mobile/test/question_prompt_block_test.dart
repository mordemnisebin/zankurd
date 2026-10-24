import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/question_prompt_block.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Soru başlığı ayrıştırması ekranda: yönerge, cümle, ipucu, çeviri ayrı
/// satırlar; kelime sıralamada Türkçe kaynak kutusu "TR → KU" rozeti taşır.
/// Dar ekran (320) ve büyük yazıda (2x) taşma olmaz.
const _fill = QuizQuestion(
  id: 'f1',
  category: 'Ziman',
  prompt: 'Hevokê temam bike: "Ev ___ e. (cihê jiyanê)" ("Bu evdir.")',
  answers: ['mal'],
  correctAnswer: 'mal',
  explanation: '',
  type: QuestionType.fillInBlank,
);

const _order = QuizQuestion(
  id: 'o1',
  category: 'Ziman',
  prompt: 'Hevokê rêz bike: "Ben öğretmenim."',
  answers: ['Ez', 'mamoste', 'me'],
  correctAnswer: 'Ez mamoste me',
  explanation: '',
  type: QuestionType.wordOrdering,
  hintKu: 'Bi peyva "ez" dest pê bike.',
);

Future<void> _pump(
  WidgetTester t,
  QuizQuestion q, {
  double width = 320,
  double scale = 2,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = Size(width, 800);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: QuestionPromptBlock.tryBuild(
              question: q,
              promptText: q.prompt,
            )!,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('boşluk doldurma: yönerge, cümle, ipucu, çeviri ayrı', (t) async {
    await _pump(t, _fill);
    expect(find.byKey(const ValueKey('prompt-instruction')), findsOneWidget);
    expect(find.byKey(const ValueKey('prompt-main')), findsOneWidget);
    expect(find.text('cihê jiyanê'), findsOneWidget);
    expect(find.text('Bu evdir.'), findsOneWidget);
    expect(find.byKey(const ValueKey('prompt-source-badge')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('kelime sıralama: Türkçe kaynak kutusu ve TR → KU rozeti', (
    t,
  ) async {
    await _pump(t, _order);
    expect(find.byKey(const ValueKey('prompt-source-box')), findsOneWidget);
    expect(find.text('TR → KU'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('kalıba uymayan soru için blok kurulmaz', (t) async {
    const plain = QuizQuestion(
      id: 'p',
      category: 'Ziman',
      prompt: 'Paytexta Fransa kîjan e?',
      answers: ['Parîs', 'Roma'],
      correctAnswer: 'Parîs',
      explanation: '',
    );
    expect(
      QuestionPromptBlock.tryBuild(question: plain, promptText: plain.prompt),
      isNull,
    );
  });
}
