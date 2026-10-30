import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

// Tur 8: eski I6 bekçisi yalnız dolu 4/4 odayı ve güvenli alansız ekranı
// ölçüyordu. Gerçek kırık 4/8 oda, iki davet eylemi ve konuk alt şeridiydi.
class _LobbyRepo extends MockZanKurdRepository {
  _LobbyRepo(this.count, this.host);
  final int count;
  final bool host;

  @override
  String get currentUserId => host ? 'p0' : 'p2';

  @override
  Future<bool> supportsRoomInvites() async => true;

  List<Player> get players => [
    for (var i = 0; i < count; i++)
      Player(
        id: 'p$i',
        name: [
          'QaAzad',
          'QaDlan',
          'QaBero',
          'QaCano',
          'Rojda',
          'Baran',
          'Dilan',
          'Azad',
        ][i],
        score: 0,
        state: Player.readyState,
        joinedAt: DateTime.utc(2026, 10, 30, 12, i),
      ),
  ];

  GameRoom get room => GameRoom(
    id: 't13-lobby',
    name: 'Grup yarışı',
    code: '199302',
    category: 'Tevlihev',
    status: RoomStatus.lobby,
    players: players,
    maxPlayers: 8,
    isCustom: true,
    hostId: 'p0',
    questionCount: 10,
  );

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => players;

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value(players);
}

Future<void> _open(
  WidgetTester tester,
  Size size,
  bool ku,
  Widget child,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: child,
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in const [
    Size(375, 812),
    Size(390, 844),
    Size(402, 874),
    Size(430, 932),
  ]) {
    for (final ku in [false, true]) {
      for (final host in [false, true]) {
        for (var count = 4; count <= 8; count++) {
          testWidgets('T13 lobi ${size.width} ku=$ku host=$host oyuncu=$count', (
            tester,
          ) async {
            final repo = _LobbyRepo(count, host);
            await _open(
              tester,
              size,
              ku,
              RoomScreen(repository: repo, initialRoom: repo.room),
            );
            final list = find.byType(ListView).first;
            final viewport = tester.getRect(list);
            if (count == 4) {
              final fourth = tester.getRect(
                find.byKey(const ValueKey('room-player-tile-4')),
              );
              expect(
                fourth.bottom,
                lessThanOrEqualTo(viewport.bottom - 16),
                reason:
                    'Dördüncü satırın tamamı ilk görünümde alt solmanın üstünde kalmalı.',
              );
            }
            final scroll = tester.state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            );
            final fade = find.descendant(
              of: find.byType(SahneBottomFade),
              matching: find.byWidgetPredicate(
                (w) => w is Positioned && w.bottom == 0 && w.height == 16,
              ),
            );
            expect(
              fade,
              scroll.position.extentAfter > 1 ? findsOneWidget : findsNothing,
            );
            scroll.position.jumpTo(scroll.position.maxScrollExtent);
            await tester.pump();
            await tester.pump();
            final last = tester.getRect(
              find.byKey(ValueKey('room-player-tile-$count')),
            );
            expect(last.bottom, lessThanOrEqualTo(viewport.bottom));
            expect(last.top, greaterThanOrEqualTo(viewport.top));
            expect(scroll.position.extentAfter, 0);
            expect(
              fade,
              findsNothing,
              reason: 'Sona gelince son satır solmamalı.',
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
      testWidgets(
        'T13 günlük çipler ilk görünümde solmanın üstünde ${size.width} ku=$ku',
        (tester) async {
          final repo = MockZanKurdRepository()
            ..sampleDailyEventBoard = const DailyEventBoard(
              participants: 1,
              yesterdayWinner: DailyEventEntry(
                rank: 1,
                name: 'Test ZK',
                correct: 10,
                total: 10,
                seconds: 60,
              ),
            );
          await _open(tester, size, ku, ContestScreen(repository: repo));
          final viewport = tester.getRect(find.byType(CustomScrollView));
          final chips = find.byType(SahneStatChip);
          expect(chips, findsNWidgets(2));
          for (var i = 0; i < 2; i++) {
            expect(
              tester.getRect(chips.at(i)).bottom,
              lessThanOrEqualTo(viewport.bottom - 32),
              reason:
                  'Soru ve süre çipleri alt perdenin solma bandında yarım kalmamalı.',
            );
          }
          final scroll = tester.state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pump();
          await tester.pump();
          expect(
            find.byKey(const ValueKey('sahne-stage-dock-edge')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
