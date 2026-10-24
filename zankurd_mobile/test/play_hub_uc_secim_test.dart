// Yarış sekmesi ÜÇ oyun seçimine indi (2026-10-24, sahibin kararı "Hepsi
// şimdi"): Canlı düello, Sırayla düello, Oda. Eskiden dört kart vardı
// (hızlı düello, sırayla düello, arkadaşına meydan oku, oda kur / kodla
// katıl) ve oyuncu "hangisi ne?" diye duruyordu. Kusur: "kiminle?" ve
// "nasıl?" soruları karışıktı. Sessiz kalan risk: bir giriş taşınırken
// işlevi kaybolur. Bu bekçi her eski girişin yeni yolunu çağrıyla sınar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/play_hub_nav.dart';
import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  int? maxPlayers;
  int createCalls = 0;

  @override
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
    int questionCount = 10,
    int entryFee = 0,
    int maxPlayers = 2,
  }) {
    createCalls++;
    this.maxPlayers = maxPlayers;
    // Sahte oda kimliksiz gelir; davet yalnız kimlikli odada açılır.
    return super
        .createOnlineRoom(
          category: category,
          secondsPerQuestion: secondsPerQuestion,
          questionCount: questionCount,
          entryFee: entryFee,
          maxPlayers: maxPlayers,
        )
        .then((r) => r.copyWith(id: "room-1"));
  }
}

Future<_Repo> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repo = _Repo();
  await tester.pumpWidget(
    testShell(child: PlayHubScreen(repository: repo, asyncDuelEnabled: true)),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('canlı düello: rakip sayfası Rastgele ve Arkadaş sunar', (
    tester,
  ) async {
    await _pump(tester);
    await openLiveOpponentSheet(tester);
    expect(
      find.byKey(const ValueKey('play-hub-opponent-sheet-live')),
      findsOneWidget,
    );
    expect(find.text('Rastgele'), findsOneWidget);
    expect(find.text('Arkadaş'), findsOneWidget);
  });

  testWidgets('canlı düello > Rastgele eşleşme ekranını açar', (tester) async {
    await _pump(tester);
    await openLiveOpponentSheet(tester);
    await tester.tap(find.byKey(const ValueKey('opponent-sheet-random')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MatchmakingScreen), findsOneWidget);
  });

  testWidgets(
    'canlı düello > Arkadaş: kapasite seçimi yok, iki kişilik oda kurulur, '
    'oda daveti kendiliğinden açılır',
    (tester) async {
      final repo = await _pump(tester);
      await openLiveOpponentSheet(tester);
      await tester.tap(find.byKey(const ValueKey('opponent-sheet-friend')));
      await tester.pumpAndSettle();
      // Kapasite çipleri gizli: iki kişilik oda SABİT.
      expect(
        find.byKey(const ValueKey('custom-room-capacity-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('custom-room-capacity-8')),
        findsNothing,
      );
      final open = find.byKey(const ValueKey('custom-room-open'));
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(repo.createCalls, 1);
      expect(repo.maxPlayers, 2);
      expect(find.byType(RoomScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('room-invite-sheet')), findsOneWidget);
    },
  );

  testWidgets('sırayla düello: rakip sayfası Rastgele ve Arkadaş sunar', (
    tester,
  ) async {
    await _pump(tester);
    await openAsyncOpponentSheet(tester);
    expect(
      find.byKey(const ValueKey('play-hub-opponent-sheet-async')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('opponent-sheet-random')), findsOneWidget);
    expect(find.byKey(const ValueKey('opponent-sheet-friend')), findsOneWidget);
  });

  testWidgets('sırayla düello > Rastgele düello oyun ekranını açar', (
    tester,
  ) async {
    await _pump(tester);
    await openAsyncOpponentSheet(tester);
    await tester.tap(find.byKey(const ValueKey('opponent-sheet-random')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
  });

  testWidgets('sırayla düello > Arkadaş meydan okuma sayfasını açar', (
    tester,
  ) async {
    await _pump(tester);
    await openAsyncOpponentSheet(tester);
    await tester.tap(find.byKey(const ValueKey('opponent-sheet-friend')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('challenge-sheet')), findsOneWidget);
    // Bağlantı yolu ve arkadaş seçimi ikisi de erişilebilir.
    expect(find.byKey(const ValueKey('challenge-sheet-link')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('challenge-sheet-friend')),
      findsOneWidget,
    );
  });

  testWidgets('oda > Oda kur yedi çipli kapasiteyle ayar sayfasını açar', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await openRoomSheet(tester);
    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();
    // Oda (3+ kişi) akışı değişmedi: kapasite seçimi durur.
    expect(
      find.byKey(const ValueKey('custom-room-capacity-8')),
      findsOneWidget,
    );
    final open = find.byKey(const ValueKey('custom-room-open'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(repo.maxPlayers, GameRoom.defaultCrowdCapacity);
    expect(find.byType(RoomScreen), findsOneWidget);
    // Kalabalık odada oda daveti kendiliğinden AÇILMAZ.
    expect(find.byKey(const ValueKey('room-invite-sheet')), findsNothing);
  });

  testWidgets('oda > Kodla katıl kod alanını açar', (tester) async {
    await _pump(tester);
    await openRoomSheet(tester);
    await tester.tap(find.byKey(const ValueKey('play-hub-join-room')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('play-hub-join-room-code-field')),
      findsOneWidget,
    );
  });

  // Kompakt "Günün çarkı" kartında "Hazır!" rozeti "H…" diye kesiliyordu.
  // Artık rozet nokta göstergesidir; metin ekran okuyucuda kalır.
  for (final scale in [1.0, 2.0]) {
    for (final ku in [false, true]) {
      testWidgets(
        'çark rozeti kesilmez: 320 pt, yazı x$scale, ${ku ? 'ku' : 'tr'}',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await tester.binding.setSurfaceSize(const Size(320, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            testShell(
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: PlayHubScreen(repository: _Repo()),
              ),
              languageProvider: ku ? kurmanciLang() : turkishLang(),
            ),
          );
          await tester.pumpAndSettle();
          final wheel = find.byKey(const ValueKey('play-hub-spin-wheel'));
          await tester.scrollUntilVisible(wheel, 200);
          expect(
            find.descendant(
              of: wheel,
              matching: find.byKey(const ValueKey('mode-tile-badge-dot')),
            ),
            findsOneWidget,
          );
          expect(find.textContaining('…'), findsNothing);
          expect(
            tester.getSemantics(wheel).label,
            contains(ku ? 'Amade ye!' : 'Hazır!'),
          );
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }

  testWidgets('eski "Arkadaşına meydan oku" kartı yok', (tester) async {
    await _pump(tester);
    expect(
      find.byKey(const ValueKey('play-hub-async-duel-challenge')),
      findsNothing,
    );
    expect(find.text('Arkadaşına meydan oku'), findsNothing);
    expect(find.text('Oda kur'), findsNothing);
    expect(find.text('Kodla katıl'), findsNothing);
  });
}
