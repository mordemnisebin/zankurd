/// Bildirim izni kartı BAĞLAMINA uygun metinle sorulur.
///
/// ## Kusur
///
/// Günün turu sonucu, "Sıra sende olunca haber verelim mi?" diye soruyordu:
/// oyuncu tek başına bir tur bitirmişti, sırasını bekleyen rakip yoktu. Bu
/// düelloya özgü bir vaattir ve yanlış yerde sorulunca hem yanıltır hem izin
/// hakkını (iOS bir kez sorar) boşa harcar (2026-10-24 simülatör turu).
///
/// ## Niçin sessiz kalırdı
///
/// Kart tek metinliydi ve her tur sonucunda aynı çiziliyordu; hiçbir derleme
/// ya da birim testi "bu metin bu ekrana uyuyor mu"yu sormaz.
///
/// ## Kural
///
/// * Günün turu sonucu: düello metni ("Sıra sende") YOK; yerine yarınki
///   turun hatırlatması ("Yarın günün turunu hatırlatalım mı?").
/// * Düello metni düello bağlamında kalır: sırayla düello başlatılınca
///   [SocialPushPrompt] sorar (`social_push_prompt_test.dart`) ve kart
///   varsayılan (düello) metniyle çizilir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/social_push_prompt.dart';
import 'package:zankurd_mobile/src/widgets/notification_prompt_card.dart';

import 'support/widget_test_helpers.dart';

const _duelTitle = 'Sıra sende olunca haber verelim mi?';
const _dailyTitle = 'Yarın günün turunu hatırlatalım mı?';

Future<void> _pumpResult(WidgetTester tester, {required bool dailyQuiz}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 6000);
  addTearDown(tester.view.reset);
  // Politika: 2 tur şartı için bir tur önceden sayılmış.
  SharedPreferences.setMockInitialValues({'zankurd.notifPrompt.rounds': 1});
  SocialPushPrompt.resetForTest();
  final repository = MockZanKurdRepository();
  await tester.pumpWidget(
    testShell(
      child: QuizResultScreen(
        repository: repository,
        room: repository.createRoom(),
        score: 500,
        correctCount: 7,
        wrongCount: 3,
        totalQuestions: 10,
        bestStreak: 4,
        coinsAwarded: 10,
        dailyQuiz: dailyQuiz,
        answerRecords: const [],
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('günün turu sonucu: düello metni yok, yarın hatırlatması var', (
    tester,
  ) async {
    await _pumpResult(tester, dailyQuiz: true);
    expect(find.text(_duelTitle), findsNothing);
    expect(find.textContaining('Sıra sende'), findsNothing);
    expect(find.text(_dailyTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('notif-prompt-enable')), findsOneWidget);
  });

  testWidgets('düello dışı sıradan sonuç kartı eski (düello) metniyle kalır', (
    tester,
  ) async {
    await _pumpResult(tester, dailyQuiz: false);
    expect(find.text(_dailyTitle), findsNothing);
    expect(find.text(_duelTitle), findsOneWidget);
  });

  testWidgets('kart: günün turu bayrağı yoksa düello, varsa hatırlatma '
      '(TR + KU)', (tester) async {
    for (final ku in [false, true]) {
      for (final daily in [false, true]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          testShell(
            languageProvider: ku ? kurmanciLang() : null,
            child: Scaffold(
              body: NotificationPromptCard(
                dailyContest: daily,
                onEnable: () {},
                onLater: () {},
              ),
            ),
          ),
        );
        final expected = daily
            ? (ku ? 'Sibê gera rojê bi bîr bixin?' : _dailyTitle)
            : (ku ? 'Dema dora te be, em te agahdar bikin?' : _duelTitle);
        expect(find.text(expected), findsOneWidget, reason: 'ku=$ku d=$daily');
      }
    }
  });

  testWidgets('320 px + %200 yazıda hatırlatma kartı taşmaz', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: NotificationPromptCard(
                  dailyContest: true,
                  onEnable: () {},
                  onLater: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
