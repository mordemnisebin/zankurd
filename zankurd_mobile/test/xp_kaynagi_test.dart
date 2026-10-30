import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';

import 'support/widget_test_helpers.dart';

/// Sonuç ekranı XP'nin kaynağını söyler (Opus–Astra kapışması U19,
/// 2026-10-29).
///
/// Kusur: çevrimiçi turda XP sunucuda yarış puanının kendisidir
/// (`award_room_xp`, 0..2000); sonuç "+539 XP" deyip kaynağını söylemiyordu
/// ve sırayla düellonun "20 XP/doğru"suyla çelişiyor gibi okunuyordu.
/// SSS de pratik turunun jeton vermediğini ve solo günlük tavanı (45)
/// söylemiyordu.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpResult(WidgetTester tester, {required bool online}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);
    final repository = MockZanKurdRepository();
    final base = repository.createRoom();
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: online ? base.copyWith(id: 'room-1') : base,
          score: 539,
          correctCount: 3,
          wrongCount: 6,
          totalQuestions: 10,
          bestStreak: 2,
          coinsAwarded: 20,
          answerRecords: const [
            AnswerRecord(
              id: 'q1',
              category: 'Ziman',
              prompt: 'Soru?',
              answers: ['A', 'B', 'C', 'D'],
              correctAnswer: 'A',
              selectedAnswer: 'A',
              explanation: 'A.',
            ),
          ],
          opponents: online
              ? const [
                  Player(id: 'o', name: 'QaAlı', score: 300, state: 'Online'),
                ]
              : const [],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final header = find.descendant(
      of: find.byKey(const ValueKey('result-details-section')),
      matching: find.byKey(const ValueKey('result-collapsible-header')),
    );
    await tester.scrollUntilVisible(
      header,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Görünüm sınırına gelmesi alt eylem perdesinin üstünde olduğu anlamına
    // gelmez. Başlığı kaydırılabilir alanın üst yarısına alıp gerçekten dokun.
    await Scrollable.ensureVisible(
      tester.element(header.first),
      alignment: 0.25,
    );
    await tester.pump();
    expect(header.hitTestable(), findsOneWidget);
    await tester.tap(header.first);
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('çevrimiçi turda ayrıntılar "XP = yarış puanı" der', (
    tester,
  ) async {
    await pumpResult(tester, online: true);
    expect(find.byKey(const ValueKey('result-xp-source')), findsOneWidget);
    expect(
      find.text('Çevrimiçi oyunda XP, yarış puanın kadardır (en çok 2000).'),
      findsOneWidget,
    );
  });

  testWidgets('tek kişilik turda bu satır yok (formül farklı)', (tester) async {
    await pumpResult(tester, online: false);
    expect(find.byKey(const ValueKey('result-xp-source')), findsNothing);
  });

  test('SSS jeton cevabı pratik/tavan kuralını söyler', () {
    final a = Tr.of(K.faqCoinsA, AppLanguage.tr);
    expect(a, contains('Yanlış tekrarı turu jeton vermez'));
    expect(a, contains('45'));
  });
}
