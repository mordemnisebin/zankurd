/// Türkçe arayüzde Türkçe metni olmayan (çevrimiçi) sorunun "Kurmancî"
/// etiketinin bekçisi.
///
/// ## Kusur
///
/// Oda/düello soruları sunucudan `fromServerRow` ile gelir ve YALNIZ Kurmancî
/// `prompt` taşır (`questions` tablosunda Türkçe metin sütunu yok). Türkçe
/// seçen oyuncu hiçbir işaret olmadan Kurmancî soru görüyordu; bu bir arıza
/// gibi duruyordu.
///
/// ## Niçin sessizdi
///
/// `promptFor` çeviri yoksa Kurmancî'ye düşer ve bu bilerek böyledir ("eksik
/// çeviri boş ekrandan iyidir"). Düşüşün kendisi hiçbir yerde görünmüyordu,
/// bu yüzden ne hata ne test onu yakaladı.
///
/// ## Bekçi
///
/// Türkçesi olmayan soru Türkçe arayüzde etiket taşır, Türkçesi olan ve
/// Kurmancî arayüz taşımaz; etiket 375×667'de soruyu kaydırmaya zorlamaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

const _tagKey = ValueKey('prompt-kurmanci-tag');

QuizQuestion _server() => QuizQuestion.fromServerRow({
  'id': '00000000-0000-4000-8000-000000000001',
  'category_name': 'Dîrok',
  'prompt': 'Mîrektiya Botanê li kîjan bajarî bû?',
  'option_a': 'Cizîr',
  'option_b': 'Amed',
  'option_c': 'Wan',
  'option_d': 'Bedlîs',
  'question_type': 'multiple_choice',
});

const _translated = QuizQuestion(
  id: 'tr-1',
  category: 'Dîrok',
  prompt: 'Mîrektiya Botanê li kîjan bajarî bû?',
  promptTr: 'Botan Beyliği hangi şehirdeydi?',
  answers: ['Cizîr', 'Amed', 'Wan', 'Bedlîs'],
  correctAnswer: 'Cizîr',
  explanation: '',
);

Future<void> _open(
  WidgetTester tester,
  QuizQuestion q, {
  required bool ku,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 667));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repository = freshMockRepository();
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: [q],
        enableTimer: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('sunucu satırı Türkçe metin taşımaz ve düşüşü bildirir', () {
    final q = _server();
    expect(q.promptTr, isNull);
    expect(q.promptFallsBackToKurmanci, isTrue);
    expect(_translated.promptFallsBackToKurmanci, isFalse);
  });

  testWidgets('TR arayüz + Türkçesiz soru: etiket var, soru Kurmancî', (
    tester,
  ) async {
    await _open(tester, _server(), ku: false);
    expect(find.byKey(_tagKey), findsOneWidget);
    expect(find.textContaining('Mîrektiya Botanê'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Etiket 375×667'de soruyu kaydırmaya zorlamaz.
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('quiz-portrait-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, 0);
  });

  testWidgets('uzun Türkçesiz soru etiketle de 375×667\'ye kaydırmasız sığar', (
    tester,
  ) async {
    final long = QuizQuestion.fromServerRow({
      'id': '00000000-0000-4000-8000-000000000002',
      'category_name': 'Dîrok',
      'prompt':
          'Di sedsala nozdehan de li herêma Botanê, kîjan mîrê Kurd '
          'bi hêza xwe ya leşkerî û bi pergala xwe ya îdarî navdar bû?',
      'option_a': 'Bedirxan Beg, mîrê Cizîrê û Botanê',
      'option_b': 'Mîr Mihemedê Rewandizî ji Soranê',
      'option_c': 'Evdirehman Paşayê Baban ê Silêmaniyê',
      'option_d': 'Şerefxanê Bedlîsî, nivîskarê Şerefname',
      'question_type': 'multiple_choice',
    });
    await _open(tester, long, ku: false);
    expect(find.byKey(_tagKey), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('quiz-portrait-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, 0);
  });

  testWidgets('TR arayüz + Türkçeli soru: etiket yok', (tester) async {
    await _open(tester, _translated, ku: false);
    expect(find.byKey(_tagKey), findsNothing);
  });

  testWidgets('KU arayüz: etiket yok', (tester) async {
    await _open(tester, _server(), ku: true);
    expect(find.byKey(_tagKey), findsNothing);
  });
}
