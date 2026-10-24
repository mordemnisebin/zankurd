/// Süre dolunca ekranda `TIMEOUT` yazmamalı.
///
/// ## Kusur
///
/// Mağaza ekran görüntüsü turunda (2026-10-13, gerçek uygulama) "Günün
/// soruları"nda cümle kurma sorusunda (Soru 3/10) süre dolunca cevap
/// kutusuna İngilizce `TIMEOUT` yazıldı. Süre dolumu istemcide, cevap
/// yerine geçen 'TIMEOUT' anahtarıyla işlenir (şıklı sorularda hiçbir şık
/// ona eşit olmadığı için görünmez). `WordOrderingWidget` ise cevaptan sonra
/// `selectedAnswer`ı OLDUĞU GİBİ kullanıcının cümlesi diye basıyordu;
/// `FillInBlankWidget` de devam edilen turda aynı anahtarı yazı alanına
/// dolduruyordu.
///
/// ## Niçin sessiz kaldı
///
/// Şıklı soru, bankanın büyük çoğunluğudur ve onlarda anahtar hiçbir yerde
/// metin olarak çizilmez. Süre dolumunu sınayan testler yalnız şıklı soruyla
/// kuruluydu ve çağrıldığını (`QuizTimeoutNotice`) doğruluyordu; serbest
/// cevaplı iki tür (cümle kurma, boşluk doldurma) için "ham anahtar
/// çizilmez" diye bir beklenti yoktu. Sentinel'in metin gibi çizilebileceği
/// yer yalnız bu iki widget'tı ve ikisinin de kendi testi `selectedAnswer`ı
/// gerçek bir cevap varsayıyordu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/fill_in_blank_widget.dart';
import 'package:zankurd_mobile/src/screens/quiz/word_ordering_widget.dart';

const _ordering = QuizQuestion(
  id: 'timeout-wo',
  category: 'Ziman',
  prompt: 'Hevokê rêz bike',
  answers: ['Ez', 'diçim', 'malê'],
  correctAnswer: 'Ez diçim malê',
  explanation: '',
  type: QuestionType.wordOrdering,
);

const _fill = QuizQuestion(
  id: 'timeout-fill',
  category: 'Ziman',
  prompt: 'Valahiya tije bike: Ez ___ dixwim.',
  answers: [],
  correctAnswer: 'nan',
  explanation: '',
  type: QuestionType.fillInBlank,
);

Widget _host(String lang, Widget child) => ChangeNotifierProvider(
  create: (_) => LanguageProvider(initialLang: lang),
  child: MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Widget _ordered({String? selected, bool disabled = true}) => WordOrderingWidget(
  key: const ValueKey('wo'),
  question: _ordering,
  disabled: disabled,
  selectedAnswer: selected,
  onAnswerSubmitted: (_) {},
);

void main() {
  group('cümle kurma', () {
    testWidgets('süre dolunca ham anahtar değil "Süre doldu" yazar (TR)', (
      tester,
    ) async {
      await tester.pumpWidget(_host('tr', _ordered(selected: 'TIMEOUT')));
      expect(find.text('TIMEOUT'), findsNothing);
      expect(find.text('Süre doldu'), findsOneWidget);
    });

    testWidgets('süre dolunca "Dem qediya" yazar (KU)', (tester) async {
      await tester.pumpWidget(_host('ku', _ordered(selected: 'TIMEOUT')));
      expect(find.text('TIMEOUT'), findsNothing);
      expect(find.text('Dem qediya'), findsOneWidget);
    });

    testWidgets('süre dolmadan kurulan parça cümle korunur', (tester) async {
      // Kelime seçilir, sonra (süre dolumunu taklit ederek) widget aynı
      // State ile `disabled` + 'TIMEOUT' alır.
      Widget build({required bool timedOut}) => _host(
        'tr',
        _ordered(selected: timedOut ? 'TIMEOUT' : null, disabled: timedOut),
      );
      await tester.pumpWidget(build(timedOut: false));
      await tester.tap(find.text('Ez'));
      await tester.pump();
      await tester.tap(find.text('diçim'));
      await tester.pump();

      await tester.pumpWidget(build(timedOut: true));
      expect(find.text('TIMEOUT'), findsNothing);
      expect(find.text('Ez diçim'), findsOneWidget);
    });

    testWidgets('gerçek cevap olduğu gibi gösterilir', (tester) async {
      await tester.pumpWidget(_host('tr', _ordered(selected: 'Ez diçim malê')));
      expect(find.text('Ez diçim malê'), findsOneWidget);
      expect(find.text('Süre doldu'), findsNothing);
    });
  });

  group('boşluk doldurma', () {
    testWidgets('devam edilen turda yazı alanına TIMEOUT dolmaz', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          'tr',
          FillInBlankWidget(
            key: const ValueKey('fill'),
            question: _fill,
            disabled: true,
            showResult: true,
            selectedAnswer: 'TIMEOUT',
            onAnswerSubmitted: (_) {},
          ),
        ),
      );
      expect(find.text('TIMEOUT'), findsNothing);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, isEmpty);
    });
  });
}
