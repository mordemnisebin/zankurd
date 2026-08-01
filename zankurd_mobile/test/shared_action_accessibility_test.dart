import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room_message.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/badge_collection_section.dart';
import 'package:zankurd_mobile/src/widgets/colorful_action_card.dart';
import 'package:zankurd_mobile/src/widgets/room_chat.dart';
import 'package:zankurd_mobile/src/widgets/styled_button.dart';

import 'support/widget_test_helpers.dart';

class _AccessibilityChatRepository extends MockZanKurdRepository {
  final messages = StreamController<List<RoomMessage>>.broadcast();

  @override
  String? get currentUserId => 'user1';

  @override
  Stream<List<RoomMessage>> subscribeRoomMessages(String roomId) =>
      messages.stream;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BadgeService.resetInstance();
  });

  testWidgets('colorful action card exposes one tappable semantic node', (
    tester,
  ) async {
    var tapped = false;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorfulActionCard(
            title: '1 vs 1',
            subtitle: 'Hemen oyna',
            icon: Icons.bolt_rounded,
            colors: const [AppTheme.playPink, Color(0xFFFF6B70)],
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pump();

    final data = tester
        .getSemantics(find.bySemanticsLabel('1 vs 1. Hemen oyna'))
        .getSemanticsData();
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(data.rect.height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel('1 vs 1. Hemen oyna'), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel('1 vs 1. Hemen oyna'));
    expect(tapped, isTrue);
    handle.dispose();
  });

  testWidgets('loading colorful action card is named and disabled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorfulActionCard(
            title: 'Günün Yarışması',
            icon: Icons.emoji_events_rounded,
            colors: const [AppTheme.brand, AppTheme.brandDeep],
            loading: true,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    final data = tester
        .getSemantics(find.bySemanticsLabel('Günün Yarışması'))
        .getSemanticsData();
    expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(data.label, 'Günün Yarışması');
    handle.dispose();
  });

  testWidgets('geometric gradient button exposes action and 44px target', (
    tester,
  ) async {
    var pressed = false;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GeometricGradientButton(
            label: 'Devam',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );
    await tester.pump();

    final data = tester
        .getSemantics(find.bySemanticsLabel('Devam'))
        .getSemanticsData();
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(data.rect.height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel('Devam'), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel('Devam'));
    expect(pressed, isTrue);
    handle.dispose();
  });

  testWidgets('loading geometric gradient button is disabled semantically', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GeometricGradientButton(
            label: 'Yükleniyor',
            onPressed: _noop,
            isLoading: true,
          ),
        ),
      ),
    );
    await tester.pump();

    final data = tester
        .getSemantics(find.bySemanticsLabel('Yükleniyor'))
        .getSemanticsData();
    expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(data.label, 'Yükleniyor');
    handle.dispose();
  });

  testWidgets('badge collection action keeps a 44px semantic target', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testShell(child: const Scaffold(body: BadgeCollectionSection())),
    );
    await tester.pumpAndSettle();

    final button = find.byType(TextButton);
    expect(button, findsOneWidget);
    final data = tester.getSemantics(button).getSemanticsData();
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(data.rect.width, greaterThanOrEqualTo(44));
    expect(data.rect.height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel('Tümü'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('room chat toggle is a single 44px tappable semantic node', (
    tester,
  ) async {
    final repository = _AccessibilityChatRepository();
    addTearDown(repository.messages.close);
    var toggled = false;
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: SizedBox(
            height: 320,
            child: RoomChat(
              repository: repository,
              roomId: 'room-1',
              visible: true,
              onToggle: () => toggled = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final semanticsNode = tester.getSemantics(find.bySemanticsLabel('Sohbet'));
    final data = semanticsNode.getSemanticsData();
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(data.rect.width, greaterThanOrEqualTo(44));
    expect(data.rect.height, greaterThanOrEqualTo(44));
    expect(find.bySemanticsLabel('Sohbet'), findsOneWidget);

    tester.semantics.tap(find.semantics.byLabel('Sohbet'));
    expect(toggled, isTrue);
    handle.dispose();
  });

  testWidgets('opponent chat message exposes one long press action', (
    tester,
  ) async {
    final repository = _AccessibilityChatRepository();
    addTearDown(repository.messages.close);
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: SizedBox(
            height: 320,
            child: RoomChat(
              repository: repository,
              roomId: 'room-1',
              visible: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    repository.messages.add([
      RoomMessage(
        id: 'message-1',
        roomId: 'room-1',
        senderId: 'opponent',
        senderName: 'Heval',
        senderAvatarColor: '#E94560',
        text: 'Slav heval!',
        createdAt: DateTime.utc(2026, 7, 13, 12),
      ),
    ]);
    await tester.pump();
    await tester.pump();
    final finder = find.bySemanticsLabel('Heval: Slav heval!');
    expect(finder, findsOneWidget);
    final semanticsNode = tester.getSemantics(finder);
    final semanticsData = semanticsNode.getSemanticsData();
    expect(semanticsData.hasAction(ui.SemanticsAction.longPress), isTrue);
    expect(semanticsData.rect.width, greaterThanOrEqualTo(44));
    expect(semanticsData.rect.height, greaterThanOrEqualTo(44));
    tester.semantics.longPress(find.semantics.byLabel('Heval: Slav heval!'));
    await tester.pumpAndSettle();
    expect(find.text('Mesajı bildir'), findsOneWidget);
    handle.dispose();
  });
}

void _noop() {}
