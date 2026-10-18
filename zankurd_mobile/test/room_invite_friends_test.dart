/// Odaya arkadaş daveti: arkadaş listesinden, kod girmeden.
///
/// ## Kusur
///
/// Oda sahibi zaten arkadaş olduğu kişilere de kodu elle iletmek zorundaydı
/// (test kullanıcılarının geri bildirimi): kod kopyala, mesaj uygulamasını
/// aç, yapıştır. Arkadaş listesi ve bildirim altyapısı (düello daveti) hazır
/// olduğu hâlde odaya bağlanmamıştı.
///
/// ## Niçin sessiz kalırdı
///
/// Eksik bir düğme hiçbir hata üretmez; davet katmanları (sayfa, alıcı kartı,
/// bildirim dokunuşu, depo) ayrı ayrı çalışıp aralarındaki sözleşme
/// (reddet -> kart kalkar, süresi dolmuş -> dürüst mesaj, kabul -> MEVCUT
/// katılma yolu) kopabilir. Bu dosya o sözleşmeleri sabitler; sunucu tarafı
/// `oda_davet_sql_test.dart`ta.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/room_invite.dart';
import 'package:zankurd_mobile/src/screens/home/room_invite_card.dart';
import 'package:zankurd_mobile/src/screens/room_invite_friends_sheet.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends TestMockZanKurdRepository {
  _Repo({int friendCount = 3}) : _friendCount = friendCount;

  final int _friendCount;
  final List<List<String>> sent = [];
  final List<String> joined = [];

  @override
  Future<List<Friend>> loadFriends() async => [
    for (var i = 0; i < _friendCount; i++)
      Friend(
        id: 'f$i',
        userId: 'me',
        friendId: 'friend-$i',
        friendName: 'Dost${String.fromCharCode(65 + i)}',
        createdAt: DateTime(2026, 10, 1),
      ),
  ];

  @override
  Future<int> inviteFriendsToRoom(GameRoom room, List<String> friendIds) {
    sent.add(friendIds);
    return super.inviteFriendsToRoom(room, friendIds);
  }

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    joined.add(code);
    return super.joinOnlineRoom(code);
  }
}

RoomInvite _invite({String id = 'inv1', String code = 'ZK-TEST'}) => RoomInvite(
  id: id,
  roomId: 'room-$id',
  roomCode: code,
  inviterId: 'u2',
  inviterName: 'Rojda',
  categoryName: 'Ziman',
  playerCount: 2,
  maxPlayers: 8,
  createdAt: DateTime(2026, 10, 18),
);

GameRoom _room(_Repo repo, {List<Player>? players}) => repo
    .createRoom()
    .copyWith(id: 'room-1', isCustom: true, maxPlayers: 8, players: players);

Widget _sheetHost(_Repo repo, GameRoom room, ValueChanged<int?> onResult) =>
    testShell(
      child: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () async => onResult(
                await showRoomInviteFriendsSheet(context, repo, room),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );

Future<void> _surface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  group('davet sayfası', () {
    testWidgets(
      'çoklu seçim, gönder düğmesi sayıyı söyler ve seçilenleri yollar',
      (tester) async {
        await _surface(tester);
        final repo = _Repo();
        int? result = -1;
        await tester.pumpWidget(
          _sheetHost(repo, _room(repo), (r) => result = r),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();

        final send = find.byKey(const ValueKey('room-invite-send'));
        expect(find.text('Davet gönder (0)'), findsOneWidget);
        // Seçim yokken gönder kapalı.
        await tester.tap(send, warnIfMissed: false);
        await tester.pump();
        expect(repo.sent, isEmpty);

        await tester.tap(
          find.byKey(const ValueKey('room-invite-friend-friend-0')),
        );
        await tester.tap(
          find.byKey(const ValueKey('room-invite-friend-friend-2')),
        );
        await tester.pump();
        expect(find.text('Davet gönder (2)'), findsOneWidget);

        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(repo.sent.single.toSet(), {'friend-0', 'friend-2'});
        expect(result, 2);
      },
    );

    testWidgets('odadaki seçilemez, davet edilmiş olan etiketlenir', (
      tester,
    ) async {
      await _surface(tester);
      final repo = _Repo();
      final room = _room(
        repo,
        players: const [
          Player(id: 'friend-0', name: 'DostA', score: 0, state: 'Hazır'),
        ],
      );
      await repo.inviteFriendsToRoom(room, ['friend-1']);
      repo.sent.clear();
      await tester.pumpWidget(_sheetHost(repo, room, (_) {}));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      expect(find.text('Odada'), findsOneWidget);
      expect(find.text('Davet edildi'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('room-invite-friend-friend-0')),
      );
      await tester.pump();
      // Odadaki seçilemedi: sayı 0 kaldı.
      expect(find.text('Davet gönder (0)'), findsOneWidget);
    });

    testWidgets('arama kutusu 8de yok, 9da var ve süzer', (tester) async {
      await _surface(tester);
      final few = _Repo(friendCount: 8);
      await tester.pumpWidget(_sheetHost(few, _room(few), (_) {}));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-invite-search')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final many = _Repo(friendCount: 9);
      await tester.pumpWidget(_sheetHost(many, _room(many), (_) {}));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      final search = find.byKey(const ValueKey('room-invite-search'));
      expect(search, findsOneWidget);
      await tester.enterText(
        find.descendant(of: search, matching: find.byType(EditableText)),
        'dostc',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('room-invite-friend-friend-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('room-invite-friend-friend-0')),
        findsNothing,
      );
    });

    testWidgets('arkadaşı yoksa boş durum yazılır, gönder yoktur', (
      tester,
    ) async {
      await _surface(tester);
      final repo = _Repo(friendCount: 0);
      await tester.pumpWidget(_sheetHost(repo, _room(repo), (_) {}));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-invite-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('room-invite-send')), findsNothing);
    });
  });

  group('alıcı kartı', () {
    Widget host(_Repo repo) => testShell(
      child: Scaffold(
        body: SingleChildScrollView(child: RoomInviteCard(repository: repo)),
      ),
    );

    testWidgets('davet yokken hiçbir şey çizmez', (tester) async {
      await _surface(tester);
      await tester.pumpWidget(host(_Repo()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-invite-card')), findsNothing);
    });

    testWidgets(
      'davet edenin adı ve oda bilgisi görünür; Reddet kartı kaldırır',
      (tester) async {
        await _surface(tester);
        final repo = _Repo()..seedRoomInviteForTesting(_invite());
        await tester.pumpWidget(host(repo));
        await tester.pumpAndSettle();

        expect(find.text('Rojda seni odaya çağırıyor'), findsOneWidget);
        expect(find.text('Ziman · 2/8 kişi'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('room-invite-decline')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('room-invite-card')), findsNothing);
        expect(repo.joined, isEmpty);
      },
    );

    testWidgets('Katıl daveti kabul edip MEVCUT katılma yoluna kodu verir', (
      tester,
    ) async {
      await _surface(tester);
      final repo = _Repo();
      // Kodun biçimi KAPALI bir dizgedir: geçerli bir kodu depodan alırız.
      final code = repo.createRoom().code;
      repo.seedRoomInviteForTesting(_invite(code: code));
      await tester.pumpWidget(host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('room-invite-join')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(repo.joined, [code]);
      expect(find.byType(RoomScreen), findsOneWidget);
    });

    testWidgets('süresi dolmuş davet dürüst bir mesaj verir ve kart kalkar', (
      tester,
    ) async {
      await _surface(tester);
      final repo = _Repo()
        ..seedRoomInviteForTesting(_invite())
        ..respondRoomInviteFailureForTesting = RoomInviteFailure.expired;
      await tester.pumpWidget(host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('room-invite-join')));
      await tester.pumpAndSettle();

      expect(
        find.text('Bu davetin süresi doldu ya da oda kapandı.'),
        findsOneWidget,
      );
      expect(repo.joined, isEmpty);
      expect(find.byKey(const ValueKey('room-invite-card')), findsNothing);
    });
  });

  group('lobi düğmesi', () {
    testWidgets('kurulu odada çıkar; göç yoksa çıkmaz', (tester) async {
      await _surface(tester);
      for (final supported in [true, false]) {
        final repo = _Repo()..roomInvitesSupportedForTesting = supported;
        await tester.pumpWidget(
          testShell(
            child: RoomScreen(repository: repo, initialRoom: _room(repo)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.byKey(const ValueKey('room-invite-friends')),
          supported ? findsOneWidget : findsNothing,
        );
        // Mevcut paylaşım düğmesi her durumda yerinde.
        expect(find.byKey(const ValueKey('room-invite-share')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    });
  });

  group('depo ve yönlendirme', () {
    test(
      'mock: davet kaydı, kabul kodu döner, ikinci yanıt süresi dolmuş sayılır',
      () async {
        final repo = _Repo();
        final room = _room(repo);
        expect(await repo.inviteFriendsToRoom(room, ['a', 'b', 'a']), 2);
        expect(await repo.loadRoomInvitedIds(room), {'a', 'b'});

        repo.seedRoomInviteForTesting(_invite());
        expect(await repo.respondRoomInvite('inv1', accept: true), 'ZK-TEST');
        expect(
          () => repo.respondRoomInvite('inv1', accept: true),
          throwsA(
            isA<RoomInviteException>().having(
              (e) => e.reason,
              'reason',
              RoomInviteFailure.expired,
            ),
          ),
        );
      },
    );

    test('sunucu mesajları sebebe eşlenir', () {
      expect(
        RoomInviteException.reasonForMessage('Invite expired'),
        RoomInviteFailure.expired,
      );
      expect(
        RoomInviteException.reasonForMessage('Room is full'),
        RoomInviteFailure.full,
      );
      expect(
        RoomInviteException.reasonForMessage('Too many invites'),
        RoomInviteFailure.tooMany,
      );
      expect(
        RoomInviteException.reasonForMessage('timeout'),
        RoomInviteFailure.unknown,
      );
    });

    test('RoomInvite.fromJson sunucu alanlarını okur', () {
      final invite = RoomInvite.fromJson({
        'invite_id': 'i',
        'room_id': 'r',
        'room_code': 'ZK-X',
        'inviter_id': 'u',
        'inviter_name': 'Rojda',
        'category_name': 'Ziman',
        'player_count': 3,
        'max_players': 8,
        'created_at': '2026-10-18T10:00:00Z',
      });
      expect(invite.roomCode, 'ZK-X');
      expect(invite.playerCount, 3);
      expect(invite.maxPlayers, 8);
    });

    test('room_invite bildirimi davet hedefine gider', () {
      expect(
        PushTapRouter.targetForKind('room_invite'),
        PushTapTarget.roomInvite,
      );
    });
  });
}
