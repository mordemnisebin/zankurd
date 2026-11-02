// T3 (k4) lobi sohbeti görünürlüğü bekçisi.
//
// Eksik olan: sohbet paneli kapalıyken kimse mesaj akışını dinlemiyordu;
// lobideki oyuncu biri yazdığını ancak paneli açınca (ve kalabalık odada
// ekranın dışında) görüyordu. Bu bekçiler dört davranışı sabitler:
//  1. gelen mesaj gönderenin satırında balon olarak çıkar, ~4 sn sonra söner,
//  2. sohbet simgesinde okunmamış sayısı çıkar, sohbet açılınca sıfırlanır,
//  3. oyuncu listesinin altındaki şerit son mesajı gösterir, dokununca sohbet açar,
//  4. hızlı tepke tek dokunuşla sohbet mesajı olarak gider.
// Tam ekran sohbet kendiliğinden ASLA açılmaz.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room_message.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/widgets/room_chat.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  final stream = StreamController<List<RoomMessage>>.broadcast();
  final sent = <String>[];

  @override
  String? get currentUserId => 'me';

  @override
  Stream<List<RoomMessage>> subscribeRoomMessages(String roomId) =>
      stream.stream;

  @override
  Future<void> sendRoomMessage({
    required String roomId,
    required String text,
  }) async => sent.add(text);
}

RoomMessage _msg(String id, String text, {String sender = 'other'}) =>
    RoomMessage(
      id: id,
      roomId: 'room-hud',
      senderId: sender,
      senderName: 'Berfin',
      text: text,
      createdAt: DateTime.utc(2026, 11, 3, 12, int.parse(id.substring(1))),
    );

Future<_Repo> _open(WidgetTester tester) async {
  final repo = _Repo();
  addTearDown(repo.stream.close);
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = const Size(375, 667) * 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      child: RoomScreen(
        repository: repo,
        initialRoom: repo.createRoom().copyWith(
          id: 'room-hud',
          players: const [
            Player(id: 'me', name: 'Tu', score: 0, state: 'Hazır'),
            Player(id: 'other', name: 'Berfin', score: 0, state: 'Hazır'),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  // İlk anlık görüntü (geçmiş) "yeni" sayılmaz.
  repo.stream.add([_msg('m0', 'eski')]);
  await tester.pump();
  return repo;
}

Future<void> _scrollDown(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -400));
  await tester.pump();
  await tester.drag(find.byType(ListView).first, const Offset(0, -400));
  await tester.pump();
}

void main() {
  testWidgets('gelen mesaj gönderenin satırında balon olur ve söner', (
    tester,
  ) async {
    final repo = await _open(tester);
    repo.stream.add([_msg('m0', 'eski'), _msg('m1', 'Silav heval')]);
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-bubble')), findsOneWidget);
    expect(find.byType(RoomChat), findsNothing, reason: 'sohbet açılmaz');
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(const ValueKey('chat-bubble')), findsNothing);
  });

  testWidgets('rozet okunmamışı sayar, sohbet açılınca temizlenir', (
    tester,
  ) async {
    final repo = await _open(tester);
    expect(find.byKey(const ValueKey('chat-unread-badge')), findsNothing);
    repo.stream.add([_msg('m1', 'bir')]);
    await tester.pump();
    repo.stream.add([_msg('m1', 'bir'), _msg('m2', 'iki')]);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('chat-unread-badge')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('room-chat-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-unread-badge')), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('şerit son mesajı gösterir ve dokununca sohbeti açar', (
    tester,
  ) async {
    final repo = await _open(tester);
    repo.stream.add([_msg('m1', 'Hazır olun')]);
    await tester.pump();
    final strip = find.byKey(const ValueKey('chat-last-strip'));
    await _scrollDown(tester);
    expect(
      find.descendant(of: strip, matching: find.textContaining('Hazır olun')),
      findsOneWidget,
    );
    await tester.tap(strip);
    await tester.pump();
    expect(find.byType(RoomChat), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('hızlı tepki sohbet mesajı olarak gönderilir', (tester) async {
    final repo = await _open(tester);
    final chip = find.byKey(const ValueKey('room-reaction-🔥'));
    await _scrollDown(tester);
    await tester.tap(chip);
    await tester.pump();
    expect(repo.sent, ['🔥']);
    await tester.pump(const Duration(seconds: 5));
  });
}
