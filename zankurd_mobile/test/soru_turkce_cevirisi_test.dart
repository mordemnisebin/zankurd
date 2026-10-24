import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// Soru altında açılır Türkçe çeviri (2026-10-23).
///
/// ## Kusur
///
/// Kullanıcı geri bildirimi: Kurmancîyi hiç bilmeyen biri soruyu anlamadan
/// cevaplıyordu; "altta kapalı, basınca çevirisini gösteren bir şey" istendi.
/// Paketteki her sorunun Türkçesi vardı ama Kurmancî oynayana gösterilmiyordu.
///
/// ## Niçin sessiz kalabilirdi
///
/// Şerit sözlük dokunuşuna bağlansaydı konu karosundan açılan normal turda
/// (sözlük orada kapalı) hiç çıkmazdı; yarışta açık kalsaydı rakibe karşı
/// ipucu olurdu.
///
/// ## Bekçi
///
/// Kurmancî tek kişilik turda şerit kapalı başlar, dokununca Türkçe soru
/// görünür; Türkçe arayüzde ve yarış/oda bayraklarında çıkmaz.
const _q = QuizQuestion(
  id: 'tr-reveal-1',
  category: 'Dîrok',
  prompt: 'Mîrektiya Botanê li kîjan bajarî bû?',
  promptTr: 'Botan Beyliği hangi şehirdeydi?',
  answers: ['Cizîr', 'Amed', 'Wan', 'Bedlîs'],
  correctAnswer: 'Cizîr',
  explanation: '',
  type: QuestionType.multipleChoice,
);

Future<void> _open(WidgetTester tester, {required bool ku}) async {
  final repository = freshMockRepository();
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: const [_q],
        enableTimer: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Kurmancî tek kişilik tur: kapalı başlar, dokununca açılır', (
    tester,
  ) async {
    await _open(tester, ku: true);
    final toggle = find.byKey(const ValueKey('prompt-tr-toggle'));
    expect(toggle, findsOneWidget);
    expect(find.text('Botan Beyliği hangi şehirdeydi?'), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Botan Beyliği hangi şehirdeydi?'), findsOneWidget);
    expect(toggle, findsNothing);
  });

  testWidgets('Türkçe arayüzde şerit yok (soru zaten Türkçe)', (tester) async {
    await _open(tester, ku: false);
    expect(find.byKey(const ValueKey('prompt-tr-toggle')), findsNothing);
  });

  test('yarış, düello, günün soruları ve oda: kapalı', () {
    bool allowed({
      bool is1v1 = false,
      bool botRace = false,
      bool dailyQuiz = false,
      bool contest = false,
      bool versus = false,
      bool onlineRoom = false,
    }) => translationRevealAllowedFor(
      is1v1: is1v1,
      botRace: botRace,
      dailyQuiz: dailyQuiz,
      contest: contest,
      versus: versus,
      onlineRoom: onlineRoom,
    );
    expect(allowed(), isTrue);
    expect(allowed(is1v1: true), isFalse);
    expect(allowed(botRace: true), isFalse);
    expect(allowed(dailyQuiz: true), isFalse);
    expect(allowed(contest: true), isFalse);
    expect(allowed(versus: true), isFalse);
    expect(allowed(onlineRoom: true), isFalse);
  });
}
