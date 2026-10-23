// Bekçi: sunucudaki engel listesi odada ve yarışta uygulanır (C1).
//
// ## Kusur
// `RoomScreen._blockedPlayerIds` yalnız bellekteydi: ekran açılınca
// sunucudaki `blocked_users` hiç okunmuyordu (`loadBlockedPlayerIds` yalnız
// sıralama ekranında kullanılıyordu). Dün engellenen oyuncu bugün aynı odaya
// girince satırı görünüyor, canlı tepkileri (`type: reaction` yayını) hem
// lobide hem `QuizScreen`de ekrana basılıyordu — engelleyen kişi tam da
// engellediği kişinin mesajını görüyordu.
//
// ## Niçin sessiz kalırdı
// Mevcut bekçi (`room_screen_block_refresh_test`) engeli AYNI oturumda
// verir; sunucudan gelen eski engel hiç denenmedi. Tepkiler hiçbir testte
// gönderen kimliğine göre süzülmüyordu.
//
// ## Kural
// Oda açılırken ve yarış başlarken sunucu engel listesi yüklenir; engelli
// gönderenin tepkisi çizilmez, engelli oyuncunun satırı lobide görünmez.
// Engel listesi okunamazsa ekran bozulmaz (tepkiler gelmeye devam eder).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/widgets/floating_reaction_overlay.dart';

import 'support/widget_test_helpers.dart';

class _BroadcastRepository extends MockZanKurdRepository {
  final StreamController<Map<String, dynamic>> broadcasts =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);
  bool blockedLoadFails = false;

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) =>
      broadcasts.stream;

  @override
  Future<Set<String>> loadBlockedPlayerIds() async {
    if (blockedLoadFails) throw StateError('ağ yok');
    return super.loadBlockedPlayerIds();
  }
}

const _reaction = {
  'type': 'reaction',
  'text': '👏 Destxweş!',
  'sender_id': 'blocked-1',
  'sender_name': 'Berfin',
};

void main() {
  testWidgets('sunucuda engelli oyuncunun satırı lobide görünmez', (
    tester,
  ) async {
    final repository = _BroadcastRepository();
    addTearDown(repository.broadcasts.close);
    await repository.blockPlayer('blocked-1');
    final room = repository.createRoom().copyWith(
      id: 'room-blocked-rows',
      players: const [
        Player(id: 'user', name: 'Sen', score: 0, state: 'Hazır'),
        Player(id: 'blocked-1', name: 'Berfin', score: 0, state: 'Hazır'),
      ],
    );

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(repository: repository, initialRoom: room),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Berfin'), findsNothing);
  });

  testWidgets('engelli gönderenin lobi tepkisi çizilmez', (tester) async {
    final repository = _BroadcastRepository();
    addTearDown(repository.broadcasts.close);
    await repository.blockPlayer('blocked-1');
    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom().copyWith(id: 'room-react-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    repository.broadcasts.add(_reaction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(FloatingReactionOverlay.bubbleKey), findsNothing);
  });

  testWidgets('engelli olmayan gönderenin tepkisi yine çizilir', (
    tester,
  ) async {
    final repository = _BroadcastRepository();
    addTearDown(repository.broadcasts.close);
    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom().copyWith(id: 'room-react-2'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    repository.broadcasts.add(_reaction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(FloatingReactionOverlay.bubbleKey), findsOneWidget);
  });

  testWidgets('engel listesi okunamazsa lobi tepkileri çalışmaya devam eder', (
    tester,
  ) async {
    final repository = _BroadcastRepository()..blockedLoadFails = true;
    addTearDown(repository.broadcasts.close);
    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom().copyWith(id: 'room-react-3'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    repository.broadcasts.add(_reaction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(FloatingReactionOverlay.bubbleKey), findsOneWidget);
  });

  testWidgets('engelli gönderenin yarış içi tepkisi çizilmez', (tester) async {
    final repository = _BroadcastRepository();
    addTearDown(repository.broadcasts.close);
    await repository.blockPlayer('blocked-1');
    final question = repository.questions.first;
    final room = GameRoom(
      id: 'room-quiz-blocked',
      name: '1v1',
      code: 'ZK-BLK',
      category: question.category,
      status: RoomStatus.active,
      questionCount: 1,
      players: const [
        Player(id: 'user', name: 'Sen', score: 0, state: 'Hazır'),
        Player(id: 'blocked-1', name: 'Berfin', score: 0, state: 'Hazır'),
      ],
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: room,
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    repository.broadcasts.add(_reaction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(FloatingReactionOverlay.bubbleKey), findsNothing);
  });
}
