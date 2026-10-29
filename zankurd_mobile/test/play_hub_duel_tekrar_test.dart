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
      find.descendant(of: tile, matching: find.text('Düello başlat')),
      findsOneWidget,
    );
    // Eyleme çevrilebilir bilgi üstte kalır (kurul C30: rozet "Devam et").
    expect(find.text('Devam et'), findsWidgets);
  });

  testWidgets('sırası bende düello yoksa kartta rozet yok', (tester) async {
    await _pumpHub(tester, pendingDuel: false);
    final tile = find.byKey(const ValueKey('play-hub-async-duel'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('Düello başlat')),
      findsNothing,
    );
    expect(
      find.descendant(of: tile, matching: find.text('Sıra sende')),
      findsNothing,
    );
  });

  // 2026-10-28 kurul K3/K5 (eski "çark dolgulu Zêr kart" beklentisi
  // DEĞİŞTİ): Sırayla düello ve Oda eşit boyutlu iki SAKİN karttır; Günün
  // turu ve Günün çarkı Arkadaşlar/Turnuva ile aynı standart liste satırı.
  testWidgets('sırayla düello ve oda eşit; günün turu ve çark standart satır', (
    tester,
  ) async {
    await _pumpHub(tester, pendingDuel: false);
    final big = tester.getSize(
      find.byKey(const ValueKey('play-hub-async-duel')),
    );
    final room = tester.getSize(find.byKey(const ValueKey('play-hub-room')));
    expect(big.height, greaterThanOrEqualTo(SahneModeTile.minHeight));
    expect(room.height, closeTo(big.height, 0.5), reason: 'eşit boy');
    expect(room.width, closeTo(big.width, 0.5), reason: 'eşit en');
    for (final key in ['play-hub-daily-contest', 'play-hub-spin-wheel']) {
      final finder = find.byKey(ValueKey(key));
      expect(tester.widget(finder), isA<SahneListRow>(), reason: key);
      expect(
        find.descendant(of: finder, matching: find.byType(FilledButton)),
        findsNothing,
        reason: key,
      );
    }
    // 2026-10-29 G2 (canlılık katmanı): sakin pastel kart değil, doygun
    // LOBİ kartı (rolün degradesi + cam ikon rozeti); turuncu değil.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('play-hub-room')),
        matching: find.byKey(const ValueKey('mode-tile-lobby')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Yarış merkezinde tek turuncu birincil düğme var', (
    tester,
  ) async {
    await _pumpHub(tester, pendingDuel: false);
    // Ekranın birincil eylemi "Rakip seç"tir; başka dolgulu birincil düğme
    // (SahneButton.primary) çizilmez.
    final primaries = find.byWidgetPredicate(
      (w) => w is SahneButton && w.isPrimary,
    );
    expect(primaries, findsOneWidget);
  });
}
