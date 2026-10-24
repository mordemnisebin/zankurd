/// Yarış sekmesinde "Sıra sende" bilgisi TEK yerde durur.
///
/// ## Kusur
///
/// Üstteki sıra bölümü ("Rüya · Yarım kaldı · Sıra sende · 24 sa kaldı") ile
/// alttaki "Sırayla düello" mod kartı aynı bilgiyi iki kez söylüyordu:
/// ikisi de "Sıra sende" rozeti taşıyordu (2026-10-24 simülatör turu).
///
/// ## Niçin sessiz kalırdı
///
/// İki yüzey ayrı kaynaktan beslenir ve ikisi de doğru çalışır; tekrar bir
/// derleme/mantık hatası değil bir tasarım kusurudur, hiçbir test onu
/// sormazdı.
///
/// ## Kural
///
/// * Sırası bende olan düello üstte listelenir ve eyleme çevrilebilir.
/// * "Sırayla düello" kartı, o düello zaten üstte varken "Sıra sende" DEMEZ;
///   nötr "Yeni düello" der (kartın işi yeni düello başlatmaktır).
/// * Sırası bende düello yoksa kartta rozet yoktur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

Future<void> _pumpHub(WidgetTester tester, {required bool pendingDuel}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(600, 3000);
  addTearDown(tester.view.reset);
  final repository = freshMockRepository();
  if (pendingDuel) {
    final start = await repository.startAsyncDuel();
    await repository.answerAsyncDuel(
      duelId: start.duelId,
      questionIndex: 0,
      choice: 'A',
      responseMs: 1000,
    );
  }
  await tester.pumpWidget(
    testShell(
      child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
    ),
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('üstte "Sıra sende" varken mod kartı onu tekrarlamaz', (
    tester,
  ) async {
    await _pumpHub(tester, pendingDuel: true);
    final tile = find.byKey(const ValueKey('play-hub-async-duel'));
    expect(tile, findsOneWidget);

    expect(
      find.descendant(of: tile, matching: find.text('Sıra sende')),
      findsNothing,
      reason: 'aynı bilgi üstteki sıra bölümünde zaten var',
    );
    expect(
      find.descendant(of: tile, matching: find.text('Yeni düello')),
      findsOneWidget,
    );
    // Eyleme çevrilebilir bilgi üstte kalır.
    expect(find.text('Sıra sende'), findsWidgets);
  });

  testWidgets('sırası bende düello yoksa kartta rozet yok', (tester) async {
    await _pumpHub(tester, pendingDuel: false);
    final tile = find.byKey(const ValueKey('play-hub-async-duel'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('Yeni düello')),
      findsNothing,
    );
    expect(
      find.descendant(of: tile, matching: find.text('Sıra sende')),
      findsNothing,
    );
  });

  testWidgets(
    'ikincil modlar (çark) sade; büyük kartlar yalnız oyun seçimleri',
    (tester) async {
      await _pumpHub(tester, pendingDuel: false);
      final big = tester.getSize(
        find.byKey(const ValueKey('play-hub-async-duel')),
      );
      final daily = tester.getSize(
        find.byKey(const ValueKey('play-hub-daily-contest')),
      );
      final wheel = tester.getSize(
        find.byKey(const ValueKey('play-hub-spin-wheel')),
      );
      final room = tester.getSize(find.byKey(const ValueKey('play-hub-room')));
      expect(big.height, greaterThanOrEqualTo(SahneModeTile.minHeight));
      expect(room.height, greaterThanOrEqualTo(SahneModeTile.minHeight));
      // 2026-10-24: büyük kartlar yalnız oyun seçimleri (canlı düello,
      // sırayla düello, oda); günün turu ve çarkı sade tek satır.
      expect(
        daily.height,
        lessThan(SahneModeTile.minHeight * 0.7),
        reason: 'günün turu tek satırlık sade kart',
      );
      expect(
        wheel.height,
        lessThan(SahneModeTile.minHeight * 0.7),
        reason: 'çark tek satırlık sade kart',
      );
      // Renk kimliği korunur: çark hâlâ Zêr dolgulu.
      final fill = tester
          .widget<SahneTappable>(
            find.descendant(
              of: find.byKey(const ValueKey('play-hub-spin-wheel')),
              matching: find.byType(SahneTappable),
            ),
          )
          .color;
      expect(fill, isNotNull);
    },
  );
}
