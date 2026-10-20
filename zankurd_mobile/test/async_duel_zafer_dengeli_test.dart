// 2026-10-20 TASARIM KURULU (tur 9b): sıralı düello zafer ekranı dikey denge.
//
// ## Kusur
//
// Skor ve ödül kartlarından sonra ekranın ~%35'i boştu: içerik üstten
// dizilip alt perdeye kadar boşluk bırakıyordu; taç ve skor da küçüktü
// (Opus + ChatGPT).
//
// ## Niçin sessiz kalırdı
//
// Boş alan hata değildir; metin, kart ve düğme testleri yeşildi. Bekçi
// (1) taç ≥ 64 ve skor ≥ 32 punto, (2) içerik grubunun gövdede dikey
// ortalandığı (üst ve alt boşluk birbirine yakın), (3) kartlar arası
// boşlukların 16-24 olduğunu ölçer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('zafer: büyük taç/skor, grup dikeyde dengeli, boşluklar 16-24', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: AsyncDuelResultScreen(
          repository: freshMockRepository(),
          view: AsyncDuelResultView.fromSummary(
            AsyncDuelSummary(
              duelId: 'd1',
              status: AsyncDuelStatus.completed,
              role: AsyncDuelRole.opponent,
              opponentName: 'Rojda',
              myCorrect: 5,
              opponentCorrect: 3,
              outcome: AsyncDuelOutcome.win,
              createdAt: DateTime.utc(2026, 9, 27),
              seen: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final crown = tester.getRect(find.byType(SahneGlyph).first);
    expect(crown.height, greaterThanOrEqualTo(64));
    final score = tester.widget<Text>(find.textContaining('Sen 5 – 3'));
    expect(score.style?.fontSize, greaterThanOrEqualTo(32));

    final board = tester.getRect(
      find.byKey(const ValueKey('async-duel-result-scoreboard')),
    );
    final reward = tester.getRect(find.byType(SahneResultRewards));
    final gap = reward.top - board.bottom;
    expect(gap, inInclusiveRange(16, 24));

    // Grup: taçtan ödül kartının altına. Üst boşluk (üst satırın altından
    // taca) ile alt boşluk (ödülden alt perdeye) birbirine yakın olmalı.
    final dock = tester.getRect(find.byType(SahneResultDock));
    final topBar = tester.getRect(
      find.byIcon(Icons.close).evaluate().isEmpty
          ? find.byType(SahneResultScaffold)
          : find.byIcon(Icons.close),
    );
    final emptyBelow = dock.top - reward.bottom;
    final emptyAbove = crown.top - (topBar.bottom.clamp(0, 120));
    expect(
      emptyBelow,
      lessThan(dock.top * 0.30),
      reason: 'ekranın büyük bölümü artık boş kalmaz',
    );
    expect((emptyBelow - emptyAbove).abs(), lessThan(160));
  });
}
