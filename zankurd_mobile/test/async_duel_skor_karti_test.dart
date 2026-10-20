// 7. tasarım kurulu (2026-10-20): sıralı düello zafer ekranının alt yarısı
// boştu; tek "+130 XP" kartı vardı, "kime karşı kaç doğru" yalnız başlık
// altındaki tek satırda okunuyordu (Opus + ChatGPT).
//
// ## Niçin sessiz kalırdı
//
// Boş alan hata değildir: sonuç metni, XP kartı ve düğmeler doğru çıkıyordu,
// bütün sonuç testleri yeşildi. Bekçi iki oyunculu skor kartının tamamlanmış
// düelloda var, bekleyen/yarım düelloda YOK olduğunu sabitler (rakibin sayısı
// bilinmeyen durumda "0/7" uydurulmaz) ve kartın iki doğru sayısını modeldeki
// değerlerden gösterdiğini doğrular.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';

import 'support/widget_test_helpers.dart';

AsyncDuelSummary _summary(AsyncDuelStatus status, {int? theirs}) =>
    AsyncDuelSummary(
      duelId: 'd-$status',
      status: status,
      role: AsyncDuelRole.opponent,
      opponentName: 'Rojda',
      myCorrect: 5,
      opponentCorrect: theirs,
      outcome: theirs == null ? null : AsyncDuelOutcome.win,
      createdAt: DateTime.utc(2026, 9, 27),
      seen: true,
    );

void main() {
  Future<void> open(WidgetTester tester, AsyncDuelSummary s) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: AsyncDuelResultScreen(
          repository: freshMockRepository(),
          view: AsyncDuelResultView.fromSummary(s),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tamamlanan düelloda iki oyunculu skor kartı gerçek sayıları '
      'gösterir', (tester) async {
    await open(tester, _summary(AsyncDuelStatus.completed, theirs: 3));
    final card = find.byKey(const ValueKey('async-duel-result-scoreboard'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('5/7')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('3/7')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Rojda')),
      findsOneWidget,
    );
  });

  testWidgets('rakip sayısı bilinmezken skor kartı çizilmez', (tester) async {
    await open(tester, _summary(AsyncDuelStatus.open));
    expect(
      find.byKey(const ValueKey('async-duel-result-scoreboard')),
      findsNothing,
    );
  });
}
