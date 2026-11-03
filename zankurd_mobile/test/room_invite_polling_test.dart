import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/room_invite.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/screens/home/room_invite_card.dart';

import 'support/widget_test_helpers.dart';

class _Repository extends TestMockZanKurdRepository {
  String? userId = 'account-a';
  @override
  String? get currentUserId => userId;
  int calls = 0;
  bool fail = false;
  bool receivedThrowOnError = false;
  Completer<List<RoomInvite>>? pending;
  List<RoomInvite> invites = [];

  @override
  Future<List<RoomInvite>> loadMyRoomInvites({
    bool throwOnError = false,
    String? inviteId,
  }) async {
    calls++;
    receivedThrowOnError = throwOnError;
    if (fail) {
      if (throwOnError) throw StateError('temporary network failure');
      return [];
    }
    return pending == null ? invites : pending!.future;
  }
}

final _invite = RoomInvite(
  id: 'new-invite',
  roomId: 'room',
  roomCode: 'code',
  inviterId: 'friend',
  inviterName: 'Rojda',
  categoryName: 'Test',
  playerCount: 2,
  maxPlayers: 4,
  createdAt: DateTime(2026, 10, 31),
);

Widget _host(
  _Repository repository, {
  bool visible = true,
  RemoteAvailability? availability,
}) => testShell(
  remoteAvailability: availability,
  child: Scaffold(
    body: RoomInviteCard(repository: repository, isVisible: visible),
  ),
);

void _background(WidgetTester tester) => tester.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.paused);

void _foreground(WidgetTester tester) => tester.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

void main() {
  for (final language in ['tr', 'ku']) {
    testWidgets('davet kategorisi $language dilinde, koşulları korunur', (
      tester,
    ) async {
      final repository = _Repository()
        ..invites = [
          RoomInvite(
            id: 'localized',
            roomId: 'room',
            roomCode: 'code',
            inviterId: 'friend',
            inviterName: 'Rojda',
            categoryName: 'Tevlihev',
            playerCount: 2,
            maxPlayers: 4,
            createdAt: DateTime(2026, 11, 1),
            entryFee: 25,
            questionCount: 5,
            secondsPerQuestion: 20,
          ),
        ];
      await tester.pumpWidget(
        testShell(
          languageProvider: LanguageProvider(initialLang: language),
          child: Scaffold(body: RoomInviteCard(repository: repository)),
        ),
      );
      await tester.pump();
      final meta = tester
          .widget<Text>(find.byKey(const ValueKey('room-invite-meta')))
          .data!;
      expect(meta, contains(language == 'tr' ? 'Karışık' : 'Tevlihev'));
      if (language == 'tr') expect(meta, isNot(contains('Tevlihev')));
      expect(meta, contains('2'));
      expect(meta, contains('4'));
      expect(find.textContaining('25'), findsWidgets);
      expect(repository.invites.single.categoryName, 'Tevlihev');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('aynı depoda hesap değişince ağ hatası eski daveti göstermez', (
    tester,
  ) async {
    final repository = _Repository()..invites = [_invite];
    await tester.pumpWidget(_host(repository));
    await tester.pump();
    expect(find.byKey(const ValueKey('room-invite-card')), findsOneWidget);
    repository
      ..userId = 'account-b'
      ..fail = true;
    await tester.pumpWidget(_host(repository));
    await tester.pump();
    expect(find.byKey(const ValueKey('room-invite-card')), findsNothing);
    expect(repository.calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('kilitli boş kart bağlantı dönünce hemen polling başlatır', (
    tester,
  ) async {
    final repository = _Repository();
    final availability = RemoteAvailability(reachable: false);
    await tester.pumpWidget(_host(repository, availability: availability));
    await tester.pump(const Duration(seconds: 120));
    expect(repository.calls, 0);
    availability.update(true);
    await tester.pump();
    expect(repository.calls, 1);
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(repository.calls, 2);
    await tester.pumpWidget(const SizedBox());
    availability.dispose();
  });

  testWidgets('FCM gelmeden yeni davet görünür; ağ hatası son kartı silmez', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_host(repository));
    await tester.pump();
    expect(find.byKey(const ValueKey('room-invite-card')), findsNothing);
    repository.invites = [_invite];
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(find.byKey(const ValueKey('room-invite-card')), findsOneWidget);
    expect(repository.receivedThrowOnError, isTrue);
    repository.fail = true;
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(find.byKey(const ValueKey('room-invite-card')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('gizli sekme arka plan ve dispose sonrası polling yapmaz', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_host(repository, visible: false));
    await tester.pump(const Duration(seconds: 120));
    expect(repository.calls, 0);
    await tester.pumpWidget(_host(repository));
    await tester.pump();
    expect(repository.calls, 1);
    _background(tester);
    await tester.pump(const Duration(seconds: 120));
    expect(repository.calls, 1);
    _foreground(tester);
    await tester.pump();
    expect(repository.calls, 2);
    await tester.pumpWidget(_host(repository, visible: false));
    await tester.pump(const Duration(seconds: 120));
    expect(repository.calls, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 120));
    expect(repository.calls, 2);
  });

  testWidgets('yavaş sorgu sürerken polling ikinci isteği başlatmaz', (
    tester,
  ) async {
    final repository = _Repository()..pending = Completer<List<RoomInvite>>();
    await tester.pumpWidget(_host(repository));
    await tester.pump(const Duration(seconds: 60));
    expect(repository.calls, 1);
    repository.pending!.complete([_invite]);
    await tester.pump();
    repository.pending = null;
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(repository.calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('üst rota açıkken polling durur geri dönüşte tazeler', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_host(repository));
    await tester.pump();
    final context = tester.element(find.byType(RoomInviteCard));
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('other-page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final coveredCalls = repository.calls;
    await tester.pump(const Duration(seconds: 120));
    expect(repository.calls, coveredCalls);
    Navigator.of(tester.element(find.text('other-page'))).pop();
    await tester.pumpAndSettle();
    expect(repository.calls, coveredCalls + 1);
    await tester.pumpWidget(const SizedBox());
  });
}
