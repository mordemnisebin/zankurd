import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/word_ordering_widget.dart';

/// Cümle kurma ipucu ekranda görünür (2026-10-15).
///
/// ## Kusur
///
/// Bankadaki 126 cümle kurma sorusu `hintKu`/`hintTr` taşıyordu
/// («"ez" sözcüğüyle başla.») ama hiçbir ekran bunları çizmiyordu; ipucu
/// yazan içerik emeği oyuncuya hiç ulaşmadı.
///
/// ## Niçin sessiz kaldı
///
/// Alan modelde, JSON'da ve kopyalama kodunda doğruydu; "veri var mı"
/// testleri geçiyordu. Hiçbir test "ipucu ekranda çıkıyor mu" diye
/// sormuyordu — okunmayan bir alan hata üretmez.
///
/// ## Bekçi
///
/// İpucu seçili dilde, cevap verilmeden önce, 320 px ve 2× yazıda taşmadan
/// görünür; cevaptan sonra kalkar; her ipuculu soru iki dilde de ipucu taşır.
const _q = QuizQuestion(
  id: 'wo-hint',
  category: 'Ziman',
  prompt: 'Hevokê rêz bike',
  answers: ['Ez', 'diçim', 'malê'],
  correctAnswer: 'Ez diçim malê',
  explanation: '',
  type: QuestionType.wordOrdering,
  hintKu: 'Bi peyva "ez" dest pê bike.',
  hintTr: '"ez" sözcüğüyle başla.',
);

Widget _host(
  String lang, {
  bool disabled = false,
  double scale = 1,
  String? selectedAnswer,
}) => ChangeNotifierProvider(
  create: (_) => LanguageProvider(initialLang: lang),
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: WordOrderingWidget(
          question: _q,
          disabled: disabled,
          selectedAnswer: selectedAnswer,
          onAnswerSubmitted: (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('ipucu Türkçe ekranda Türkçe görünür', (tester) async {
    await tester.pumpWidget(_host('tr'));
    expect(find.text('"ez" sözcüğüyle başla.'), findsOneWidget);
    expect(find.text('Bi peyva "ez" dest pê bike.'), findsNothing);
  });

  testWidgets('ipucu Kurmancî ekranda Kurmancî görünür', (tester) async {
    await tester.pumpWidget(_host('ku'));
    expect(find.text('Bi peyva "ez" dest pê bike.'), findsOneWidget);
  });

  testWidgets('cevap verilince ipucu kalkar', (tester) async {
    await tester.pumpWidget(
      _host('tr', disabled: true, selectedAnswer: 'Ez diçim malê'),
    );
    expect(find.byKey(const ValueKey('word-ordering-hint')), findsNothing);
  });

  testWidgets('320 px ve 2x yazıda ipucu taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host('tr', scale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final box = tester.getRect(
      find.byKey(const ValueKey('word-ordering-hint')),
    );
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.right, lessThanOrEqualTo(320));
  });

  test('ipuculu her soru iki dilde de ipucu taşır', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await QuestionBankLoader.instance.load();
    final hinted = QuestionBankLoader.instance.allQuestions.where(
      (q) => q.hasHint,
    );
    expect(hinted, isNotEmpty);
    for (final q in hinted) {
      expect(q.hintFor(isKu: true), isNotNull, reason: q.id);
      expect(q.hintFor(isKu: false), isNotNull, reason: q.id);
    }
  });
}
